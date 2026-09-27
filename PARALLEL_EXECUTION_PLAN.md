# AccessibleBrowser Fast-Track Completion Plan

Status: execution blueprint

Purpose: finish the current AccessibleBrowser milestone quickly with parallel AI agents, while preserving the locked Jac/Electron architecture and avoiding a broad rewrite.

This document is intended to be given to an orchestration agent or used as shared context for new agent sessions.

---

## 1. Executive objective

Complete and verify the first usable accessibility vertical slice:

```
real webpage
  -> Electron captures a bounded page snapshot
  -> Jac receives a typed adaptation request
  -> Jac creates a deterministic or LLM-backed structured plan
  -> Jac validates the plan
  -> UI previews the plan and explanation
  -> Electron applies only allowlisted reversible actions
  -> live webpage changes
  -> Electron returns an undo token
  -> user can undo the change
  -> Jac records the result
  -> user explicitly approves whether to save a preference
  -> Jac persists the approved preference
```

The fastest acceptable implementation may be intentionally narrow:

- single active window;
- single active page/tab;
- a small, explicit action allowlist;
- deterministic planning as the reliable fallback;
- one working local preference store;
- one local demo webpage or fixture;
- clear unsupported states for voice and unavailable LLM behavior;
- no multi-tab redesign;
- no plugin marketplace;
- no arbitrary page scripting;
- no attempt to finish every future accessibility feature before the first vertical slice works.

The goal is a safe, demonstrable, testable slice, not a complete browser product.

---

## 2. Verified repository state

The relevant refs currently are:

```
main                          b4d7bb1  origin/main
integration                   8ca941b  origin/integration
feat/integration-tests        9dbeba3  origin/feat/integration-tests
feat/accessibility-experience fcbb35c  origin/feat/accessibility-experience
feat/electron-browser         ff38cdb  origin/feat/electron-browser
feat/jac-core                 ff38cdb  origin/feat/jac-core
```

The combined branch is integration, not integration/main:

- integration contains the Electron foundation merge.
- integration contains the Jac core bridge and persistence work.
- integration contains the accessibility experience merge.
- integration contains the integration-test harness merge.
- integration contains the later browser-command contract test commit.
- integration is pushed and tracks origin/integration.
- main remains the stable branch and has not received integration.

The current checkout is on main and has an untracked .codex/ directory. Do not commit that directory unless the project lead explicitly decides it is source-controlled project material.

Every orchestrator must re-check the actual remote state before implementation:

```
git fetch origin
git status --short --branch
git log --oneline --decorate --max-count=12 origin/integration
git diff --check origin/integration
```

The execution baseline is origin/integration, not the current local main checkout.

---

## 3. Locked architecture and non-negotiable rules

Read these files before changing a shared interface:

1. AGENTS.md
2. ARCHITECTURE.md
3. CONTRACTS.md
4. DECISIONS.md
5. the relevant section of PHASE_1_WORKSTREAM_PROMPTS.md

### 3.1 Ownership boundary

Jac owns:

- accessibility profiles;
- global, origin, and page-scoped preferences;
- preference memory and approved change history;
- adaptation-request construction;
- deterministic planning;
- online LLM planning through the provider boundary;
- plan validation;
- explanations and warnings;
- persistence proposals;
- explicit preference saving;
- validation of constrained browser commands;
- the product-facing Jac API.

Electron and Node own:

- application lifecycle;
- Chromium hosting;
- navigation and current browser controls;
- the preload bridge and IPC transport;
- page snapshot extraction;
- applying allowlisted DOM/CSS/browser actions;
- transactional rollback and undo;
- browser-level actions.

The UI may coordinate these operations, but must not create a second planner, persistence system, or contract shape.

### 3.2 Safety requirements

- The LLM returns data, never executable code.
- No arbitrary JavaScript or CSS is accepted from a model or user request.
- No shell command is accepted as an accessibility action.
- Every action has a known type and validated parameters.
- Page element IDs are valid only for the page revision that produced them.
- Stale plans are rejected before mutation.
- Apply is transactional where practical.
- Undo is tied to the page revision and invalid after navigation or a major revision.
- Applying a plan never silently saves a preference.
- Preference saving requires explicit user approval.
- Do not commit API keys or populated environment files.
- Do not persist raw page content, password values, cookies, or raw form values by default.

### 3.3 Scope discipline

Do not use this effort to:

- redesign the Jac/Electron boundary;
- move browser-specific code into Jac to increase a language percentage;
- create fake Jac files or remove legitimate HTML;
- add unsupported services;
- introduce multi-tab architecture;
- replace existing contracts without evidence;
- make unrelated UI redesigns;
- add a new framework or cloud database;
- make the LLM responsible for page mutation;
- merge directly to main during implementation.

If a worker discovers a genuine contract flaw, document it and propose the smallest compatible correction. Do not silently redesign the system.

---

## 4. Fast-track operating model

Use one orchestration thread and isolated worker branches or worktrees.

### 4.1 Branch model

```
main                         stable; merge only after acceptance
  |
  integration                 shared staging and integration target
    |
    +-- codex/contract-audit
    +-- codex/electron-slice
    +-- codex/jac-hardening
    +-- codex/ui-live-path
    +-- codex/test-hardening
    +-- codex/demo-specs
    +-- codex/docs-graphify
```

Use the repository's existing naming convention if the project lead selected another exact name. Never have two workers edit the same files simultaneously.

### 4.2 Worker rules

Every worker must:

1. start from the latest origin/integration or an identified integration commit;
2. read the required architecture files;
3. state file ownership before editing;
4. inspect current code before assuming a feature is missing;
5. make the smallest change satisfying the acceptance criteria;
6. run focused tests;
7. run git diff --check;
8. report changed files, tests, known gaps, and commit hash;
9. push its branch if authorized;
10. never merge another worker branch unless assigned by the orchestrator.

### 4.3 Orchestrator rules

The orchestrator must:

- maintain a task ledger;
- dispatch independent tasks in waves;
- wait only on dependencies;
- merge small branches into integration in dependency order;
- run gates after each merge group;
- stop parallel work when a shared contract needs a decision;
- resolve conflicts centrally;
- never merge failing or unverified work into main;
- keep main untouched until final acceptance.

Recommended ledger:

```
Task ID | owner | branch | files | dependency | state | tests | commit
```

---

## 5. Definition of done

The milestone is complete only when all of the following are true on integration.

### Product flow

- A real or local demo webpage loads in Electron.
- The browser produces a bounded page snapshot.
- The snapshot includes a stable page revision.
- Jac creates an adaptation request from that snapshot.
- A deterministic plan works without an API key.
- The online provider path is isolated behind environment variables.
- An unavailable LLM produces a clear fallback or structured error.
- Jac validates the generated plan.
- The UI shows a preview before apply.
- Electron rejects unsupported actions.
- Electron rejects stale revisions.
- Electron applies at least the selected minimum action set.
- The page visibly changes.
- The application returns one undo token.
- Undo restores the previous state.
- Apply and undo results are recorded by Jac.
- Persistence is offered separately from apply.
- A preference is saved only after explicit approval.
- The saved preference resolves correctly on a later request.

### Quality and safety

- npm run jac:check passes.
- Jac tests pass.
- Browser and contract tests pass.
- Integration tests pass.
- git diff --check passes.
- No secrets are tracked.
- No arbitrary code path exists in the model-to-browser flow.
- Error states are visible and actionable.
- Demo and test instructions are reproducible.
- Architecture and contract documentation match implementation.
- Graphify is refreshed after final integration.

---

## 6. Minimum action set

Use existing contract names and implementation where possible. Do not expand the allowlist until the first path works.

Recommended minimum set:

1. set_text_scale
2. set_spacing
3. set_contrast
4. reduce_motion
5. enlarge_targets
6. focus_elements
7. reading_mode

If one is not end to end, reduce the first demonstration to the smallest safe subset, preferably text scale, spacing, and focus visibility, and document the rest as follow-up.

Each action must specify:

- exact action type;
- exact parameter shape;
- allowed range or enum;
- reversible status;
- original-state capture;
- undo behavior;
- page revision;
- missing-target behavior;
- user-facing explanation.

Do not invent a new action shape without updating CONTRACTS.md, Jac validation, Electron validation, tests, and UI together.

---

## 7. Workstream map

### W0 — Baseline and integration audit

Branch: codex/baseline-audit

Dependency: none.

Purpose: establish exactly what is present on integration before workers duplicate work.

Inspect:

- git history and branch state;
- architecture, contracts, and decisions;
- all Jac files;
- Electron files;
- frontend.jac;
- tests;
- phase prompts.

Deliverables:

- feature matrix marked working, partial, stub, missing, or unknown;
- exact current vertical-slice path;
- passing and failing commands;
- contract mismatch list;
- duplicate or development-adapter paths to replace;
- merge recommendation for each later worker.

Preferred output: docs/INTEGRATION_AUDIT.md.

Do not change runtime behavior.

Acceptance:

- every status has file/function/test evidence;
- implemented code is distinguished from fixtures and plans.

### W1 — Contract stabilization audit

Branch: codex/contract-audit

Dependency: W0 inventory, although implementation can start from origin/integration.

Primary files:

- CONTRACTS.md;
- jac/core.jac;
- jac/api.jac;
- jac/service.jac;
- electron/preload.js;
- electron/main.js;
- frontend.jac;
- focused contract tests.

Tasks:

1. Compare every shared message shape across docs, Jac, preload, Electron, frontend, and tests.
2. Check camelCase consistency.
3. Check schemaVersion, requestId, tabId, and pageRevision propagation.
4. Check action type and parameter names.
5. Check stale-revision behavior.
6. Check error codes and retryability.
7. Check apply and undo token behavior.
8. Check explicit persistence approval.
9. Mark ambiguous shapes, such as reading-font behavior, as gaps instead of guessing.
10. Make only small compatibility fixes.

Deliverables:

- contract audit table;
- focused tests for each fixed mismatch;
- updated CONTRACTS.md only when implementation is authoritative;
- DECISIONS.md entry only when an agreed decision changes.

Acceptance:

- one canonical action vocabulary exists;
- all layers agree on required fields;
- invalid and stale messages fail safely;
- no unrelated redesign is included.

### W2 — Electron real-page vertical slice

Branch: codex/electron-slice

Dependency: W1 final contract names; prototype may run in parallel.

Primary files:

- electron/main.js;
- electron/preload.js;
- Electron page-host modules;
- Electron tests;
- fixtures under tests.

Tasks:

1. Confirm a real webpage or local fixture loads.
2. Confirm page identity and revision tracking.
3. Implement or finish bounded snapshot extraction.
4. Include stable element IDs, role, accessible name, visible text, visibility, disabled state, and bounds where available.
5. Exclude passwords, cookies, raw form values, and secrets.
6. Bound snapshot size and truncate text safely.
7. Implement the minimum allowlisted actions.
8. Capture previous state before mutation.
9. Apply a plan transactionally where practical.
10. Return one undo token.
11. Reject unsupported actions before mutation.
12. Reject stale revisions before mutation.
13. Restore prior state on undo.
14. Invalidate undo on navigation or major revision.
15. Keep browser commands separate from page adaptation actions.

Fast implementation guidance:

- use one active page;
- use a namespaced style state or controlled classes;
- store original values in a private bounded transaction record;
- prefer CSS variables for reversible visual changes;
- never use model-provided arbitrary selectors or code;
- return clear unsupported responses for unfinished actions.

Acceptance:

- a local or real webpage changes visibly;
- a plan can be undone;
- stale and invalid plans do not mutate the page;
- focused Electron tests cover success and failure.

### W3 — Jac brain and persistence hardening

Branch: codex/jac-hardening

Dependency: W1 contract decision; can run in parallel with W2 without editing Electron files.

Primary files:

- jac/core.jac;
- jac/service.jac;
- jac/provider.jac;
- jac/persistence.jac;
- jac/api.jac;
- Jac tests and fixtures.

Tasks:

1. Verify all contract objects serialize to the bridge shape.
2. Verify deterministic planning for the minimum action set.
3. Verify action allowlist validation.
4. Verify parameter bounds and enums.
5. Verify request, plan, tab, and page revision matching.
6. Verify target IDs belong to the request snapshot.
7. Verify empty, unsafe, malformed, and unsupported requests.
8. Verify LLM-unavailable fallback.
9. Verify malformed model JSON handling.
10. Verify provider output uses the same validator as deterministic plans.
11. Verify bounded payloads and sensitive-value redaction.
12. Verify graph-backed profile persistence.
13. Verify global, origin, then page preference precedence.
14. Verify declined persistence saves nothing.
15. Verify apply and undo history recording.
16. Verify public API functions remain narrow and typed.

Fast implementation guidance:

- keep the provider boundary small;
- use deterministic fallback without an API key;
- do not block the demo on a live API key;
- prefer structured errors across the bridge;
- preserve local-first preferences.

Acceptance:

- npm run jac:check passes;
- Jac tests cover the failure matrix;
- no API key is required for deterministic tests;
- the provider cannot bypass Jac validation.

### W4 — UI live-path completion

Branch: codex/ui-live-path

Dependency: W1 and stable W3 function names.

Primary files:

- main.jac;
- frontend.jac;
- Jac UI files;
- UI tests or fixtures.

Tasks:

1. Identify every development-adapter use.
2. Keep it only for explicit offline fixture states.
3. Route natural-language requests through the real Jac API.
4. Load page context through the typed bridge.
5. Show loading, ready, preview, applying, applied, undoable, undone, rejected, stale, unavailable, and failed states.
6. Render summary, actions, reasons, confidence, warnings, and affected areas.
7. Require preview or approval before apply where required.
8. Offer undo after success.
9. Offer persistence separately.
10. Show saved scope explicitly.
11. Show a useful LLM-unavailable fallback.
12. Show voice unavailable without claiming success.
13. Preserve keyboard access, visible focus, labels, and readable errors.
14. Do not duplicate Jac planning or preference logic in UI code.

Fast implementation guidance:

- fix state wiring before styling;
- use plain explicit controls;
- defer polish that does not affect the slice;
- keep the adapter out of the real path.

Acceptance:

- a user can request, preview, apply, undo, and save through the real path;
- UI success matches bridge success;
- major failure states are understandable.

### W5 — Integration test and failure-matrix hardening

Branch: codex/test-hardening

Dependency: current integration branch; update tests after W1-W4 merge.

Primary files:

- tests;
- test scripts;
- test documentation.

Required cases:

1. page snapshot;
2. natural-language request;
3. deterministic plan;
4. mocked LLM plan;
5. preview data;
6. apply;
7. visible page change;
8. undo;
9. explicit preference saving;
10. global preference;
11. origin preference;
12. page preference;
13. stale revision;
14. invalid action;
15. invalid parameters;
16. unknown target;
17. malformed model response;
18. LLM unavailable;
19. failed apply;
20. rollback after partial apply;
21. failed undo;
22. voice provider unavailable;
23. navigation invalidating undo;
24. no accidental preference save;
25. sensitive values omitted from snapshot and provider payload.

Test style:

- use deterministic fixtures;
- mock network calls;
- never require a real OpenAI key;
- prefer contract assertions over private DOM details;
- add one real local webpage smoke test if supported.

Acceptance:

- failure matrix is executable;
- messages are actionable;
- tests do not use agent-local paths or secrets.

### W6 — Demo page and deterministic specifications

Branch: codex/demo-specs or the friend's existing branch.

Dependency: none for preparation; implementation merges after core integration.

This can run on a different machine and must not block W1-W5.

Demo requirements:

- small text;
- tight spacing;
- weak but intentional contrast;
- small buttons and controls;
- distracting sidebars or popups;
- visible motion;
- article-like content;
- headings, links, buttons, and form controls;
- enough content to verify reading mode and focus behavior.

Specification requirements for every action:

- action kind;
- parameter shape;
- range or enum;
- expected visual result;
- reversible status;
- original state capture;
- undo behavior;
- stale revision behavior;
- missing-target behavior;
- explanation;
- preference scope behavior.

Specify:

- text scaling;
- spacing;
- contrast;
- color filtering;
- reduced motion;
- larger targets;
- focus outlines;
- reading fonts;
- reading mode.

Acceptance:

- demo and specs match contract names;
- ambiguous behavior is documented rather than guessed.

### W7 — Documentation, Graphify, and release hygiene

Branch: codex/docs-graphify

Dependency: after implementation branches merge into integration.

Tasks:

1. Update README with actual start and test commands.
2. Update ARCHITECTURE if verified data flow changed.
3. Update CONTRACTS only for confirmed changes.
4. Update DECISIONS for new architectural decisions.
5. Add a vertical-slice runbook.
6. Document environment variables without values.
7. Document deterministic offline behavior.
8. Document unavailable-provider behavior.
9. Document branch and integration procedure.
10. Refresh Graphify on the final integrated tree.
11. Query Jac to bridge to Electron relationships.
12. Confirm generated Graphify output is ignored or intentionally tracked.
13. Remove stale documentation claims.

Acceptance:

- a new agent can run the project from README;
- docs describe actual implementation;
- Graphify reflects the final architecture.

---

## 8. Execution waves and dependencies

### Wave 0 — Dispatch immediately

Run these in parallel:

- W0 baseline audit;
- W1 contract audit;
- W3 Jac hardening audit and tests;
- W4 UI live-path inventory;
- W5 test-harness inventory;
- W6 demo/spec preparation if the friend's machine is available.

W0 is read-mostly. W1, W3, W4, and W5 must use disjoint files. Shared contract discoveries go into the ledger and are resolved centrally.

### Wave 1 — Merge contract-safe foundations

Merge in this order:

1. focused W3 Jac fixes;
2. focused W1 contract fixes;
3. W5 tests matching the merged contracts;
4. rerun Jac and contract gates.

Do not merge a shared message change without corresponding tests.

### Wave 2 — Build the real vertical slice in parallel

After contracts stabilize, run in parallel:

- W2 Electron snapshot, apply, and undo;
- W4 UI live path;
- W5 integration tests;
- W6 demo fixture and specification documentation.

The UI may use a temporary adapter while Electron is incomplete, but the adapter must be removed from the real path before final acceptance.

### Wave 3 — Integrate the slice

Merge in this order:

1. W2 Electron browser path;
2. W3 follow-up Jac corrections;
3. W4 UI live path;
4. W5 integration tests;
5. W6 demo/spec branch if ready.

Then run the complete vertical slice manually and through tests.

### Wave 4 — Final hardening

Run in parallel against merged integration:

- happy-path reproduction;
- invalid and stale-input attack;
- persistence and privacy review;
- keyboard and accessibility review;
- startup, packaging, and environment review;
- documentation and Graphify update.

Only docs and test fixes should be made unless a release-blocking defect is found.

### Wave 5 — Promote to main

Do not merge to main until:

- complete path works;
- required tests pass;
- failure matrix is covered;
- secrets scan cleanly;
- docs match reality;
- project lead reviews integration.

Promotion:

```
git switch main
git pull --ff-only origin main
git merge --no-ff integration -m "Merge completed accessibility vertical slice"
git push origin main
```

The project lead owns promotion.

---

## 9. Orchestrator prompt

Use this as the initial orchestration prompt:

```
You are the lead implementation orchestrator for AccessibleBrowser.

Read PARALLEL_EXECUTION_PLAN.md, AGENTS.md, ARCHITECTURE.md, CONTRACTS.md, DECISIONS.md, and the relevant sections of PHASE_1_WORKSTREAM_PROMPTS.md before changing code.

The execution baseline is origin/integration. Do not use local main as the implementation baseline. Do not merge to main until final acceptance. The project is a Jac-heavy Electron Chromium browser:

- Jac owns profiles, preferences, graph-backed memory, request interpretation, planning, validation, explanations, and persistence decisions.
- Electron and Node own Chromium hosting, snapshots, page mutation, browser commands, IPC, transactions, and undo.
- The LLM may return only structured allowlisted reversible actions.
- No arbitrary JavaScript, CSS, shell commands, or unrestricted browser actions are allowed.

First inspect the real state and produce a task ledger. Do not assume a feature is missing because a prompt says it should exist. Mark each item working, partial, stub, missing, or unknown with file, function, and test evidence.

Dispatch independent Wave 0 agents in isolated branches or worktrees. Give each worker a strict file ownership boundary. Ask each worker to report changed files, tests, commit hash, known gaps, and integration notes. Do not let workers edit the same shared interface simultaneously.

Prioritize the smallest safe first vertical slice: bounded snapshot -> Jac request -> deterministic or LLM plan -> Jac validation -> preview -> Electron apply -> undo -> explicit preference save. Single-page behavior and deterministic offline fallback are acceptable.

Merge only verified work into integration, in dependency order. After each merge group run Jac, contract, integration, and diff checks. Keep main untouched until the full acceptance checklist passes.

If a requirement is ambiguous, preserve the existing contract, record the ambiguity, and ask the project lead only when a decision changes architecture or data shape. Do not add fake Jac files, delete legitimate HTML, or change code merely to influence language percentages.
```

---

## 10. Worker prompt template

Give every worker a task-specific version:

```
You are a worker on AccessibleBrowser. Your assigned task is: [TASK ID AND NAME].

Start from the latest origin/integration or the exact commit supplied by the orchestrator. Use your own branch or worktree. Read AGENTS.md, ARCHITECTURE.md, CONTRACTS.md, DECISIONS.md, and the task section in PARALLEL_EXECUTION_PLAN.md.

Before editing:

1. inspect current implementation;
2. identify files you own;
3. identify files you will not touch;
4. record assumptions and gaps;
5. check whether another branch already implements the behavior.

Implement the smallest safe change. Preserve the Jac/Electron boundary. Do not invent a parallel contract. Do not add arbitrary code execution. Do not commit secrets. Do not change unrelated files.

Run focused tests and git diff --check. If a test cannot run, report the exact reason. Before finishing, report:

- summary of work;
- changed files;
- tests and results;
- contract or architectural implications;
- known remaining gaps;
- commit hash;
- whether the branch is ready to merge.
```

---

## 11. Verification commands

Run from the repository root.

### Baseline and hygiene

```
git status --short --branch
git diff --check
git diff --stat origin/integration...HEAD
git ls-files | rg '(^|/)(\.env|.*secret|.*credentials)' || true
```

### Jac checks

```
npm run jac:check
env -u OPENAI_API_KEY -u OPENAI_MODEL jac test jac/core_test.jac -v
```

If the Jac wrapper is required, use the project script rather than inventing another runtime command.

### Integration tests

```
node tests/integration/run-contract-tests.js
```

Run any additional commands documented by the tests README or package scripts.

### Runtime smoke path

```
npm install
npm run dev
```

Verify:

1. Jac starts.
2. Electron starts.
3. The page loads.
4. Jac experience reads current page context.
5. Deterministic request produces a plan.
6. UI previews it.
7. Apply changes the page.
8. Undo restores the page.
9. Save requires explicit approval.
10. Reload or navigation invalidates stale plan and undo state as documented.

### Final Graphify evidence

After final code merges, refresh Graphify according to the Graphify skill and query:

- How does a user request travel from Jac UI through the Jac planner and typed bridge to Electron page mutation?
- Which Jac modules own planning, validation, persistence, and provider access?
- Which Electron modules own snapshot creation, allowlisted application, and undo?

Record evidence in the audit or release notes. Graphify is an analysis and documentation tool here, not a runtime dependency.

---

## 12. Manual acceptance script

Use the friend's intentionally inaccessible demo page if available. Otherwise use a minimal local HTML fixture.

### Happy path

1. Start the application.
2. Open the fixture page.
3. Capture a page snapshot.
4. Confirm it has a revision and no sensitive form values.
5. Enter: Make this page easier to read.
6. Generate the plan.
7. Confirm preview lists only known actions.
8. Confirm the explanation says what changes and why.
9. Apply the plan.
10. Confirm the page visibly changes.
11. Confirm an undo control appears.
12. Undo the change.
13. Confirm the previous visual state returns.
14. Apply again.
15. Choose an explicit preference scope.
16. Approve saving.
17. Request another plan for the same scope.
18. Confirm the saved preference is resolved.

### Failure path

Repeat with:

- empty request;
- stale page revision;
- unknown action;
- invalid parameters;
- missing target;
- unavailable LLM;
- malformed provider output;
- forced apply failure;
- forced undo failure;
- navigation before undo;
- voice provider unavailable;
- declined persistence.

Every failure must leave the page safe and produce a useful structured or user-visible result.

---

## 13. Conflict-resolution policy

When branches conflict:

1. keep the existing contract unless a confirmed bug exists;
2. keep Jac as the source of product meaning and validation;
3. keep Electron as the source of browser mutation and undo;
4. prefer tested implementation over untested redesign;
5. prefer narrower working actions over broader unsafe actions;
6. preserve backward-compatible fields when possible;
7. update docs after code and tests agree;
8. record changed decisions in DECISIONS.md;
9. rerun the relevant gate after resolution.

Never resolve conflicts by:

- copying both incompatible implementations into production;
- leaving duplicate action vocabularies;
- bypassing validation;
- reintroducing the development adapter into the real path;
- moving Electron-specific mutation into Jac for language-ratio reasons.

---

## 14. What can remain rudimentary

Acceptable for this milestone if documented:

- one active tab;
- local demo webpage;
- small supported action list;
- deterministic planning when provider unavailable;
- basic but accessible UI;
- simple local Jac graph store;
- one undo transaction at a time;
- visible voice-unavailable state;
- basic explanation generator;
- fixture-based browser tests.

Not acceptable:

- fake Jac code solely to increase the Jac percentage;
- arbitrary JavaScript execution;
- silently applying an unreviewed plan;
- silently saving preferences;
- ignoring stale revisions;
- exposing API keys to renderer code;
- treating a mocked adapter as the completed real slice;
- claiming full support for an action that is only a visual stub.

---

## 15. Final handoff checklist

Before declaring completion, provide:

- final integration commit;
- merged worker commits;
- intentionally deferred items;
- Jac check result;
- contract and integration test results;
- manual vertical-slice result;
- privacy and secret-handling check;
- current branch and remote status;
- updated README or runbook;
- refreshed Graphify evidence;
- explicit recommendation to merge or not merge to main.

The final report must distinguish:

```
implemented and verified
implemented but not fully verified
stubbed or demo-only
blocked by external work
deferred intentionally
```

This distinction is more important than claiming every planned feature is complete.

