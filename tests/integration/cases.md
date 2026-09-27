# Live Electron/Jac/UI integration checklist

Status for this branch: **BLOCKED / NOT RUN**. These are manual and live
integration cases, not claims that the fixture harness has passed the real
vertical slice. Use a deterministic local demo page only. For every case,
record a visible or structured artifact and fill in the pass/fail field.

## Core vertical slice

### INT-001 — Application launch

- Preconditions: Merged Electron, Jac, and UI branches are running; no unrelated Electron process is using the test profile.
- Action: Launch with the documented local development command.
- Expected: A visible Electron window opens and the Jac UI reports a connected bridge without exposing Node APIs to the webpage.
- Evidence: Launch command, app log excerpt, screenshot of the window.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-002 — Real webpage opened

- Preconditions: Electron is running with the local deterministic demo page available.
- Action: Open the demo page in the active tab.
- Expected: The real Chromium webpage is visible, has a stable `tabId`, and reports navigation success.
- Evidence: Demo URL, tab identifier, screenshot.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-003 — Snapshot captured

- Preconditions: INT-002 passed.
- Action: Request the active page snapshot.
- Expected: A bounded snapshot contains snapshot ID, tab ID, page revision, URL/origin, title, viewport, sections, element summaries, and no secrets or form values.
- Evidence: Redacted JSON snapshot and captured revision.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-004 — Request submitted through Jac

- Preconditions: INT-003 passed; active accessibility profile is loaded.
- Action: Submit “Make this page easier to read and make the buttons easier to click.”
- Expected: Jac receives a request containing request ID, current snapshot, active profile, applicable rules, and explicit mode.
- Evidence: Redacted request envelope and Jac log/trace.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-005 — Jac plan returned

- Preconditions: INT-004 passed; planner is available or deterministic mode is selected.
- Action: Request a plan.
- Expected: A structured ready plan contains plan ID, request ID, tab ID, page revision, summary, confidence, warnings, scope, and at least one allowlisted action.
- Evidence: Redacted plan JSON and Jac validation result.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-006 — Preview displayed without mutation

- Preconditions: INT-005 returned a ready plan.
- Action: Open the plan preview and compare the page before and after opening it.
- Expected: Preview lists every action, affected targets, summary, confidence, warnings, Apply, and Cancel; webpage DOM/visual state is unchanged.
- Evidence: Before/after DOM or screenshots and preview capture.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-007 — Plan applied to the real page

- Preconditions: INT-006 passed and Apply is visible.
- Action: Select Apply.
- Expected: The plan is revalidated, only allowlisted actions run, the UI waits for the completed response, and the real webpage visibly changes.
- Evidence: Apply response with status/undo token, before/after screenshot, changed-state summary.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-008 — Undo completed

- Preconditions: INT-007 returned a successful undo token.
- Action: Select Undo.
- Expected: The prior webpage state is restored; the UI reports completion and the token cannot be reused.
- Evidence: Before/apply/undo screenshots or DOM comparison and undo response.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-009 — Preference approval and website save

- Preconditions: INT-007 completed; a preference proposal is shown.
- Action: Choose the exact website scope and explicitly approve it.
- Expected: Apply did not save automatically; the saved rule includes setting, value, scope, source, approval, and timestamps, and no raw page content is persisted.
- Evidence: Approval UI, saved rule JSON, local-store inspection with sensitive content redacted.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-010 — Reload and reconsider saved preference

- Preconditions: INT-009 saved a website rule for the demo origin.
- Action: Reload the page and request applicable preferences.
- Expected: The approved website rule is rediscovered for the exact origin and is not silently applied to another origin.
- Evidence: Reload event, rule lookup response, second-origin control check.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

## Failure and recovery paths

### INT-011 — Stale revision rejected

- Preconditions: Capture a snapshot and plan at revision N.
- Action: Navigate or make a major deterministic page change to reach N+1, then submit the N plan.
- Expected: Apply is rejected before mutation with `STALE_PAGE_REVISION`, `retryable: true`, and a refresh/retry message.
- Evidence: Revisions N/N+1, rejection response, unchanged-page screenshot.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-012 — Invalid plan/action rejected

- Preconditions: A valid page at a known revision.
- Action: Try unknown action kind, missing parameter, invalid numeric value, stale target ID, arbitrary JavaScript/CSS, shell command, raw selector, and unbounded browser operation.
- Expected: Each is rejected before page mutation with a structured code and failed action ID; the UI gives a clear recovery message.
- Evidence: One response per invalid case and before/after state comparison.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-013 — LLM unavailable

- Preconditions: Disable or isolate the online planner without changing the deterministic controls.
- Action: Submit an LLM-mode request.
- Expected: The user sees `LLM_UNAVAILABLE`, truthful retry guidance, usable deterministic controls, and no fake LLM plan or page mutation.
- Evidence: UI screenshot, structured error, unchanged page state.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-014 — Failed apply rolls back

- Preconditions: Test seam can force the second action of a two-action plan to fail.
- Action: Apply the plan.
- Expected: Earlier actions are rolled back, result is failed/rejected with `APPLY_FAILED`, failed action is identified, and the UI does not claim success.
- Evidence: Injected failure setup, apply response, before/after/rollback state comparison.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-015 — Voice provider unavailable

- Preconditions: Voice provider is unavailable or explicitly disabled.
- Action: Enter voice mode and issue a command.
- Expected: Voice becomes unavailable with a recovery message; no BrowserCommand is sent; keyboard and text controls remain usable; development-only text adapter is labeled.
- Evidence: UI screenshot, provider state, bridge/message log showing no command.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

## Preference and voice safety details

### INT-016 — Preference scopes and private browsing

- Preconditions: Have global, exact-origin website, and exact-page rules plus a private-browsing context.
- Action: Resolve the same setting at each scope, decline a save, and repeat in private browsing.
- Expected: Most-specific rule wins; “No thanks” stores nothing; private browsing persists nothing; raw page content is absent.
- Evidence: Resolution results, store before/after, private-context inspection.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-017 — Voice command mapping and confirmation

- Preconditions: Voice provider is available, or use the explicitly labeled development-only text adapter.
- Action: Issue one allowlisted command, one unsupported command, and one destructive/external command.
- Expected: Allowlisted input maps to the correct `BrowserCommand`; unsupported input is rejected; destructive input requires confirmation.
- Evidence: Input transcript, mapped command, confirmation UI/result.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:

### INT-018 — Cancel path

- Preconditions: A ready plan is previewed.
- Action: Choose Cancel instead of Apply.
- Expected: The preview closes, the webpage remains unchanged, no undo token is created, and no preference proposal is treated as approved.
- Evidence: Cancel response, unchanged state comparison, preference-store check.
- Pass/fail: [ ] Pass  [ ] Fail
- Notes:
