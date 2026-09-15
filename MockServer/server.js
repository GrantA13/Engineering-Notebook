// Minimal in-memory REST server matching the Engineering Notebook API contract.
//
// Usage:
//   node server.js            (listens on http://localhost:3000)
//
// Then point the app at it by setting, in BackendService.swift:
//   static let backendBaseURL: URL? = URL(string: "http://localhost:3000")
//
// Data lives in memory only and resets when the process restarts. This exists
// so the app's RESTBackendService can be exercised against a real HTTP endpoint;
// swap in your own deployed backend when ready.

const http = require("http");
const { randomUUID } = require("crypto");

const projects = new Map(); // id -> project
const entries = new Map();   // id -> entry

const PORT = process.env.PORT || 3000;

function send(res, status, body) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(body === undefined ? "" : JSON.stringify(body));
}

function readJSON(req) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (chunk) => (data += chunk));
    req.on("end", () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch (e) {
        reject(e);
      }
    });
    req.on("error", reject);
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const parts = url.pathname.split("/").filter(Boolean);
  const method = req.method;

  try {
    // GET /projects
    if (method === "GET" && parts.length === 1 && parts[0] === "projects") {
      const all = [...projects.values()].sort((a, b) =>
        b.createdAt.localeCompare(a.createdAt)
      );
      return send(res, 200, all);
    }

    // POST /projects
    if (method === "POST" && parts.length === 1 && parts[0] === "projects") {
      const body = await readJSON(req);
      const project = {
        id: body.id || randomUUID().toUpperCase(),
        name: body.name || "",
        summary: body.summary || "",
        createdAt: body.createdAt || new Date().toISOString(),
      };
      projects.set(project.id, project);
      return send(res, 201, project);
    }

    // DELETE /projects/{id}
    if (method === "DELETE" && parts.length === 2 && parts[0] === "projects") {
      const id = parts[1];
      projects.delete(id);
      for (const [entryId, entry] of entries) {
        if (entry.projectID === id) entries.delete(entryId);
      }
      return send(res, 204);
    }

    // GET /projects/{id}/entries
    if (
      method === "GET" &&
      parts.length === 3 &&
      parts[0] === "projects" &&
      parts[2] === "entries"
    ) {
      const projectID = parts[1];
      const list = [...entries.values()]
        .filter((e) => e.projectID === projectID)
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
      return send(res, 200, list);
    }

    // POST /projects/{id}/entries
    if (
      method === "POST" &&
      parts.length === 3 &&
      parts[0] === "projects" &&
      parts[2] === "entries"
    ) {
      const projectID = parts[1];
      const body = await readJSON(req);
      const entry = {
        id: body.id || randomUUID().toUpperCase(),
        projectID,
        note: body.note || "",
        location: body.location ?? null,
        photoData: body.photoData ?? null, // base64 string
        temperature: body.temperature ?? null,
        temperatureUnit: body.temperatureUnit || "°C",
        measurement: body.measurement ?? null,
        measurementUnit: body.measurementUnit ?? null,
        rating: body.rating ?? null,
        createdAt: body.createdAt || new Date().toISOString(),
      };
      entries.set(entry.id, entry);
      return send(res, 201, entry);
    }

    // DELETE /entries/{id}
    if (method === "DELETE" && parts.length === 2 && parts[0] === "entries") {
      entries.delete(parts[1]);
      return send(res, 204);
    }

    send(res, 404, { error: "Not found" });
  } catch (e) {
    send(res, 400, { error: String(e) });
  }
});

server.listen(PORT, () => {
  console.log(`Engineering Notebook mock API listening on http://localhost:${PORT}`);
});
