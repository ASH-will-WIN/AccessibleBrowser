# Integration Task Ledger

Baseline: `origin/integration` at `8ca941b` (2026-09-27 fetch).

The implementation target is `integration`; `main` remains stable and intentionally untouched.

| Task | Owner/worktree | Files | Dependency | Initial state | Evidence / next gate |
| --- | --- | --- | --- | --- | --- |
| W0 | Orchestrator + audit worker | `docs/INTEGRATION_AUDIT.md`, ledger | none | working | Baseline refs fetched; full feature matrix must distinguish live code, fixtures, and adapters. |
| W1 | Contract worker | `CONTRACTS.md`, Jac/Electron contract surfaces, focused tests | W0 evidence | partial | Shared schemas and stale/error behavior exist in several layers; compare exact field names and required fields. |
| W2 | Electron worker | `electron/**`, Electron fixtures/tests | W1 decisions | partial | `electron/main.js` has snapshot, allowlist, apply, rollback, undo symbols; prove real-page behavior and bridge wiring. |
| W3 | Jac worker | `jac/**`, Jac tests | W1 decisions | partial/implemented | `jac/core.jac`, provider, persistence, service, API, and tests exist; verify all are executable and used by live path. |
| W4 | UI worker | `frontend.jac`, `main.jac`, UI modules | W3 surface | partial/stubbed | `frontend.jac` contains a typed adapter and UI states; identify remaining development-adapter use and connect real APIs. |
| W5 | Test worker | `tests/**`, test scripts/docs | W1-W4 merges | partial | Fixture contract runner covers many failure cases but explicitly says live Electron/Jac/UI integration is not run. |
| W6 | Demo/spec worker | demo fixture/spec docs | none | unknown/partial | No dedicated demo file was found in the initial file inventory; inspect existing fixtures and add only deterministic, contract-matching assets. |
| W7 | Docs/Graphify worker | `README.md`, runbook/docs, Graphify output | after code merges | partial | README/docs exist; Graphify output is absent and must be refreshed only after final integration. |

## Verification snapshot

Static/Jac/fixture gates are green: Jac check exit 0, 11 Jac tests passed, 20 fixture contract tests passed, JavaScript syntax checks passed, and `git diff --check` passed. The native Electron shell smoke also passed snapshot → text-scale apply → undo on `example.com`. The separate Jac experience window and UI-driven live plan path remain unverified; do not mark the vertical slice complete until that gap is closed.

## Baseline constraints

- Do not merge to `main` during this effort.
- Preserve the Jac/Electron ownership boundary and existing contract vocabulary.
- Preserve user-owned untracked `.codex/` and execution-plan files.
- No secrets, arbitrary JavaScript/CSS, shell commands, or silent preference saves.

## Required completion evidence

Each worker must report its changed files, focused tests, `git diff --check`, known gaps, and commit hash. The orchestrator will merge only verified work into `integration` in dependency order and rerun Jac, contract, integration, privacy, and Graphify checks.
