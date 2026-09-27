"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  FixtureAdapter,
  BROWSER_COMMAND_KINDS,
  preferenceRank,
  validateBrowserCommand,
  validatePlan,
  validatePreference,
  validateRequest,
  validateSnapshot,
} = require("./test-adapter");

const fixturesRoot = path.resolve(__dirname, "..", "fixtures", "integration");

function load(name) {
  return JSON.parse(fs.readFileSync(path.join(fixturesRoot, name), "utf8"));
}

const fixtures = {
  snapshot: load("valid-page-snapshot.json"),
  request: load("valid-adaptation-request.json"),
  readyPlan: load("ready-plan.json"),
  rejectedPlan: load("rejected-plan.json"),
  staleRequest: load("stale-request.json"),
  stalePlan: load("stale-plan.json"),
  invalidActions: load("invalid-actions.json"),
  failedApply: load("failed-apply.json"),
  llmUnavailable: load("llm-unavailable.json"),
  voiceUnavailable: load("voice-unavailable.json"),
  snapshotFailure: load("snapshot-failure.json"),
  preferences: load("preferences.json"),
};

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    passed += 1;
    console.log(`PASS [fixture] ${name}`);
  } catch (error) {
    failed += 1;
    console.error(`FAIL [fixture] ${name}`);
    console.error(`      ${error.stack || error.message}`);
  }
}

function assertErrorShape(result, expectedCode) {
  assert.equal(result.status, "failed");
  assert.equal(result.errorCode, expectedCode);
  assert.equal(typeof result.requestId, "string");
  assert.equal(typeof result.planId, "string");
  assert.equal(typeof result.tabId, "string");
  assert(Number.isInteger(result.pageRevision));
  assert.equal(typeof result.retryable, "boolean");
}

function assertFixtureError(result, expected) {
  for (const field of ["status", "errorCode", "retryable"]) assert.equal(result[field], expected[field], field);
  assert.equal(result.changedState, expected.changedState);
}

const adapter = new FixtureAdapter({
  snapshot: fixtures.snapshot,
  request: fixtures.request,
  readyPlan: fixtures.readyPlan,
  stalePlan: fixtures.stalePlan,
  failedApply: fixtures.failedApply,
  llmUnavailable: fixtures.llmUnavailable,
  voiceUnavailable: fixtures.voiceUnavailable,
});

test("page snapshot has the contract fields and excludes sensitive data", () => {
  validateSnapshot(fixtures.snapshot);
  const serialized = JSON.stringify(fixtures.snapshot);
  assert(!/password|cookie|apiKey|formValue|secret/i.test(serialized));
  assert(fixtures.snapshot.contentSummary.length <= 2000);
  assert.equal(fixtures.snapshot.pageMetadata.crossOriginIframes, false);
});

test("snapshot IDs and element IDs are stable within a page revision", () => {
  const first = adapter.createSnapshot();
  const second = adapter.createSnapshot();
  assert.equal(first.snapshot.snapshotId, second.snapshot.snapshotId);
  assert.deepEqual(
    first.snapshot.elements.map((element) => element.elementId),
    second.snapshot.elements.map((element) => element.elementId),
  );
  assert.equal(first.pageRevision, second.pageRevision);
});

test("page revision changes are represented after navigation or major page changes", () => {
  assert.equal(fixtures.snapshot.pageRevision + 1, fixtures.staleRequest.expectedCurrentPageRevision);
  assert.equal(fixtures.stalePlan.expectedCurrentPageRevision, fixtures.staleRequest.expectedCurrentPageRevision);
});

test("snapshot creation failure is structured and retryable", () => {
  const result = fixtures.snapshotFailure;
  assertErrorShape(result, "SNAPSHOT_FAILED");
  assert.equal(result.retryable, true);
  assert.equal(result.changedState, false);
});

test("adaptation request contains profile, page context, rules, and explicit mode", () => {
  validateRequest(fixtures.request);
  assert.equal(fixtures.request.userRequest, "Make this page easier to read and make the buttons easier to click.");
  assert(Object.hasOwn(fixtures.request, "activeProfile"));
  assert(Object.hasOwn(fixtures.request, "applicableRules"));
  assert(["deterministic", "llm"].includes(fixtures.request.mode));
  assert(!/javascript|<script|shellCommand/i.test(JSON.stringify(fixtures.request)));
});

test("fixture adapter creates a request from the current snapshot", () => {
  const result = adapter.createRequest();
  assert.equal(result.status, "completed");
  assert.equal(result.request.requestId, fixtures.request.requestId);
  assert.equal(result.request.tabId, fixtures.snapshot.tabId);
  assert.equal(result.request.pageRevision, fixtures.snapshot.pageRevision);
});

test("ready plan has allowlisted, typed, reversible actions", () => {
  const result = adapter.requestPlan(fixtures.request);
  assert.equal(result.status, "ready");
  const validation = adapter.validatePlan(fixtures.readyPlan, fixtures.request);
  assert.equal(validation.status, "ready");
  assert(fixtures.readyPlan.actions.length > 0);
  for (const action of fixtures.readyPlan.actions) {
    assert.equal(typeof action.actionId, "string");
    assert.equal(typeof action.type, "string");
    assert.equal(typeof action.reason, "string");
    assert.equal(action.reversible, true);
  }
});

test("rejected plan is explanatory and contains no executable action", () => {
  const plan = fixtures.rejectedPlan;
  assert.equal(plan.status, "rejected");
  assert.equal(plan.errorCode, "INVALID_PLAN");
  assert.equal(plan.actions.length, 0);
  assert.equal(typeof plan.explanation, "string");
  assert(!/javascript|css|shell|execute/i.test(JSON.stringify(plan)));
});

test("all invalid action payloads are rejected before mutation", () => {
  for (const fixture of fixtures.invalidActions) {
    const result = validatePlan(fixture.plan, fixtures.request);
    assertErrorShape(result, fixture.expectedErrorCode);
    assert.equal(result.changedState, false);
    assert.equal(result.failedActionId, fixture.plan.actions[0].actionId);
  }
});

test("preview exposes the plan and does not mutate page state", () => {
  const before = JSON.stringify(adapter.pageState);
  const preview = adapter.previewPlan(fixtures.readyPlan, fixtures.request);
  assert.equal(preview.status, "preview");
  assert.equal(preview.changedState, false);
  assert.equal(preview.applyAvailable, true);
  assert.equal(preview.cancelAvailable, true);
  assert.equal(preview.summary, fixtures.readyPlan.summary);
  assert.equal(preview.actions.length, fixtures.readyPlan.actions.length);
  assert.equal(JSON.stringify(adapter.pageState), before);
});

test("apply is transactional and returns one undo token with changed state", () => {
  const result = adapter.applyPlan(fixtures.readyPlan, fixtures.request);
  assert.equal(result.status, "completed");
  assert.equal(result.changedState, true);
  assert.equal(typeof result.undoToken, "string");
  assert.equal(result.requestId, fixtures.readyPlan.requestId);
  assert.equal(result.planId, fixtures.readyPlan.planId);
  assert.equal(result.tabId, fixtures.readyPlan.tabId);
  assert.equal(result.pageRevision, fixtures.readyPlan.pageRevision);
  assert.equal(result.changed.textScale, 1.25);
  assert.equal(result.changed.spacing, "comfortable");
  assert.equal(result.changed.enlargedTargets, true);
});

test("undo restores the complete prior page state", () => {
  const result = adapter.undoPlan();
  assert.equal(result.status, "completed");
  assert.equal(result.changedState, true);
  assert.deepEqual(result.restored, { textScale: 1, spacing: "normal", enlargedTargets: false });
  assert.equal(adapter.undoPlan().errorCode, "UNDO_FAILED");
});

test("stale plan is rejected before mutation and is retryable", () => {
  const staleRequestContext = { ...fixtures.request, requestId: fixtures.stalePlan.requestId };
  const result = validatePlan(fixtures.stalePlan, staleRequestContext, { currentPageRevision: fixtures.stalePlan.expectedCurrentPageRevision });
  assertErrorShape(result, "STALE_PAGE_REVISION");
  assert.equal(result.retryable, true);
  assert.equal(result.changedState, false);
  assert.equal(fixtures.stalePlan.expectedResult.mutationApplied, false);
});

test("failed apply rolls back earlier actions and makes no partial-success claim", () => {
  const result = adapter.applyPlan(fixtures.failedApply.plan, {
    ...fixtures.request,
    requestId: fixtures.failedApply.plan.requestId,
  });
  assertFixtureError(result, fixtures.failedApply.expectedResult);
  assert.equal(result.failedActionId, fixtures.failedApply.forcedFailure.actionId);
  assert.equal(result.rolledBack, true);
  assert.equal(result.partialSuccess, false);
  assert.deepEqual(adapter.pageState, { textScale: 1, spacing: "normal", enlargedTargets: false });
});

test("LLM unavailable is truthful, retryable, and does not produce a fake plan", () => {
  const result = adapter.requestPlan({ ...fixtures.request, mode: "llm" });
  assertErrorShape(result, "LLM_UNAVAILABLE");
  assert.equal(result.retryable, true);
  assert.equal(result.changedState, false);
  assert.equal(fixtures.llmUnavailable.fakePlanPresented, false);
  assert.equal(fixtures.llmUnavailable.deterministicControlsAvailable, true);
});

test("explicit preference approval is required and saved values are reloadable", () => {
  const rule = fixtures.preferences.approved[1];
  const cancelled = adapter.savePreference(rule, false);
  assert.equal(cancelled.status, "cancelled");
  assert.equal(cancelled.errorCode, "USER_CANCELLED");
  assert.equal(adapter.loadPreferences().preferences.length, 0);

  const saved = adapter.savePreference(rule, true);
  assert.equal(saved.status, "completed");
  assert.equal(saved.preference.explicitlyApproved, true);
  assert.equal(saved.preference.scope, "website");
  assert.equal(adapter.loadPreferences().preferences.length, 1);
});

test("preference scopes use global, website, then page specificity", () => {
  const rules = fixtures.preferences.approved;
  rules.forEach((rule) => validatePreference(rule));
  const ordered = [...rules].sort((left, right) => preferenceRank(left) - preferenceRank(right));
  assert.deepEqual(ordered.map((rule) => rule.scope), ["global", "website", "page"]);
  assert.equal(ordered.at(-1).value, 1.5);
  assert.notEqual(rules[1].origin, "https://other.example");
  assert.throws(() => validatePreference(fixtures.preferences.privateBrowsing, { privateBrowsing: true }));
});

test("voice provider unavailability sends no BrowserCommand and preserves text paths", () => {
  const result = adapter.runVoiceCommand();
  assertErrorShape(result, "VOICE_PROVIDER_UNAVAILABLE");
  assert.equal(result.providerState, "unavailable");
  assert.equal(result.browserCommandSent, false);
  assert.equal(result.keyboardPathAvailable, true);
  assert.equal(result.textPathAvailable, true);
});

test("BrowserCommand accepts every allowlisted kind with typed arguments", () => {
  const commands = [
    ["new_tab", {}],
    ["close_tab", {}],
    ["switch_tab", { tabId: fixtures.snapshot.tabId }],
    ["back", {}],
    ["forward", {}],
    ["reload", {}],
    ["navigate", { url: "https://example.test/article" }],
    ["scroll", { deltaY: 400, deltaX: 10 }],
    ["zoom", { factor: 1.25 }],
    ["search", { searchType: "page", query: "accessible" }],
    ["read_page", {}],
    ["stop_reading", {}],
  ];
  assert.equal(commands.length, BROWSER_COMMAND_KINDS.size);
  for (const [kind, arguments_] of commands) {
    const result = validateBrowserCommand({
      schemaVersion: 1,
      requestId: `command_${kind}`,
      tabId: fixtures.snapshot.tabId,
      kind,
      arguments: arguments_,
      requiresConfirmation: kind === "close_tab",
    });
    assert.equal(result.status, "accepted", kind);
  }
});

test("BrowserCommand rejects unknown, unbounded, and unconfirmed operations", () => {
  const base = {
    schemaVersion: 1,
    requestId: "command_invalid",
    tabId: fixtures.snapshot.tabId,
    arguments: {},
    requiresConfirmation: false,
  };
  assert.deepEqual(validateBrowserCommand({ ...base, kind: "run_shell" }), { status: "rejected", errorCode: "INVALID_MESSAGE" });
  assert.deepEqual(validateBrowserCommand({ ...base, kind: "scroll", arguments: { deltaY: 2001 } }), { status: "rejected", errorCode: "INVALID_PARAMETERS" });
  assert.deepEqual(validateBrowserCommand({ ...base, kind: "zoom", arguments: { factor: 3 } }), { status: "rejected", errorCode: "INVALID_PARAMETERS" });
  assert.deepEqual(validateBrowserCommand({ ...base, kind: "search", arguments: { searchType: "page", query: "  " } }), { status: "rejected", errorCode: "INVALID_PARAMETERS" });
  assert.deepEqual(validateBrowserCommand({ ...base, kind: "close_tab" }), { status: "cancelled", errorCode: "USER_CANCELLED" });
});

console.log(`\nFixture contract tests: ${passed} passed, ${failed} failed`);
console.log("Live Electron/Jac/UI integration: NOT RUN; see tests/integration/README.md and cases.md.");
process.exitCode = failed === 0 ? 0 : 1;
