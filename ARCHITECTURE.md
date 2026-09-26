# AccessibleBrowser Architecture

## Product boundary

AccessibleBrowser is a true Chromium wrapper with a Jac-heavy product layer. The browser has two cooperating processes:

1. Jac product layer — profile state, preference graph, request interpretation, LLM planning, explanations, and user-facing accessibility experience.
2. Electron/Node browser layer — Chromium window, navigation, tabs, page inspection, safe page changes, undo, and the narrow IPC bridge.

## Data flow

    User request or saved profile
              |
              v
    Jac builds an adaptation request
              |
              v
    Online OpenAI model chooses an allowlisted plan
              |
              v
    Jac validates and explains the plan
              |
              v
    Typed IPC message to Electron
              |
              v
    Electron applies reversible DOM/CSS/browser actions
              |
              v
    User reviews, undoes, refines, or approves persistence

## Jac owns

- Accessibility profile and preference concepts
- Global, website, and page-scoped rules
- Preference persistence and approved change history
- Adaptation request interpretation
- Page understanding and plan generation
- Plan validation and human-readable explanations
- OpenAI API integration behind a small provider boundary
- Future Jac UI and voice interaction logic where practical

## Electron/Node owns

- Desktop application lifecycle
- Chromium page hosting
- Address bar, navigation, and tab controls
- Preload script and IPC transport
- DOM/accessibility snapshot extraction
- Applying allowlisted actions to the live page
- Capturing reversible state for undo
- Browser-level actions such as back, forward, reload, and tab operations

## Safety boundary

The online model returns data, not executable code. Electron accepts only validated actions named in CONTRACTS.md. Every page mutation must be attributable to a plan action and reversible where practical.

## Persistence and privacy

The initial product is single-user and local-first. Store approved accessibility rules and profile settings locally through the Jac layer. Do not persist raw page contents by default. Online model requests may contain a minimal page snapshot; the UI and documentation must make that boundary clear.

## Phase 0 scope

Phase 0 creates the project boundary and a bridge smoke path. It does not implement final accessibility transformations, full voice mode, Simple Mode, or the final demonstration page.
