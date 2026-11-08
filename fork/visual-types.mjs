#!/usr/bin/env node
// Writes the engine's catalogue of visual types as JSON: what kinds of video the engine can make, which registry
// blocks and components make each, the libraries they use, a preview frame where the registry has one, and the style
// tokens, theme packs and frame presets a project's taste is set with. Agents above the engine (a video service, a
// media service) show it to a person before a generation, so the person chooses the kind of video instead of meeting
// it in the result (board request b948516e, 2026-11-08).
//
//   node fork/visual-types.mjs [--root <checkout>] [--base vX.Y.Z] [--release <label>] [--commit <sha>]
//
// Read only from the checkout: registry/*/*/registry-item.json and the files beside each, themes/, and the frame
// presets of the hyperframes skill. No network, no clock: the same tree gives the same bytes.
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const opt = (name, fallback = "") => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const ROOT = path.resolve(opt("--root", "."));

// A visual type is a person's word for a kind of video; an item belongs to every type one of its tags names.
const TYPES = [
  [
    "kinetic-typography",
    "Kinetic typography",
    "words as the picture: titles, headlines, typing, handwriting, text effects",
    [
      "typography",
      "text",
      "kinetic-text",
      "kinetic-type",
      "kinetic",
      "title-card",
      "headline",
      "text-effects",
      "text-effect",
      "text-treatment",
      "typing",
      "variable-font",
      "handwritten",
      "wordmark",
      "lockup",
    ],
  ],
  [
    "data-charts-maps",
    "Data, charts, maps and diagrams",
    "numbers and relations drawn and animated: charts, rankings, comparisons, maps, flows",
    [
      "data",
      "data-viz",
      "chart",
      "map",
      "geography",
      "choropleth",
      "number",
      "ranking",
      "compare",
      "diagram",
      "flow",
      "path",
    ],
  ],
  [
    "interface-and-product",
    "Interface and product",
    "an app or site shown working: mock screens, cursor and clicks, chats, notifications, devices, feature tours",
    [
      "mock-ui",
      "product-demo",
      "ui-props",
      "ui-flow",
      "cursor",
      "click",
      "pointer",
      "chat",
      "notification",
      "phone",
      "device",
      "mobile",
      "feature-tour",
      "demonstrate",
    ],
  ],
  [
    "code",
    "Code on screen",
    "source code typed, highlighted and explained",
    ["code", "code-animation", "developer"],
  ],
  [
    "captions-and-overlays",
    "Captions and overlays",
    "words and marks over footage: captions, lower thirds, callouts, end cards, calls to action",
    [
      "captions",
      "caption-style",
      "lower-third",
      "overlay",
      "annotation",
      "highlight",
      "hud",
      "end-card",
      "cta",
      "social-proof",
      "media-treatment-overlay",
    ],
  ],
  [
    "3d-and-shaders",
    "3D, shaders and particles",
    "rendered depth and light: 3D objects and scenes, WebGL and WebGPU shaders, particles",
    [
      "3d",
      "3d-motion",
      "3d-object",
      "three-js",
      "gltf",
      "webgl",
      "webgpu",
      "webgpu-shader",
      "shader",
      "particles",
      "html-in-canvas",
    ],
  ],
  [
    "transitions",
    "Transitions",
    "the cut between two shots: wipes, crossfades, morphs, match cuts",
    ["transition", "transition-primitive", "wipe", "crossfade", "match-cut", "morph", "swap"],
  ],
  [
    "backgrounds-and-textures",
    "Backgrounds and textures",
    "the ground a scene stands on: gradients, grain, noise, patterns, ambient motion",
    ["background", "texture", "gradient", "grain", "noise", "pattern", "ambient", "glow"],
  ],
  [
    "images-and-footage",
    "Images and footage",
    "photos and video arranged and moved: galleries, carousels, picture in picture, freeze frames",
    ["images", "gallery", "carousel", "media", "video-primitive", "freeze-frame"],
  ],
  [
    "camera-and-depth",
    "Camera and depth",
    "the frame itself moving: pans, zooms, orbits, parallax, motion blur",
    ["camera", "parallax", "zoom", "orbit", "motion-blur", "depth"],
  ],
  [
    "talk-and-social",
    "Talk, interview and social formats",
    "formats built around a speaker or a feed: podcast and interview frames, vertical social posts",
    ["podcast", "interview", "social", "creator", "youtube", "vertical"],
  ],
];

// Made outside the engine's own registry, through its skills: listed so a person sees them among the choices.
const OUTSIDE = [
  {
    id: "talking-head",
    label: "Talking head (avatar or presenter)",
    made_with:
      "the media-use skill (HeyGen avatars, voice); footage composed with captions and overlays",
  },
  {
    id: "screen-recording",
    label: "Screen recording",
    made_with:
      "a capture of the product (hyperframes capture), framed with interface items, cursor and camera moves",
  },
  {
    id: "generated-footage",
    label: "Generated footage",
    made_with:
      "the media-use skill (generated video and images), composed with transitions and overlays",
  },
];

// Libraries named by what an item's files load or call.
const TECHNIQUES = [
  ["gsap", /\bgsap\b/],
  ["three.js", /\bTHREE\.|from ["']three["']|three\.module/],
  ["webgpu", /navigator\.gpu|GPUDevice|\bwgsl\b/i],
  ["webgl", /getContext\(\s*["']webgl2?["']|WebGLRenderer/],
  ["lottie", /\blottie\b/i],
  ["d3", /\bd3\.|from ["']d3/],
  ["canvas-2d", /getContext\(\s*["']2d["']/],
  ["svg", /<svg\b/],
];

const read = (p) => fs.readFileSync(p, "utf8");
const exists = (p) => fs.existsSync(p);

function registryItems() {
  const out = [];
  const reg = path.join(ROOT, "registry");
  for (const kind of fs.readdirSync(reg).sort()) {
    const dir = path.join(reg, kind);
    if (!fs.statSync(dir).isDirectory()) continue;
    for (const name of fs.readdirSync(dir).sort()) {
      const file = path.join(dir, name, "registry-item.json");
      if (!exists(file)) continue;
      const item = JSON.parse(read(file));
      const text = (item.files || [])
        .map((f) => path.join(dir, name, f.path))
        .filter((p) => exists(p) && /\.(html|js|mjs|ts|css)$/.test(p))
        .map(read)
        .join("\n");
      out.push({ item, techniques: TECHNIQUES.filter(([, rx]) => rx.test(text)).map(([t]) => t) });
    }
  }
  return out;
}

function entry({ item, techniques }) {
  const e = {
    name: item.name,
    kind: String(item.type || "").replace(/^hyperframes:/, ""),
    title: item.title || item.name,
    description: item.description || "",
    tags: item.tags || [],
    techniques,
    install: `npx hyperframes add ${item.name}`,
  };
  if (item.dimensions) e.dimensions = item.dimensions;
  if (item.duration) e.duration = item.duration;
  if (item.preview?.poster) e.poster = item.preview.poster;
  if (item.preview?.video) e.video = item.preview.video;
  return e;
}

function themeTokens() {
  const contract = read(path.join(ROOT, "themes", "CONTRACT.md"));
  const section = contract.split("## Final token set")[1]?.split("\n## ")[0] || "";
  // Only the table's rows, and only names in backticks: the prose around it names tokens that are not the contract's.
  const rows = section.split("\n").filter((l) => l.startsWith("|"));
  return [...new Set(rows.flatMap((l) => [...l.matchAll(/`(--[a-z0-9-]+)`/g)].map((m) => m[1])))];
}

function themePacks() {
  const dir = path.join(ROOT, "themes");
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".css"))
    .sort()
    .map((f) => ({
      name: f.replace(/\.css$/, ""),
      file: `themes/${f}`,
      tokens: Object.fromEntries(
        [...read(path.join(dir, f)).matchAll(/(--[a-z0-9-]+)\s*:\s*([^;]+);/g)].map((m) => [
          m[1],
          m[2].trim(),
        ]),
      ),
    }));
}

function framePresets() {
  const dir = path.join(ROOT, "skills", "hyperframes", "assets", "frame-presets");
  if (!exists(dir)) return [];
  return fs
    .readdirSync(dir)
    .sort()
    .filter((n) => exists(path.join(dir, n, "FRAME.md")))
    .map((n) => {
      const md = read(path.join(dir, n, "FRAME.md"));
      const title = (md.match(/^name:\s*(.+)$/m) || [])[1] || n;
      const desc = (md.match(/^description:\s*>\s*\n((?:\s{2,}.+\n)+)/m) || [])[1] || "";
      return {
        name: n,
        title: title.trim(),
        description: desc.replace(/\s+/g, " ").trim(),
        files: `skills/hyperframes/assets/frame-presets/${n}/`,
      };
    });
}

const items = registryItems();
const typed = new Set();
const types = TYPES.map(([id, label, shows, tags]) => {
  const want = new Set(tags);
  const members = items.filter(({ item }) => (item.tags || []).some((t) => want.has(t)));
  members.forEach(({ item }) => typed.add(item.name));
  const techniques = {};
  for (const m of members) for (const t of m.techniques) techniques[t] = (techniques[t] || 0) + 1;
  const list = members
    .map(entry)
    .sort((a, b) => Number(!a.poster) - Number(!b.poster) || a.name.localeCompare(b.name));
  return {
    id,
    label,
    shows,
    tags,
    count: list.length,
    with_preview: list.filter((e) => e.poster).length,
    techniques,
    items: list,
  };
});

const catalog = {
  schema: "hyperframes-visual-types/1",
  engine: {
    base: opt("--base") || null,
    release: opt("--release") || null,
    commit: opt("--commit") || null,
  },
  how_to_use:
    "Show the types (label, shows, a poster of the first items) to the person before a generation and let them choose, or record that they left it to the agent. Install an item with its `install` command; set a project's taste with a style preset (fork/style-preset.mjs).",
  totals: { items: items.length, typed: typed.size, untyped: items.length - typed.size },
  types,
  outside_registry: OUTSIDE,
  styles: {
    token_contract: { file: "themes/CONTRACT.md", tokens: themeTokens() },
    theme_packs: themePacks(),
    frame_presets: framePresets(),
  },
};
process.stdout.write(JSON.stringify(catalog, null, 2) + "\n");
