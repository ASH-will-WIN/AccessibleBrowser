const { contextBridge, ipcRenderer } = require("electron");

function jac(operation, payload = {}) {
  return ipcRenderer.invoke("accessible-browser:jac", { operation, payload });
}

contextBridge.exposeInMainWorld("accessibleBrowser", {
  ping: () => ipcRenderer.invoke("accessible-browser:ping"),
  jac: {
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
  },
  executeBrowserCommand: (command) =>
    ipcRenderer.invoke("accessible-browser:browser-command", command),
});

function updateBridgeStatus() {
  const status = document.querySelector("[data-bridge-status]");
  if (!status) return;

  ipcRenderer.invoke("accessible-browser:ping").then((result) => {
    status.textContent =
      `Electron bridge online (${result.source}, contract v${result.contractVersion})`;
  }).catch((error) => {
    status.textContent = `Electron bridge error: ${error.message}`;
  });
}

window.addEventListener("DOMContentLoaded", () => {
  const poll = setInterval(() => {
    if (!document.querySelector("[data-bridge-status]")) return;
    clearInterval(poll);
    updateBridgeStatus();
  }, 50);
  setTimeout(() => clearInterval(poll), 2_000);
});
