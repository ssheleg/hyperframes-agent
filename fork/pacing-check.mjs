#!/usr/bin/env node
// Pacing check of a rendered short video (board request a4d1b095, 2026-11-11): a short (Shorts, TikTok, Reels, up to
// 3 minutes) must not stall between scenes. It measures the file with ffmpeg's silencedetect and freezedetect, the same
// measure the operator's judge takes before publication, and fails the video when
//
//   - it has no audio stream (music and sound are always there, even when the order did not name them),
//   - one silence is longer than --max-gap seconds (0.8), or all silences together exceed --max-silence-share of the
//     length (0.08),
//   - the picture stands still longer than --max-still seconds (1.0).
//
// A silence is audio under --noise dB (-35) for at least --min-silence seconds (0.4); a still is a picture whose frames
// differ by less than --freeze-noise (0.003) for at least 0.5 s. Run it after `hyperframes render`, before delivery.
//
//   node fork/pacing-check.mjs <video> [--json] [--max-gap 0.8] [--max-silence-share 0.08] [--max-still 1.0]
//                                      [--noise -35] [--min-silence 0.4] [--freeze-noise 0.003]
//
// Prints a verdict line (or the hyperframes-pacing/1 report with --json). Exit 0: pass; 1: fail; 2: the file or ffmpeg
// could not be read. FFMPEG and FFPROBE name the programs (default: found on PATH).
import { spawnSync } from "node:child_process";
import fs from "node:fs";

const args = process.argv.slice(2);
const usage = () => {
  process.stderr.write(
    "usage: node fork/pacing-check.mjs <video> [--json] [--max-gap s] [--max-silence-share f] [--max-still s] [--noise dB] [--min-silence s] [--freeze-noise f]\n",
  );
  process.exit(2);
};
const NUMERIC = {
  "--max-gap": 0.8,
  "--max-silence-share": 0.08,
  "--max-still": 1.0,
  "--noise": -35,
  "--min-silence": 0.4,
  "--freeze-noise": 0.003,
};
const opts = { ...NUMERIC };
let file = null;
let json = false;
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === "--json") json = true;
  else if (a in NUMERIC) {
    const v = Number(args[++i]);
    if (!Number.isFinite(v)) usage();
    opts[a] = v;
  } else if (a.startsWith("-") || file) usage();
  else file = a;
}
if (!file) usage();
if (!fs.existsSync(file)) {
  process.stderr.write(`pacing-check: no such file: ${file}\n`);
  process.exit(2);
}

const FFMPEG = process.env.FFMPEG || "ffmpeg";
const FFPROBE = process.env.FFPROBE || "ffprobe";
const run = (cmd, argv) => {
  const r = spawnSync(cmd, argv, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  if (r.error) {
    process.stderr.write(`pacing-check: cannot run ${cmd}: ${r.error.message}\n`);
    process.exit(2);
  }
  return r;
};

const probe = run(FFPROBE, [
  "-v",
  "error",
  "-show_entries",
  "format=duration:stream=codec_type",
  "-of",
  "json",
  file,
]);
let meta;
try {
  meta = JSON.parse(probe.stdout);
} catch {
  process.stderr.write(`pacing-check: ffprobe could not read ${file}: ${probe.stderr.trim()}\n`);
  process.exit(2);
}
const duration = Number(meta.format?.duration);
const streams = (meta.streams || []).map((s) => s.codec_type);
if (!Number.isFinite(duration) || duration <= 0 || !streams.includes("video")) {
  process.stderr.write(`pacing-check: ${file} has no video with a duration\n`);
  process.exit(2);
}
const hasAudio = streams.includes("audio");

// One pass for both filters; their findings arrive on stderr.
const argv = ["-hide_banner", "-nostats", "-i", file];
if (hasAudio)
  argv.push("-af", `silencedetect=noise=${opts["--noise"]}dB:d=${opts["--min-silence"]}`);
argv.push("-vf", `freezedetect=n=${opts["--freeze-noise"]}:d=0.5`, "-f", "null", "-");
const pass = run(FFMPEG, argv);
if (pass.status !== 0) {
  process.stderr.write(
    `pacing-check: ffmpeg failed on ${file}: ${pass.stderr.trim().split("\n").slice(-2).join(" ")}\n`,
  );
  process.exit(2);
}

// A span opened and never closed runs to the end of the file.
const round = (x) => Math.round(x * 1000) / 1000;
function spans(text, startRe, endRe) {
  const out = [];
  let open = null;
  for (const line of text.split("\n")) {
    const s = line.match(startRe);
    if (s) {
      open = Math.max(0, Number(s[1]));
      continue;
    }
    const e = line.match(endRe);
    if (e && open !== null) {
      out.push({
        start: round(open),
        end: round(Number(e[1])),
        duration: round(Number(e[1]) - open),
      });
      open = null;
    }
  }
  if (open !== null)
    out.push({ start: round(open), end: round(duration), duration: round(duration - open) });
  return out;
}
const silences = hasAudio
  ? spans(pass.stderr, /silence_start: (-?[\d.]+)/, /silence_end: ([\d.]+)/)
  : [];
const stills = spans(pass.stderr, /freeze_start: ([\d.]+)/, /freeze_end: ([\d.]+)/);

const silenceTotal = round(silences.reduce((t, s) => t + s.duration, 0));
const longest = (list) => round(list.reduce((m, s) => Math.max(m, s.duration), 0));
const reasons = [];
if (!hasAudio) reasons.push("no audio stream: a short always carries music and sound");
const gaps = silences.filter((s) => s.duration > opts["--max-gap"]);
for (const g of gaps)
  reasons.push(`silence ${g.duration} s at ${g.start} s (limit ${opts["--max-gap"]} s)`);
const share = round(silenceTotal / duration);
if (share > opts["--max-silence-share"])
  reasons.push(
    `silence is ${round(share * 100)}% of the length (limit ${round(opts["--max-silence-share"] * 100)}%)`,
  );
for (const s of stills.filter((x) => x.duration > opts["--max-still"]))
  reasons.push(
    `picture still for ${s.duration} s at ${s.start} s (limit ${opts["--max-still"]} s)`,
  );

const report = {
  schema: "hyperframes-pacing/1",
  file,
  duration_s: round(duration),
  audio: hasAudio,
  thresholds: {
    max_gap_s: opts["--max-gap"],
    max_silence_share: opts["--max-silence-share"],
    max_still_s: opts["--max-still"],
    silence_noise_db: opts["--noise"],
    min_silence_s: opts["--min-silence"],
    freeze_noise: opts["--freeze-noise"],
  },
  silences,
  silence_total_s: silenceTotal,
  silence_share: share,
  longest_silence_s: longest(silences),
  stills,
  longest_still_s: longest(stills),
  verdict: reasons.length ? "fail" : "pass",
  reasons,
};
if (json) process.stdout.write(JSON.stringify(report, null, 2) + "\n");
else {
  process.stdout.write(
    `${report.verdict}: ${file}, ${report.duration_s} s, silence ${silenceTotal} s (${round(share * 100)}%, longest ${report.longest_silence_s} s), longest still ${report.longest_still_s} s\n`,
  );
  for (const r of reasons) process.stdout.write(`  ${r}\n`);
}
process.exit(reasons.length ? 1 : 0);
