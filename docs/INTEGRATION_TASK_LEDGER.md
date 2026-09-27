# Integration Task Ledger

Baseline: `origin/integration` at `8ca941b` (2026-09-27 fetch).

The implementation target is `integration`; `main` remains stable and intentionally untouched.

| Task | Owner/worktree | Files | Dependency | Initial state | Evidence / next gate |
| --- | --- | --- | --- | --- | --- |
| W0 | Orchestrator + audit worker | `docs/INTEGRATION_AUDIT.md`, ledger | none | working | Baseline refs fetched; full feature matrix must distinguish live code, fixtures, and adapters. |
| W1 | Contract worker | `CONTRACTS.md`, Jac/Electron contract surfaces, focused tests | W0 evidence | partial | Shared schemas and stale/error behavior exist in several layers; compare exact field names and required fields. |
| W2 | Electron worker | `electron/**`, Electron fixtures/tests | W1 decisions | implemented, smoke-verified | Snapshot, allowlist, apply, rollback, undo, and browser-command validation merged; native shell proved snapshot → text-scale apply → undo. |
| W3 | Jac worker | `jac/**`, Jac tests | W1 decisions | implemented, unit-verified | Request/plan/revision validation, provider fallback, preference precedence, persistence approval, and bounded records merged; provider network mocking remains open. |
| W4 | UI worker | `frontend.jac`, `main.jac`, UI modules | W3 surface | implemented, runtime-unverified | Natural-language/deterministic requests use Jac/Electron; preview, apply, undo, stale/rejected/unavailable, explicit save, and voice-unavailable states are wired. |
| W5 | Test worker | `tests/**`, test scripts/docs | W1-W4 merges | implemented, fixture-verified | Failure matrix now has 27 passing fixture cases; native live integration remains a separate verification gate. |
| W6 | Demo/spec worker | `demo/**`, deterministic spec | none | implemented, static-verified | Added a repeatable local page, built-in demo server, and contract-matching action specification. |
| W7 | Docs/Graphify worker | `README.md`, runbook/docs, Graphify output | after code merges | in progress | README/runbook updated; Graphify must be refreshed against the final integrated tree before completion. |

## Verification snapshot

Static/Jac/fixture gates are green: Jac check exit 0, 11 Jac tests passed, 27 fixture contract tests passed, JavaScript syntax checks passed, and `git diff --check` passed. The native Electron shell smoke passed snapshot → text-scale apply → undo on `example.com`. The separate Jac experience window and UI-driven live plan/save path remain unverified; do not mark the vertical slice complete until that gap is closed.

## Baseline constraints

- Do not merge to `main` during this effort.
- Preserve the Jac/Electron ownership boundary and existing contract vocabulary.
- Preserve user-owned untracked `.codex/` and execution-plan files.
- No secrets, arbitrary JavaScript/CSS, shell commands, or silent preference saves.

## Required completion evidence

Each worker must report its changed files, focused tests, `git diff --check`, known gaps, and commit hash. The orchestrator will merge only verified work into `integration` in dependency order and rerun Jac, contract, integration, privacy, and Graphify checks.
