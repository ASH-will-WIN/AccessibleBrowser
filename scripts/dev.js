const { spawn } = require("node:child_process");
const { loadEnvFile } = require("node:process");
const path = require("node:path");
const { spawnJac } = require("./jac");

const repositoryRoot = path.resolve(__dirname, "..");
try { loadEnvFile(path.join(repositoryRoot, ".env")); } catch { /* .env is optional */ }
const configuredJacUrl = process.env.ACCESSIBLE_BROWSER_JAC_URL || "";
const jacStartupTimeoutMs = Number(process.env.ACCESSIBLE_BROWSER_JAC_TIMEOUT_MS) || 120_000;

let jacProcess;
let electronProcess;
let shuttingDown = false;
let observedJacUiUrl = "";
let observedJacApiUrl = "";

function observeJacOutput(chunk, writer) {
  const text = chunk.toString();
  writer.write(text);
  const localMatch = text.match(/\bLocal:\s+(https?:\/\/[^\s]+)/);
  const apiMatch = text.match(/\bAPI:\s+(https?:\/\/[^\s]+)/) || text.match(/Jac API Server running on\s+(https?:\/\/[^\s]+)/);
  if (localMatch) observedJacUiUrl = localMatch[1].replace(/[),]+$/, "");
  if (apiMatch) observedJacApiUrl = apiMatch[1].replace(/[),]+$/, "");
}

async function isJacUi(url) {
  try {
    const response = await fetch(url);
    const contentType = response.headers.get("content-type") || "";
    return response.ok && (contentType.includes("text/html") || contentType.includes("application/xhtml+xml"));
  } catch {
    return false;
  }
}

async function isReachable(url) {
  try {
    const response = await fetch(url);
    return response.status < 500;
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
  // The marker can belong to a previous Jac process. Prefer the URL emitted
  // by the current child process and do not attach Electron to stale servers.
  if (observedJacUiUrl) return [observedJacUiUrl];
  return [];
}

async function jacApiCandidates() {
  const candidates = [];
  if (observedJacApiUrl) candidates.push(observedJacApiUrl);
  const configuredApiUrl = process.env.ACCESSIBLE_BROWSER_JAC_API_URL || "";
  if (configuredApiUrl && !candidates.includes(configuredApiUrl)) candidates.push(configuredApiUrl);
  return candidates;
}

async function waitForJacApi(timeoutMs = 45_000) {
  const startedAt = Date.now();
  let lastCandidates = [];
  while (Date.now() - startedAt < timeoutMs) {
    lastCandidates = await jacApiCandidates();
    for (const url of lastCandidates) {
      if (await isReachable(url)) return url;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`Jac API did not become ready at ${lastCandidates.join(", ")}`);
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
  // The Jac client must be served for the accessibility experience window;
  // --no-dev starts only the API for this project and cannot provide a UI URL.
  jacProcess = spawnJac(["run", "--dev"], {
    cwd: repositoryRoot,
    stdio: ["inherit", "pipe", "pipe"],
  });

  jacProcess.stdout.on("data", (chunk) => observeJacOutput(chunk, process.stdout));
  jacProcess.stderr.on("data", (chunk) => observeJacOutput(chunk, process.stderr));

  jacProcess.on("error", (error) => {
    console.error(`Unable to start Jac: ${error.message}`);
    shutdown(1);
  });

  const resolvedJacUrl = await waitForJac(jacStartupTimeoutMs);
  const resolvedJacApiUrl = await waitForJacApi(jacStartupTimeoutMs);

  const electronBinary = require("electron");
  const electronEnvironment = { ...process.env };
  delete electronEnvironment.NVIDIA_API_KEY;
  electronProcess = spawn(electronBinary, [repositoryRoot], {
    cwd: repositoryRoot,
    env: {
      ...electronEnvironment,
      ACCESSIBLE_BROWSER_JAC_URL: resolvedJacUrl,
      ACCESSIBLE_BROWSER_JAC_API_URL: resolvedJacApiUrl,
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
