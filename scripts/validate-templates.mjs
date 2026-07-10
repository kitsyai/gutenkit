import { readdirSync, readFileSync } from "node:fs";
import { join, extname } from "node:path";

function walk(dir, visit) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, visit);
    } else if (entry.isFile() && extname(entry.name).toLowerCase() === ".json") {
      visit(full);
    }
  }
}

let ok = true;
walk("templates", (path) => {
  try {
    const raw = readFileSync(path, "utf8");
    JSON.parse(raw);
  } catch (err) {
    console.error(`Invalid JSON: ${path}`);
    console.error(err?.message || err);
    ok = false;
  }
});

if (!ok) {
  process.exit(1);
}

console.log("template json validation: ok");