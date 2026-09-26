# AccessibleBrowser Parallel Build Prompts

This document contains three standalone prompts for three fresh Codex sessions. Give one prompt to each session while it works on the matching branch.

## How to use these prompts

These are three parallel workstreams inside one build phase. They are not three sequential product phases:

```text
Workstream A: Electron browser runtime ─┐
Workstream B: Jac brain and persistence ─┼─ build in parallel → integrate → demo
Workstream C: Accessibility experience ──┘
```

Use the existing branches:

```text
feat/electron-browser
feat/jac-core
feat/accessibility-experience
```

Each session must work only on its assigned branch or worktree. The project lead owns merges into `main`. Do not have two sessions edit the same files at the same time.

The first shared vertical slice is:

```text
User asks: “Make the text larger.”
        ↓
Jac creates a structured adaptation plan.
        ↓
Electron applies a controlled text-scale change to a real webpage.
        ↓
The UI shows what changed and can undo it.
```

The prompts below are intentionally detailed, but they do not authorize redesigning the product architecture. If an implementation choice is unclear, preserve the boundaries in `AGENTS.md`, `ARCHITECTURE.md`, and `CONTRACTS.md`, then document the decision.

---

# Prompt A — Electron Browser Runtime

Copy everything from this heading through the end of this section into the fresh session working on `feat/electron-browser`.

## Role

You own the Electron and Node browser runtime for AccessibleBrowser. Build the smallest reliable Chromium wrapper that can load a real webpage, expose a narrow typed bridge to the Jac UI, extract a bounded page snapshot, apply allowlisted accessibility actions, and undo the latest page adaptation.

## Project context

AccessibleBrowser is an accessibility-first Chromium browser. Jac owns product logic, accessibility profiles, preferences, memory, request interpretation, adaptation planning, explanations, and most first-party application code. Electron/Node owns the desktop window, Chromium page hosting, browser navigation, page inspection, safe DOM/CSS operations, browser commands, and undo.

The repository is:

```text
/Users/ashwinshrivastav/Documents/GitHub/AccessibleBrowser
```

The project uses Electron with Node.js and Jac `0.37.23`. The runtime model is an online OpenAI API model called from Jac. Electron must never call the OpenAI API directly. The model must never send arbitrary JavaScript, arbitrary CSS, shell commands, raw selectors, or unrestricted browser actions to Electron.

The current Phase 0 scaffold already contains:

- `electron/main.js`
- `electron/preload.js`
- `electron/placeholder.html`
- `scripts/dev.js`
- `CONTRACTS.md`
- `ARCHITECTURE.md`
- `AGENTS.md`
- `DECISIONS.md`
- `package.json`

The current Electron bridge only has a ping method. Extend it carefully rather than exposing `ipcRenderer` or a general-purpose JavaScript evaluator.

## Required first actions

1. Confirm the working directory and branch.
2. Run `git status --short --branch` and preserve unrelated changes.
3. Read `AGENTS.md`, `ARCHITECTURE.md`, `CONTRACTS.md`, `DECISIONS.md`, and this prompt.
4. Because `graphify-out/graph.json` exists, use Graphify before manually rescanning the repository:

   ```text
   graphify query "How do Electron startup, the preload bridge, and the Jac UI currently connect?"
   graphify query "Which files currently own Electron startup and bridge behavior?"
   ```

5. Check the installed Electron version and the existing `npm` scripts.
6. Do not start by rewriting the architecture or moving product logic into Electron.

If the branch is not `feat/electron-browser`, stop and report the branch mismatch before editing.

## Ownership boundary

You own these files and directories unless the project lead coordinates an exception:

- `electron/**`
- `scripts/dev.js` when the change is required for Electron startup
- Electron-specific parts of `package.json`
- Electron-specific smoke scripts or fixtures

Avoid editing these files while the other sessions are active:

- `frontend.jac`
- `main.jac`
- Jac brain modules owned by Workstream B
- accessibility UI modules owned by Workstream C
- `CONTRACTS.md`, `ARCHITECTURE.md`, and `DECISIONS.md`

If the bridge contract truly needs to change, make the smallest compatible change, explain it in your final report, and tell the project lead exactly which contract text must be updated. Do not silently invent a second protocol.

## Runtime target

Use a secure Electron structure that keeps the Jac product UI and the live webpage separate:

- The Jac UI is a local trusted app surface.
- The live webpage is a Chromium page surface.
- The live webpage must not receive Node integration or unrestricted privileged APIs.
- The preload API exposed to the Jac UI must be narrow, typed, and JSON-compatible.
- Page mutations must happen through validated Electron-owned operations.

Use Electron APIs available in the installed version. A `BaseWindow` plus `WebContentsView` design is acceptable if it keeps the UI and webpage surfaces clear. A simpler `BrowserWindow` design is acceptable for the first vertical slice if it remains secure and does not block later separation. Keep the browser chrome simple; the adaptation path matters more than visual polish.

## Build in this order

### A1. Stable browser shell

Implement a real browser window that can:

- start from `npm run dev` through the existing Jac launcher;
- show the Jac UI or a clearly bounded local UI surface;
- host a real webpage in Chromium;
- navigate to a typed URL from an address bar or a temporary development control;
- go back;
- go forward;
- reload;
- report loading and navigation failures clearly;
- keep the remote page isolated from Node APIs.

Tabs are useful if they fit the time, but they are secondary to the first vertical slice. If tabs are implemented, use stable generated `tabId` values and keep them separate from numeric display indexes.

### A2. Typed preload bridge

Extend the preload bridge with narrow methods shaped around the contracts. Use names close to these unless the existing contract requires another name:

```text
browser.getActivePageSnapshot()
browser.requestAdaptation(request)
browser.applyAdaptationPlan(plan)
browser.undoAdaptation(undoToken)
browser.executeBrowserCommand(command)
browser.getBrowserState()
browser.onPageChanged(listener)
```

The preload layer may invoke IPC methods, validate basic message shape, and subscribe to safe events. It must not expose:

- raw `ipcRenderer`;
- arbitrary `executeJavaScript` to the Jac UI;
- arbitrary filesystem access;
- shell execution;
- unrestricted navigation commands;
- OpenAI credentials;
- the ability for a model response to bypass validation.

Use `contextIsolation: true` and `nodeIntegration: false` for browser content. Keep the API surface small enough that Workstream C can use it without learning Electron internals.

### A3. Page snapshot extraction

Implement a bounded `PageSnapshot` for the active webpage. It should contain at least:

- `snapshotId`;
- `tabId`;
- `pageRevision`;
- URL and origin;
- title;
- viewport dimensions;
- scroll position;
- a bounded visible text summary;
- headings;
- buttons;
- links;
- inputs without values or secrets;
- detected page sections;
- visible element identifiers;
- role and accessible name where available;
- disabled state;
- viewport-relative bounds;
- limited style/accessibility metadata needed for adaptation.

Element identifiers are generated by Electron and are valid only for the exact page revision that produced them. Increment `pageRevision` after navigation and major page changes. Reject adaptation actions using stale revisions or stale element identifiers.

Privacy requirements:

- never include password values;
- never include form values by default;
- never include cookies or tokens;
- never include raw page HTML in the plan request;
- bound and truncate text;
- keep cross-origin iframe support deferred unless it is already safe and isolated.

### A4. Allowlisted page adaptation

Implement controlled handlers for the initial action kinds in `CONTRACTS.md`:

- `set_text_scale`;
- `set_spacing`;
- `set_contrast`;
- `set_color_filter`;
- `reduce_motion`;
- `enlarge_targets`;
- `hide_regions`;
- `reading_mode`;
- `focus_elements`.

The first required implementation is `set_text_scale`. It must change text on a real webpage and be undoable. Prefer a browser-owned style layer or stylesheet class with a unique transaction marker so adaptation can be reapplied without destroying the page’s original styles.

Every action handler must:

- validate the action kind;
- validate parameter ranges and types;
- validate `tabId` and `pageRevision`;
- validate target element identifiers when targets are required;
- reject arbitrary JavaScript, CSS, selectors, shell commands, or unknown fields that would create an escape hatch;
- return a structured result;
- record enough prior state for undo;
- fail the entire plan safely if a required action cannot be applied.

Deterministic actions such as text scale, contrast, color filters, spacing, reduced motion, and larger targets should work without an LLM response.

### A5. Transaction and undo behavior

Treat one adaptation plan as one transaction:

1. Validate the full plan.
2. Capture the reversible state needed for every action.
3. Apply the actions in a deterministic order.
4. If one action fails, roll back the actions already applied.
5. Return one `undoToken` or `transactionId` for the successful plan.
6. Reject the undo token after navigation or a major page revision.
7. Undo the complete latest plan rather than only an arbitrary action.

The Electron layer owns actual page mutation history. Jac owns the conceptual request and saved preference history.

### A6. Browser commands

Implement the constrained browser command shape needed by the later voice layer:

- new tab;
- close tab;
- switch tab;
- back;
- forward;
- reload;
- bounded scroll;
- bounded zoom;
- search;
- read page placeholder/result;
- stop reading placeholder/result.

Distinguish web search, page search, and focusing a search field. Do not allow dangerous protocols or unbounded navigation. Return `accepted`, `completed`, `rejected`, `failed`, or `cancelled` in the command result shape.

## Shared vertical slice

Before polishing other browser features, make this path work:

1. Open a deterministic development webpage or a simple public article.
2. Obtain a page snapshot.
3. Receive a validated `set_text_scale` plan.
4. Apply it to the live page.
5. Return a human-readable result and undo token.
6. Undo it and restore the original page appearance.

If Jac or the UI is not ready, use a local development-only fixture request that exactly matches `CONTRACTS.md`. Keep the fixture behind an explicit development path and do not create a second production contract.

## Verification

Run the existing checks that apply, including:

```text
npm run jac:check
node --check electron/main.js
node --check electron/preload.js
npm run dev
```

For the manual smoke path, verify the visible behavior rather than only process startup:

- a real webpage loads;
- a page snapshot is produced;
- text scale changes;
- undo restores the page;
- stale page revisions are rejected;
- the remote webpage cannot access Node APIs.

Do not spend the workstream on a full test framework, final visual polish, full voice recognition, or the final demo page. Those belong after the vertical slice works.

## Definition of done

This workstream is ready for integration when:

- Electron starts through the documented launcher;
- a real webpage is hosted inside the application;
- navigation controls work at the basic level;
- the Jac UI has a narrow bridge with no raw Electron internals;
- `PageSnapshot` is bounded, privacy-aware, and revisioned;
- `set_text_scale` changes the real webpage and can be undone;
- the initial allowlist is enforced;
- stale plans and invalid actions are rejected;
- browser commands use typed bounded arguments;
- the workstream has a focused commit on `feat/electron-browser`;
- the final report lists changed files, contract assumptions, checks run, and any integration follow-up.

---

# Prompt B — Jac Brain and Persistence

Copy everything from this heading through the end of this section into the fresh session working on `feat/jac-core`.

## Role

You own the Jac product logic for AccessibleBrowser: accessibility profiles, preference memory, site-specific rules, adaptation request interpretation, structured plan generation, OpenAI orchestration, explanations, and local persistence.

The Jac layer must be the center of the product. Electron performs browser-specific operations, but it does not interpret the user’s accessibility intent and it does not call the OpenAI API.

## Project context

The repository is:

```text
/Users/ashwinshrivastav/Documents/GitHub/AccessibleBrowser
```

The project uses Jac `0.37.23`, Electron, Node.js, and an online OpenAI API model. The current Jac web-app scaffold contains:

- `jac.toml`;
- `main.jac`;
- `frontend.jac`;
- `jac/main.jac`;
- `CONTRACTS.md`;
- `ARCHITECTURE.md`;
- `AGENTS.md`;
- `DECISIONS.md`.

The product goal is to let a person say things like:

```text
Make this page easier to read and make the buttons easier to click.
```

Jac should turn that request into a structured, explainable, allowlisted adaptation plan. It must never return executable JavaScript, arbitrary CSS, shell commands, raw selectors, or unrestricted browser commands.

## Required first actions

1. Confirm the working directory and branch.
2. Run `git status --short --branch` and preserve unrelated changes.
3. Read `AGENTS.md`, `ARCHITECTURE.md`, `CONTRACTS.md`, `DECISIONS.md`, and this prompt.
4. Use Graphify first because `graphify-out/graph.json` exists:

   ```text
   graphify query "What files and functions currently define the Jac project entrypoints?"
   graphify query "What is the current Electron bridge contract exposed to the Jac UI?"
   ```

5. Confirm whether Jac MCP tools are visible in the fresh session. If they are unavailable, use the installed Jac CLI guides and local Jac documentation. Do not pretend the MCP is available.
6. Check the Jac version and run the existing Jac check before changing code.
7. If the branch is not `feat/jac-core`, stop and report the mismatch before editing.

## Ownership boundary

Own these areas:

- `jac/**` for product logic, models, persistence, providers, and planning;
- Jac-specific dependency changes in `jac.toml`;
- Jac-specific configuration and provider adapters;
- focused Jac documentation needed to explain the implementation.

Avoid editing while other sessions are active:

- `electron/**`;
- `scripts/dev.js`;
- `frontend.jac` and `main.jac` except through explicit coordination with Workstream C;
- shared architecture and contract documents.

If a shared interface must change, preserve backward compatibility where possible, document the exact change, and report it to the project lead. Do not create a second set of types with different field names.

## Build in this order

### B1. Jac conceptual types

Create Jac-owned representations for the shared concepts in `CONTRACTS.md`:

- `AccessibilityProfile`;
- `PreferenceRule`;
- `PageSnapshot`;
- `AdaptationRequest`;
- `PlanAction`;
- `AdaptationPlan`;
- `BrowserCommand`;
- structured result and error types.

The external bridge format remains JSON-compatible and camelCase. Jac may use idiomatic internal naming if the boundary conversion is explicit and stable.

At minimum, the plan must include:

- schema version;
- plan ID;
- request ID;
- tab ID;
- page revision;
- human-readable summary;
- action list;
- confidence;
- warnings;
- suggested persistence scope;
- status.

Every action must have:

- action ID;
- allowlisted action type;
- typed parameters;
- optional target element IDs;
- human-readable reason;
- reversible flag.

### B2. Deterministic request path first

Implement a deterministic path that can produce a plan without an LLM for common settings:

- larger text;
- increased spacing;
- high contrast;
- color filter;
- reduced motion;
- larger click targets;
- reading mode;
- focus/highlight changes.

This path must remain useful when the OpenAI service is unavailable. It should normalize simple requests into structured plans and return `noOp` when the requested setting is already active.

The first required request is:

```text
Make the text larger.
```

It must create a valid `set_text_scale` action that Electron can apply.

### B3. OpenAI provider boundary

Add a small Jac-owned provider boundary for the online model. Keep model calls behind one clear interface so the rest of the product does not depend on a specific SDK shape.

Requirements:

- read the API key from `OPENAI_API_KEY`;
- read an optional model name from `OPENAI_MODEL`;
- never commit secrets;
- never send secrets to Electron or the browser page;
- send only the bounded page snapshot and the relevant profile/rules;
- explicitly instruct the model to return structured plan data;
- validate the returned data in Jac before it reaches Electron;
- reject unknown action types and invalid parameters;
- return `LLM_UNAVAILABLE` or a safe deterministic fallback when the service fails;
- bound request size and response size;
- log useful local diagnostics without logging API keys, password values, cookies, or raw sensitive form data.

The model may suggest a plan. It does not get to decide whether arbitrary code should execute.

### B4. Plan validation and explanation

Implement a Jac pipeline with distinct stages:

```text
request interpretation
→ applicable profile/rules
→ deterministic or LLM plan generation
→ schema validation
→ allowlist validation
→ explanation
→ preview/apply handoff
→ optional persistence suggestion
```

Do not combine plan generation, application, and persistence into one opaque function.

The explanation should tell the UI:

- what will change;
- which parts of the page are affected;
- why the change was suggested;
- the confidence level;
- any limitation or warning;
- whether the change is reversible;
- whether the user may save it for this page, this website, or all websites.

### B5. Profile and preference persistence

Implement local-first storage for:

- the active accessibility profile;
- approved global settings;
- approved website/origin rules;
- approved page rules where appropriate;
- timestamps and source of the rule;
- explicit approval state;
- enough history to explain the current setting.

Use Jac’s supported persistence and graph model after checking the Jac documentation for the installed version. Keep the persistence API behind a small repository/service boundary so the UI does not know storage details.

Preference rules must support:

- setting;
- value;
- scope: page, website/origin, or global;
- source: setup, voice, manual, or learned;
- explicit approval;
- created and updated timestamps.

Precedence is:

```text
global → website/origin → page
```

The most specific applicable rule wins for the same setting. “Just for now” is not persisted. Applying a plan does not automatically save it. Persistence requires explicit user approval.

Do not persist raw page contents, raw CSS, arbitrary model prompts, or unbounded snapshots by default.

### B6. UI and Electron service boundary

Expose a small stable service surface for Workstream C and the Electron bridge. Use the names and payloads already defined in `CONTRACTS.md`, or document a compatibility-preserving refinement.

The service surface should support:

- get active profile;
- update active profile;
- get applicable preferences for an origin/page;
- create an adaptation request;
- return a validated adaptation plan;
- explain a plan;
- record apply/undo results;
- propose persistence;
- save a preference only after explicit approval;
- execute or forward a constrained browser command.

Jac should not directly mutate the DOM. It sends a plan through the bridge for Electron to validate and apply.

### B7. Development fixtures

Because the three workstreams run in parallel, provide deterministic local fixture data or a development-only adapter that lets Workstream C build before the real LLM and Electron path are complete.

The fixture must:

- use the exact shared JSON shapes;
- produce a text-scale plan;
- produce a larger-target plan;
- support a `noOp` result;
- return a structured validation error;
- be clearly marked as development-only;
- be replaceable by the real provider without changing UI contracts.

Do not invent a separate mock protocol.

## Privacy and failure behavior

Implement safe behavior for:

- missing `OPENAI_API_KEY`;
- LLM timeouts;
- malformed model output;
- unsupported action types;
- stale page revisions;
- missing target element IDs;
- empty user requests;
- no applicable changes;
- persistence declined by the user.

When the LLM is unavailable, deterministic controls must continue to work. When confidence is low or validation fails, return a previewable warning or a rejected plan; do not silently apply uncertain actions.

## Verification

Run:

```text
npm run jac:check
jac check
jac run
```

Verify with representative data:

1. A text-scale request returns a valid allowlisted plan.
2. A combined readability request returns multiple typed actions.
3. A malformed or unknown model action is rejected.
4. A global preference is overridden by a website rule, which is overridden by a page rule.
5. “Just for now” is not persisted.
6. A declined “Remember this?” choice leaves storage unchanged.
7. Missing LLM configuration still permits deterministic plans.
8. No secret or raw form value appears in the request payload or logs.

Do not build the full control panel or full voice provider in this workstream. Return the data and services that those experiences need.

## Definition of done

This workstream is ready for integration when:

- the shared conceptual types exist in Jac;
- deterministic adaptation planning works without the LLM;
- the OpenAI provider is isolated behind a Jac boundary;
- model output is validated against the allowlist;
- explanations and warnings are available to the UI;
- profile and approved preference persistence works locally;
- scope precedence is implemented;
- “Remember this?” requires explicit approval;
- development fixtures use the production contract shapes;
- `npm run jac:check` passes;
- the workstream has a focused commit on `feat/jac-core`;
- the final report lists changed files, contract assumptions, checks run, and integration follow-up.

---

# Prompt C — Accessibility Experience

Copy everything from this heading through the end of this section into the fresh session working on `feat/accessibility-experience`.

## Role

You own the Jac-powered accessibility experience: the first screen, accessibility control panel, profile presets, quick controls, request flow, plan preview, apply/undo feedback, explanations, preference-saving dialog, scope selection, Simple Mode, and the visible voice mode state.

The interface should make the product understandable immediately:

```text
How should this page work better for you?
```

The UI asks Jac for plans and sends validated plans through the typed Electron bridge. It does not apply arbitrary DOM changes itself and it does not call Electron internals directly.

## Project context

The repository is:

```text
/Users/ashwinshrivastav/Documents/GitHub/AccessibleBrowser
```

The project uses Jac `0.37.23` for product logic and UI, Electron for the Chromium shell, and an online OpenAI model behind Jac. The current UI scaffold contains:

- `main.jac`;
- `frontend.jac`;
- the Electron bridge in `electron/preload.js`;
- the shared contracts in `CONTRACTS.md`;
- the product boundary in `ARCHITECTURE.md`.

The three workstreams are being built in parallel. Workstream A may still be adding browser operations, and Workstream B may still be adding planning and persistence. Build against the stable contract and use a development adapter when a dependency is not ready.

## Required first actions

1. Confirm the working directory and branch.
2. Run `git status --short --branch` and preserve unrelated changes.
3. Read `AGENTS.md`, `ARCHITECTURE.md`, `CONTRACTS.md`, `DECISIONS.md`, and this prompt.
4. Use Graphify first because `graphify-out/graph.json` exists:

   ```text
   graphify query "What is the current Jac UI entrypoint and Electron bridge status path?"
   graphify query "Which project files are currently connected to the Electron preload bridge?"
   ```

5. Confirm the Jac version and run `npm run jac:check` before editing.
6. If the branch is not `feat/accessibility-experience`, stop and report the mismatch before editing.

## Ownership boundary

Own these areas:

- `frontend.jac`;
- `main.jac` when needed for the Jac UI;
- new UI modules under a clearly named UI directory;
- Jac UI styles and accessible interaction patterns;
- UI-specific development adapters that use the shared contract.

Avoid editing while the other sessions are active:

- `electron/**`;
- `scripts/dev.js`;
- Jac persistence, planner, and provider internals owned by Workstream B;
- shared architecture and contract documents.

If the UI needs a bridge method that does not exist yet, define the required method and payload using `CONTRACTS.md`, add a temporary typed adapter for local development, and tell the project lead exactly what Workstream A or B must provide. Do not expose raw Electron APIs from the UI.

## Product experience requirements

### C1. First screen

Create a clear first screen with:

- the question “How should this page work better for you?”;
- a text input or command field;
- a clear submit action;
- a compact current-profile summary;
- a visible current-page status;
- quick toggles for common deterministic settings;
- a clear place to undo the last applied adaptation;
- readable focus states and keyboard navigation.

The first screen should be useful before a person understands the full product. Keep labels plain and avoid hiding core actions behind unexplained icons.

### C2. Accessibility control panel

Build controls for the first supported settings:

- larger text;
- more spacing;
- high contrast;
- color filter;
- reduced motion;
- larger click targets;
- reading mode/simple mode;
- focus/highlight changes;
- reading font or dyslexia-friendly font when the contract supports it.

Each control must show its current state and make clear whether it applies to:

- this page;
- this website;
- all websites/global profile.

Use deterministic control paths for deterministic settings. They must still work if the LLM is unavailable.

### C3. Preset profiles

Create a small set of understandable presets without making medical claims. For example:

- easier reading;
- low vision;
- reduced motion;
- easier clicking;
- custom.

Presets should map to the shared `AccessibilityProfile` fields. They must be editable and explain which settings they activate. Avoid diagnosing or labeling the user.

### C4. Natural-language request flow

When the user submits a request:

1. Show that the request is being understood.
2. Include the active profile and current page context through Jac.
3. Receive a structured plan or a clear error.
4. Show a human-readable “What will change?” preview.
5. Show warnings, confidence, and affected targets when available.
6. Let the user apply, cancel, or revise the request.
7. Show the result and expose undo after applying.

The UI must not assume that every plan is valid. It should display rejected plans as explanations rather than attempting to apply them.

### C5. Apply, undo, and explanation states

Provide clear states for:

- idle;
- understanding request;
- preview ready;
- applying;
- applied;
- undone;
- rejected;
- failed;
- LLM unavailable;
- stale page requiring a refresh/retry.

After an adaptation is applied, show:

- what changed;
- why it changed;
- whether it can be undone;
- the undo action;
- the current persistence suggestion.

The UI must not claim success until Electron returns a completed result.

### C6. Preference saving flow

After a successful plan, show a small explicit prompt such as:

```text
Remember this change?
Just for this page · For this website · For all websites · No thanks
```

Use the preference scope values from `CONTRACTS.md`. “Just for now” must not be saved. The UI should show when a setting came from a saved global, website, or page rule.

Do not save a preference automatically because a user clicked Apply. Persistence requires a separate approval action.

### C7. Simple Mode

Implement a focused Simple Mode for normal article-like pages:

- reduce distracting regions;
- emphasize the main article content;
- improve text scale and spacing;
- reduce motion;
- make headings and links easier to scan;
- provide a clear way to return to the normal page.

Keep the first version modest. It can request a `reading_mode` action and display the result. Do not attempt a universal page rewrite or a complete content extraction engine in this workstream.

### C8. Voice mode state

Implement the visible interaction state for voice mode:

- off;
- activating;
- listening;
- processing;
- speaking/confirming;
- paused after silence;
- error;
- unavailable.

Show a clear indicator and a way to exit voice mode. Support the constrained browser command vocabulary from `CONTRACTS.md` when a command adapter is available:

- new tab;
- close tab;
- switch tab;
- back;
- forward;
- reload;
- scroll;
- zoom;
- search;
- read page;
- stop reading.

Keep actual speech-to-text and text-to-speech provider choice behind a small adapter. If the provider is not ready, implement the state machine and a development text-command adapter using the same `BrowserCommand` shape. Do not make a fake voice result look like real microphone input.

## Parallel development adapter

Create a typed UI adapter that can use either:

- the real Jac service and Electron bridge;
- a development fixture implementing the same request, plan, apply, undo, and preference shapes.

Make the adapter selection explicit and development-only. The UI must not fork into a separate mock protocol. This lets the UI session demonstrate the full interaction while Workstreams A and B finish their implementations.

## Accessibility quality bar

The control panel itself must be accessible:

- keyboard navigation works;
- focus is visible;
- controls have labels;
- status messages are announced appropriately;
- color is not the only way to convey state;
- text has readable contrast;
- buttons are large enough to activate;
- motion is limited and can be reduced;
- error messages explain what the user can do next.

Use plain language. Do not make medical claims about Parkinson’s, dyslexia, epilepsy, blindness, or any other condition. Describe settings and user preferences instead of diagnosing users.

## Verification

Run:

```text
npm run jac:check
npm run dev
```

Walk through the UI with the development adapter if the real services are not ready:

1. Open the first screen.
2. Choose larger text.
3. Submit “Make this page easier to read.”
4. See a structured preview.
5. Apply the plan.
6. See “What changed?” and an undo action.
7. Undo it.
8. Choose “For this website” and confirm the preference flow.
9. Reload the page and show the saved rule being considered.
10. Turn on Simple Mode and return to the normal page.
11. Toggle voice mode and demonstrate its visible state transitions with the development adapter.

Do not spend this workstream on a final demo webpage, production speech provider, advanced page restructuring, or visual polish that blocks the first complete flow.

## Definition of done

This workstream is ready for integration when:

- the first screen clearly communicates the product;
- deterministic accessibility controls are usable;
- profile presets map to Jac profile data;
- natural-language requests show preview, apply, result, and undo states;
- explanations and warnings are visible;
- preference scope selection requires explicit approval;
- Simple Mode has a modest article-oriented flow;
- voice mode has a truthful visible state machine and constrained command adapter;
- the UI can use a typed development adapter while services are incomplete;
- the UI itself passes the accessibility quality bar;
- `npm run jac:check` passes;
- the workstream has a focused commit on `feat/accessibility-experience`;
- the final report lists changed files, contract assumptions, checks run, and integration follow-up.

---

# Integration instructions for the project lead

The three sessions should report back without merging each other’s branches. Review each focused commit, then integrate through `main`.

## Shared interface that must stay stable

The first integration target is this conceptual sequence:

```text
UI request
  → Jac AdaptationRequest
  → Jac AdaptationPlan
  → Electron validation
  → Electron page mutation
  → ApplyResult with undoToken
  → UI explanation and optional PreferenceRule approval
```

The minimal methods needed for the first vertical slice are:

```text
getActivePageSnapshot()
createAdaptationPlan(request)
applyAdaptationPlan(plan)
undoAdaptation(undoToken)
proposePreference(plan, scope)
savePreference(rule)
```

The exact transport may be IPC, a local Jac API call, or a combination, but the payloads must follow `CONTRACTS.md` and remain JSON-compatible.

## Recommended integration order

1. Review Workstream A’s snapshot, action, undo, and bridge behavior.
2. Review Workstream B’s Jac types, deterministic planner, validation, and persistence behavior.
3. Review Workstream C’s UI adapter and replace its fixture with the real service calls.
4. Run the complete “Make the text larger” path on a real webpage.
5. Run the combined readability request.
6. Check undo, stale revisions, LLM failure fallback, and explicit preference approval.
7. Only then choose and build the final demo page.

## Rules for resolving disagreements

- Electron owns live page state and undo.
- Jac owns intent, policy, plans, explanations, and saved preferences.
- The UI owns presentation and user approval.
- The model produces data that Jac validates.
- The browser executes only allowlisted actions.
- Deterministic accessibility controls must work without the model.
- A contract change requires an update to `CONTRACTS.md` and a note in `DECISIONS.md`.
- If two branches touch the same file, the project lead decides the merge rather than allowing both sessions to overwrite each other.

## Final integration acceptance

The parallel build is ready to call the first release slice complete when a new user can:

1. launch the app;
2. see the question “How should this page work better for you?”;
3. open a real webpage;
4. ask for larger text;
5. see a structured explanation;
6. apply the change;
7. observe the real webpage change;
8. undo the change;
9. optionally save the preference for a chosen scope;
10. reload and see the saved preference considered;
11. continue using deterministic controls if the LLM is unavailable.

The full voice provider, medical claims, production privacy hardening, advanced page restructuring, and final visual polish remain separate follow-up work unless the team explicitly expands the scope.
