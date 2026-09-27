const { contextBridge, ipcRenderer } = require("electron");

const invoke = (method, payload) => ipcRenderer.invoke(`accessible-browser:${method}`, payload);

function onPageChanged(listener) {
  if (typeof listener !== "function") throw new TypeError("listener must be a function");
  const wrapped = (_event, message) => listener(message);
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

contextBridge.exposeInMainWorld("browser", api);
// Preserve the Phase 0 ping used by the Jac UI smoke surface.
contextBridge.exposeInMainWorld("accessibleBrowser", Object.freeze({ ping: api.ping }));

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
