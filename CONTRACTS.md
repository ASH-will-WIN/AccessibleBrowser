# AccessibleBrowser Contracts

These are the initial cross-process contracts. Jac is the conceptual source of truth; Electron consumes JSON-compatible messages over the bridge.

All messages use camelCase and include schemaVersion: 1. Requests have a unique requestId. Page operations also include tabId and pageRevision.

## Shared message envelope

    {
      "schemaVersion": 1,
      "messageId": "msg_123",
      "type": "adaptation.request",
      "requestId": "req_123",
      "tabId": "tab_1",
      "pageRevision": 4,
      "payload": {}
    }

Responses reuse requestId. Events may omit requestId. Optional fields are omitted rather than inconsistently represented as null.

## Page snapshot

    PageSnapshot {
      snapshotId: string
      tabId: string
      pageRevision: number
      url: string
      origin: string
      title: string
      viewport: { width: number, height: number }
      scroll: { x: number, y: number }
      elements: ElementSummary[]
      sections: SectionSummary[]
      contentSummary: string
      pageMetadata: PageMetadata
    }

ElementSummary contains a stable per-snapshot elementId, role, accessible name, visible text, visibility, disabled state, viewport-relative bounds, and limited style/accessibility metadata. Element IDs are valid only for their exact pageRevision. Password values, form values, cookies, and secrets are never included. Snapshot text is bounded and truncated. Cross-origin iframes are deferred.

The pageRevision increments after navigation and major DOM changes. Electron rejects actions against stale revisions.

## Adaptation request

    AdaptationRequest {
      schemaVersion: 1
      requestId: string
      tabId: string
      pageRevision: number
      userRequest: string
      activeProfile: AccessibilityProfile
      page: PageSnapshot
      applicableRules: PreferenceRule[]
      mode: "deterministic" | "llm"
    }

## Adaptation plan

    AdaptationPlan {
      schemaVersion: 1
      planId: string
      requestId: string
      tabId: string
      pageRevision: number
      summary: string
      actions: PlanAction[]
      confidence: high | medium | low
      warnings: string[]
      suggestedScope: page | website | global | none
      status: ready | noOp | rejected
    }

Initial allowlisted action kinds:

- set_text_scale
- set_spacing
- set_contrast
- set_color_filter
- reduce_motion
- enlarge_targets
- hide_regions
- reading_mode
- focus_elements

Each action has an actionId, an explicit type, typed parameters, optional target element IDs, a human-readable reason, and a reversible flag. No action may contain arbitrary JavaScript, arbitrary CSS, raw selectors, shell commands, or unbounded browser control.

## Browser command

    BrowserCommand {
      schemaVersion: 1
      requestId: string
      tabId: string
      kind: new_tab | close_tab | switch_tab | back | forward
          | reload | navigate | scroll | zoom | search | read_page | stop_reading
      arguments: object
      requiresConfirmation: boolean
    }

The later voice layer maps speech to this allowlisted command shape. Search must distinguish web search, page search, and focusing a search field. Switch tab uses a stable tabId. Scroll and zoom arguments are bounded. Destructive or externally consequential actions must require confirmation.

`navigate` is used by the address bar and accepts a bounded `arguments.url` string. Electron permits only HTTP and HTTPS destinations and rejects embedded credentials and other protocols.

Command results use one of: accepted, completed, rejected, failed, cancelled.

## Accessibility profile and preference rules

    AccessibilityProfile {
      textScale?: number
      spacing?: string
      contrast?: string
      colorFilter?: string
      reduceMotion?: boolean
      enlargeTargets?: boolean
      readingFont?: string
      voiceEnabled?: boolean
    }

    PreferenceRule {
      setting: string
      value: unknown
      scope: page | website | global
      source: setup | voice | manual | learned
      explicitlyApproved: boolean
      createdAt: string
      updatedAt: string
    }

## Errors and undo

- Jac separates plan generation, validation, preview, apply, undo, and save.
- Electron validates the entire plan before applying it.
- A plan is applied transactionally; if an action fails, the plan is rolled back.
- Each adaptation application returns one undoToken or transactionId for the complete plan.
- Undo tokens are invalid after navigation or a major page revision.
- Unknown action kinds, invalid parameters, and stale element IDs are rejected before page mutation.
- Jac may ask the user whether to save a successful change; applying a change does not imply persistence.
- Preference precedence is global, then origin, then page; the more specific rule wins for the same setting.
- “Just for now” is not persisted. “This website” means the exact origin. Private browsing does not save preferences.

Structured errors include requestId, code, message, retryable, and optional failedActionId. Minimum codes are INVALID_MESSAGE, UNSUPPORTED_VERSION, STALE_PAGE_REVISION, TARGET_NOT_FOUND, INVALID_PLAN, UNSUPPORTED_ACTION, INVALID_PARAMETERS, APPLY_FAILED, UNDO_FAILED, LLM_UNAVAILABLE, TIMEOUT, PERMISSION_DENIED, and USER_CANCELLED.
