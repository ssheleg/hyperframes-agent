#!/usr/bin/env node
// Delivery of a generated file to the operator's generations channel (operator, 2026-11-15: every generation goes to
// that channel, captioned with its style, the version of its settings, the file's name and the run's id). Sending goes
// only through the operator's own Telegram gateway, a Fabric service reached over MCP; no other Telegram client.
//
//   node fork/deliver.mjs <file> [--style <name>] [--settings <version>] [--preset <preset.json>] [--run <id>]
//                                [--dry-run] [--json]
//
// The caption has four lines: style, settings, file, run. --preset names a style preset (fork/style-preset.mjs): its
// `name` is the style when --style is absent, and `<name>@<sha256 of the file, 8 hex>` the settings version when
// --settings is absent. The run id is --run, else HF_RUN_ID, else one made from the UTC time.
//
// Where it goes is private and lives outside this repository: FORK_DELIVER_CONFIG names a JSON file (default
// ~/.config/hyperframes-agent/deliver.json) with `chat_id`, `mcp_url` and `header_command`, a command whose standard
// output is the JSON headers the gateway takes (a vault's header helper; the token is read by the program and never
// printed). FORK_DELIVER_CHAT, FORK_DELIVER_MCP and FORK_DELIVER_HEADER_CMD override the file's fields.
//
// Exit 0: delivered (or printed with --dry-run); 1: the gateway refused or failed; 2: bad input (no file, a type the
// gateway does not take, a file over 25 MB); 3: delivery is not configured on this machine (nothing sent).
import { createHash, randomBytes } from "node:crypto";
import { execSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const MAX_BYTES = 25 * 1024 * 1024; // one attachment given as content to a Mac instance of the gateway
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
    "usage: node fork/deliver.mjs <file> [--style s] [--settings v] [--preset p.json] [--run id] [--dry-run] [--json]",
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
if (bytes.length > MAX_BYTES) {
  die(
    2,
    `${name} is ${(bytes.length / 1048576).toFixed(1)} MB; the gateway takes up to 25 MB a file`,
  );
}

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
const stamp = new Date().toISOString().replace(/[-:]/g, "").slice(0, 15);
const run =
  opts["--run"] || process.env.HF_RUN_ID || `run-${stamp}-${randomBytes(2).toString("hex")}`;
const caption = [
  `Стиль: ${style || "не указан"}`,
  `Настройки: ${settings || "не указаны"}`,
  `Файл: ${name}`,
  `Прогон: ${run}`,
].join("\n");
// The same run and the same bytes are the same send: a retry never posts twice.
const idempotencyKey = `hf-${createHash("sha256").update(`${run}\n${name}\n`).update(bytes).digest("hex").slice(0, 40)}`;

function config() {
  const cfgPath =
    process.env.FORK_DELIVER_CONFIG ||
    path.join(os.homedir(), ".config", "hyperframes-agent", "deliver.json");
  let cfg = {};
  if (fs.existsSync(cfgPath)) {
    try {
      cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
    } catch {
      die(3, `the delivery config is not JSON: ${cfgPath}`);
    }
  }
  return {
    chat: process.env.FORK_DELIVER_CHAT || cfg.chat_id,
    url: process.env.FORK_DELIVER_MCP || cfg.mcp_url,
    headerCmd: process.env.FORK_DELIVER_HEADER_CMD || cfg.header_command,
    cfgPath,
  };
}
const cfg = config();
const report = (extra) => {
  const out = {
    file: name,
    bytes: bytes.length,
    mime,
    style: style || null,
    settings: settings || null,
    run,
    ...extra,
  };
  if (opts["--json"]) process.stdout.write(`${JSON.stringify(out, null, 2)}\n`);
  return out;
};

if (opts["--dry-run"]) {
  report({ chat_id: cfg.chat || null, idempotency_key: idempotencyKey, caption });
  if (!opts["--json"]) process.stdout.write(`${caption}\n`);
  process.exit(0);
}
if (!cfg.chat || !cfg.url || !cfg.headerCmd) {
  die(
    3,
    `delivery is not configured on this machine (chat_id, mcp_url and header_command in ${cfg.cfgPath}); nothing sent`,
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
async function call(tool, args) {
  const r = await rpc("tools/call", { name: tool, arguments: args });
  const sc = r?.structuredContent ?? JSON.parse(r?.content?.[0]?.text || "{}");
  if (r?.isError || sc?.error) throw new Error(`${tool}: ${sc?.error?.message || "refused"}`);
  return sc;
}

try {
  await rpc("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "hyperframes-agent-deliver", version: "1" },
  });
  await rpc("notifications/initialized", {}, true);
  let out = await call("telegram.messages.send", {
    chat_id: String(cfg.chat),
    text: caption,
    format: "plain",
    attachments: [{ name, mime, content_b64: bytes.toString("base64") }],
    idempotency_key: idempotencyKey,
  });
  // A send is a job; an exempt chat runs it at once, so a few short polls settle it.
  const jobId = out?.job?.id;
  for (let i = 0; jobId && i < 60; i++) {
    const job = out?.job ?? out;
    if (out?.message_ids || ["completed", "failed", "cancelled"].includes(job?.status)) break;
    await new Promise((r) => setTimeout(r, 2000));
    out = await call("fabric.job.get", { id: jobId });
  }
  const job = out?.job ?? out;
  const result = job?.result?.output ?? job?.result ?? out;
  if (job?.status && job.status !== "completed") {
    throw new Error(`send ${job.status}${job.error?.message ? `: ${job.error.message}` : ""}`);
  }
  report({ message_ids: result?.message_ids ?? null, job: jobId ?? null });
  if (!opts["--json"])
    process.stdout.write(`delivered ${name} (run ${run}), message ${result?.message_ids ?? "?"}\n`);
} catch (e) {
  die(1, `${e.message}; ${name} not confirmed delivered`);
}
