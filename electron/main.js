const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("node:path");

function createWindow() {
  const window = new BrowserWindow({
    width: 1280,
    height: 820,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  const jacUrl = process.env.ACCESSIBLE_BROWSER_JAC_URL || "http://127.0.0.1:8000";
  window.loadURL(jacUrl).catch(() => {
    window.loadFile(path.join(__dirname, "placeholder.html"));
  });
}

ipcMain.handle("accessible-browser:ping", () => ({
  ok: true,
  source: "electron",
  contractVersion: 1,
}));

app.whenReady().then(() => {
  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
