# AccessibleBrowser Recovery Plan

Status: urgent live-runtime recovery

This plan corrects the assumption that the parallel execution plan was fully verified. The repository has substantial implementation and passing fixture tests, but the real Jac UI/Electron path is not reliable.

## 1. Confirmed failure

Native startup was run with host permissions on 2026-09-27.

Jac reported:

    Local: http://localhost:5173/
    API:   http://localhost:8006/

Electron then reported:

    Failed to load URL: http://127.0.0.1:8005/
    ERR_CONNECTION_REFUSED

Electron opens only the browser shell. The Jac accessibility experience does not load. The visible shell still shows the old development fixture control, which makes the application appear unchanged.

The current scripts/dev.js:

- reads a potentially stale .jac/client/.dev-port file;
- probes unrelated fallback ports;
- can select an old server instead of the Jac process it just started;
- does not reliably discover the current Jac UI port;
- does not pass the current Jac API port to Electron.

This is the first release-blocking issue.

## 2. What is not the primary issue

NVIDIA_API_KEY is not required for the deterministic accessibility path.

Without an API key:

- deterministic controls should create plans through Jac;
- Jac should validate those plans;
- Electron should apply and undo supported actions;
- free-form LLM requests should return a truthful LLM_UNAVAILABLE or deterministic fallback state.

The missing key may prevent LLM planning, but it does not explain why the Jac experience window fails to appear.

## 3. Recovery target

The first target is:

    npm run dev
      -> Jac UI starts on its actual port
      -> Jac API starts on its actual port
      -> Electron receives both URLs from that same Jac process
      -> browser shell opens
      -> Jac experience window opens
      -> deterministic control creates a preview
      -> apply changes the page
      -> undo restores the page

## 4. Parallel work lanes

Use isolated branches or worktrees. Only one lane may edit scripts/dev.js.

### Lane A: launcher and port discovery

Files:

- scripts/dev.js
- scripts/jac.js only if required
- launcher tests

Tasks:

1. Discover the UI and API URLs from the Jac process that was just started.
2. Do not select an arbitrary stale process from a fallback port list.
3. Prefer parsing Jac startup output or using a supported deterministic Jac CLI configuration.
4. Pass both ACCESSIBLE_BROWSER_JAC_URL and ACCESSIBLE_BROWSER_JAC_API_URL to Electron.
5. Ensure both endpoints come from the same Jac process.
6. Fail with a clear diagnostic if either endpoint is unavailable.
7. Preserve explicit environment overrides.
8. Add a regression test for the observed 5173/8006 versus stale 8005 failure.

Acceptance: Electron receives the current UI and API endpoints even when old candidate ports are occupied.

### Lane B: native startup smoke test

Files:

- tests/native or tests/integration
- test documentation
- package scripts only if necessary

Tasks:

1. Start Jac and Electron with the real launcher.
2. Verify both URLs respond.
3. Verify the shell opens.
4. Verify the Jac experience window loads a non-error URL.
5. Verify bridge ping.
6. Verify a deterministic request reaches Jac.
7. Verify preview, apply, and undo.
8. Capture useful logs on failure.

The existing 27 fixture cases remain valuable, but they are not live integration evidence.

### Lane C: Jac no-key deterministic path

Files:

- jac/core.jac
- jac/service.jac
- jac/provider.jac
- jac/persistence.jac
- Jac tests

Tasks:

1. Confirm deterministic controls do not call OpenAI.
2. Confirm profile loading works without NVIDIA_API_KEY.
3. Confirm a no-key deterministic plan contains supported actions.
4. Confirm LLM mode gives truthful unavailable or fallback behavior.
5. Confirm graph-backed state does not silently fail after startup.
6. Confirm provider errors do not block deterministic controls.

Do not add a fake API key or fake successful LLM response.

### Lane D: Jac experience window and UI

Files:

- electron/main.js only for window-loading fixes;
- frontend.jac;
- UI-specific tests and docs.

Tasks:

1. Confirm the experience window loads the exact URL passed by scripts/dev.js.
2. Confirm trusted-origin validation accepts that URL.
3. Confirm the UI calls the real typed bridge.
4. Confirm deterministic controls display a preview.
5. Confirm Apply, Undo, and explicit Save work.
6. Confirm bridge/API errors appear visibly.
7. Confirm the development adapter is not the production path.
8. Keep the existing visual system until a rendering failure requires a focused fix.

### Lane E: Electron page mutation

Files:

- electron/main.js
- electron/preload.js
- Electron tests

Tasks:

1. Verify snapshot creation on the demo page.
2. Verify text scale and spacing visibly change the page.
3. Verify changes are reversible.
4. Verify stale revisions reject before mutation.
5. Verify invalid actions reject before mutation.
6. Verify the UI receives apply and undo results.

The native shell already has smoke evidence for snapshot, text-scale apply, and undo. Re-run it after the launcher fix and focus on the UI-driven route.

### Lane F: visual and product polish

Dependency: Lane A and Lane D must first make the real Jac UI visible.

Do not redesign before confirming which window is actually running. The unchanged appearance is primarily explained by the Jac experience window failing to load and the shell showing its development fixture control.

After the live UI is visible, fix only:

- readable layout;
- clear page context;
- obvious request input;
- obvious preview, apply, and undo states;
- clear unavailable-provider message;
- keyboard focus and labels;
- removal or relabeling of development-only controls.

## 5. Merge order

1. Lane A launcher fix.
2. Lane B native smoke coverage.
3. Lane C no-key deterministic verification.
4. Lane D experience-window verification.
5. Lane E UI-driven Electron apply and undo.
6. Lane F focused polish.
7. Documentation and Graphify refresh.

After each merge run:

    npm run jac:check
    env -u NVIDIA_API_KEY -u NVIDIA_NIM_MODEL node scripts/jac.js test jac/core_test.jac -v
    node tests/integration/run-contract-tests.js
    node --check scripts/dev.js
    node --check electron/main.js
    node --check electron/preload.js
    git diff --check

## 6. Manual recovery verification

Run npm run demo and npm run dev.

Verify:

1. Jac prints a UI URL and an API URL.
2. Electron loads that exact UI URL, not a stale fallback port.
3. Two usable windows are present: browser shell and accessibility experience.
4. The shell loads http://127.0.0.1:4173/.
5. The Jac experience shows the live page title and URL.
6. Select a deterministic control such as larger text.
7. A preview appears before the page changes.
8. Apply changes the demo page.
9. Undo restores the previous appearance.
10. Save requires an explicit scope choice.
11. A free-form request without an API key gives an honest unavailable or fallback state.

## 7. Completion classification

Implemented and verified means:

- current UI URL is passed correctly;
- current API URL is passed correctly;
- experience window visibly loads;
- deterministic request reaches Jac through the UI;
- preview, apply, undo, and explicit save work through the UI;
- no-key behavior is truthful;
- native smoke passes.

Still incomplete may include live LLM planning without a key, production voice, advanced reading mode, broad multi-tab UX, and final visual polish.

The immediate job is to make the real application launch and prove the live path. Do not spend time on language percentages or visual redesign until that works.
