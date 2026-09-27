const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("node:path");

const jacUrl = process.env.ACCESSIBLE_BROWSER_JAC_URL || "http://127.0.0.1:8000";
const jacOperations = new Set([
  "get_active_profile",
  "update_active_profile",
  "get_applicable_preferences",
  "create_adaptation_request",
  "create_adaptation_plan",
  "explain_adaptation_plan",
  "record_apply_result",
  "propose_persistence",
  "save_approved_preference",
  "forward_browser_command",
]);

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 820,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.loadURL(jacUrl).catch(() => {
    mainWindow.loadFile(path.join(__dirname, "placeholder.html"));
  });
}

function bridgeError(code, message, retryable = false) {
  const error = new Error(message);
  error.code = code;
  error.retryable = retryable;
  return error;
}

async function callJac(operation, payload = {}) {
  if (!jacOperations.has(operation)) {
    throw bridgeError("INVALID_MESSAGE", "Jac operation is not allowlisted.");
  }

  const response = await fetch(`${jacUrl.replace(/\/$/, "")}/function/${operation}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  let envelope;
  try {
    envelope = await response.json();
  } catch {
    throw bridgeError("INVALID_MESSAGE", "Jac returned a non-JSON response.", true);
  }

  if (!response.ok || envelope.ok === false) {
    const detail = envelope.error?.message || `Jac request failed with HTTP ${response.status}.`;
    throw bridgeError(envelope.error?.code || "JAC_UNAVAILABLE", detail, response.status >= 500);
  }
  return envelope.data?.result ?? envelope.data ?? envelope;
}

function validateCommandShape(command) {
  if (!command || typeof command !== "object") {
    throw bridgeError("INVALID_MESSAGE", "Browser command must be an object.");
  }
  if (command.schemaVersion !== 1 || typeof command.kind !== "string") {
    throw bridgeError("UNSUPPORTED_VERSION", "Browser command schema is unsupported.");
  }
}

async function executeBrowserCommand(command) {
  validateCommandShape(command);
  const validation = await callJac("forward_browser_command", { command });
  if (!validation?.ok) return validation;
  if (!mainWindow || mainWindow.isDestroyed()) {
    throw bridgeError("APPLY_FAILED", "The Electron window is not available.", true);
  }

  const contents = mainWindow.webContents;
  const args = command.arguments || {};
  switch (command.kind) {
    case "back":
      if (contents.canGoBack()) contents.goBack();
      break;
    case "forward":
      if (contents.canGoForward()) contents.goForward();
      break;
    case "reload":
      contents.reload();
      break;
    case "scroll":
      await contents.executeJavaScript(`window.scrollBy(0, ${Number(args.delta)});`);
      break;
    case "zoom":
      contents.setZoomFactor(Number(args.level));
      break;
    case "search":
      contents.findInPage(String(args.query));
      break;
    default:
      return {
        ok: false,
        status: "rejected",
        error: {
          requestId: command.requestId,
          code: "UNSUPPORTED_ACTION",
          message: `Electron's current single-window scaffold does not implement ${command.kind}.`,
          retryable: false,
        },
      };
  }
  return { ok: true, status: "completed", command };
}

ipcMain.handle("accessible-browser:ping", () => ({
  ok: true,
  source: "electron",
  contractVersion: 1,
}));

ipcMain.handle("accessible-browser:jac", async (_event, request = {}) => {
  if (!request || typeof request.operation !== "string") {
    throw bridgeError("INVALID_MESSAGE", "A Jac operation is required.");
  }
  return callJac(request.operation, request.payload || {});
});

ipcMain.handle("accessible-browser:browser-command", (_event, command) =>
  executeBrowserCommand(command)
);

app.whenReady().then(() => {
  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
