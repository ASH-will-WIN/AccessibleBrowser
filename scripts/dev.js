const { spawn } = require("node:child_process");
const fs = require("node:fs/promises");
const path = require("node:path");
const { spawnJac } = require("./jac");

const repositoryRoot = path.resolve(__dirname, "..");
const configuredJacUrl = process.env.ACCESSIBLE_BROWSER_JAC_URL || "";
const jacDevPortFile = path.join(repositoryRoot, ".jac", "client", ".dev-port");
const jacStartupTimeoutMs = Number(process.env.ACCESSIBLE_BROWSER_JAC_TIMEOUT_MS) || 120_000;

let jacProcess;
let electronProcess;
let shuttingDown = false;

async function isJacUi(url) {
  try {
    const response = await fetch(url);
    const contentType = response.headers.get("content-type") || "";
    return response.ok && (contentType.includes("text/html") || contentType.includes("application/xhtml+xml"));
  } catch {
    return false;
  }
}

function waitForJac(timeoutMs = 45_000) {
  const startedAt = Date.now();

  return new Promise((resolve, reject) => {
    let lastCandidates = [];
    const poll = async () => {
      if (jacProcess?.exitCode !== null && jacProcess?.exitCode !== undefined) {
        reject(new Error(`Jac exited before becoming ready (exit code ${jacProcess.exitCode})`));
        return;
      }
      if (jacProcess?.signalCode) {
        reject(new Error(`Jac exited before becoming ready (signal ${jacProcess.signalCode})`));
        return;
      }

      const candidates = configuredJacUrl ? [configuredJacUrl] : await jacUiCandidates();
      lastCandidates = candidates;
      for (const url of candidates) {
        if (await isJacUi(url)) {
          resolve(url);
          return;
        }
      }

      if (Date.now() - startedAt >= timeoutMs) {
        reject(new Error(`Jac UI did not become ready at ${lastCandidates.join(", ")}`));
        return;
      }

      setTimeout(poll, 250);
    };

    poll();
  });
}

async function jacUiCandidates() {
  const candidates = [];
  try {
    const port = Number((await fs.readFile(jacDevPortFile, "utf8")).trim());
    if (Number.isInteger(port) && port >= 1024 && port <= 65535) candidates.push(`http://127.0.0.1:${port}`);
  } catch {
    // Jac may not have written its Vite port marker yet.
  }
  for (const port of [8000, 8001, 8003, 8004, 8005]) {
    const url = `http://127.0.0.1:${port}`;
    if (!candidates.includes(url)) candidates.push(url);
  }
  return candidates;
}

function stopProcess(child) {
  if (child && !child.killed) child.kill("SIGINT");
}

function shutdown(exitCode = 0) {
  if (shuttingDown) return;
  shuttingDown = true;
  stopProcess(electronProcess);
  stopProcess(jacProcess);
  setTimeout(() => process.exit(exitCode), 250);
}

async function main() {
  jacProcess = spawnJac(["run"], {
    cwd: repositoryRoot,
    stdio: "inherit",
  });

  jacProcess.on("error", (error) => {
    console.error(`Unable to start Jac: ${error.message}`);
    shutdown(1);
  });

  const resolvedJacUrl = await waitForJac(jacStartupTimeoutMs);

  const electronBinary = require("electron");
  electronProcess = spawn(electronBinary, [repositoryRoot], {
    cwd: repositoryRoot,
    env: {
      ...process.env,
      ACCESSIBLE_BROWSER_JAC_URL: resolvedJacUrl,
      ACCESSIBLE_BROWSER_DEVELOPMENT: "1",
    },
    stdio: "inherit",
  });

  electronProcess.on("error", (error) => {
    console.error(`Unable to start Electron: ${error.message}`);
    shutdown(1);
  });

  electronProcess.on("exit", (code) => shutdown(code ?? 0));
}

process.on("SIGINT", () => shutdown(0));
process.on("SIGTERM", () => shutdown(0));

main().catch((error) => {
  console.error(error.message);
  shutdown(1);
});
