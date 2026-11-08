#!/usr/bin/env bash
# Builds, checks and (with --publish) releases one package of HyperFrames Agent (fork/README.md):
# the `hyperframes` CLI as a tarball attached to a GitHub Release. Never publishes to npm.
#
#   fork/release.sh <n>              build + check, leave the tarball in fork/out/
#   fork/release.sh <n> --publish    also tag, push the branch and the tag, create the release
#   fork/release.sh <n> --skip-deps  reuse the built workspace packages (the CLI is always rebuilt)
#   fork/release.sh <n> --publish --prebuilt <tgz>
#                                    publish a tarball another machine built from this same commit
#                                    (fork/remote-build.sh): no build, no tests, the smoke install still runs
#
# Names (see fork/README.md):
#   CLI version  <base>+sshlg.<n>        build metadata: semver compares it equal to <base>, so
#                                        registry minCliVersion gates and update checks behave as
#                                        on <base>, while `hyperframes --version` names the line
#   tag          fork-v<base>-sshlg.<n>  "fork-" because upstream's publish workflow fires on v*-*
#   asset        hyperframes-<base>-sshlg.<n>.tgz (no "+" in a URL)
set -euo pipefail

usage() { echo "usage: fork/release.sh <n> [--publish] [--skip-deps] [--prebuilt <tgz>]" >&2; exit 2; }
[ $# -ge 1 ] || usage
N="$1"; shift
[[ "$N" =~ ^[1-9][0-9]*$ ]] || { echo "release number must be a positive integer, got: $N" >&2; exit 2; }
PUBLISH=0; DEPS=1; PREBUILT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --publish) PUBLISH=1 ;;
    --skip-deps) DEPS=0 ;;
    --prebuilt) [ $# -ge 2 ] || usage; PREBUILT="$2"; shift ;;
    *) usage ;;
  esac
  shift
done
if [ -n "$PREBUILT" ]; then
  [ -f "$PREBUILT" ] || { echo "no tarball at $PREBUILT" >&2; exit 2; }
  PREBUILT="$(cd "$(dirname "$PREBUILT")" && pwd)/$(basename "$PREBUILT")"
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
# An exported copy of the line (fork/export.sh) carries no upstream history: its fork/line.env names the base,
# the test files of the patches and the patches themselves, which this repository finds in Git.
LINE_BASE=""; LINE_TESTS=""; LINE_PATCHES=""
# shellcheck source=/dev/null
[ ! -f fork/line.env ] || . fork/line.env
REPO="${FORK_REPO:-ssheleg/hyperframes-agent}"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "main" ] || { echo "release from main, not $BRANCH" >&2; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "the tree has uncommitted changes" >&2; exit 1; }

# The newest upstream release merged into HEAD. Not `git describe`: through merges it picks the tag fewest
# commits away, which after `merge v0.8.209` was v0.8.206.
BASE="${LINE_BASE:-$(git tag --merged HEAD --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | awk '!/-/' | head -n1)}"
[ -n "$BASE" ] || { echo "no upstream release tag is merged into HEAD" >&2; exit 1; }
COMMIT="$(git rev-parse HEAD)"
VERSION="${BASE#v}+sshlg.${N}"
LABEL="${BASE#v}-sshlg.${N}"
TAG="fork-v${LABEL}"
OUT="$ROOT/fork/out"
TARBALL="hyperframes-${LABEL}.tgz"
log() { printf '[fork-release] %s\n' "$*" >&2; }

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || [ -n "$(git ls-remote --tags origin "refs/tags/$TAG")" ]; then
  echo "tag $TAG already exists; use the next number" >&2; exit 1
fi
log "base $BASE, commit ${COMMIT:0:12}, CLI version $VERSION, tag $TAG"
# fork/test.sh runs this script on throwaway repositories: it sets FORK_TEST_RUNNING so that run does not recurse.
# An exported copy carries no fork/test.sh (it is the line's own tooling): there the step is skipped.
if [ -z "${FORK_TEST_RUNNING:-}" ] && [ -x fork/test.sh ]; then
  log "tests of the line's own scripts"
  TEST_OUT="$(fork/test.sh 2>&1)" || { printf '%s\n' "$TEST_OUT" | grep -v '^ok' >&2; echo "fork/test.sh failed" >&2; exit 1; }
fi

TMPS=(); PKG_SAVED=""
# The version stamp goes back from a saved copy, not `git checkout`: a checkout that met a busy index failed silently
# on 2026-11-02, and the stamp reached a commit (7385d1f55, reverted in the next one).
cleanup() {
  if [ -n "$PKG_SAVED" ]; then
    cp "$PKG_SAVED" packages/cli/package.json
    git diff --quiet -- packages/cli/package.json \
      || echo "packages/cli/package.json still differs from HEAD: restore it before committing" >&2
  fi
  [ ${#TMPS[@]} -eq 0 ] || rm -rf "${TMPS[@]}"
}
trap cleanup EXIT
# Sets the variable named by $2 rather than printing: a $(tmpdir ...) would run in a subshell, its TMPS+= would
# never reach cleanup, and every run would leave its directories behind.
tmpdir() { local d; d="$(mktemp -d "${TMPDIR:-/tmp}/hf-fork-$1.XXXXXX")"; TMPS+=("$d"); printf -v "$2" '%s' "$d"; }

if [ -n "$PREBUILT" ]; then
  # Built elsewhere from this commit (fork/remote-build.sh): check that it is this release before trusting it.
  [ "$(basename "$PREBUILT")" = "$TARBALL" ] || { echo "the prebuilt tarball is $(basename "$PREBUILT"), this release is $TARBALL" >&2; exit 1; }
  [ -f "$PREBUILT.sha256" ] || { echo "no $PREBUILT.sha256 beside the prebuilt tarball" >&2; exit 1; }
  (cd "$(dirname "$PREBUILT")" && shasum -a 256 -c "$TARBALL.sha256" >/dev/null) \
    || { echo "the prebuilt tarball does not match its .sha256" >&2; exit 1; }
  BUILT="$(tar -xzOf "$PREBUILT" package/package.json | node -e '
    let s=""; process.stdin.on("data",d=>s+=d).on("end",()=>{const p=JSON.parse(s); console.log(p.version+" "+((p.hyperframesFork||{}).commit||""))})')"
  [ "$BUILT" = "$VERSION $COMMIT" ] || { echo "the prebuilt tarball is '$BUILT', this release is '$VERSION $COMMIT'" >&2; exit 1; }
  mkdir -p "$OUT"
  if [ "$PREBUILT" != "$OUT/$TARBALL" ]; then cp "$PREBUILT" "$PREBUILT.sha256" "$OUT/"; fi
  log "prebuilt $TARBALL checked: version $VERSION, commit ${COMMIT:0:12}"
else
  if [ "$DEPS" = 1 ]; then
    log "build the workspace packages the CLI bundles"
    bun install --frozen-lockfile
    bun run --filter '@hyperframes/{parsers,lint,studio-server}' build
    bun run --filter @hyperframes/core build
    bun run --filter '@hyperframes/{engine,producer,player,studio,shader-transitions,aws-lambda,gcp-cloud-run,sdk,inspector}' build
  fi

  log "build the CLI as $VERSION"
  # tsup bakes package.json's version into dist as __CLI_VERSION__; the stamp is reverted on exit.
  tmpdir pkg PKG_DIR; cp packages/cli/package.json "$PKG_DIR/package.json"; PKG_SAVED="$PKG_DIR/package.json"
  VERSION="$VERSION" node -e '
    const fs = require("fs");
    const p = "packages/cli/package.json";
    const pkg = JSON.parse(fs.readFileSync(p, "utf8"));
    pkg.version = process.env.VERSION;
    fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n");
  '
  bun run --filter @hyperframes/cli build
  grep -rqF "\"$VERSION\"" packages/cli/dist || { echo "packages/cli/dist does not carry $VERSION" >&2; exit 1; }

  # The watcher tests run on the real file system, and FSEvents delivers nothing for 15 s while fseventsd is busy
  # (fork/HANDOFF.md, "Watcher tests under load"). Its own CPU is the signal, not the load average: wait for it.
  # One reading under the limit is not enough: on 2026-11-05 the tests started on one, fseventsd went back to 100%
  # within seconds and three watcher tests heard nothing. So it takes FSEVENTSD_CALM_SAMPLES readings in a row, 10 s apart.
  wait_for_fseventsd() {
    [ "$(uname -s)" = Darwin ] || return 0
    local limit="${FSEVENTSD_MAX_CPU:-60}" calm_needed="${FSEVENTSD_CALM_SAMPLES:-3}" calm=0
    local deadline=$((SECONDS + ${FSEVENTSD_WAIT_SECONDS:-1800})) cpu
    while :; do
      cpu="$(ps -Ao pcpu=,comm= | awk '$2 ~ /fseventsd$/ { s += $1 } END { printf "%d", s }')"
      if [ "$cpu" -lt "$limit" ]; then
        calm=$((calm + 1))
        [ "$calm" -ge "$calm_needed" ] && return 0
      else
        calm=0
      fi
      [ "$SECONDS" -lt "$deadline" ] || { echo "fseventsd still at ${cpu}% CPU (limit ${limit}%, ${calm} of ${calm_needed} calm readings); the watcher tests would fail" >&2; return 1; }
      if [ "$calm" -gt 0 ]; then sleep 10; else
        log "fseventsd at ${cpu}% CPU, waiting for it to stay under ${limit}% for ${calm_needed} readings"
        sleep 30
      fi
    done
  }

  log "tests of the fork's patches"
  PATCHED_TESTS="${LINE_TESTS:-$(git diff --name-only "$BASE" HEAD -- 'packages/cli/src/**/*.test.ts')}"
  if [ -n "$PATCHED_TESTS" ]; then
    case "$PATCHED_TESTS" in *fileWatcher*) wait_for_fseventsd ;; esac
    # shellcheck disable=SC2086
    (cd packages/cli && npx vitest run ${PATCHED_TESTS//packages\/cli\//})
  fi

  log "pack"
  tmpdir pack STAGE
  cp -R packages/cli/bin packages/cli/dist packages/cli/package.json "$STAGE/"
  for f in README.md LICENSE; do
    if [ -f "packages/cli/$f" ]; then cp "packages/cli/$f" "$STAGE/"; elif [ -f "$f" ]; then cp "$f" "$STAGE/"; fi
  done
  STAGE="$STAGE" BASE="$BASE" COMMIT="$COMMIT" REPO="$REPO" LABEL="$LABEL" node -e '
    const fs = require("fs");
    const p = process.env.STAGE + "/package.json";
    const pkg = JSON.parse(fs.readFileSync(p, "utf8"));
    pkg.name = "hyperframes"; // the name upstream publishes the CLI under
    pkg.repository = { type: "git", url: "https://github.com/" + process.env.REPO, directory: "packages/cli" };
    pkg.hyperframesFork = { repository: process.env.REPO, base: process.env.BASE, release: process.env.LABEL, commit: process.env.COMMIT };
    fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n");
  '
  mkdir -p "$OUT"
  rm -f "$OUT/$TARBALL" "$OUT/$TARBALL.sha256"
  PACKED="$(cd "$STAGE" && npm pack --silent --json --pack-destination "$OUT" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s)[0].filename))')"
  [ -f "$OUT/$PACKED" ] || { echo "npm pack did not produce $PACKED" >&2; exit 1; }
  [ "$PACKED" = "$TARBALL" ] || mv "$OUT/$PACKED" "$OUT/$TARBALL"
  (cd "$OUT" && shasum -a 256 "$TARBALL" > "$TARBALL.sha256")

fi

log "smoke: install the tarball into an empty project and run it"
tmpdir smoke SMOKE
# Quiet on success, its own output on failure: a silent `npm install` that exits 1 says nothing about why.
if ! (cd "$SMOKE" && npm init -y >/dev/null && PUPPETEER_SKIP_DOWNLOAD=1 npm install --no-audit --no-fund --loglevel=warn "$OUT/$TARBALL") > "$SMOKE/npm-install.log" 2>&1; then
  tail -n 40 "$SMOKE/npm-install.log" >&2; echo "smoke: npm install of the tarball failed" >&2; exit 1
fi
mkdir -p "$SMOKE/userhome/.hyperframes/running"
DEAD=99999999
: > "$SMOKE/userhome/.hyperframes/running/$DEAD"
GOT="$(cd "$SMOKE" && HOME="$SMOKE/userhome" HYPERFRAMES_NO_UPDATE_CHECK=1 HYPERFRAMES_NO_TELEMETRY=1 ./node_modules/.bin/hyperframes --version)"
case "$GOT" in *"$VERSION"*) ;; *) echo "smoke: --version printed '$GOT', expected $VERSION" >&2; exit 1 ;; esac
# --version exits before the CLI registers itself; --help goes through the start that sweeps markers.
(cd "$SMOKE" && HOME="$SMOKE/userhome" HYPERFRAMES_NO_UPDATE_CHECK=1 HYPERFRAMES_NO_TELEMETRY=1 ./node_modules/.bin/hyperframes --help >/dev/null)
[ ! -e "$SMOKE/userhome/.hyperframes/running/$DEAD" ] || { echo "smoke: the marker of dead pid $DEAD survived a start" >&2; exit 1; }
FORK_FIELD="$(node -p 'JSON.stringify(require(process.argv[1]).hyperframesFork)' "$SMOKE/node_modules/hyperframes/package.json")"
case "$FORK_FIELD" in *"$COMMIT"*) ;; *) echo "smoke: the installed package.json lacks hyperframesFork.commit" >&2; exit 1 ;; esac
log "smoke passed: --version '$GOT', dead marker swept, hyperframesFork $FORK_FIELD"
log "tarball $OUT/$TARBALL ($(cut -d' ' -f1 "$OUT/$TARBALL.sha256"))"

# The catalogue of visual types travels with every release (fork/visual-types.mjs; board request b948516e): built from
# this commit's registry, not from the tarball, so a prebuilt tarball gets the same file.
CATALOG="visual-types-${LABEL}.json"
node fork/visual-types.mjs --base "$BASE" --release "$LABEL" --commit "$COMMIT" > "$OUT/$CATALOG"
node -e 'const c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); if (!c.types.length || !c.totals.items) process.exit(1)' "$OUT/$CATALOG" \
  || { echo "the catalogue of visual types is empty" >&2; exit 1; }
log "catalogue $OUT/$CATALOG"

[ "$PUBLISH" = 1 ] || { log "not published (no --publish)"; exit 0; }

log "publish"
git fetch -q origin main 2>/dev/null || true
if git rev-parse -q --verify refs/remotes/origin/main >/dev/null; then
  git merge-base --is-ancestor origin/main HEAD || { echo "origin/main is not an ancestor of HEAD: the line is never rewritten" >&2; exit 1; }
fi
git tag -a "$TAG" -m "hyperframes $VERSION: upstream $BASE plus the fork's patches" "$COMMIT"
git push -q origin "HEAD:refs/heads/main" "refs/tags/$TAG"
# A workflow file the merged release added is enabled and already starting on this push.
fork/workflows-guard.sh "$REPO"
tmpdir notes NOTES_DIR; NOTES="$NOTES_DIR/notes.md"
{
  echo "The \`hyperframes\` CLI \`$VERSION\`: upstream [$BASE](https://github.com/heygen-com/hyperframes/releases/tag/$BASE) plus the patches below. Not published to npm."
  echo
  echo "Patches on top of $BASE:"
  if [ -n "$LINE_PATCHES" ]; then printf '%s\n' "$LINE_PATCHES"; else
    git log --reverse --no-merges --format='- %s (%h)' "$BASE..$COMMIT" -- . ':!fork'
  fi
  echo
  echo "Install: \`npm install https://github.com/$REPO/releases/download/$TAG/$TARBALL\`"
  echo
  echo "sha256: \`$(cut -d' ' -f1 "$OUT/$TARBALL.sha256")\`"
  echo
  echo "Visual types and style presets: \`$CATALOG\` (what the engine can make, with registry items, libraries and preview frames; fork/README.md)."
} > "$NOTES"
gh release create "$TAG" "$OUT/$TARBALL" "$OUT/$TARBALL.sha256" "$OUT/$CATALOG" --repo "$REPO" --title "hyperframes $VERSION" --notes-file "$NOTES" --verify-tag

log "verify the published asset"
tmpdir check CHECK
# Through gh, not an anonymous download: an exported copy's repository is private.
gh release download "$TAG" --repo "$REPO" --pattern "$TARBALL" --dir "$CHECK"
(cd "$CHECK" && echo "$(cut -d' ' -f1 "$OUT/$TARBALL.sha256")  $TARBALL" | shasum -a 256 -c -)
log "released $TAG: https://github.com/$REPO/releases/tag/$TAG"
