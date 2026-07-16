import { createRequire } from "node:module";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { dirname } from "node:path";

const REQUIRE_GUTEN_VERSION = "0.2.7";
const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const TEMPLATES_ROOT = join(ROOT, "templates");
const SAMPLE_LIMIT = 3;

const require = createRequire(import.meta.url);
const gutenEntryPath = require.resolve("@kitsy/guten");
const { version: gutenVersion } = JSON.parse(
  readFileSync(join(dirname(gutenEntryPath), "..", "package.json"), "utf8"),
);
if (gutenVersion !== REQUIRE_GUTEN_VERSION) {
  throw new Error(`expected @kitsy/guten@${REQUIRE_GUTEN_VERSION}, got @kitsy/guten@${gutenVersion}`);
}

const { newWithBuiltins } = await import("@kitsy/guten");
const registry = JSON.parse(readFileSync(join(TEMPLATES_ROOT, "index.json"), "utf8"));
const requested = ["invoice", "notification", "otp", "password_reset", "receipt", "welcome"];

function resolveTemplatePart(templatesDir, name, partSource) {
  if (partSource.startsWith("@")) {
    return readFileSync(join(templatesDir, name, partSource.slice(1)), "utf8");
  }
  return partSource;
}

function readTemplateManifest(templatesDir, name) {
  return JSON.parse(readFileSync(join(templatesDir, name, "template.json"), "utf8"));
}

function readTemplateSample(templatesDir, name) {
  const path = join(templatesDir, name, "sample.json");
  if (!existsSync(path)) return {};
  return JSON.parse(readFileSync(path, "utf8"));
}

const candidates = registry.templates
  .map((template) => template.name)
  .filter((name) => requested.includes(name))
  .slice(0, SAMPLE_LIMIT);

if (candidates.length === 0) {
  throw new Error("no template candidates found in @kitsy/gutenkit");
}

for (const name of candidates) {
  const template = readTemplateManifest(TEMPLATES_ROOT, name);
  const parts = Object.fromEntries(
    Object.entries(template.parts || {}).map(([part, partSource]) => [
      part,
      resolveTemplatePart(TEMPLATES_ROOT, name, partSource),
    ]),
  );

  const engine = newWithBuiltins();
  engine.register({
    name,
    renderer: template.renderer,
    parts,
  });

  const sample = readTemplateSample(TEMPLATES_ROOT, name);
  const rendered = engine.render(name, sample);
  const partNames = Object.keys(parts);
  if (partNames.length === 0) {
    throw new Error(`${name}: no parts found in template.json`);
  }

  for (const part of partNames) {
    if (typeof rendered.parts[part] !== "string") {
      throw new Error(`${name}: expected rendered part ${part} to be a string`);
    }
  }
}

console.log(`[gutenkit] rendered ${candidates.length} sample templates with @kitsy/guten@${gutenVersion}`);
