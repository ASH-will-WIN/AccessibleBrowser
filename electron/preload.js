const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("accessibleBrowser", {
  ping: () => ipcRenderer.invoke("accessible-browser:ping"),
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
