# Accessa

Accessa is an accessibility-first Chromium browser. The basic idea is pretty simple: you tell it what would make a page easier to use, it figures out a safe set of changes, and you get to decide whether those changes should be remembered.

It is still a work in progress, but the main pieces are here. Accessa has a Jac planner, an Electron browser shell, an accessibility panel, deterministic quick actions, natural-language planning through NVIDIA NIM, reversible page changes, and saved preferences.

## How it works

Accessa is split into two main parts:

- Jac owns the product logic: profiles, preference memory, planning, validation, and explanations.
- Electron/Node owns the actual browser: tabs, navigation, page snapshots, CSS/DOM changes, undo, and the IPC bridge.

The LLM does not get to run arbitrary code. It can only return structured, allowlisted accessibility actions. Electron validates those actions before changing the live page.

The normal flow looks like this:

```text
webpage
  → Electron snapshot
  → Jac request
  → deterministic or NVIDIA NIM plan
  → user review
  → Electron applies reversible changes
  → optional preference save
```

Saved preferences can be scoped to one page, one website, or all websites. Once a preference is explicitly approved, Accessa can reuse it automatically on matching pages without calling the LLM again.

## Run it locally

You need Node/npm, Jac `0.37.23`, and the Electron dependencies.

```bash
npm install
cp .env.example .env
npm run dev
```

If you want the NVIDIA NIM planner, add your key to `.env`:

```env
NVIDIA_API_KEY=your_key_here
NVIDIA_NIM_MODEL=meta/llama-3.1-8b-instruct
```

Never commit `.env` or an API key.

There is also a deterministic demo page:

```bash
npm run demo
```

Then open `http://127.0.0.1:4173/` in the browser shell.

## Useful checks

```bash
npm run jac:check
node tests/integration/run-contract-tests.js
git diff --check
```

The contract tests cover snapshots, planning, invalid actions, stale revisions, rollback, undo, provider failures, voice unavailability, privacy, and preference persistence.

## Current state

The browser shell has normal browser basics like tabs, navigation, an address bar, Google search fallback, page snapshots, and an accessibility panel. Quick actions can be combined and applied together. Natural-language requests can produce multi-action plans, and applied LLM settings can be saved as Jac preferences.

The part that still needs regular attention is live end-to-end testing in Electron. The local contract tests are useful, but they do not replace opening the app and checking the real page, planner, apply, undo, and save flow.

## Project notes

If you are working on the project, start with these files:

- [AGENTS.md](AGENTS.md) — project rules and architecture boundaries
- [ARCHITECTURE.md](ARCHITECTURE.md) — how the pieces fit together
- [CONTRACTS.md](CONTRACTS.md) — Jac/Electron message contracts
- [DECISIONS.md](DECISIONS.md) — decisions we are keeping locked
- [docs/VERTICAL_SLICE_RUNBOOK.md](docs/VERTICAL_SLICE_RUNBOOK.md) — live verification steps
- [docs/DETERMINISTIC_ACTION_SPEC.md](docs/DETERMINISTIC_ACTION_SPEC.md) — supported accessibility actions

The repo is intentionally Jac-heavy, while Electron stays focused on browser-specific work. If a change crosses that boundary, update the relevant contract and document the decision.
