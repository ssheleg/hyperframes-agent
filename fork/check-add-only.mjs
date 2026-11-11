#!/usr/bin/env node
// Add, never replace: the line's composition recipes (fork/recipes/<name>/) that went out in a release are locked in
// fork/shipped.lock.json with the hash of their files. A locked recipe is never changed or removed; a changed recipe
// ships beside it under a new name, and one taken out of use stays locked with `retired: {date, reason}`. The
// operator's hard rule for every agent of the content farm and its copies, 2026-11-11 (board thread 2f651c5c, message
// 7e3ea2fb); fork/release.sh runs this before it builds.
//
//   node fork/check-add-only.mjs [--root <checkout>]                 check; exit 1 names each breach
//   node fork/check-add-only.mjs [--root <checkout>] --lock <name>   lock a new recipe at its current files
//
// The lock names the upstream base a recipe first shipped on, not a release tag: the line's own name must not reach
// an exported copy (fork/export.sh refuses a tree that names it).
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join, relative } from "node:path";

const args = process.argv.slice(2);
let root = process.cwd();
let lockName = null;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--root" && args[i + 1]) root = args[++i];
  else if (args[i] === "--lock" && args[i + 1]) lockName = args[++i];
  else {
    console.error("usage: node fork/check-add-only.mjs [--root <checkout>] [--lock <name>]");
    process.exit(2);
  }
}
const recipesDir = join(root, "fork/recipes");
const lockPath = join(root, "fork/shipped.lock.json");

function files(dir) {
  return readdirSync(dir).flatMap((name) => {
    const p = join(dir, name);
    return statSync(p).isDirectory() ? files(p) : [p];
  });
}
// One hash over every file of a recipe: its path inside the recipe and the hash of its bytes, in path order.
function recipeHash(name) {
  const dir = join(recipesDir, name);
  const lines = files(dir)
    .map(
      (p) => `${relative(dir, p)}\0${createHash("sha256").update(readFileSync(p)).digest("hex")}`,
    )
    .sort();
  return createHash("sha256").update(lines.join("\n")).digest("hex");
}
const present = existsSync(recipesDir)
  ? readdirSync(recipesDir).filter((n) => statSync(join(recipesDir, n)).isDirectory())
  : [];
const lock = existsSync(lockPath)
  ? JSON.parse(readFileSync(lockPath, "utf8"))
  : { schema: 1, recipes: {} };
const recipes = lock.recipes ?? {};

if (lockName) {
  if (!/^[a-z0-9][a-z0-9-]*$/.test(lockName)) {
    console.error(`not a recipe name: ${lockName}`);
    process.exit(2);
  }
  if (recipes[lockName]) {
    console.error(`${lockName} is locked already: a changed recipe ships under a new name`);
    process.exit(1);
  }
  if (!present.includes(lockName)) {
    console.error(`no recipe fork/recipes/${lockName}`);
    process.exit(1);
  }
  const base = execBase();
  recipes[lockName] = {
    since: new Date().toISOString().slice(0, 10),
    base,
    sha256: recipeHash(lockName),
  };
  const sorted = Object.fromEntries(Object.entries(recipes).sort(([a], [b]) => a.localeCompare(b)));
  writeFileSync(lockPath, `${JSON.stringify({ schema: 1, recipes: sorted }, null, 2)}\n`);
  console.log(`locked ${lockName} (${recipes[lockName].sha256.slice(0, 12)})`);
  process.exit(0);
}

function execBase() {
  // The newest upstream release merged into HEAD, as fork/release.sh names the base.
  try {
    const tags = execFileSync(
      "git",
      [
        "-C",
        root,
        "tag",
        "--merged",
        "HEAD",
        "--list",
        "v[0-9]*.[0-9]*.[0-9]*",
        "--sort=-v:refname",
      ],
      {
        encoding: "utf8",
      },
    );
    return tags.split("\n").find((t) => t && !t.includes("-")) ?? null;
  } catch {
    return null;
  }
}

const breaches = [];
for (const [name, entry] of Object.entries(recipes)) {
  if (entry.retired) {
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(entry.retired.date ?? "") ||
      !String(entry.retired.reason ?? "").trim()
    )
      breaches.push(`${name}: retired needs a date (YYYY-MM-DD) and a reason`);
    continue;
  }
  if (!present.includes(name))
    breaches.push(`${name}: a shipped recipe was removed (retire it in the lock instead)`);
  else if (recipeHash(name) !== entry.sha256)
    breaches.push(`${name}: a shipped recipe was changed (ship the change under a new name)`);
}
for (const name of present)
  if (!recipes[name])
    breaches.push(`${name}: not locked yet (node fork/check-add-only.mjs --lock ${name})`);
if (breaches.length) {
  for (const b of breaches) console.error(`add-only: ${b}`);
  process.exit(1);
}
console.log(`add-only: ${Object.keys(recipes).length} shipped recipe(s) intact`);
