# Integration-test harness

This directory prepares the first complete AccessibleBrowser vertical slice:

```text
real webpage → Electron snapshot → Jac request → structured plan
→ Jac validation → preview → Electron apply → live change
→ undo → explicit preference save
```

The harness is deliberately split into three evidence levels:

| Level | Files | What it proves |
| --- | --- | --- |
| Contract-only | `run-contract-tests.js`, `test-adapter.js` | JSON shapes, allowlist validation, error semantics, fixture transaction behavior |
| Fixture-based | `tests/fixtures/integration/*.json` | Representative valid and failure payloads derived from `CONTRACTS.md` |
| Live/manual | `cases.md` | What must be verified against the merged Electron, Jac, and accessibility UI implementation |

The fixture adapter is an in-memory test double. A passing command such as
`node tests/integration/run-contract-tests.js` is not evidence that the real
Electron bridge, Jac service, webpage, or UI works.

## Run

From the repository root:

```text
node tests/integration/run-contract-tests.js
```

The runner uses only Node built-ins, reads JSON fixtures, prints each result as
`PASS [fixture]` or `FAIL [fixture]`, and exits nonzero on failure. It does not
need npm packages, an API key, a network connection, or a running Electron
process.

## Test adapter contract

The future live adapter should expose the same conceptual operations as the
fixture adapter. Names may change to match the merged implementation; this
document is an adapter seam, not a request to add production exports.

```text
createSnapshot() -> {
  tabId, pageRevision, status, snapshot, changedState
}

createRequest({ userRequest, activeProfile, mode, applicableRules }) -> {
  requestId, tabId, pageRevision, status, request, changedState
}

requestPlan(request) -> {
  requestId, planId, tabId, pageRevision, status,
  plan | errorCode, retryable, changedState
}

validatePlan(plan, request) -> {
  requestId, planId, tabId, pageRevision, status,
  errorCode, retryable, failedActionId, changedState
}

previewPlan(plan, request) -> {
  requestId, planId, tabId, pageRevision, status,
  summary, confidence, warnings, actions, affectedTargetIds,
  applyAvailable, cancelAvailable, changedState: false
}

applyPlan(plan, request) -> {
  requestId, planId, tabId, pageRevision, status,
  undoToken, changed, changedState, errorCode, retryable
}

undoPlan(undoToken) -> {
  requestId, planId, tabId, pageRevision, status,
  restored, changedState, errorCode, retryable
}

savePreference(rule, explicitlyApproved) -> {
  requestId, tabId, pageRevision, status,
  preference, errorCode, retryable, changedState
}

loadPreferences() -> {
  requestId, tabId, pageRevision, status,
  preferences, changedState: false
}

runVoiceCommand(input) -> {
  requestId, planId, tabId, pageRevision, status,
  browserCommandSent, errorCode, retryable, changedState
}
```

Responses should carry the identifiers relevant to the operation. Errors must
use the structured error codes in `CONTRACTS.md`; no method should hide a stale
revision, invalid action, failed apply, or unavailable provider inside a
generic success response.

## Contract assumptions made by this harness

- The contract names action kinds in `type`, so fixtures use `type` rather than
  inventing a second `kind` field.
- The snapshot fixtures include `schemaVersion: 1` for consistency, although
  the `PageSnapshot` section does not require it explicitly.
- The harness treats text scale as bounded to `0.8..3`, spacing as
  `compact|comfortable|loose`, and other enumerated values as shown in
  `test-adapter.js`. These are test-safety assumptions and must be reconciled
  with the merged implementation before live tests are enabled.
- Element IDs are valid only for the exact `tabId` and `pageRevision` that
  produced them.
- Applying a plan does not save a preference. The preference fixture requires
  explicit approval and tests global → website → page specificity.
- Cross-origin iframe content is deferred and is represented only by metadata.
- The fixture adapter models rollback; it does not prove Electron DOM rollback.

## Live integration blocked until the following methods exist

This branch is based on `origin/main`, whose current Electron preload/main
surface exposes only `ping`. No live vertical-slice test was run.

The merged implementation must provide a narrow, JSON-compatible seam for:

1. Launching or connecting to Electron without changing the integration
   owner’s process.
2. Opening a deterministic local demo page and identifying the active `tabId`.
3. Retrieving a bounded page snapshot with `snapshotId` and `pageRevision`.
4. Sending an adaptation request through the real Jac path.
5. Receiving a structured plan from Jac, including LLM-unavailable behavior.
6. Validating a plan before Electron mutation.
7. Showing a non-mutating preview and cancel path in the UI.
8. Applying allowlisted actions transactionally through the typed bridge.
9. Inspecting the changed real webpage and returning `changedState`.
10. Undoing with a revision-bound `undoToken`.
11. Saving and loading an explicitly approved page, website, or global
    preference without persisting raw page content.
12. Forcing or observing stale revision, invalid action, and failed-apply
    rollback responses in a deterministic test page.
13. Reporting voice provider availability and ensuring no BrowserCommand is
    emitted when voice is unavailable.

The live checklist in `cases.md` is intentionally marked pending until these
seams are supplied by the integration owner. Do not convert fixture passes to
live passes in CI or in release notes.

## Fixture inventory

- `valid-page-snapshot.json` — bounded page snapshot without secrets.
- `valid-adaptation-request.json` — profile, rules, snapshot, and explicit mode.
- `ready-plan.json` — allowlisted reversible actions.
- `rejected-plan.json` — explanation-only rejection with no actions.
- `stale-request.json`, `stale-plan.json` — retryable revision mismatch.
- `invalid-actions.json` — unsupported, malformed, unsafe, and unbounded inputs.
- `failed-apply.json` — multi-action rollback with no partial-success claim.
- `llm-unavailable.json` — truthful planner failure with deterministic controls.
- `voice-unavailable.json` — no BrowserCommand and usable text/keyboard paths.
- `snapshot-failure.json` — structured snapshot error.
- `preferences.json` — explicit approval, scope precedence, and private browsing cases.
