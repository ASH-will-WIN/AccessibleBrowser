# AccessibleBrowser

An accessibility-first Chromium browser that adapts webpages to a person's needs, remembers approved preferences, and uses voice and natural-language requests to make the web easier to use.

## Phase 0 status

The repository is being prepared for a Jac-heavy Electron implementation.

- Jac owns product logic, profiles, preferences, memory, and adaptation planning.
- Electron/Node owns the Chromium host and safe page mutations.
- NVIDIA NIM API calls are online and configured through environment variables.

Read these before contributing:

- AGENTS.md — context and AI coding rules
- ARCHITECTURE.md — component responsibilities and data flow
- CONTRACTS.md — Jac/Electron message shapes
- DECISIONS.md — locked decisions and deferred choices
- PHASE_1_WORKSTREAM_PROMPTS.md — copy-paste briefs for the three parallel build sessions

## Local setup

Requirements: Node.js/npm, Jac `0.37.23`, and the Electron package installed by `npm install`.

1. Copy `.env.example` to `.env`, add your `NVIDIA_API_KEY`, and optionally change `NVIDIA_NIM_MODEL`. Never commit the populated file.
2. Install JavaScript dependencies with `npm install`.
3. Run `npm run dev`. This starts Jac, waits for its dev server, opens the Jac UI inside Electron, and exercises the preload bridge on that page.
4. Run `npm run jac:check` for Jac checks and `npm run graphify` to refresh local architecture evidence.

For a deterministic local page, run `npm run demo` and open `http://127.0.0.1:4173/` in the active Electron page. See [the vertical-slice runbook](docs/VERTICAL_SLICE_RUNBOOK.md) and [the deterministic action specification](docs/DETERMINISTIC_ACTION_SPEC.md) for the exact verification sequence.

The Jac RPC API uses local port `8002`. The Jac UI dev server normally uses `8000`, but Jac may move it when that port is occupied; `npm run dev` detects the emitted UI/API URLs and passes them to Electron. Set `ACCESSIBLE_BROWSER_JAC_URL` and `ACCESSIBLE_BROWSER_JAC_API_URL` to override these endpoints explicitly. NVIDIA NIM uses `https://integrate.api.nvidia.com/v1/chat/completions`; configure its base URL and model with `NVIDIA_NIM_BASE_URL` and `NVIDIA_NIM_MODEL`.

The native smoke path is available in the Electron shell: load the current page, request a bounded snapshot, preview an allowlisted plan, apply it, and undo it. Fixture tests cover stale, invalid, unavailable-provider, rollback, privacy, and explicit-save failures; the full Jac experience window and UI-driven save flow remain subject to native runtime verification.

The Electron shell can also be launched separately with `npm run electron` after `npm run jac:dev` is running.

The exact user-facing accessibility features are intentionally deferred to Phase 1.
