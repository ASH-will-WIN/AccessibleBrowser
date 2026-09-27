const { spawn, spawnSync } = require("node:child_process");
const path = require("node:path");

const repositoryRoot = path.resolve(__dirname, "..");

function toWslPath(windowsPath) {
  const resolved = path.win32.resolve(windowsPath);
  const match = /^([a-z]):\\(.*)$/i.exec(resolved);
  if (!match) throw new Error(`Cannot map Windows path to WSL: ${resolved}`);
  return `/mnt/${match[1].toLowerCase()}/${match[2].replace(/\\/g, "/")}`;
}

function jacInvocation(args, cwd) {
  if (process.env.ACCESSIBLE_BROWSER_JAC_COMMAND) {
    return { command: process.env.ACCESSIBLE_BROWSER_JAC_COMMAND, args };
  }

  if (process.platform !== "win32") return { command: "jac", args };

  const probe = spawnSync("jac", ["--version"], { cwd, stdio: "ignore", timeout: 5000 });
  if (!probe.error || probe.error.code !== "ENOENT") return { command: "jac", args };

  return {
    command: process.env.ACCESSIBLE_BROWSER_WSL_COMMAND || "wsl.exe",
    args: [
      "--distribution", process.env.ACCESSIBLE_BROWSER_WSL_DISTRO || "Ubuntu",
      "--cd", toWslPath(cwd),
      "--exec", "bash", "-lc", 'exec jac "$@"', "accessible-browser-jac", ...args,
    ],
  };
}

function spawnJac(args, options = {}) {
  const cwd = options.cwd || repositoryRoot;
  const invocation = jacInvocation(args, cwd);
  return spawn(invocation.command, invocation.args, { ...options, cwd });
}

if (require.main === module) {
  const child = spawnJac(process.argv.slice(2), { cwd: repositoryRoot, stdio: "inherit" });
  child.on("error", (error) => {
    console.error(`Unable to start Jac: ${error.message}`);
    process.exitCode = 1;
  });
  child.on("exit", (code, signal) => {
    process.exitCode = code ?? (signal ? 1 : 0);
  });
  for (const signal of ["SIGINT", "SIGTERM"]) {
    process.on(signal, () => child.kill(signal));
  }
}

module.exports = { spawnJac };
