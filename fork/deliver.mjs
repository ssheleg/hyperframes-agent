#!/usr/bin/env node
// The media feed (operator, 2026-11-15; the agents database's pattern media-feed 1.0.0, decision D-47): every file the
// line generates goes to the operator's generations channel as its own message, captioned in one format for every
// agent, organization and machine. Sending goes only through the operator's own Telegram gateway (a Fabric service
// reached over MCP), from the gateway account the deployment names; never another Telegram client.
//
//   node fork/deliver.mjs <file> [--style <name>] [--format <format>] [--settings <version>] [--preset <preset.json>]
//                                [--run <id>] [--release <version>] [--dry-run] [--json]
//
// The caption, fixed labels (the operator's own words), one line each:
//
//   Стиль: <style>[, <format>]
//   Настройки: <settings version>, hyperframes-agent <release>
//   Файл: <file name>
//   Прогон: <run id>
//   Источник: <machine> · <organization or personal> · <service id>
//
// --preset names a style preset (fork/style-preset.mjs): its `name` is the style when --style is absent, and
// `<name>@<sha256 of the file, 8 hex>` the settings version when --settings is absent. The run id is --run, else
// HF_RUN_ID, else one made from the UTC time. The release is --release, else the newest fork tag this checkout holds.
// The source comes from the deployment (MEDIA_FEED_MACHINE, MEDIA_FEED_ORG, MEDIA_FEED_SERVICE, or `source` in the
// config), never guessed from a host name: a missing one reads «не задано» and is named in the warnings.
//
// Where it goes is private and lives outside this repository: FORK_DELIVER_CONFIG names a JSON file (default
// ~/.config/hyperframes-agent/deliver.json) with `chat_id`, `account` (the gateway account that posts), `mcp_url`,
// `header_command` (a command whose standard output is the JSON headers the gateway takes: a vault's header helper; the
// token is read by this program and never printed), optional `upload_limit` and `source` {machine, organization,
// service}. FORK_DELIVER_CHAT, FORK_DELIVER_ACCOUNT, FORK_DELIVER_MCP and FORK_DELIVER_HEADER_CMD override the fields.
//
// A file over the limit (the channel's 50 000 000 bytes, the gateway's 25 MiB for a file sent as content, or a lower
// `upload_limit`) goes as the caption alone with a sixth line naming its size. The same run and the same bytes keep
// one send key, so a retry never posts twice. A caller never fails its work on this script's exit code.
//
// Exit 0: posted (or printed with --dry-run); 1: the gateway refused or failed; 2: bad input (no file, a type the
// gateway does not take); 3: the feed is not configured on this machine (nothing sent).
import { createHash, randomBytes } from "node:crypto";
import { execFileSync, execSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const CHANNEL_LIMIT = 50_000_000; // the channel's upload limit in its lower reading (media-feed rule 3)
const GATEWAY_CONTENT_LIMIT = 25 * 1024 * 1024; // one attachment given as content to a Mac instance of the gateway
const CAPTION_MAX = 1024; // the messenger's caption limit
const AGENT = "hyperframes-agent";
const MIME = {
  ".mp4": "video/mp4",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".mp3": "audio/mpeg",
  ".ogg": "audio/ogg",
  ".html": "text/html",
  ".pdf": "application/pdf",
  ".txt": "text/plain",
  ".csv": "text/csv",
};

const args = process.argv.slice(2);
const flags = new Set(["--dry-run", "--json"]);
const opts = {};
const positional = [];
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (flags.has(a)) opts[a] = true;
  else if (a.startsWith("--")) {
    if (args[i + 1] === undefined) die(2, `${a} needs a value`);
    opts[a] = args[++i];
  } else positional.push(a);
}
function die(code, message) {
  process.stderr.write(`deliver: ${message}\n`);
  process.exit(code);
}
if (positional.length !== 1) {
  die(
    2,
    "usage: node fork/deliver.mjs <file> [--style s] [--format f] [--settings v] [--preset p.json] [--run id] [--release r] [--dry-run] [--json]",
  );
}

const file = path.resolve(positional[0]);
if (!fs.existsSync(file) || !fs.statSync(file).isFile()) die(2, `no such file: ${positional[0]}`);
const name = path.basename(file);
const mime = MIME[path.extname(name).toLowerCase()];
if (!mime)
  die(
    2,
    `the gateway takes no ${path.extname(name) || "extensionless"} file (${Object.keys(MIME).join(" ")})`,
  );
const bytes = fs.readFileSync(file);
const digest = createHash("sha256").update(bytes).digest("hex");

function config() {
  const cfgPath =
    process.env.FORK_DELIVER_CONFIG ||
    path.join(os.homedir(), ".config", "hyperframes-agent", "deliver.json");
  let cfg = {};
  if (fs.existsSync(cfgPath)) {
    try {
      cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
    } catch {
      die(3, `the feed config is not JSON: ${cfgPath}`);
    }
  }
  const src = cfg.source || {};
  return {
    chat: process.env.FORK_DELIVER_CHAT || cfg.chat_id,
    account: process.env.FORK_DELIVER_ACCOUNT || cfg.account,
    url: process.env.FORK_DELIVER_MCP || cfg.mcp_url,
    headerCmd: process.env.FORK_DELIVER_HEADER_CMD || cfg.header_command,
    limit: Math.min(
      CHANNEL_LIMIT,
      GATEWAY_CONTENT_LIMIT,
      Number(cfg.upload_limit) || CHANNEL_LIMIT,
    ),
    machine: process.env.MEDIA_FEED_MACHINE || src.machine,
    organization: process.env.MEDIA_FEED_ORG || src.organization,
    service: process.env.MEDIA_FEED_SERVICE || src.service,
    cfgPath,
  };
}
const cfg = config();

// A value is data: no em or en dash and no line break reach the caption (media-feed rule 8).
const clean = (v) =>
  String(v)
    .replace(/[—–]/g, "-")
    .replace(/\s*[\r\n]+\s*/g, " ")
    .trim();
const sha8 = (buf) => createHash("sha256").update(buf).digest("hex").slice(0, 8);

let style = opts["--style"];
let settings = opts["--settings"];
if (opts["--preset"]) {
  const p = path.resolve(opts["--preset"]);
  if (!fs.existsSync(p)) die(2, `no such preset: ${opts["--preset"]}`);
  const raw = fs.readFileSync(p);
  let preset;
  try {
    preset = JSON.parse(raw.toString("utf8"));
  } catch {
    die(2, `the preset is not JSON: ${opts["--preset"]}`);
  }
  const presetName = String(preset.name || path.basename(p, ".json"));
  style ??= presetName;
  settings ??= `${presetName}@${sha8(raw)}`;
}
function release() {
  if (opts["--release"]) return opts["--release"];
  try {
    const here = path.dirname(fileURLToPath(import.meta.url));
    const tag = execFileSync(
      "git",
      ["-C", here, "describe", "--tags", "--abbrev=0", "--match", "fork-v*"],
      {
        stdio: ["ignore", "pipe", "ignore"],
      },
    )
      .toString()
      .trim();
    return tag.replace(/^fork-v/, "");
  } catch {
    return "не задано";
  }
}
const stamp = new Date().toISOString().replace(/[-:]/g, "").slice(0, 15);
const run =
  opts["--run"] || process.env.HF_RUN_ID || `run-${stamp}-${randomBytes(2).toString("hex")}`;

const warnings = [];
const unset = (value, what) => {
  if (value) return clean(value);
  warnings.push(`${what} is not set`);
  return "не задано";
};
const fmt = opts["--format"] ? `, ${clean(opts["--format"])}` : "";
const lines = [
  `Стиль: ${unset(style, "style")}${fmt}`,
  `Настройки: ${unset(settings, "settings version")}, ${AGENT} ${clean(release())}`,
  `Файл: ${clean(name)}`,
  `Прогон: ${clean(run)}`,
  `Источник: ${unset(cfg.machine, "machine (MEDIA_FEED_MACHINE)")} · ${unset(cfg.organization, "organization (MEDIA_FEED_ORG)")} · ${unset(cfg.service, "service (MEDIA_FEED_SERVICE)")}`,
];
const mb = (n) => `${(n / 1_000_000).toFixed(1)} MB`;
const oversize = bytes.length > cfg.limit;
if (oversize) {
  lines.push(
    `Размер: ${mb(bytes.length)}, больше лимита канала ${mb(cfg.limit)}, файл не отправлен, только подпись`,
  );
}
// Every label is kept within the caption limit: a long value is cut, never a line.
let caption = lines.join("\n");
while (caption.length > CAPTION_MAX) {
  const longest = lines.reduce((a, l, i) => (l.length > lines[a].length ? i : a), 0);
  lines[longest] =
    `${lines[longest].slice(0, lines[longest].length - (caption.length - CAPTION_MAX) - 1)}…`;
  caption = lines.join("\n");
}
// The run id with the file's SHA-256: a retry after an unknown outcome is the same send (media-feed rule 5).
const idempotencyKey = `${createHash("sha256").update(`${run}\n`).digest("hex").slice(0, 16)}-${digest.slice(0, 40)}`;

const report = (extra) => {
  const out = {
    file: name,
    bytes: bytes.length,
    sha256: digest,
    mime,
    run,
    caption_only: oversize,
    warnings,
    ...extra,
  };
  if (opts["--json"]) process.stdout.write(`${JSON.stringify(out, null, 2)}\n`);
  return out;
};

if (opts["--dry-run"]) {
  report({
    chat_id: cfg.chat || null,
    account: cfg.account || null,
    idempotency_key: idempotencyKey,
    caption,
  });
  if (!opts["--json"]) process.stdout.write(`${caption}\n`);
  process.exit(0);
}
if (!cfg.chat || !cfg.account || !cfg.url || !cfg.headerCmd) {
  die(
    3,
    `the feed is not configured on this machine (chat_id, account, mcp_url and header_command in ${cfg.cfgPath}); nothing sent`,
  );
}

let headers;
try {
  // The helper prints the gateway's headers; they stay in this process and are never written anywhere.
  headers = JSON.parse(
    execSync(cfg.headerCmd, { stdio: ["ignore", "pipe", "pipe"], timeout: 20000 }).toString("utf8"),
  );
} catch (e) {
  die(1, `the header command failed (${String(e.status ?? e.code ?? "error")}); nothing sent`);
}

let session = null;
let nextId = 1;
async function rpc(method, params, notify = false) {
  const h = {
    ...headers,
    "Content-Type": "application/json",
    Accept: "application/json, text/event-stream",
  };
  if (session) h["Mcp-Session-Id"] = session;
  const body = { jsonrpc: "2.0", method, params };
  if (!notify) body.id = nextId++;
  const res = await fetch(cfg.url, { method: "POST", headers: h, body: JSON.stringify(body) });
  session = res.headers.get("mcp-session-id") || session;
  if (!res.ok) throw new Error(`${method}: HTTP ${res.status}`);
  let text = await res.text();
  const data = text.split("\n").filter((l) => l.startsWith("data:"));
  if (data.length) text = data[data.length - 1].slice(5);
  if (!text.trim()) return null;
  const msg = JSON.parse(text);
  if (msg.error) throw new Error(`${method}: ${msg.error.message || JSON.stringify(msg.error)}`);
  return msg.result;
}
async function call(tool, toolArgs) {
  const r = await rpc("tools/call", { name: tool, arguments: toolArgs });
  const sc = r?.structuredContent ?? JSON.parse(r?.content?.[0]?.text || "{}");
  if (r?.isError || sc?.error) throw new Error(`${tool}: ${sc?.error?.message || "refused"}`);
  return sc;
}

try {
  await rpc("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: `${AGENT}-feed`, version: "1" },
  });
  await rpc("notifications/initialized", {}, true);
  const send = {
    chat_id: String(cfg.chat),
    account: String(cfg.account),
    text: caption,
    format: "plain",
    idempotency_key: idempotencyKey,
  };
  if (!oversize) send.attachments = [{ name, mime, content_b64: bytes.toString("base64") }];
  let out = await call("telegram.messages.send", send);
  // A send is a job; a chat without per-message approval runs it at once, so a few short polls settle it.
  const jobId = out?.job?.id;
  for (let i = 0; jobId && i < 60; i++) {
    const job = out?.job ?? out;
    if (
      out?.message_ids ||
      ["completed", "failed", "cancelled", "input_required"].includes(job?.status)
    )
      break;
    await new Promise((r) => setTimeout(r, 2000));
    out = await call("fabric.job.get", { id: jobId });
  }
  const job = out?.job ?? out;
  const result = job?.result?.output ?? job?.result ?? out;
  // A send waiting for the gateway's approval is held at most once: it counts as posted (media-feed guarantee 8).
  if (job?.status && !["completed", "input_required"].includes(job.status)) {
    throw new Error(`send ${job.status}${job.error?.message ? `: ${job.error.message}` : ""}`);
  }
  const waiting = job?.status === "input_required";
  report({ message_ids: result?.message_ids ?? null, job: jobId ?? null, waiting });
  if (!opts["--json"]) {
    process.stdout.write(
      waiting
        ? `queued ${name} (run ${run}) for the gateway's approval, job ${jobId}\n`
        : `posted ${name} (run ${run}), message ${result?.message_ids ?? "?"}${oversize ? ", caption only" : ""}\n`,
    );
  }
  for (const w of warnings) process.stderr.write(`deliver: warning: ${w}\n`);
} catch (e) {
  die(1, `${e.message}; ${name} not confirmed posted`);
}
