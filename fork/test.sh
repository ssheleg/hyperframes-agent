#!/usr/bin/env bash
# Tests of the line's own scripts (fork/*.sh), with throwaway Git repositories and stubs for gh and ssh: no network,
# no build, nothing pushed. fork/release.sh runs it before it builds anything.
#
#   fork/test.sh
#
# Each case prints "ok" or "FAIL"; the run exits 1 on any failure.
set -uo pipefail

FORK="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/hf-fork-test.XXXXXX")"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
FAILS=0
ok() { printf 'ok    %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '      %s\n' "$2"; FAILS=$((FAILS + 1)); }
# expect <name> <exit-code> <text the output must contain> -- <command...>
expect() {
  local name="$1" code="$2" text="$3"; shift 4
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" != "$code" ]; then fail "$name" "exit $rc, expected $code: $(printf '%s' "$out" | tail -n 2 | tr '\n' ' ')"
  elif [ -n "$text" ] && ! printf '%s' "$out" | grep -qF -- "$text"; then fail "$name" "output lacks '$text': $(printf '%s' "$out" | tail -n 2 | tr '\n' ' ')"
  else ok "$name"; fi
}
gitq() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c tag.gpgsign=false "$@"; }

# A stub directory first on PATH: gh answers what each case puts in its files, ssh is never reached.
STUB="$WORK/bin"; mkdir -p "$STUB"
cat > "$STUB/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "pr list"*) cat "${GH_STUB_DIR}/prs" 2>/dev/null ;;
  "workflow list"*) cat "${GH_STUB_DIR}/workflows" 2>/dev/null ;;
  "workflow disable"*) echo "$*" >> "${GH_STUB_DIR}/disabled" ;;
  "run list"*) : ;;
  *) echo "gh stub: unexpected $*" >&2; exit 3 ;;
esac
EOF
printf '#!/bin/sh\necho "ssh stub: no network in tests" >&2; exit 255\n' > "$STUB/ssh"
# gitleaks finds nothing in the fixtures; the stub keeps the tests from depending on it being installed, and records
# where it ran and with what (the allow list's paths only match relative names, so it must scan "." from the stage).
# shellcheck disable=SC2016  # the stub's own variables expand when it runs
printf '#!/bin/sh\nprintf "%%s|%%s\\n" "$PWD" "$*" >> "$GH_STUB_DIR/gitleaks.calls"\nexit 0\n' > "$STUB/gitleaks"
chmod +x "$STUB/gh" "$STUB/ssh" "$STUB/gitleaks"
export GH_STUB_DIR="$WORK/gh"; mkdir -p "$GH_STUB_DIR"
export PATH="$STUB:$PATH"
export FORK_TEST_RUNNING=1
# release.sh reads free space before it starts; the cases see plenty unless one sets less.
export FORK_FREE_KB=999999999

# A line: an "upstream" tag v1.2.3, the fork's scripts committed on main, an origin to push to.
LINE="$WORK/line"; ORIGIN="$WORK/origin.git"
git init -q --bare "$ORIGIN"
git init -q -b main "$LINE"
(
  cd "$LINE" || exit 1
  mkdir -p packages/cli fork/org
  printf '{"name":"@hyperframes/cli","version":"1.2.3"}\n' > packages/cli/package.json
  printf 'upstream\n' > README.md; printf 'claude\n' > CLAUDE.md; printf 'agents\n' > AGENTS.md
  gitq add -A; gitq commit -q -m base; gitq tag v1.2.3
  cp "$FORK"/*.sh "$FORK"/*.mjs fork/; cp "$FORK"/org/* fork/org/
  gitq add -A; gitq commit -q -m "fork scripts"
  git remote add origin "$ORIGIN"; git push -q origin main
)

# --- release.sh: arguments and --prebuilt --------------------------------------------------------------------------
cd "$LINE" || exit 1
expect "release: number must be a positive integer" 2 "positive integer" -- fork/release.sh 0
expect "release: unknown flag" 2 "usage" -- fork/release.sh 1 --nope
expect "release: --prebuilt needs a path" 2 "usage" -- fork/release.sh 1 --prebuilt
expect "release: --prebuilt of a missing file" 2 "no tarball" -- fork/release.sh 1 --prebuilt "$WORK/none.tgz"

COMMIT="$(git rev-parse HEAD)"
mktgz() { # mktgz <dir> <file name> <version> <commit>
  local d="$WORK/pkg-$RANDOM"; mkdir -p "$d/package" "$1"
  printf '{"name":"hyperframes","version":"%s","hyperframesFork":{"commit":"%s"}}\n' "$3" "$4" > "$d/package/package.json"
  (cd "$d" && tar -czf "$1/$2" package)
  (cd "$1" && shasum -a 256 "$2" > "$2.sha256")
}
P="$WORK/prebuilt"
mktgz "$P/a" hyperframes-1.2.3-sshlg.1.tgz "1.2.3+sshlg.1" "$COMMIT"
mktgz "$P/a2" hyperframes-1.2.3-sshlg.2.tgz "1.2.3+sshlg.2" "$COMMIT"
expect "release: --prebuilt of another release number" 1 "this release is hyperframes-1.2.3-sshlg.1.tgz" \
  -- fork/release.sh 1 --prebuilt "$P/a2/hyperframes-1.2.3-sshlg.2.tgz"
mktgz "$P/b" hyperframes-1.2.3-sshlg.1.tgz "1.2.3+sshlg.2" "$COMMIT"
expect "release: --prebuilt renamed to another number" 1 "this release is '1.2.3+sshlg.1" \
  -- fork/release.sh 1 --prebuilt "$P/b/hyperframes-1.2.3-sshlg.1.tgz"
mktgz "$P/c" hyperframes-1.2.3-sshlg.1.tgz "1.2.3+sshlg.1" "0000000000000000000000000000000000000000"
expect "release: --prebuilt of another commit" 1 "this release is" \
  -- fork/release.sh 1 --prebuilt "$P/c/hyperframes-1.2.3-sshlg.1.tgz"
mktgz "$P/d" hyperframes-1.2.3-sshlg.1.tgz "1.2.3+sshlg.1" "$COMMIT"; printf x >> "$P/d/hyperframes-1.2.3-sshlg.1.tgz"
expect "release: --prebuilt with an appended byte" 1 "does not match its .sha256" \
  -- fork/release.sh 1 --prebuilt "$P/d/hyperframes-1.2.3-sshlg.1.tgz"
mktgz "$P/e" hyperframes-1.2.3-sshlg.1.tgz "1.2.3+sshlg.1" "$COMMIT"; rm "$P/e/hyperframes-1.2.3-sshlg.1.tgz.sha256"
expect "release: --prebuilt without its .sha256" 1 ".sha256 beside" \
  -- fork/release.sh 1 --prebuilt "$P/e/hyperframes-1.2.3-sshlg.1.tgz"
# Free space: under the threshold a build is refused with the way out, over it the build starts (a bun stub stops it
# right after), and a prebuilt tarball never meets the build's threshold, only its own smoke install's.
expect "release: refuses to build short of disk, names remote-build" 1 "remote-build.sh <host> 1, then publish here with --prebuilt" \
  -- env FORK_FREE_KB=1048576 fork/release.sh 1
BUNSTUB="$WORK/bunstub"; mkdir -p "$BUNSTUB"; printf '#!/bin/sh\necho "bun stub" >&2; exit 7\n' > "$BUNSTUB/bun"; chmod +x "$BUNSTUB/bun"
expect "release: with enough disk the build starts" 7 "bun stub" \
  -- env PATH="$BUNSTUB:$PATH" FORK_FREE_KB=9437184 fork/release.sh 1 --skip-deps
expect "release: the build stamp is restored after a failed build" 0 "" -- git diff --quiet -- packages/cli/package.json
expect "release: --prebuilt skips the build's disk threshold" 1 "this release is hyperframes-1.2.3-sshlg.1.tgz" \
  -- env FORK_FREE_KB=4194304 fork/release.sh 1 --prebuilt "$P/a2/hyperframes-1.2.3-sshlg.2.tgz"
expect "release: --prebuilt refused when its smoke install would not fit" 1 "the smoke install of the prebuilt tarball wants" \
  -- env FORK_FREE_KB=1024 fork/release.sh 1 --prebuilt "$P/a/hyperframes-1.2.3-sshlg.1.tgz"
gitq tag -a fork-v1.2.3-sshlg.1 -m t
expect "release: an existing tag is refused" 1 "already exists" -- fork/release.sh 1
expect "release: a number past the next is a gap" 1 "leaves a gap: the next on v1.2.3 is 2" -- fork/release.sh 3
expect "release: auto takes the next number" 1 "this release is hyperframes-1.2.3-sshlg.2.tgz" \
  -- fork/release.sh auto --prebuilt "$P/a/hyperframes-1.2.3-sshlg.1.tgz"
expect "release: neither a number nor auto" 2 "positive integer or auto" -- fork/release.sh next
git tag -d fork-v1.2.3-sshlg.1 >/dev/null
printf 'x\n' >> README.md
expect "release: a dirty tree is refused" 1 "uncommitted changes" -- fork/release.sh 1
git checkout -q -- README.md
git switch -q -c side
expect "release: only from main" 1 "release from main" -- fork/release.sh 1
git switch -q main

# --- remote-build.sh: refusals before any SSH ---------------------------------------------------------------------
expect "remote-build: needs FORK_REMOTE_DIR" 2 "set FORK_REMOTE_DIR" -- env -u FORK_REMOTE_DIR fork/remote-build.sh host 1
expect "remote-build: refuses a directory it cannot quote" 2 "will not quote" -- env FORK_REMOTE_DIR='a;b' fork/remote-build.sh host 1
expect "remote-build: number must be a positive integer" 2 "positive integer" -- env FORK_REMOTE_DIR=x fork/remote-build.sh host x
gitq commit -q --allow-empty -m "not pushed"
expect "remote-build: HEAD must be on origin's main" 1 "push it first" -- env FORK_REMOTE_DIR=x fork/remote-build.sh host 1
git push -q origin main
expect "remote-build: reaches ssh only after its checks" 1 "the build on host failed" -- env FORK_REMOTE_DIR=x fork/remote-build.sh host 1

# --- door-audit.sh: test utilities are not shipped code -----------------------------------------------------------
mkdir -p packages/core/src/__fixtures__ packages/core/src/__test_utils__
printf 'const a = process.env.SHIPPED_VAR;\n' > packages/core/src/shipped.ts
printf 'const b = process.env.FIXTURE_VAR;\n' > packages/core/src/__fixtures__/f.ts
printf 'const c = process.env.UTIL_VAR;\n' > packages/core/src/__test_utils__/u.ts
printf 'const d = process.env.HELPER_VAR;\n' > packages/core/src/x.test-helpers.ts
printf 'const e = process.env.TEST_VAR;\n' > packages/core/src/x.test.ts
gitq add -A; gitq commit -q -m "door fixtures"; gitq tag v1.2.4
AUDIT="$(fork/door-audit.sh v1.2.3 v1.2.4 2>&1)"
if printf '%s' "$AUDIT" | grep -q SHIPPED_VAR && ! printf '%s' "$AUDIT" | grep -qE 'FIXTURE_VAR|UTIL_VAR|HELPER_VAR|TEST_VAR'; then
  ok "door-audit: lists shipped code, leaves test utilities out"
else fail "door-audit: lists shipped code, leaves test utilities out" "$(printf '%s' "$AUDIT" | grep -E '_VAR' | tr '\n' ' ')"; fi
expect "door-audit: refuses an unknown tag" 2 "no tag" -- fork/door-audit.sh v1.2.3 v9.9.9

# --- visual-types.mjs and style-preset.mjs ---------------------------------------------------------------------------
VT="$WORK/vt"; mkdir -p "$VT/themes" "$VT/registry/blocks/title-a" "$VT/registry/blocks/wipe-a" "$VT/registry/components/odd" \
  "$VT/skills/hyperframes/assets/frame-presets/plain"
# shellcheck disable=SC2016  # backticks are the file's own markdown
printf '## Final token set\n\n| Group | Tokens |\n| --- | --- |\n| Palette | `--bg`, `--fg` |\n| Motion | `--dur-beat` |\n\n`--demo-bg` is not a token.\n\n## Next\n' > "$VT/themes/CONTRACT.md"
printf ':root {\n  --bg: #fff;\n  --fg: #000;\n  --dur-beat: 0.4s;\n}\n' > "$VT/themes/plain.css"
printf -- '---\nname: Plain\ndescription: >\n  A plain frame.\n---\n' > "$VT/skills/hyperframes/assets/frame-presets/plain/FRAME.md"
printf '{"name":"title-a","type":"hyperframes:block","tags":["typography"],"files":[{"path":"a.html"}],"preview":{"poster":"https://x/p.jpg"}}\n' > "$VT/registry/blocks/title-a/registry-item.json"
printf '<script>gsap.to(1)</script>\n' > "$VT/registry/blocks/title-a/a.html"
printf '{"name":"wipe-a","type":"hyperframes:block","tags":["transition"],"files":[]}\n' > "$VT/registry/blocks/wipe-a/registry-item.json"
printf '{"name":"odd","type":"hyperframes:component","tags":["nothing-known"],"files":[]}\n' > "$VT/registry/components/odd/registry-item.json"
VTJ="$(node fork/visual-types.mjs --root "$VT" --base v1.2.3)"
if printf '%s' "$VTJ" | node -e '
  let s=""; process.stdin.on("data",d=>s+=d).on("end",()=>{ const c=JSON.parse(s); const t=Object.fromEntries(c.types.map(x=>[x.id,x]));
  const ok = c.totals.items===3 && c.totals.untyped===1 && t["kinetic-typography"].count===1 && t["kinetic-typography"].items[0].techniques.includes("gsap")
    && t["kinetic-typography"].items[0].poster && t.transitions.count===1 && c.styles.token_contract.tokens.join()==="--bg,--fg,--dur-beat"
    && c.styles.frame_presets[0].description==="A plain frame." && c.styles.theme_packs[0].name==="plain";
  process.exit(ok?0:1) })'; then ok "visual-types: groups items by tag, names libraries, reads tokens, packs and presets"
else fail "visual-types: groups items by tag, names libraries, reads tokens, packs and presets" "$(printf '%s' "$VTJ" | head -c 300)"; fi
expect "visual-types: the same tree gives the same bytes" 0 "" -- test "$(node fork/visual-types.mjs --root "$VT" --base v1.2.3)" = "$VTJ"
# --files: one frame reachable, one not; the recipe is copied and named by its path inside the archive.
mkdir -p "$VT/fork/recipes/presenter-over-diagram" "$WORK/frames"
printf '<html></html>\n' > "$VT/fork/recipes/presenter-over-diagram/index.html"
printf 'not really a png' > "$WORK/frames/w.png"
printf '{"name":"wipe-a","type":"hyperframes:block","tags":["transition"],"files":[],"preview":{"poster":"file://%s/frames/none.png"}}\n' "$WORK" > "$VT/registry/blocks/wipe-a/registry-item.json"
printf '{"name":"title-a","type":"hyperframes:block","tags":["typography"],"files":[{"path":"a.html"}],"preview":{"poster":"file://%s/frames/w.png"}}\n' "$WORK" > "$VT/registry/blocks/title-a/registry-item.json"
FILES="$WORK/vt-files"
# The frame is not an image, so ffmpeg (if installed) fails on it and the original is kept under its own name.
VTF="$(node fork/visual-types.mjs --root "$VT" --release 1.2.3-sshlg.1 --files "$FILES" 2>&1)"
if printf '%s' "$VTF" | node -e '
  let s=""; process.stdin.on("data",d=>s+=d).on("end",()=>{ const c=JSON.parse(s); const t=Object.fromEntries(c.types.map(x=>[x.id,x]));
  const ok = c.files.asset==="visual-types-files-1.2.3-sshlg.1.tar.gz" && c.files.posters_fetched===1 && c.files.posters_missing.join()==="wipe-a"
    && t["kinetic-typography"].items[0].poster_file==="posters/title-a.png" && !t.transitions.items[0].poster_file
    && c.compositions.length===1 && c.compositions[0].file==="recipes/presenter-over-diagram/index.html";
  process.exit(ok?0:1) })' && [ -s "$FILES/posters/title-a.png" ] && [ -f "$FILES/recipes/presenter-over-diagram/index.html" ]; then
  ok "visual-types --files: frames and recipes inside the archive, an unreachable frame listed"
else fail "visual-types --files: frames and recipes inside the archive, an unreachable frame listed" "$(printf '%s' "$VTF" | head -c 300)"; fi
# An item no type names gets no frame; dashes between words leave every string; the mirror keeps the registry's layout.
printf '{"name":"odd","type":"hyperframes:component","title":"Odd \xe2\x80\x94 thing","description":"one - two -- three","tags":["nothing-known"],"files":[{"path":"o.html"},{"path":"big.mp4","url":"https://cdn/x.mp4"}],"preview":{"poster":"file://%s/frames/w.png"}}\n' "$WORK" > "$VT/registry/components/odd/registry-item.json"
printf '<div></div>\n' > "$VT/registry/components/odd/o.html"
printf '{"name":"t","items":[]}\n' > "$VT/registry/registry.json"
FILES2="$WORK/vt-files2"; MIR="$WORK/vt-mirror"
VTM="$(node fork/visual-types.mjs --root "$VT" --release 1.2.3-sshlg.1 --files "$FILES2" --registry-mirror "$MIR" 2>&1)"
if printf '%s' "$VTM" | node -e '
  let s=""; process.stdin.on("data",d=>s+=d).on("end",()=>{ const c=JSON.parse(s); const t=Object.fromEntries(c.types.map(x=>[x.id,x]));
  const m=c.registry_mirror;
  const ok = c.files.posters_fetched===1 && !s.includes("\u2014") && !/\S --? \S/.test(s)
    && m.asset==="registry-1.2.3-sshlg.1.tar.gz" && m.items===3 && m.files===2 && m.hosted_elsewhere.join()==="odd/big.mp4"
    && t["kinetic-typography"].items[0].mirror_dir==="blocks/title-a/";
  process.exit(ok?0:1) })' && [ ! -e "$FILES2/posters/odd.png" ] && [ -f "$MIR/registry.json" ] \
  && [ -f "$MIR/components/odd/o.html" ] && [ -f "$MIR/blocks/title-a/registry-item.json" ] && [ ! -e "$MIR/components/odd/big.mp4" ]; then
  ok "visual-types: frames only for typed items, no dash between words, the registry mirrored in its layout"
else fail "visual-types: frames only for typed items, no dash between words, the registry mirrored in its layout" "$(printf '%s' "$VTM" | head -c 300)"; fi
node fork/style-preset.mjs new plain --name demo --root "$VT" > "$WORK/preset.json"
expect "style-preset: a preset from a theme pack is whole" 0 "whole (3 tokens)" -- node fork/style-preset.mjs check "$WORK/preset.json" --root "$VT"
node -e 'const fs=require("fs");const p=JSON.parse(fs.readFileSync(process.argv[1]));p.frame_preset="plain";p.transitions=["wipe-a"];p.captions="title-a";delete p.tokens["--fg"];p.tokens["--dur-beat"]="slow";fs.writeFileSync(process.argv[2],JSON.stringify(p))' "$WORK/preset.json" "$WORK/bad.json"
BAD="$(node fork/style-preset.mjs check "$WORK/bad.json" --root "$VT" 2>&1)"; BADRC=$?
if [ "$BADRC" = 1 ] && printf '%s' "$BAD" | grep -q "token --fg is missing" && printf '%s' "$BAD" | grep -q "not a duration" \
  && printf '%s' "$BAD" | grep -q "title-a is not tagged captions" && ! printf '%s' "$BAD" | grep -q "frame preset\|wipe-a"; then
  ok "style-preset: names every missing token, a bad pace and a wrong caption item"
else fail "style-preset: names every missing token, a bad pace and a wrong caption item" "$(printf '%s' "$BAD" | tr '\n' ' ')"; fi
expect "style-preset: css writes every token in a :root block" 0 "--dur-beat: 0.4s;" -- node fork/style-preset.mjs css "$WORK/preset.json" --root "$VT"

# --- workflows-guard.sh ---------------------------------------------------------------------------------------------
: > "$GH_STUB_DIR/workflows"
expect "workflows-guard: nothing active" 0 "no active workflow" -- fork/workflows-guard.sh --check owner/repo
printf '7\t.github/workflows/stale.yml\n' > "$GH_STUB_DIR/workflows"
expect "workflows-guard: --check reports an active workflow" 1 "active .github/workflows/stale.yml" -- fork/workflows-guard.sh --check owner/repo
expect "workflows-guard: disables it" 0 "disabled .github/workflows/stale.yml" -- fork/workflows-guard.sh owner/repo
expect "workflows-guard: refuses upstream" 2 "refusing heygen-com" -- fork/workflows-guard.sh heygen-com/hyperframes

# --- export.sh: refusals ---------------------------------------------------------------------------------------------
# export.sh checks the copy's origin by name, so the bare repository's path carries it.
COPY_ORIGIN="$WORK/appvillis-com/appvillis-hyperframes-agent.git"; COPY="$WORK/copy"
mkdir -p "$WORK/appvillis-com"; git init -q --bare "$COPY_ORIGIN"
git init -q -b main "$COPY"
(cd "$COPY" && printf 'copy\n' > README.md && GIT_AUTHOR_EMAIL=appvillis-hyperframes-agent@users.noreply.github.com \
  gitq add -A && GIT_AUTHOR_EMAIL=appvillis-hyperframes-agent@users.noreply.github.com GIT_COMMITTER_EMAIL=x@x \
  gitq commit -q -m "export: first" && git remote add origin "$COPY_ORIGIN" && git push -q origin main)
MARK="$WORK/markers.txt"; printf 'neverwrittenmarker\n' > "$MARK"
FAKE_AUDIT="$WORK/audit.py"; printf 'import sys\nprint(sys.argv[1].rsplit("/",1)[-1]+": ready")\n' > "$FAKE_AUDIT"
export ORG_TRANSFER_AUDIT="$FAKE_AUDIT" ORG_TRANSFER_MARKERS="$MARK"
expect "export: needs the transfer audit" 2 "ORG_TRANSFER_AUDIT" -- env -u ORG_TRANSFER_AUDIT fork/export.sh "$COPY"
expect "export: needs the marker file" 2 "ORG_TRANSFER_MARKERS" -- env ORG_TRANSFER_MARKERS="$WORK/none" fork/export.sh "$COPY"
(cd "$COPY" && printf 'team fix\n' > team.txt && gitq add team.txt && gitq commit -q -m "team: a fix" && git push -q origin main)
expect "export: refuses a commit made in the copy" 1 "commits made since the last export" -- fork/export.sh "$COPY"
TEAM_SHA="$(git -C "$COPY" rev-parse --short=12 HEAD)"
gitq commit -q --allow-empty -m "take the team's fix" -m "Backports: $TEAM_SHA"
printf '#7 open\n' > "$GH_STUB_DIR/prs"
expect "export: a commit named in Backports passes; an open pull request refuses" 1 "open pull requests" -- fork/export.sh "$COPY"
: > "$GH_STUB_DIR/prs"
printf 'ssheleg\n' > stray.txt; gitq add stray.txt; gitq commit -q -m "a stray name"
expect "export: refuses a tree that names this line" 1 "still name this line" -- fork/export.sh "$COPY"
git rm -q stray.txt; gitq commit -q -m "remove the stray name"
printf 'import sys\nprint(sys.argv[1].rsplit("/",1)[-1]+": fix_tree")\n' > "$WORK/audit-fix.py"
expect "export: a transfer audit that is not ready refuses before the commit" 1 "nothing committed" \
  -- env ORG_TRANSFER_AUDIT="$WORK/audit-fix.py" fork/export.sh "$COPY"
expect "export: the refused copy has a clean tree" 0 "" -- test -z "$(git -C "$COPY" status --porcelain)"
expect "export: nothing was committed in the copy by the refusals" 0 "" -- test "$(git -C "$COPY" rev-parse --short=12 HEAD)" = "$TEAM_SHA"
expect "export: a clean line exports one commit with Source-Revision" 0 "committed" -- fork/export.sh "$COPY"
expect "export: the commit names the line's revision" 0 "Source-Revision: line@$(git rev-parse --short=12 HEAD)" -- git -C "$COPY" log -1 --format=%B
CALL="$(tail -n1 "$GH_STUB_DIR/gitleaks.calls" 2>/dev/null)"
case "$CALL" in
  *"|dir . --config "*)
    if [ "${CALL%%|*}" != "$LINE" ]; then ok "export: gitleaks scans the stage as \".\" from inside it"
    else fail "export: gitleaks scans the stage as \".\" from inside it" "ran in the line's root: $CALL"; fi ;;
  *) fail "export: gitleaks scans the stage as \".\" from inside it" "call: ${CALL:-none}" ;;
esac

echo
if [ "$FAILS" -gt 0 ]; then echo "$FAILS failed"; exit 1; fi
echo "all passed"
