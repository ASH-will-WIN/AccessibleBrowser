# Jac core

The Jac-owned product layer lives under `jac/` and keeps the Electron boundary
data-only.

## Service flow

`AdaptationService` in `jac/service.jac` exposes the stable flow used by the UI
and bridge. `jac/api.jac` publishes the same operations as typed Jac RPC
endpoints (`/function/<name>`), and the Electron preload exposes an explicit
allowlisted facade for those operations:

1. Read or update the active `AccessibilityProfile`.
2. Resolve approved preferences using global → website/origin → page precedence.
3. Create an `AdaptationRequest` from a bounded `PageSnapshot`.
4. Generate a deterministic or LLM-backed `AdaptationPlan`.
5. Validate metadata, action allowlists, parameters, target IDs, and page revision.
6. Explain the plan and propose explicit persistence scope.
7. Record apply/undo results and save a rule only after approval.
8. Validate an allowlisted `BrowserCommand` before forwarding it to Electron.

`jac/core.jac` owns the JSON-compatible contract objects. Plans contain no
JavaScript, CSS, selectors, shell commands, or unrestricted browser commands.

## Planning and provider boundary

`jac/provider.jac` is the only module that calls NVIDIA NIM. It reads
`NVIDIA_API_KEY`, optional `NVIDIA_NIM_MODEL`, and optional `NVIDIA_NIM_BASE_URL`, caps the snapshot and response,
redacts textbox/password text, and requests JSON-only structured output. Model
results pass through the same Jac validator as deterministic results. Missing
configuration, network errors, malformed JSON, and invalid actions return a
safe deterministic fallback when the request is locally recognizable.

## Persistence

`PreferenceProfileNode`, `PreferenceRuleNode`, and `ProfileHasRule` define the
Jac graph model. Served endpoints use `graph_load_store()` and attach the
profile, approved rules, and apply history to the current Jac `root`, so they
survive requests and use Jac's persistent store. Rule values are encoded as
JSON strings in graph nodes because Jac's persistent serializer cannot safely
materialize an `any`-typed node field. The atomic JSON adapter remains for
isolated deterministic tests and local migration compatibility; neither path
stores page snapshots or raw form values.

## Public bridge surface

The Electron main process calls only the allowlisted Jac functions below and
never receives or forwards `NVIDIA_API_KEY`:

```text
get_active_profile
update_active_profile
get_applicable_preferences
create_adaptation_request
create_adaptation_plan
explain_adaptation_plan
record_apply_result
propose_persistence
save_approved_preference
forward_browser_command
```

`executeBrowserCommand` first asks Jac to validate the command, then performs
only fixed browser operations supported by the current single-window scaffold
(back, forward, reload, bounded scroll, bounded zoom, and page search).
Multi-tab operations and DOM snapshot/action application remain with the
Electron browser-host workstream because this scaffold does not yet have a
tab or page-snapshot subsystem.

## Verification

```text
npm run jac:check
env -u NVIDIA_API_KEY -u NVIDIA_NIM_MODEL node scripts/jac.js test jac/core_test.jac -v
```

The fixtures in `jac/fixtures.jac` use the production contract shapes and cover
text scale, larger targets, no-op behavior, validation errors, persistence
precedence, declined persistence, and missing-LLM fallback.
