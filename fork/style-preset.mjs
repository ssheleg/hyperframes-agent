#!/usr/bin/env node
// A project's taste as a file: the style preset. The taste decisions a person makes on a project's first videos
// (palette, type, pace, curves, frame preset, caption style, transitions, text density) are written once and every
// later video repeats them without asking (board request b948516e, 2026-11-08). The preset belongs to the project and
// lives with its consumer (a video service's project profile); the engine only reads it.
//
//   node fork/style-preset.mjs check <preset.json> [--root <checkout>]   exit 0 when whole, 1 with the reasons
//   node fork/style-preset.mjs css <preset.json> [--root <checkout>]     the :root block a composition loads
//   node fork/style-preset.mjs new <theme-pack> [--name <name>]          a starting preset from a theme pack
//
// Shape (schema hyperframes-style-preset/1):
//   name          the project's name for it
//   tokens        every token of themes/CONTRACT.md's table (palette, type, radius and spacing, --dur-beat and the
//                 two curves); --dur-beat is the pace
//   frame_preset  optional: a frame preset of the hyperframes skill (skills/hyperframes/assets/frame-presets/<name>)
//   captions      optional: a registry item tagged captions or caption-style
//   transitions   optional: registry items tagged transition or transition-primitive, in the order to prefer them
//   text_density  optional: low | medium | high (words on screen per beat; the tokens cannot say it)
//   decided_by    who set it and when: [{field, by: person|agent, at: YYYY-MM-DD, note?}]; a field a person never
//                 decided stays the agent's suggestion, which the first generations show again
import fs from "node:fs";
import path from "node:path";

const [cmd, target, ...rest] = process.argv.slice(2);
const opt = (name, fallback = "") => {
  const i = rest.indexOf(name);
  return i >= 0 && rest[i + 1] ? rest[i + 1] : fallback;
};
const ROOT = path.resolve(opt("--root", "."));
const usage = () => {
  console.error(
    "usage: fork/style-preset.mjs check|css <preset.json> | new <theme-pack> [--name <name>] [--root <checkout>]",
  );
  process.exit(2);
};
if (!cmd || !target) usage();

const read = (p) => fs.readFileSync(p, "utf8");
function contractTokens() {
  const section =
    read(path.join(ROOT, "themes", "CONTRACT.md"))
      .split("## Final token set")[1]
      ?.split("\n## ")[0] || "";
  const rows = section.split("\n").filter((l) => l.startsWith("|"));
  return [...new Set(rows.flatMap((l) => [...l.matchAll(/`(--[a-z0-9-]+)`/g)].map((m) => m[1])))];
}
function registryTags(name) {
  for (const kind of ["blocks", "components", "examples"]) {
    const f = path.join(ROOT, "registry", kind, name, "registry-item.json");
    if (fs.existsSync(f)) return JSON.parse(read(f)).tags || [];
  }
  return null;
}

if (cmd === "new") {
  const css = path.join(ROOT, "themes", `${target}.css`);
  if (!fs.existsSync(css)) {
    console.error(`no theme pack ${target} (themes/*.css)`);
    process.exit(2);
  }
  const tokens = Object.fromEntries(
    [...read(css).matchAll(/(--[a-z0-9-]+)\s*:\s*([^;]+);/g)].map((m) => [m[1], m[2].trim()]),
  );
  const preset = {
    schema: "hyperframes-style-preset/1",
    name: opt("--name", target),
    tokens,
    text_density: "medium",
    decided_by: [],
  };
  process.stdout.write(JSON.stringify(preset, null, 2) + "\n");
  process.exit(0);
}

let preset;
try {
  preset = JSON.parse(read(target));
} catch (e) {
  console.error(`cannot read ${target}: ${e.message}`);
  process.exit(2);
}

function problems(p) {
  const out = [];
  if (p.schema !== "hyperframes-style-preset/1")
    out.push(`schema is ${JSON.stringify(p.schema)}, expected "hyperframes-style-preset/1"`);
  if (!p.name || typeof p.name !== "string") out.push("name is missing");
  const tokens = p.tokens && typeof p.tokens === "object" ? p.tokens : {};
  for (const t of contractTokens()) {
    const v = tokens[t];
    if (typeof v !== "string" || !v.trim()) out.push(`token ${t} is missing`);
    else if (/[;{}]/.test(v))
      out.push(`token ${t} holds ${JSON.stringify(v)}: a value cannot carry ; { or }`);
  }
  if (
    typeof tokens["--dur-beat"] === "string" &&
    !/^\d+(\.\d+)?m?s$/.test(tokens["--dur-beat"].trim())
  )
    out.push(`--dur-beat (the pace) is not a duration: ${tokens["--dur-beat"]}`);
  if (
    p.frame_preset !== undefined &&
    !fs.existsSync(
      path.join(
        ROOT,
        "skills",
        "hyperframes",
        "assets",
        "frame-presets",
        String(p.frame_preset),
        "FRAME.md",
      ),
    )
  )
    out.push(`no frame preset ${p.frame_preset}`);
  const needTag = (name, want, field) => {
    const tags = registryTags(name);
    if (tags === null) out.push(`${field}: no registry item ${name}`);
    else if (!tags.some((t) => want.includes(t)))
      out.push(`${field}: ${name} is not tagged ${want.join(" or ")}`);
  };
  if (p.captions !== undefined)
    needTag(String(p.captions), ["captions", "caption-style"], "captions");
  if (p.transitions !== undefined) {
    if (!Array.isArray(p.transitions)) out.push("transitions is not a list");
    else
      p.transitions.forEach((n) =>
        needTag(String(n), ["transition", "transition-primitive"], "transitions"),
      );
  }
  if (p.text_density !== undefined && !["low", "medium", "high"].includes(p.text_density))
    out.push(`text_density is ${JSON.stringify(p.text_density)}, expected low, medium or high`);
  if (p.decided_by !== undefined) {
    if (!Array.isArray(p.decided_by)) out.push("decided_by is not a list");
    else
      p.decided_by.forEach((d, i) => {
        if (
          !d ||
          !d.field ||
          !["person", "agent"].includes(d.by) ||
          !/^\d{4}-\d{2}-\d{2}$/.test(String(d.at || ""))
        )
          out.push(`decided_by[${i}] needs field, by (person or agent) and at (YYYY-MM-DD)`);
      });
  }
  return out;
}

const found = problems(preset);
if (cmd === "check") {
  if (found.length) {
    for (const f of found) console.error(`- ${f}`);
    console.error(`${target}: ${found.length} problem(s)`);
    process.exit(1);
  }
  const people = new Set(
    (preset.decided_by || []).filter((d) => d.by === "person").map((d) => d.field),
  );
  console.log(
    `${target}: whole (${contractTokens().length} tokens); decided by a person: ${people.size ? [...people].sort().join(", ") : "nothing yet"}`,
  );
  process.exit(0);
}
if (cmd === "css") {
  if (found.length) {
    for (const f of found) console.error(`- ${f}`);
    process.exit(1);
  }
  const lines = contractTokens().map((t) => `  ${t}: ${preset.tokens[t].trim()};`);
  process.stdout.write(
    `/* style preset ${preset.name} (hyperframes-style-preset/1) */\n:root {\n${lines.join("\n")}\n}\n`,
  );
  process.exit(0);
}
usage();
