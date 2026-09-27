# AccessibleBrowser Integration Audit

## Scope and baseline

This audit starts from `origin/integration` at `8ca941b`, fetched on 2026-09-27. The checkout is on local `integration`, which tracks `origin/integration`. `main` is stale relative to origin and is not an implementation target.

## Initial evidence matrix

| Feature | Status | Evidence | Verification still required |
| --- | --- | --- | --- |
| Jac conceptual contracts | implemented, unverified | `jac/core.jac` defines `PageSnapshot`, `AdaptationRequest`, `PlanAction`, `AdaptationPlan`, errors, results; `jac/core_test.jac` has focused tests | Run Jac checks and compare every field against `CONTRACTS.md`. |
| Deterministic planner | implemented, unverified | `jac/core.jac:289` `deterministic_plan`; tests for text scale/readability/no-op | Prove output reaches live UI/Electron path. |
| OpenAI provider boundary | implemented, unverified | `jac/provider.jac` contains bounded payload and provider functions; `.env.example` exists | Run unavailable/malformed cases without a key; verify no renderer exposure. |
| Local preference persistence | implemented, unverified | `jac/persistence.jac` contains file and graph store paths, precedence, explicit approval | Verify reload, scope precedence, declined save, and runtime store location. |
| Jac public API/service | implemented, unverified | `jac/api.jac` and `jac/service.jac` expose planning, explanation, apply/undo records, persistence, browser-command forwarding | Trace actual caller and bridge usage. |
| Electron shell | implemented, unverified | `electron/main.js` creates BrowserWindow/WebContentsView and loads Jac UI/page | Run startup and confirm real webpage surface. |
| Typed preload bridge | partial | `electron/preload.js` exposes named methods and event subscriptions | Compare names/payloads with UI and main IPC registration; verify no raw IPC escape hatch. |
| Page snapshot | implemented, unverified | `electron/main.js` has bounded `getPageSnapshot`, element IDs, revisions, metadata | Exercise on a local page and inspect redaction/bounds. |
| Allowlisted apply | partial | `electron/main.js` validates plan envelope/actions and has action handlers | Prove all claimed action kinds or narrow docs/status to implemented subset. |
| Transactional rollback | implemented, unverified | `electron/main.js` captures `applied`, rolls back on error, returns structured result | Force partial failure in a real Electron test. |
| Undo | implemented, unverified | `electron/main.js` stores one undo token and invalidates on revision changes | Prove visible restoration and stale-token rejection. |
| UI first screen | partial | `frontend.jac` defines `app` and controls | Verify it is the active UI and does not rely on a fixture for production path. |
| UI request/preview/apply/undo/save | partial/stubbed | `frontend.jac` has adapter methods and state fields; integration fixtures model the sequence | Trace each action to Jac API and preload; replace dev adapter in real path. |
| Voice unavailable state | implemented, unverified | UI/fixture symbols and `voice-unavailable.json` are present | Verify truthfully visible state in running UI. |
| Demo webpage | implemented, statically verified | `demo/accessible-demo.html`, `scripts/demo-server.js`, and deterministic action spec | Native Electron run against the local fixture remains part of live verification. |
| Integration tests | partial but hardened | `tests/integration/run-contract-tests.js` covers 27 fixture cases; README explicitly says live integration is not run | Run the native vertical slice without secrets. |
| Documentation/runbook | implemented | README, architecture, contracts, decisions, test README, action spec, and runbook match the current implementation | Reconcile any runtime findings after native verification. |
| Graphify evidence | refreshed | `graphify-out/graph.json` was updated after W1-W6 integration and queried for Jac→Electron flow | Keep generated artifacts aligned with final code changes. |

## Initial risks

1. Fixture adapter coverage may be mistaken for the live path.
2. Branch history contains the merged work, but `origin/integration` is the only authorized implementation baseline.
3. Contract names may diverge across `CONTRACTS.md`, Jac, preload, Electron, and UI.
4. Browser/page action validation must remain stricter than fixture validation.
5. Graph-backed persistence and runtime file persistence may not be the same path.

## Verification update (2026-09-27)

- `npm run jac:check`: passed (exit 0; Jac emitted existing `any`/intrinsic/undefined-name warnings).
- `env -u OPENAI_API_KEY -u OPENAI_MODEL node scripts/jac.js test jac/core_test.jac -v`: 11 passed.
- `node tests/integration/run-contract-tests.js`: 27 fixture contract cases passed; the harness explicitly reports live Electron/Jac/UI integration as not run.
- `node --check` passed for Electron and integration-test JavaScript.
- `git diff --check`: passed.
- Secrets scan found only the tracked `.env.example`, with empty values.
- With host permissions, `npm run dev` started Jac API on `8002`, a Vite/Jac UI on a dynamic local port, and Electron. The original fixed-port assumption caused `ERR_CONNECTION_REFUSED`; the launcher now prefers Jac's generated `.jac/client/.dev-port` marker and probes safe local fallbacks.
- Native Electron shell smoke passed on `example.com`: bridge ping was visible, snapshot returned a revision and bounded visible elements, the development text-scale plan changed the live page, and undo restored it.
- The separate Jac experience window was not counted as fully verified because the host exposed a stale/blank `chrome-error://chromewebdata/` window during native window switching; the shell and Jac RPC endpoint were healthy. This remains a release-blocking live-path verification gap, not a fixture success.

## Current classification (after W1-W6 integration)

### Implemented and verified

Jac checks and deterministic tests, the 27-case fixture failure matrix, secure Electron shell startup, bounded snapshot, allowlisted text-scale apply, transactional undo behavior, Jac request/plan/persistence hardening, canonical UI wiring, the deterministic local demo fixture, and the corrected dynamic Jac UI/API launcher path.

### Implemented but not fully verified

Full Jac experience window rendering, UI-driven Jac plan preview/apply/save path, all Electron action handlers beyond the text-scale smoke, graph-backed persistence through the running UI, and live stale/invalid-plan interaction. The Jac provider network boundary is unit-guarded but not integration-tested with a mock server.

### Stubbed or demo-only

The placeholder shell's `Text +25% (development fixture)` control; `read_page`/voice provider behavior; fixture adapter tests as runtime substitutes; any actions not proven in the native smoke.

### Blocked by external work

Native experience-window verification is currently blocked by the host's multiple/stale Electron window state; Jac requires host filesystem permissions for its embedded Postgres/cache during `npm run dev`. No repository or architecture blocker remains.

### Intentionally deferred

Production voice providers, advanced page restructuring, broad multi-tab UX, final visual polish, and promotion to `main`.
