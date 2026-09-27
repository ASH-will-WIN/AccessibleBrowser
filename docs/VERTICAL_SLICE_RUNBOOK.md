# Vertical-slice runbook

All implementation work belongs on `integration`, based on `origin/integration`. `main` is the stable branch and is intentionally not part of this runbook.

## Start

```sh
npm install
cp .env.example .env
npm run demo
npm run dev
```

The demo server is optional when using `https://example.com`; it provides a repeatable local page at `http://127.0.0.1:4173/`. Jac's API uses port `8002`; its UI port may move when occupied and is detected by `scripts/dev.js`.

## Verify

```sh
npm run jac:check
env -u NVIDIA_API_KEY -u NVIDIA_NIM_MODEL node scripts/jac.js test jac/core_test.jac -v
node tests/integration/run-contract-tests.js
node --check electron/main.js
node --check electron/preload.js
node --check scripts/dev.js
git diff --check
```

In the running browser, verify: snapshot with a stable revision; deterministic request; preview before apply; visible text-scale or spacing change; one undo token; restoration after undo; stale plan rejection after navigation; invalid action rejection; and explicit preference approval before save. The fixture runner is contract/failure-matrix evidence, not a substitute for the native smoke.

## Configuration and safety

`NVIDIA_API_KEY`, optional `NVIDIA_NIM_MODEL`, and optional `NVIDIA_NIM_BASE_URL` are read by Jac only. Never commit `.env` or any populated secret. `ACCESSIBLE_BROWSER_JAC_URL` and `ACCESSIBLE_BROWSER_JAC_API_URL` override the local Jac UI/API endpoints. Keep browser actions allowlisted and reversible; do not add arbitrary page scripts or shell commands.

## Integration procedure

Merge worker branches into `integration` in dependency order: contracts, Jac hardening, tests, Electron, UI, demo/specs, then documentation/Graphify. After each group run the relevant gates above. Do not merge to `main` until the complete vertical slice and the live failure matrix are verified.
