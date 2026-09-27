const { contextBridge, ipcRenderer } = require("electron");

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function invoke(method, payload) {
  if (payload !== undefined && !isObject(payload)) throw new TypeError(`${method} payload must be a JSON object`);
  return ipcRenderer.invoke(`accessible-browser:${method}`, payload);
}

function onPageChanged(listener) {
  if (typeof listener !== "function") throw new TypeError("listener must be a function");
  const wrapped = (_event, message) => {
    if (!isObject(message) || message.schemaVersion !== 1 || typeof message.tabId !== "string" || !Number.isInteger(message.pageRevision)) return;
    listener(Object.freeze({
      schemaVersion: message.schemaVersion,
      tabId: message.tabId,
      pageRevision: message.pageRevision,
      ...(typeof message.url === "string" ? { url: message.url } : {}),
      ...(typeof message.title === "string" ? { title: message.title } : {}),
      ...(typeof message.reason === "string" ? { reason: message.reason } : {}),
    }));
  };
  ipcRenderer.on("accessible-browser:page-changed", wrapped);
  return () => ipcRenderer.removeListener("accessible-browser:page-changed", wrapped);
}

const api = Object.freeze({
  getActivePageSnapshot: () => invoke("get-page-snapshot"),
  requestAdaptation: (request) => invoke("request-adaptation", request),
  applyAdaptationPlan: (plan) => invoke("apply-adaptation-plan", plan),
  undoAdaptation: (undoToken) => invoke("undo-adaptation", { undoToken }),
  executeBrowserCommand: (command) => invoke("execute-browser-command", command),
  getBrowserState: () => invoke("get-browser-state"),
  onPageChanged,
  ping: () => invoke("ping"),
});

function jac(operation, payload = {}) {
  return invoke("jac", { operation, payload });
}

const jacApi = Object.freeze({
    getActiveProfile: () => jac("get_active_profile"),
    updateActiveProfile: (profile) => jac("update_active_profile", { profile }),
    getApplicablePreferences: (origin, pageUrl) =>
      jac("get_applicable_preferences", { origin, pageUrl }),
    createAdaptationRequest: (request) =>
      jac("create_adaptation_request", request),
    createAdaptationPlan: (request) =>
      jac("create_adaptation_plan", { adaptation: request }),
    explainAdaptationPlan: (plan) =>
      jac("explain_adaptation_plan", { plan }),
    recordApplyResult: (record) =>
      jac("record_apply_result", record),
    proposePersistence: (plan) =>
      jac("propose_persistence", { plan }),
    saveApprovedPreference: (rule, explicitlyApproved) =>
      jac("save_approved_preference", { rule, explicitlyApproved }),
});

contextBridge.exposeInMainWorld("browser", api);
// Preserve the Phase 0 ping used by the Jac UI smoke surface.
contextBridge.exposeInMainWorld("accessibleBrowser", Object.freeze({
  ping: api.ping,
  jac: jacApi,
}));

function updateBridgeStatus() {
  const status = document.querySelector("[data-bridge-status]");
  if (!status) return;
  api.ping().then((result) => {
    if (result.status === "rejected") throw new Error(result.error?.message || "Electron bridge unavailable");
    status.textContent = `Electron bridge online (${result.source}, contract v${result.contractVersion})`;
  }).catch((error) => {
    status.textContent = `Electron bridge error: ${error.message}`;
  });
}

window.addEventListener("DOMContentLoaded", updateBridgeStatus);
