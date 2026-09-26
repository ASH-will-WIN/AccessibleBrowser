const { spawn } = require("node:child_process");
const path = require("node:path");

const repositoryRoot = path.resolve(__dirname, "..");
const jacUrl = process.env.ACCESSIBLE_BROWSER_JAC_URL || "http://127.0.0.1:8000";

let jacProcess;
let electronProcess;
let shuttingDown = false;

function waitForJac(url, timeoutMs = 45_000) {
  const startedAt = Date.now();

  return new Promise((resolve, reject) => {
    const poll = async () => {
      try {
        const response = await fetch(url);
        if (response.ok) {
          resolve();
          return;
        }
      } catch {
        // Jac is still starting. Poll again below.
      }

      if (Date.now() - startedAt >= timeoutMs) {
        reject(new Error(`Jac did not become ready at ${url}`));
        return;
      }

      setTimeout(poll, 250);
    };

    poll();
  });
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
  jacProcess = spawn("jac", ["run"], {
    cwd: repositoryRoot,
    stdio: "inherit",
  });

  jacProcess.on("error", (error) => {
    console.error(`Unable to start Jac: ${error.message}`);
    shutdown(1);
  });

  await waitForJac(jacUrl);

  const electronBinary = require("electron");
  electronProcess = spawn(electronBinary, [repositoryRoot], {
    cwd: repositoryRoot,
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
