# Contributing

## Branches and ownership

- `main` is the stable integration branch.
- The project lead owns merges into `main`.
- `feat/electron-browser` owns the Electron window, Chromium page host, preload bridge, snapshots, DOM/CSS operations, and undo.
- `feat/jac-core` owns Jac profiles, graph persistence, LLM planning, contracts, memory, and explanations.
- `feat/accessibility-experience` owns the Jac UI, voice interaction, settings, Simple Mode, and demo experience.

Use a separate branch and preferably a separate worktree for every contributor or AI session. Never have two sessions edit the same files at the same time. Keep commits small and focused; merge the Phase 0 foundation before starting Phase 1 branches.

## Local commands

```text
npm install
npm run dev          # starts Jac, waits for port 8000, then opens Electron
npm run jac:check    # checks the Jac project
npm run graphify     # refreshes local graphify-out/ artifacts
```

`npm run electron` launches only the Electron shell and expects a Jac server at `ACCESSIBLE_BROWSER_JAC_URL`. `npm run jac:dev` starts the Jac app by itself.

## Change discipline

Read `ARCHITECTURE.md`, `CONTRACTS.md`, and `DECISIONS.md` before changing a shared boundary. If an agreed interface changes, update `DECISIONS.md` in the same change. Use Graphify for architecture and codebase questions, and confirm the Jac MCP is available before relying on it for Jac-specific documentation.
