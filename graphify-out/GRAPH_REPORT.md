# Graph Report - AccessibleBrowser  (2026-09-27)

## Corpus Check
- 36 files · ~28,156 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 351 nodes · 441 edges · 21 communities
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 13 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c7719516`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- package.json
- main.js
- Prompt C — Accessibility Experience
- dev.js
- Prompt A — Electron Browser Runtime
- Prompt B — Jac Brain and Persistence
- AccessibleBrowser Decisions
- AccessibleBrowser Architecture
- AccessibleBrowser Contracts
- preload.js
- test-adapter.js
- AccessibleBrowser
- Jac core
- Contributing
- Vertical-slice runbook
- AccessibleBrowser Fast-Track Completion Plan
- Core vertical slice
- AccessibleBrowser Integration Audit
- demo-server.js
- Integration-test harness
- Integration Task Ledger

## God Nodes (most connected - your core abstractions)
1. `AccessibleBrowser Fast-Track Completion Plan` - 16 edges
2. `FixtureAdapter` - 15 edges
3. `clone()` - 14 edges
4. `metadata()` - 12 edges
5. `Core vertical slice` - 11 edges
6. `AccessibleBrowser Decisions` - 10 edges
7. `Prompt A — Electron Browser Runtime` - 10 edges
8. `Prompt C — Accessibility Experience` - 10 edges
9. `scripts` - 9 edges
10. `7. Workstream map` - 9 edges

## Surprising Connections (you probably didn't know these)
- `newAdapter()` --calls--> `FixtureAdapter`  [EXTRACTED]
  tests/integration/run-contract-tests.js → tests/integration/test-adapter.js
- `main()` --calls--> `spawnJac()`  [EXTRACTED]
  scripts/dev.js → scripts/jac.js

## Import Cycles
- None detected.

## Communities (21 total, 0 thin omitted)

### Community 0 - "package.json"
Cohesion: 0.11
Nodes (18): allowScripts, electron@38.8.6, description, devDependencies, electron, main, name, private (+10 more)

### Community 1 - "main.js"
Cohesion: 0.11
Nodes (33): ACTION_KINDS, { app, BrowserWindow, WebContentsView, ipcMain }, bridgeError(), BROWSER_COMMAND_KINDS, bumpRevision(), callJac(), commandError(), createTab() (+25 more)

### Community 2 - "Prompt C — Accessibility Experience"
Cohesion: 0.11
Nodes (18): Accessibility quality bar, C1. First screen, C2. Accessibility control panel, C3. Preset profiles, C4. Natural-language request flow, C5. Apply, undo, and explanation states, C6. Preference saving flow, C7. Simple Mode (+10 more)

### Community 3 - "dev.js"
Cohesion: 0.14
Nodes (19): electron, fs, isJacUi(), jacDevPortFile, jacUiCandidates(), main(), path, repositoryRoot (+11 more)

### Community 4 - "Prompt A — Electron Browser Runtime"
Cohesion: 0.08
Nodes (23): A1. Stable browser shell, A2. Typed preload bridge, A3. Page snapshot extraction, A4. Allowlisted page adaptation, A5. Transaction and undo behavior, A6. Browser commands, AccessibleBrowser Parallel Build Prompts, Build in this order (+15 more)

### Community 5 - "Prompt B — Jac Brain and Persistence"
Cohesion: 0.12
Nodes (16): B1. Jac conceptual types, B2. Deterministic request path first, B3. OpenAI provider boundary, B4. Plan validation and explanation, B5. Profile and preference persistence, B6. UI and Electron service boundary, B7. Development fixtures, Build in this order (+8 more)

### Community 6 - "AccessibleBrowser Decisions"
Cohesion: 0.18
Nodes (10): AccessibleBrowser Decisions, D001 — Use Electron as the Chromium host, D002 — Keep Jac central, D003 — Use an online OpenAI model, D004 — Plans use an allowlist, D005 — Store preferences locally first, D006 — Phase 0 is foundation only, D007 — Address-bar navigation uses the constrained browser command (+2 more)

### Community 7 - "AccessibleBrowser Architecture"
Cohesion: 0.22
Nodes (8): AccessibleBrowser Architecture, Data flow, Electron/Node owns, Jac owns, Persistence and privacy, Phase 0 scope, Product boundary, Safety boundary

### Community 8 - "AccessibleBrowser Contracts"
Cohesion: 0.22
Nodes (8): Accessibility profile and preference rules, AccessibleBrowser Contracts, Adaptation plan, Adaptation request, Browser command, Errors and undo, Page snapshot, Shared message envelope

### Community 9 - "preload.js"
Cohesion: 0.36
Nodes (7): api, { contextBridge, ipcRenderer }, invoke(), isObject(), jac(), jacApi, onPageChanged()

### Community 10 - "test-adapter.js"
Cohesion: 0.09
Nodes (31): adapter, assert, assertErrorShape(), {
  FixtureAdapter,
  BROWSER_COMMAND_KINDS,
  parseLlmPlanResponse,
  preferenceRank,
  resolvePreferences,
  validateBrowserCommand,
  validatePlan,
  validatePreference,
  validateRequest,
  validateSnapshot,
}, fixtures, fixturesRoot, fs, newAdapter() (+23 more)

### Community 11 - "AccessibleBrowser"
Cohesion: 0.29
Nodes (6): AccessibleBrowser, Current phase, Locked architecture, Phase 0 acceptance, Phase 1 ownership, Working rules

### Community 12 - "Jac core"
Cohesion: 0.29
Nodes (6): Jac core, Persistence, Planning and provider boundary, Public bridge surface, Service flow, Verification

### Community 13 - "Contributing"
Cohesion: 0.40
Nodes (4): Branches and ownership, Change discipline, Contributing, Local commands

### Community 14 - "Vertical-slice runbook"
Cohesion: 0.15
Nodes (10): Deterministic accessibility action specification, Deterministic fallback and unavailable provider, Configuration and safety, Integration procedure, Start, Verify, Vertical-slice runbook, AccessibleBrowser (+2 more)

### Community 15 - "AccessibleBrowser Fast-Track Completion Plan"
Cohesion: 0.04
Nodes (45): 10. Worker prompt template, 11. Verification commands, 12. Manual acceptance script, 13. Conflict-resolution policy, 14. What can remain rudimentary, 15. Final handoff checklist, 1. Executive objective, 2. Verified repository state (+37 more)

### Community 16 - "Core vertical slice"
Cohesion: 0.09
Nodes (22): Core vertical slice, Failure and recovery paths, INT-001 — Application launch, INT-002 — Real webpage opened, INT-003 — Snapshot captured, INT-004 — Request submitted through Jac, INT-005 — Jac plan returned, INT-006 — Preview displayed without mutation (+14 more)

### Community 17 - "AccessibleBrowser Integration Audit"
Cohesion: 0.17
Nodes (11): AccessibleBrowser Integration Audit, Blocked by external work, Current classification (after W1-W6 integration), Implemented and verified, Implemented but not fully verified, Initial evidence matrix, Initial risks, Intentionally deferred (+3 more)

### Community 18 - "demo-server.js"
Cohesion: 0.29
Nodes (6): demoPath, fs, http, path, port, server

### Community 19 - "Integration-test harness"
Cohesion: 0.29
Nodes (6): Contract assumptions made by this harness, Fixture inventory, Integration-test harness, Live integration blocker, Run, Test adapter contract

### Community 20 - "Integration Task Ledger"
Cohesion: 0.40
Nodes (4): Baseline constraints, Integration Task Ledger, Required completion evidence, Verification snapshot

## Knowledge Gaps
- **214 isolated node(s):** `{ app, BrowserWindow, WebContentsView, ipcMain }`, `path`, `crypto`, `{ pathToFileURL }`, `ACTION_KINDS` (+209 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 230 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `electron` connect `dev.js` to `package.json`, `main.js`, `preload.js`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **What connects `{ app, BrowserWindow, WebContentsView, ipcMain }`, `path`, `crypto` to the rest of the system?**
  _214 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `package.json` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._
- **Should `main.js` be split into smaller, more focused modules?**
  _Cohesion score 0.11092436974789915 - nodes in this community are weakly interconnected._
- **Should `Prompt C — Accessibility Experience` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._
- **Should `dev.js` be split into smaller, more focused modules?**
  _Cohesion score 0.1380952380952381 - nodes in this community are weakly interconnected._
- **Should `Prompt A — Electron Browser Runtime` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._