# AccessibleBrowser

An accessibility-first Chromium browser that adapts webpages to a person's needs, remembers approved preferences, and uses voice and natural-language requests to make the web easier to use.

## Phase 0 status

The repository is being prepared for a Jac-heavy Electron implementation.

- Jac owns product logic, profiles, preferences, memory, and adaptation planning.
- Electron/Node owns the Chromium host and safe page mutations.
- OpenAI API calls are online and configured through environment variables.

Read these before contributing:

- AGENTS.md — context and AI coding rules
- ARCHITECTURE.md — component responsibilities and data flow
- CONTRACTS.md — Jac/Electron message shapes
- DECISIONS.md — locked decisions and deferred choices

## Local setup

Requirements: Node.js/npm, Jac `0.37.23`, and the Electron package installed by `npm install`.

1. Copy `.env.example` to `.env` and add the runtime model configuration when LLM features are being developed. Never commit the populated file.
2. Install JavaScript dependencies with `npm install`.
3. Run `npm run dev`. This starts Jac, waits for its dev server, opens the Jac UI inside Electron, and exercises the preload bridge on that page.
4. Run `npm run jac:check` for Jac checks and `npm run graphify` to refresh local architecture evidence.

The Electron shell can also be launched separately with `npm run electron` after `npm run jac:dev` is running.

The exact user-facing accessibility features are intentionally deferred to Phase 1.
