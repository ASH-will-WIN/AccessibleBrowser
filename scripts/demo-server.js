const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const host = process.env.ACCESSIBLE_BROWSER_DEMO_HOST || "127.0.0.1";
const port = Number(process.env.ACCESSIBLE_BROWSER_DEMO_PORT || 4173);
const demoPath = path.join(__dirname, "..", "demo", "accessible-demo.html");

const server = http.createServer((request, response) => {
  if (request.url !== "/" && request.url !== "/accessible-demo.html") {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Not found");
    return;
  }
  response.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" });
  fs.createReadStream(demoPath).pipe(response);
});

server.listen(port, host, () => {
  console.log(`AccessibleBrowser demo: http://${host}:${port}/`);
});

process.on("SIGINT", () => server.close(() => process.exit(0)));
process.on("SIGTERM", () => server.close(() => process.exit(0)));
