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
chmod +x "$STUB/gh" "$STUB/ssh"
export GH_STUB_DIR="$WORK/gh"; mkdir -p "$GH_STUB_DIR"
export PATH="$STUB:$PATH"
export FORK_TEST_RUNNING=1

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
  cp "$FORK"/*.sh fork/; cp "$FORK"/org/* fork/org/
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
expect "release: --prebuilt of another release number" 1 "this release is hyperframes-1.2.3-sshlg.2.tgz" \
  -- fork/release.sh 2 --prebuilt "$P/a/hyperframes-1.2.3-sshlg.1.tgz"
mktgz "$P/b" hyperframes-1.2.3-sshlg.2.tgz "1.2.3+sshlg.1" "$COMMIT"
expect "release: --prebuilt renamed to another number" 1 "this release is '1.2.3+sshlg.2" \
  -- fork/release.sh 2 --prebuilt "$P/b/hyperframes-1.2.3-sshlg.2.tgz"
mktgz "$P/c" hyperframes-1.2.3-sshlg.1.tgz "1.2.3+sshlg.1" "0000000000000000000000000000000000000000"
expect "release: --prebuilt of another commit" 1 "this release is" \
  -- fork/release.sh 1 --prebuilt "$P/c/hyperframes-1.2.3-sshlg.1.tgz"
mktgz "$P/d" hyperframes-1.2.3-sshlg.1.tgz "1.2.3+sshlg.1" "$COMMIT"; printf x >> "$P/d/hyperframes-1.2.3-sshlg.1.tgz"
expect "release: --prebuilt with an appended byte" 1 "does not match its .sha256" \
  -- fork/release.sh 1 --prebuilt "$P/d/hyperframes-1.2.3-sshlg.1.tgz"
mktgz "$P/e" hyperframes-1.2.3-sshlg.1.tgz "1.2.3+sshlg.1" "$COMMIT"; rm "$P/e/hyperframes-1.2.3-sshlg.1.tgz.sha256"
expect "release: --prebuilt without its .sha256" 1 ".sha256 beside" \
  -- fork/release.sh 1 --prebuilt "$P/e/hyperframes-1.2.3-sshlg.1.tgz"
gitq tag -a fork-v1.2.3-sshlg.1 -m t
expect "release: an existing tag is refused" 1 "already exists" -- fork/release.sh 1
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

echo
if [ "$FAILS" -gt 0 ]; then echo "$FAILS failed"; exit 1; fi
echo "all passed"
