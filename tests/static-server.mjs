#!/usr/bin/env node
/**
 * Zero-dependency static file server for Playwright e2e (and local preview).
 * Replaces `serve` so tests/ stays free of transitive minimatch advisories.
 *
 * Usage: node static-server.mjs <rootDir> [-l <port>]
 */
import http from "node:http";
import fs from "node:fs";
import path from "node:path";

const MIME = {
  ".css": "text/css; charset=utf-8",
  ".csv": "text/csv; charset=utf-8",
  ".gif": "image/gif",
  ".html": "text/html; charset=utf-8",
  ".ico": "image/x-icon",
  ".jpeg": "image/jpeg",
  ".jpg": "image/jpeg",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".md": "text/markdown; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".txt": "text/plain; charset=utf-8",
  ".webp": "image/webp",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
};

function parseArgs(argv) {
  let root = null;
  let port = 4173;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "-l" || arg === "--listen") {
      port = Number(argv[i + 1]);
      i += 1;
      continue;
    }
    if (!arg.startsWith("-") && root === null) {
      root = arg;
    }
  }
  if (!root || !Number.isFinite(port) || port <= 0) {
    console.error("Usage: node static-server.mjs <rootDir> [-l <port>]");
    process.exit(1);
  }
  return { root: path.resolve(root), port };
}

function safeJoin(root, urlPath) {
  const decoded = decodeURIComponent((urlPath || "/").split("?")[0].split("#")[0]);
  const rel = decoded === "/" ? "index.html" : decoded.replace(/^\/+/, "");
  const candidate = path.resolve(root, rel);
  const rootWithSep = root.endsWith(path.sep) ? root : `${root}${path.sep}`;
  if (candidate !== root && !candidate.startsWith(rootWithSep)) {
    return null;
  }
  return candidate;
}

const { root, port } = parseArgs(process.argv.slice(2));

if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
  console.error(`Not a directory: ${root}`);
  process.exit(1);
}

const server = http.createServer((req, res) => {
  const target = safeJoin(root, req.url || "/");
  if (!target) {
    res.writeHead(403).end("Forbidden");
    return;
  }

  fs.stat(target, (statErr, stat) => {
    let filePath = target;
    if (!statErr && stat.isDirectory()) {
      filePath = path.join(target, "index.html");
    } else if (statErr) {
      res.writeHead(404).end("Not found");
      return;
    }

    const type = MIME[path.extname(filePath).toLowerCase()] || "application/octet-stream";
    fs.readFile(filePath, (readErr, data) => {
      if (readErr) {
        res.writeHead(readErr.code === "ENOENT" ? 404 : 500).end(
          readErr.code === "ENOENT" ? "Not found" : "Error",
        );
        return;
      }
      res.writeHead(200, { "Content-Type": type, "Cache-Control": "no-store" });
      res.end(data);
    });
  });
});

server.listen(port, "127.0.0.1", () => {
  console.log(`static-server listening on http://127.0.0.1:${port} (root ${root})`);
});

server.on("error", (err) => {
  console.error(err);
  process.exit(1);
});
