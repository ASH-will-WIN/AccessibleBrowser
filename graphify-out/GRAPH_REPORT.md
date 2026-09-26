# Graph Report - AccessibleBrowser  (2026-09-26)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 34 nodes · 36 edges · 4 communities
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- package.json
- main.js
- scripts
- dev.js

## God Nodes (most connected - your core abstractions)
1. `scripts` - 8 edges
2. `main()` - 4 edges
3. `electron` - 4 edges
4. `shutdown()` - 3 edges
5. `stopProcess()` - 2 edges
6. `waitForJac()` - 2 edges
7. `allowScripts` - 2 edges
8. `electron@38.8.6` - 1 edges
9. `electron` - 1 edges
10. `main` - 1 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (4 total, 0 thin omitted)

### Community 0 - "package.json"
Cohesion: 0.20
Nodes (9): allowScripts, electron@38.8.6, description, devDependencies, electron, main, name, private (+1 more)

### Community 1 - "main.js"
Cohesion: 0.25
Nodes (4): { app, BrowserWindow, ipcMain }, path, { contextBridge, ipcRenderer }, electron

### Community 2 - "scripts"
Cohesion: 0.25
Nodes (8): scripts, dev, electron, format:jac, graphify, jac:check, jac:dev, start

### Community 3 - "dev.js"
Cohesion: 0.36
Nodes (7): main(), path, repositoryRoot, shutdown(), { spawn }, stopProcess(), waitForJac()

## Knowledge Gaps
- **20 isolated node(s):** `electron@38.8.6`, `description`, `electron`, `main`, `name` (+15 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 22 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `electron` connect `main.js` to `package.json`, `dev.js`?**
  _High betweenness centrality (0.640) - this node is a cross-community bridge._
- **Why does `scripts` connect `scripts` to `package.json`?**
  _High betweenness centrality (0.384) - this node is a cross-community bridge._
- **Why does `main()` connect `dev.js` to `main.js`?**
  _High betweenness centrality (0.346) - this node is a cross-community bridge._
- **What connects `electron@38.8.6`, `description`, `electron` to the rest of the system?**
  _20 weakly-connected nodes found - possible documentation gaps or missing edges._