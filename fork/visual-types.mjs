#!/usr/bin/env node
// Writes the engine's catalogue of visual types as JSON: what kinds of video the engine can make, which registry
// blocks and components make each, the libraries they use, a preview frame where the registry has one, and the style
// tokens, theme packs and frame presets a project's taste is set with. Agents above the engine (a video service, a
// media service) show it to a person before a generation, so the person chooses the kind of video instead of meeting
// it in the result (board request b948516e, 2026-11-08).
//
//   node fork/visual-types.mjs [--root <checkout>] [--base vX.Y.Z] [--release <label>] [--commit <sha>]
//                              [--files <dir>] [--registry-mirror <dir>]
//
// Read only from the checkout: registry/*/*/registry-item.json and the files beside each, themes/, and the frame
// presets of the hyperframes skill, and the line's composition recipes (fork/recipes/). No network, no clock: the same
// tree gives the same bytes. With --files <dir> it also fetches every item's preview frame into <dir>/posters/ and
// copies the recipes into <dir>/recipes/, and names each as a path inside the release's files archive
// (`visual-types-files-<label>.tar.gz`), so a caller shows frames and uses recipes without the network (frame-agent,
// board message 7c794df6). The line's checks of a rendered video (`checks`, fork/pacing-check.mjs) go to <dir>/checks/. A frame that cannot be fetched keeps only its URL and is listed in `files.posters_missing`.
// Frames are fetched only for items a type lists: an item no type names is counted in totals.untyped and has no frame.
// With --registry-mirror <dir> it copies the registry into <dir> in the layout the HTTPS registry serves
// (registry.json, then <type-dir>/<name>/registry-item.json and every file beside it), names each item's directory as
// `mirror_dir`, and the release packs it as `registry-<label>.tar.gz`, so a run without the network reads a block's own
// sources (frame-agent, board message 61d40364). A file a manifest hosts elsewhere (`url`) is not copied and is listed in
// `registry_mirror.hosted_elsewhere`.
// Every string of the catalogue is written without a dash between words (an em dash, `--` or a spaced hyphen becomes a
// comma): the texts go in front of people, and the registry's own descriptions carry about a hundred.
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const opt = (name, fallback = "") => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const ROOT = path.resolve(opt("--root", "."));
const POSTERS = opt("--files") ? path.resolve(opt("--files")) : "";
const MIRROR = opt("--registry-mirror") ? path.resolve(opt("--registry-mirror")) : "";

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
  if (posters.got.has(item.name)) e.poster_file = posters.got.get(item.name);
  if (item.preview?.video) e.video = item.preview.video;
  if (mirror.dirs.has(item.name)) e.mirror_dir = mirror.dirs.get(item.name);
  return e;
}

// The registry as the HTTPS registry lays it out, for a run without the network.
function mirrorRegistry() {
  const dirs = new Map();
  const hosted = [];
  let files = 0;
  if (!MIRROR) return { dirs, hosted, files };
  const reg = path.join(ROOT, "registry");
  fs.mkdirSync(MIRROR, { recursive: true });
  if (exists(path.join(reg, "registry.json")))
    fs.copyFileSync(path.join(reg, "registry.json"), path.join(MIRROR, "registry.json"));
  for (const kind of fs.readdirSync(reg).sort()) {
    const dir = path.join(reg, kind);
    if (!fs.statSync(dir).isDirectory()) continue;
    for (const name of fs.readdirSync(dir).sort()) {
      const manifest = path.join(dir, name, "registry-item.json");
      if (!exists(manifest)) continue;
      const item = JSON.parse(read(manifest));
      const rel = `${kind}/${name}/`;
      fs.mkdirSync(path.join(MIRROR, kind, name), { recursive: true });
      fs.copyFileSync(manifest, path.join(MIRROR, kind, name, "registry-item.json"));
      for (const f of item.files || []) {
        if (f.url) {
          hosted.push(`${item.name}/${f.path}`);
          continue;
        }
        const src = path.join(dir, name, f.path);
        if (/(^|[/\\])\.\.([/\\]|$)/.test(f.path) || !exists(src)) continue;
        const dest = path.join(MIRROR, kind, name, f.path);
        fs.mkdirSync(path.dirname(dest), { recursive: true });
        fs.copyFileSync(src, dest);
        files++;
      }
      dirs.set(item.name, rel);
    }
  }
  return { dirs, hosted: hosted.sort(), files };
}

// A dash between words reads as a pause no reader of these labels needs; a comma says the same.
function plain(value) {
  if (typeof value === "string")
    return value.replace(/\s*\u2014\s*/g, ", ").replace(/(?<=\S) -{1,2} (?=\S)/g, ", ");
  if (Array.isArray(value)) return value.map(plain);
  if (value && typeof value === "object")
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, plain(v)]));
  return value;
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

// Fetches each preview frame once; file:// works too, so the tests need no network.
async function fetchPosters(list) {
  const got = new Map();
  const missing = [];
  if (!POSTERS) return { got, missing };
  fs.mkdirSync(path.join(POSTERS, "posters"), { recursive: true });
  // Frames are shown on a gate, not printed: with ffmpeg present each becomes a JPEG at most 640 px wide (the
  // registry's PNGs weighed 41 MB for 114 frames on 2026-11-08); without it the original is kept.
  const ffmpeg = spawnSync("ffmpeg", ["-version"], { stdio: "ignore" }).status === 0;
  for (const { item } of list) {
    const url = item.preview?.poster;
    if (!url) continue;
    const ext = (path.extname(new URL(url).pathname) || ".jpg").toLowerCase();
    const rel = `posters/${item.name}${ext}`;
    try {
      let bytes;
      if (url.startsWith("file://")) bytes = fs.readFileSync(new URL(url));
      else {
        const res = await fetch(url, { signal: AbortSignal.timeout(30000) });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        bytes = Buffer.from(await res.arrayBuffer());
      }
      if (!bytes.length) throw new Error("empty");
      fs.writeFileSync(path.join(POSTERS, rel), bytes);
      let kept = rel;
      if (ffmpeg) {
        const small = `posters/${item.name}.jpg`;
        const out = path.join(POSTERS, `${small}.tmp.jpg`);
        const r = spawnSync("ffmpeg", [
          "-v",
          "error",
          "-y",
          "-i",
          path.join(POSTERS, rel),
          "-vf",
          "scale='min(640,iw)':-2",
          "-q:v",
          "4",
          out,
        ]);
        if (r.status === 0 && fs.existsSync(out) && fs.statSync(out).size > 0) {
          fs.rmSync(path.join(POSTERS, rel));
          fs.renameSync(out, path.join(POSTERS, small));
          kept = small;
        } else fs.rmSync(out, { force: true });
      }
      got.set(item.name, kept);
    } catch {
      missing.push(item.name);
    }
  }
  return { got, missing: missing.sort() };
}

// The line's own composition recipes: whole root compositions for a layout the registry has no block for.
const RECIPES = [
  {
    id: "presenter-over-diagram",
    label: "Presenter over a diagram",
    shows:
      "a cut-out presenter with a diagram: the diagram fills the frame while the presenter shrinks into a corner, exits alternate (dissolve, reverse grow), nothing ever covers the face",
    dir: "presenter-over-diagram",
    needs:
      "a cut-out clip of the presenter with alpha (npx hyperframes media-use generate --type cutout) placed in the root, never in a sub-composition",
    pairs_with: [
      "whip-pan",
      "whip-pan-cut",
      "zoom-through-transition",
      "cut-the-curve",
      "freeze-frame-dressing",
    ],
  },
  {
    id: "short-continuous",
    label: "Short that never stalls",
    shows:
      "a vertical short (Shorts, TikTok, Reels, up to 3 minutes) cut on the voice: each scene starts on its line and overlaps the next, the picture always moves, words land one by one, a music bed under the voice and a whoosh on every cut, the hook on screen in the first 2 s",
    dir: "short-continuous",
    needs:
      "the project's own voice, music bed and two whoosh takes in assets/ (never synthesised tones), cue times from the voice's transcript, and checks/pacing-check.mjs on the render before delivery",
    pairs_with: ["whip-pan", "whip-pan-cut", "kinetic-type", "cut-the-curve"],
  },
];
// The line's checks of a rendered video, run by the agent that delivers it (board request a4d1b095, 2026-11-11).
const CHECKS = [
  {
    id: "pacing",
    label: "Pacing of a short video",
    file: "pacing-check.mjs",
    checks:
      "a rendered short (up to 3 minutes) has sound, no silence longer than 0.8 s, silence under 8% of the length, and no picture standing still longer than 1 s (ffmpeg silencedetect and freezedetect)",
    run: "node checks/pacing-check.mjs <video> --json",
    needs: "Node and ffmpeg with ffprobe; exit 0 pass, 1 fail with reasons, 2 unreadable",
    report: "hyperframes-pacing/1",
  },
];
function checks() {
  return CHECKS.filter((c) => exists(path.join(ROOT, "fork", c.file))).map((c) => {
    const out = {
      id: c.id,
      label: c.label,
      checks: c.checks,
      source: `fork/${c.file}`,
      run: c.run,
      needs: c.needs,
      report: c.report,
    };
    if (POSTERS) {
      fs.mkdirSync(path.join(POSTERS, "checks"), { recursive: true });
      fs.copyFileSync(path.join(ROOT, "fork", c.file), path.join(POSTERS, "checks", c.file));
      out.file = `checks/${c.file}`;
    }
    return out;
  });
}
function recipes() {
  return RECIPES.filter((r) => exists(path.join(ROOT, "fork", "recipes", r.dir, "index.html"))).map(
    (r) => {
      const out = {
        id: r.id,
        label: r.label,
        shows: r.shows,
        source: `fork/recipes/${r.dir}/index.html`,
        needs: r.needs,
      };
      out.pairs_with = r.pairs_with.filter((n) => items.some(({ item }) => item.name === n));
      if (POSTERS) {
        fs.mkdirSync(path.join(POSTERS, "recipes", r.dir), { recursive: true });
        fs.cpSync(path.join(ROOT, "fork", "recipes", r.dir), path.join(POSTERS, "recipes", r.dir), {
          recursive: true,
        });
        out.file = `recipes/${r.dir}/index.html`;
      }
      return out;
    },
  );
}

const items = registryItems();
const typeTags = new Set(TYPES.flatMap(([, , , tags]) => tags));
const posters = await fetchPosters(
  items.filter(({ item }) => (item.tags || []).some((t) => typeTags.has(t))),
);
const mirror = mirrorRegistry();
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
    "Show the types (label, shows, a poster of the first items) to the person before a generation and let them choose, or record that they left it to the agent. Install an item with its `install` command, or without the network copy the files of its `mirror_dir` from the registry mirror to their targets; set a project's taste with a style preset (fork/style-preset.mjs).",
  totals: { items: items.length, typed: typed.size, untyped: items.length - typed.size },
  files: POSTERS
    ? {
        asset: opt("--release") ? `visual-types-files-${opt("--release")}.tar.gz` : null,
        posters_fetched: posters.got.size,
        posters_missing: posters.missing,
      }
    : null,
  registry_mirror: MIRROR
    ? {
        asset: opt("--release") ? `registry-${opt("--release")}.tar.gz` : null,
        layout:
          "registry.json, then <type-dir>/<name>/registry-item.json with every file beside it, as the HTTPS registry serves them; an item's mirror_dir names its directory, and each file goes to its target in the project",
        items: mirror.dirs.size,
        files: mirror.files,
        hosted_elsewhere: mirror.hosted,
      }
    : null,
  types,
  outside_registry: OUTSIDE,
  compositions: recipes(),
  checks: checks(),
  styles: {
    token_contract: { file: "themes/CONTRACT.md", tokens: themeTokens() },
    theme_packs: themePacks(),
    frame_presets: framePresets(),
  },
};
process.stdout.write(JSON.stringify(plain(catalog), null, 2) + "\n");
