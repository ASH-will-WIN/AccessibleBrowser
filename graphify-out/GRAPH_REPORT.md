# Graph Report - AccessibleBrowser  (2026-09-27)

## Corpus Check
- 13 files · ~12,686 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 184 nodes · 211 edges · 15 communities
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `f04913a1`
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
- PHASE_1_WORKSTREAM_PROMPTS.md
- AccessibleBrowser
- Jac core
- Contributing
- AccessibleBrowser

## God Nodes (most connected - your core abstractions)
1. `AccessibleBrowser Decisions` - 10 edges
2. `Prompt A — Electron Browser Runtime` - 10 edges
3. `Prompt C — Accessibility Experience` - 10 edges
4. `Prompt B — Jac Brain and Persistence` - 9 edges
5. `Product experience requirements` - 9 edges
6. `createTab()` - 8 edges
7. `scripts` - 8 edges
8. `AccessibleBrowser Architecture` - 8 edges
9. `AccessibleBrowser Contracts` - 8 edges
10. `Build in this order` - 8 edges

## Surprising Connections (you probably didn't know these)
- `main()` --calls--> `spawnJac()`  [EXTRACTED]
  scripts/dev.js → scripts/jac.js

## Import Cycles
- None detected.

## Communities (15 total, 0 thin omitted)

### Community 0 - "package.json"
Cohesion: 0.11
Nodes (17): allowScripts, electron@38.8.6, description, devDependencies, electron, main, name, private (+9 more)

### Community 1 - "main.js"
Cohesion: 0.12
Nodes (29): { app, BrowserWindow, WebContentsView, ipcMain }, bridgeError(), bumpRevision(), callJac(), createTab(), createWindow(), crypto, executePageScript() (+21 more)

### Community 2 - "Prompt C — Accessibility Experience"
Cohesion: 0.11
Nodes (18): Accessibility quality bar, C1. First screen, C2. Accessibility control panel, C3. Preset profiles, C4. Natural-language request flow, C5. Apply, undo, and explanation states, C6. Preference saving flow, C7. Simple Mode (+10 more)

### Community 3 - "dev.js"
Cohesion: 0.17
Nodes (15): electron, main(), path, repositoryRoot, shutdown(), { spawn }, { spawnJac }, stopProcess() (+7 more)

### Community 4 - "Prompt A — Electron Browser Runtime"
Cohesion: 0.12
Nodes (16): A1. Stable browser shell, A2. Typed preload bridge, A3. Page snapshot extraction, A4. Allowlisted page adaptation, A5. Transaction and undo behavior, A6. Browser commands, Build in this order, Definition of done (+8 more)

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
Nodes (5): api, { contextBridge, ipcRenderer }, invoke(), jac(), jacApi

### Community 10 - "PHASE_1_WORKSTREAM_PROMPTS.md"
Cohesion: 0.25
Nodes (7): AccessibleBrowser Parallel Build Prompts, Final integration acceptance, How to use these prompts, Integration instructions for the project lead, Recommended integration order, Rules for resolving disagreements, Shared interface that must stay stable

### Community 11 - "AccessibleBrowser"
Cohesion: 0.29
Nodes (6): AccessibleBrowser, Current phase, Locked architecture, Phase 0 acceptance, Phase 1 ownership, Working rules

### Community 12 - "Jac core"
Cohesion: 0.29
Nodes (6): Jac core, Persistence, Planning and provider boundary, Public bridge surface, Service flow, Verification

### Community 13 - "Contributing"
Cohesion: 0.40
Nodes (4): Branches and ownership, Change discipline, Contributing, Local commands

### Community 14 - "AccessibleBrowser"
Cohesion: 0.50
Nodes (3): AccessibleBrowser, Local setup, Phase 0 status

## Knowledge Gaps
- **116 isolated node(s):** `{ app, BrowserWindow, WebContentsView, ipcMain }`, `path`, `crypto`, `{ pathToFileURL }`, `tabs` (+111 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 126 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `electron` connect `dev.js` to `package.json`, `main.js`, `preload.js`?**
  _High betweenness centrality (0.112) - this node is a cross-community bridge._
- **Why does `Prompt C — Accessibility Experience` connect `Prompt C — Accessibility Experience` to `PHASE_1_WORKSTREAM_PROMPTS.md`?**
  _High betweenness centrality (0.047) - this node is a cross-community bridge._
- **What connects `{ app, BrowserWindow, WebContentsView, ipcMain }`, `path`, `crypto` to the rest of the system?**
  _116 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `package.json` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._
- **Should `main.js` be split into smaller, more focused modules?**
  _Cohesion score 0.12043010752688173 - nodes in this community are weakly interconnected._
- **Should `Prompt C — Accessibility Experience` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._
- **Should `Prompt A — Electron Browser Runtime` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._