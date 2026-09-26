# AccessibleBrowser

AccessibleBrowser is a Jac-heavy, Electron-based Chromium browser that adapts webpages to a person's accessibility needs and remembers approved preferences.

## Locked architecture

    Jac UI + accessibility profile + preference graph + online LLM planner
                                  |
                             typed IPC bridge
                                  |
    Electron/Node Chromium shell + live webpage

- Jac owns product logic: profiles, preferences, memory, request interpretation, adaptation plans, explanations, and most first-party application code.
- Electron/Node owns browser-specific work: the desktop window, Chromium page host, tabs/navigation, DOM/page snapshots, safe plan application, undo, and IPC.
- The runtime model is an online OpenAI API model. Never commit API keys; use environment variables.
- Aim substantially above the 40% Jac requirement without moving Electron-specific code into Jac artificially.
- The model may choose only allowlisted, reversible browser/page actions. It must never return arbitrary JavaScript, CSS, shell commands, or unrestricted browser actions.
- Preferences are local-first. Save only approved rules, not raw page content by default.

## Current phase

Phase 0 is foundation only: repository instructions, architecture, contracts, toolchain, collaboration workflow, and a minimal Jac/Electron bridge smoke path. Do not implement the full accessibility product during Phase 0.

## Working rules

- Use the Graphify skill for codebase, architecture, and file-relationship questions. If graphify-out/graph.json exists, query it before rescanning.
- Use the Jac MCP server or bundled Jac documentation for Jac-specific questions. Confirm the MCP is actually visible before relying on it.
- Read ARCHITECTURE.md, CONTRACTS.md, and DECISIONS.md before changing a shared interface.
- Update DECISIONS.md when changing an agreed architectural decision or contract.
- Keep changes small and reversible. Do not redesign the architecture mid-task.
- Keep each contributor/AI session on its own branch or worktree. Do not edit the same files from multiple sessions.
- The project lead owns integration into main.

## Phase 1 ownership

- feat/electron-browser: Electron window, Chromium page host, preload bridge, page snapshots, DOM/CSS application, undo.
- feat/jac-core: Jac profiles, graph persistence, LLM planning, memory, contracts, explanations.
- feat/accessibility-experience: Jac UI, voice mode, settings, Simple Mode, demo experience.

## Phase 0 acceptance

The repository must have a reproducible start command, a documented Jac/Electron boundary, JSON-compatible contracts, a minimal bridge ping, a safe environment-variable path for OpenAI, and enough context for a new Codex session to continue without this conversation.
