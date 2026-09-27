"use strict";

const assert = require("node:assert/strict");

const ACTION_TYPES = new Set([
  "set_text_scale",
  "set_spacing",
  "set_contrast",
  "set_color_filter",
  "reduce_motion",
  "enlarge_targets",
  "hide_regions",
  "reading_mode",
  "focus_elements",
]);

const PREFERENCE_SCOPES = new Set(["page", "website", "global"]);
const ERROR_CODES = new Set([
  "INVALID_MESSAGE",
  "UNSUPPORTED_VERSION",
  "STALE_PAGE_REVISION",
  "TARGET_NOT_FOUND",
  "INVALID_PLAN",
  "UNSUPPORTED_ACTION",
  "INVALID_PARAMETERS",
  "APPLY_FAILED",
  "UNDO_FAILED",
  "LLM_UNAVAILABLE",
  "TIMEOUT",
  "PERMISSION_DENIED",
  "USER_CANCELLED",
  "SNAPSHOT_FAILED",
  "VOICE_PROVIDER_UNAVAILABLE",
]);

const FORBIDDEN_KEYS = new Set([
  "javascript",
  "javaScript",
  "executeJavaScript",
  "css",
  "rawCss",
  "shell",
  "shellCommand",
  "selector",
  "rawSelector",
  "browserOperation",
  "unrestrictedOperation",
]);

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function metadata({
  requestId,
  planId,
  tabId,
  pageRevision,
  status,
  errorCode,
  retryable,
  undoToken,
  changedState,
}) {
  const result = { status };
  for (const [key, value] of Object.entries({
    requestId,
    planId,
    tabId,
    pageRevision,
    errorCode,
    retryable,
    undoToken,
    changedState,
  })) {
    if (value !== undefined) result[key] = value;
  }
  return result;
}

function failure({ requestId, planId, tabId, pageRevision, errorCode, message, retryable, failedActionId, changedState = false }) {
  assert(ERROR_CODES.has(errorCode), `Unknown fixture error code: ${errorCode}`);
  return {
    ...metadata({ requestId, planId, tabId, pageRevision, status: "failed", errorCode, retryable, changedState }),
    message,
    ...(failedActionId ? { failedActionId } : {}),
  };
}

function validateSnapshot(snapshot) {
  const required = [
    "snapshotId",
    "tabId",
    "pageRevision",
    "url",
    "origin",
    "title",
    "viewport",
    "scroll",
    "elements",
    "sections",
    "contentSummary",
    "pageMetadata",
  ];
  for (const field of required) assert(Object.hasOwn(snapshot, field), `Snapshot is missing ${field}`);
  assert.equal(typeof snapshot.snapshotId, "string");
  assert.equal(typeof snapshot.tabId, "string");
  assert(Number.isInteger(snapshot.pageRevision) && snapshot.pageRevision >= 0, "Snapshot revision must be a non-negative integer");
  assert.equal(typeof snapshot.url, "string");
  assert.equal(typeof snapshot.origin, "string");
  assert.equal(typeof snapshot.title, "string");
  assert(snapshot.contentSummary.length <= 2000, "Snapshot text must be bounded");
  assert(Number.isFinite(snapshot.viewport.width) && Number.isFinite(snapshot.viewport.height));
  assert(Array.isArray(snapshot.elements));
  assert(Array.isArray(snapshot.sections));

  const ids = new Set();
  for (const element of snapshot.elements) {
    for (const field of ["elementId", "role", "accessibleName", "visibleText", "visibility", "disabled", "bounds"]) {
      assert(Object.hasOwn(element, field), `Element is missing ${field}`);
    }
    assert(!ids.has(element.elementId), `Element ID is duplicated: ${element.elementId}`);
    ids.add(element.elementId);
    assert(!Object.hasOwn(element, "value"), "Snapshot must not include form values");
    assert(!Object.hasOwn(element, "password"), "Snapshot must not include password values");
    assert(!Object.hasOwn(element, "cookie"), "Snapshot must not include cookies");
    assert(element.visibleText.length <= 500, "Element text must be bounded");
  }
  assert.equal(snapshot.pageMetadata.crossOriginIframes, false, "Cross-origin iframe content must be deferred in this fixture");
  return true;
}

function validateRequest(request) {
  for (const field of ["schemaVersion", "requestId", "tabId", "pageRevision", "userRequest", "activeProfile", "page", "applicableRules", "mode"]) {
    assert(Object.hasOwn(request, field), `Request is missing ${field}`);
  }
  assert.equal(request.schemaVersion, 1);
  assert.equal(typeof request.requestId, "string");
  assert.equal(typeof request.tabId, "string");
  assert(Number.isInteger(request.pageRevision));
  assert(request.userRequest.length > 0 && request.userRequest.length <= 1000);
  assert(["deterministic", "llm"].includes(request.mode));
  assert(Array.isArray(request.applicableRules));
  validateSnapshot(request.page);
  assert.equal(request.page.tabId, request.tabId);
  assert.equal(request.page.pageRevision, request.pageRevision);
  return true;
}

function findUnsafePayload(value, path = "payload") {
  if (Array.isArray(value)) {
    for (let index = 0; index < value.length; index += 1) {
      const found = findUnsafePayload(value[index], `${path}[${index}]`);
      if (found) return found;
    }
    return null;
  }
  if (!value || typeof value !== "object") {
    if (typeof value === "string" && /javascript:|<script|document\.|window\.|process\.|child_process/i.test(value)) return path;
    return null;
  }
  for (const [key, child] of Object.entries(value)) {
    if (FORBIDDEN_KEYS.has(key)) return `${path}.${key}`;
    const found = findUnsafePayload(child, `${path}.${key}`);
    if (found) return found;
  }
  return null;
}

function validateParameters(action) {
  const parameters = action.parameters;
  assert(parameters && typeof parameters === "object" && !Array.isArray(parameters), `${action.actionId} parameters must be an object`);
  switch (action.type) {
    case "set_text_scale":
      assert(typeof parameters.scale === "number" && parameters.scale >= 0.8 && parameters.scale <= 3, `${action.actionId} scale is out of range`);
      break;
    case "set_spacing":
      assert(["compact", "comfortable", "loose"].includes(parameters.spacing), `${action.actionId} spacing is invalid`);
      break;
    case "set_contrast":
      assert(["normal", "high", "maximum"].includes(parameters.level), `${action.actionId} contrast is invalid`);
      break;
    case "set_color_filter":
      assert(["none", "grayscale", "protanopia", "deuteranopia", "tritanopia"].includes(parameters.filter), `${action.actionId} color filter is invalid`);
      break;
    case "reduce_motion":
    case "enlarge_targets":
    case "reading_mode":
      assert(typeof parameters.enabled === "boolean", `${action.actionId} enabled must be boolean`);
      break;
    case "hide_regions":
      assert(Array.isArray(parameters.elementIds) && parameters.elementIds.length > 0, `${action.actionId} needs element IDs`);
      break;
    case "focus_elements":
      assert(Array.isArray(parameters.elementIds) && parameters.elementIds.length > 0, `${action.actionId} needs element IDs`);
      break;
    default:
      throw new Error(`Unsupported action ${action.type}`);
  }
}

function validatePlan(plan, request, { currentPageRevision = request.pageRevision } = {}) {
  const base = {
    requestId: plan.requestId || request.requestId,
    planId: plan.planId,
    tabId: plan.tabId || request.tabId,
    pageRevision: plan.pageRevision,
  };
  if (plan.schemaVersion !== 1 || plan.requestId !== request.requestId || plan.tabId !== request.tabId) {
    return failure({ ...base, errorCode: "INVALID_PLAN", message: "Plan metadata does not match the request.", retryable: false });
  }
  if (plan.pageRevision !== currentPageRevision || plan.pageRevision !== request.pageRevision) {
    return failure({ ...base, errorCode: "STALE_PAGE_REVISION", message: "The plan targets a stale page revision.", retryable: true });
  }
  if (plan.status !== "ready" || !Array.isArray(plan.actions) || plan.actions.length < 1) {
    return failure({ ...base, errorCode: "INVALID_PLAN", message: "Only a non-empty ready plan can be applied.", retryable: false });
  }
  if (!["high", "medium", "low"].includes(plan.confidence) || !Array.isArray(plan.warnings) || !["page", "website", "global", "none"].includes(plan.suggestedScope)) {
    return failure({ ...base, errorCode: "INVALID_PLAN", message: "Plan metadata is invalid.", retryable: false });
  }
  const snapshotIds = new Set(request.page.elements.map((element) => element.elementId));
  for (const action of plan.actions) {
    if (!action || typeof action !== "object" || !ACTION_TYPES.has(action.type)) {
      return failure({ ...base, errorCode: "UNSUPPORTED_ACTION", message: "The plan contains an unsupported action type.", retryable: false, failedActionId: action && action.actionId });
    }
    if (typeof action.actionId !== "string" || !action.actionId || typeof action.reason !== "string" || !action.reason || action.reversible !== true) {
      return failure({ ...base, errorCode: "INVALID_PLAN", message: "Every action needs an ID, reason, and reversible=true.", retryable: false, failedActionId: action.actionId });
    }
    const unsafePath = findUnsafePayload(action);
    if (unsafePath) {
      return failure({ ...base, errorCode: "INVALID_PLAN", message: `Unsafe executable payload at ${unsafePath}.`, retryable: false, failedActionId: action.actionId });
    }
    try {
      validateParameters(action);
    } catch (error) {
      return failure({ ...base, errorCode: "INVALID_PARAMETERS", message: error.message, retryable: false, failedActionId: action.actionId });
    }
    const targetIds = [
      ...(Array.isArray(action.targetElementIds) ? action.targetElementIds : []),
      ...(Array.isArray(action.parameters.elementIds) ? action.parameters.elementIds : []),
    ];
    for (const targetId of targetIds) {
      if (!snapshotIds.has(targetId)) {
        return failure({ ...base, errorCode: "TARGET_NOT_FOUND", message: `Target element ${targetId} is not in the current snapshot.`, retryable: true, failedActionId: action.actionId });
      }
    }
  }
  return { ...metadata({ ...base, status: "ready", changedState: false }), plan: clone(plan) };
}

function validatePreference(rule, { privateBrowsing = false } = {}) {
  for (const field of ["setting", "value", "scope", "source", "explicitlyApproved", "createdAt", "updatedAt"]) {
    assert(Object.hasOwn(rule, field), `Preference is missing ${field}`);
  }
  assert(PREFERENCE_SCOPES.has(rule.scope), `Invalid preference scope: ${rule.scope}`);
  assert(["setup", "voice", "manual", "learned"].includes(rule.source), `Invalid preference source: ${rule.source}`);
  assert.equal(typeof rule.explicitlyApproved, "boolean");
  if (privateBrowsing) assert.equal(rule.explicitlyApproved, false, "Private browsing must not persist preferences");
  return true;
}

function preferenceRank(rule) {
  return { global: 0, website: 1, page: 2 }[rule.scope];
}

class FixtureAdapter {
  constructor({ snapshot, request, readyPlan, stalePlan, failedApply, llmUnavailable, voiceUnavailable }) {
    validateSnapshot(snapshot);
    validateRequest(request);
    this.snapshot = clone(snapshot);
    this.request = clone(request);
    this.readyPlan = clone(readyPlan);
    this.stalePlan = clone(stalePlan);
    this.failedApply = clone(failedApply);
    this.llmUnavailable = clone(llmUnavailable);
    this.voiceUnavailable = clone(voiceUnavailable);
    this.pageState = { textScale: 1, spacing: "normal", enlargedTargets: false };
    this.beforeApply = null;
    this.undoToken = null;
    this.preferences = [];
  }

  createSnapshot() {
    return {
      ...metadata({ tabId: this.snapshot.tabId, pageRevision: this.snapshot.pageRevision, status: "completed", changedState: false }),
      snapshot: clone(this.snapshot),
    };
  }

  createRequest({ userRequest = this.request.userRequest, mode = this.request.mode, activeProfile = this.request.activeProfile, applicableRules = this.request.applicableRules } = {}) {
    const request = {
      ...clone(this.request),
      userRequest,
      mode,
      activeProfile: clone(activeProfile),
      applicableRules: clone(applicableRules),
      page: clone(this.snapshot),
      pageRevision: this.snapshot.pageRevision,
    };
    validateRequest(request);
    return { ...metadata({ requestId: request.requestId, tabId: request.tabId, pageRevision: request.pageRevision, status: "completed", changedState: false }), request };
  }

  requestPlan(request = this.request) {
    if (request.mode === "llm" && this.llmUnavailable) return clone(this.llmUnavailable);
    return {
      ...metadata({ requestId: this.readyPlan.requestId, planId: this.readyPlan.planId, tabId: this.readyPlan.tabId, pageRevision: this.readyPlan.pageRevision, status: "ready", changedState: false }),
      plan: clone(this.readyPlan),
    };
  }

  validatePlan(plan = this.readyPlan, request = this.request) {
    return validatePlan(plan, request, { currentPageRevision: this.snapshot.pageRevision });
  }

  previewPlan(plan = this.readyPlan, request = this.request) {
    const validation = this.validatePlan(plan, request);
    if (validation.status !== "ready") return validation;
    return {
      ...metadata({ requestId: plan.requestId, planId: plan.planId, tabId: plan.tabId, pageRevision: plan.pageRevision, status: "preview", changedState: false }),
      summary: plan.summary,
      confidence: plan.confidence,
      warnings: clone(plan.warnings),
      actions: clone(plan.actions),
      affectedTargetIds: plan.actions.flatMap((action) => action.targetElementIds || action.parameters.elementIds || []),
      applyAvailable: true,
      cancelAvailable: true,
    };
  }

  applyPlan(plan = this.readyPlan, request = this.request) {
    const validation = this.validatePlan(plan, request);
    if (validation.status !== "ready") return validation;
    if (plan.planId === this.failedApply.plan.planId) {
      return {
        ...failure({ requestId: plan.requestId, planId: plan.planId, tabId: plan.tabId, pageRevision: plan.pageRevision, errorCode: "APPLY_FAILED", message: "The plan was rolled back after an action failed.", retryable: false, failedActionId: this.failedApply.forcedFailure.actionId }),
        rolledBack: true,
        partialSuccess: false,
        changedState: false,
      };
    }
    this.beforeApply = clone(this.pageState);
    for (const action of plan.actions) {
      if (action.type === "set_text_scale") this.pageState.textScale = action.parameters.scale;
      if (action.type === "set_spacing") this.pageState.spacing = action.parameters.spacing;
      if (action.type === "enlarge_targets") this.pageState.enlargedTargets = action.parameters.enabled;
    }
    this.undoToken = `undo_${plan.planId}`;
    return {
      ...metadata({ requestId: plan.requestId, planId: plan.planId, tabId: plan.tabId, pageRevision: plan.pageRevision, status: "completed", undoToken: this.undoToken, changedState: true }),
      changed: clone(this.pageState),
      result: "Applied the validated accessibility plan.",
    };
  }

  undoPlan(undoToken = this.undoToken) {
    if (!undoToken || undoToken !== this.undoToken || !this.beforeApply) {
      return failure({ requestId: this.readyPlan.requestId, planId: this.readyPlan.planId, tabId: this.snapshot.tabId, pageRevision: this.snapshot.pageRevision, errorCode: "UNDO_FAILED", message: "There is no valid undo transaction.", retryable: false });
    }
    this.pageState = clone(this.beforeApply);
    this.beforeApply = null;
    this.undoToken = null;
    return {
      ...metadata({ requestId: this.readyPlan.requestId, planId: this.readyPlan.planId, tabId: this.snapshot.tabId, pageRevision: this.snapshot.pageRevision, status: "completed", changedState: true }),
      restored: clone(this.pageState),
    };
  }

  savePreference(rule, explicitlyApproved) {
    const candidate = { ...clone(rule), explicitlyApproved };
    if (!explicitlyApproved) {
      return {
        ...metadata({ requestId: this.request.requestId, tabId: this.snapshot.tabId, pageRevision: this.snapshot.pageRevision, status: "cancelled", retryable: false, changedState: false }),
        errorCode: "USER_CANCELLED",
        message: "The preference was not saved without explicit approval.",
      };
    }
    validatePreference(candidate);
    this.preferences.push(candidate);
    return {
      ...metadata({ requestId: this.request.requestId, tabId: this.snapshot.tabId, pageRevision: this.snapshot.pageRevision, status: "completed", changedState: true }),
      preference: clone(candidate),
    };
  }

  loadPreferences() {
    return {
      ...metadata({ requestId: this.request.requestId, tabId: this.snapshot.tabId, pageRevision: this.snapshot.pageRevision, status: "completed", changedState: false }),
      preferences: clone(this.preferences),
    };
  }

  runVoiceCommand() {
    return clone(this.voiceUnavailable);
  }
}

module.exports = {
  ACTION_TYPES,
  ERROR_CODES,
  FixtureAdapter,
  PREFERENCE_SCOPES,
  preferenceRank,
  validatePlan,
  validatePreference,
  validateRequest,
  validateSnapshot,
};
