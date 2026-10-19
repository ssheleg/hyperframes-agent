#!/usr/bin/env bash
# Builds, checks and (with --publish) releases one package of the fork line:
# the `hyperframes` CLI as a tarball attached to a GitHub Release. Never publishes to npm.
#
#   fork/release.sh <n>              build + check, leave the tarball in fork/out/
#   fork/release.sh <n> --publish    also tag, push the branch and the tag, create the release
#   fork/release.sh <n> --skip-deps  reuse the built workspace packages (the CLI is always rebuilt)
#
# Names (see fork/README.md):
#   CLI version  <base>+sshlg.<n>        build metadata: semver compares it equal to <base>, so
#                                        registry minCliVersion gates and update checks behave as
#                                        on <base>, while `hyperframes --version` names the line
#   tag          fork-v<base>-sshlg.<n>  "fork-" because upstream's publish workflow fires on v*-*
#   asset        hyperframes-<base>-sshlg.<n>.tgz (no "+" in a URL)
set -euo pipefail

usage() { echo "usage: fork/release.sh <n> [--publish] [--skip-deps]" >&2; exit 2; }
[ $# -ge 1 ] || usage
N="$1"; shift
[[ "$N" =~ ^[1-9][0-9]*$ ]] || { echo "release number must be a positive integer, got: $N" >&2; exit 2; }
PUBLISH=0; DEPS=1
for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=1 ;;
    --skip-deps) DEPS=0 ;;
    *) usage ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
REPO="${FORK_REPO:-sshlg/heygen-hyperframes-vr}"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "fork/main" ] || { echo "release from fork/main, not $BRANCH" >&2; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "the tree has uncommitted changes" >&2; exit 1; }

BASE="$(git describe --tags --match 'v[0-9]*.[0-9]*.[0-9]*' --exclude '*-*' --abbrev=0)"
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

TMPS=()
cleanup() {
  git checkout -q -- packages/cli/package.json 2>/dev/null || true
  [ ${#TMPS[@]} -eq 0 ] || rm -rf "${TMPS[@]}"
}
trap cleanup EXIT
tmpdir() { local d; d="$(mktemp -d "${TMPDIR:-/tmp}/hf-fork-$1.XXXXXX")"; TMPS+=("$d"); printf '%s' "$d"; }

if [ "$DEPS" = 1 ]; then
  log "build the workspace packages the CLI bundles"
  bun install --frozen-lockfile
  bun run --filter '@hyperframes/{parsers,lint,studio-server}' build
  bun run --filter @hyperframes/core build
  bun run --filter '@hyperframes/{engine,producer,player,studio,shader-transitions,aws-lambda,gcp-cloud-run,sdk,inspector}' build
fi

log "build the CLI as $VERSION"
# tsup bakes package.json's version into dist as __CLI_VERSION__; the stamp is reverted on exit.
VERSION="$VERSION" node -e '
  const fs = require("fs");
  const p = "packages/cli/package.json";
  const pkg = JSON.parse(fs.readFileSync(p, "utf8"));
  pkg.version = process.env.VERSION;
  fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n");
'
bun run --filter @hyperframes/cli build
grep -rqF "\"$VERSION\"" packages/cli/dist || { echo "packages/cli/dist does not carry $VERSION" >&2; exit 1; }

log "tests of the fork's patches"
PATCHED_TESTS=$(git diff --name-only "$BASE" HEAD -- 'packages/cli/src/**/*.test.ts')
if [ -n "$PATCHED_TESTS" ]; then
  # shellcheck disable=SC2086
  (cd packages/cli && npx vitest run ${PATCHED_TESTS//packages\/cli\//})
fi

log "pack"
STAGE="$(tmpdir pack)"
cp -R packages/cli/bin packages/cli/dist packages/cli/package.json "$STAGE/"
for f in README.md LICENSE; do
  if [ -f "packages/cli/$f" ]; then cp "packages/cli/$f" "$STAGE/"; elif [ -f "$f" ]; then cp "$f" "$STAGE/"; fi
done
STAGE="$STAGE" BASE="$BASE" COMMIT="$COMMIT" REPO="$REPO" LABEL="$LABEL" node -e '
  const fs = require("fs");
  const p = process.env.STAGE + "/package.json";
  const pkg = JSON.parse(fs.readFileSync(p, "utf8"));
  pkg.name = "hyperframes"; // the name upstream publishes the CLI under
  pkg.hyperframesFork = { repository: process.env.REPO, base: process.env.BASE, release: process.env.LABEL, commit: process.env.COMMIT };
  fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n");
'
mkdir -p "$OUT"
rm -f "$OUT/$TARBALL" "$OUT/$TARBALL.sha256"
PACKED="$(cd "$STAGE" && npm pack --silent --json --pack-destination "$OUT" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s)[0].filename))')"
[ -f "$OUT/$PACKED" ] || { echo "npm pack did not produce $PACKED" >&2; exit 1; }
[ "$PACKED" = "$TARBALL" ] || mv "$OUT/$PACKED" "$OUT/$TARBALL"
(cd "$OUT" && shasum -a 256 "$TARBALL" > "$TARBALL.sha256")

log "smoke: install the tarball into an empty project and run it"
SMOKE="$(tmpdir smoke)"
(cd "$SMOKE" && npm init -y >/dev/null && PUPPETEER_SKIP_DOWNLOAD=1 npm install --silent --no-audit --no-fund "$OUT/$TARBALL" >/dev/null)
mkdir -p "$SMOKE/home/.hyperframes/running"
DEAD=99999999
: > "$SMOKE/home/.hyperframes/running/$DEAD"
GOT="$(cd "$SMOKE" && HOME="$SMOKE/home" HYPERFRAMES_NO_UPDATE_CHECK=1 HYPERFRAMES_NO_TELEMETRY=1 ./node_modules/.bin/hyperframes --version)"
case "$GOT" in *"$VERSION"*) ;; *) echo "smoke: --version printed '$GOT', expected $VERSION" >&2; exit 1 ;; esac
# --version exits before the CLI registers itself; --help goes through the start that sweeps markers.
(cd "$SMOKE" && HOME="$SMOKE/home" HYPERFRAMES_NO_UPDATE_CHECK=1 HYPERFRAMES_NO_TELEMETRY=1 ./node_modules/.bin/hyperframes --help >/dev/null)
[ ! -e "$SMOKE/home/.hyperframes/running/$DEAD" ] || { echo "smoke: the marker of dead pid $DEAD survived a start" >&2; exit 1; }
FORK_FIELD="$(node -p 'JSON.stringify(require(process.argv[1]).hyperframesFork)' "$SMOKE/node_modules/hyperframes/package.json")"
case "$FORK_FIELD" in *"$COMMIT"*) ;; *) echo "smoke: the installed package.json lacks hyperframesFork.commit" >&2; exit 1 ;; esac
log "smoke passed: --version '$GOT', dead marker swept, hyperframesFork $FORK_FIELD"
log "tarball $OUT/$TARBALL ($(cut -d' ' -f1 "$OUT/$TARBALL.sha256"))"

[ "$PUBLISH" = 1 ] || { log "not published (no --publish)"; exit 0; }

log "publish"
git fetch -q origin fork/main 2>/dev/null || true
if git rev-parse -q --verify refs/remotes/origin/fork/main >/dev/null; then
  git merge-base --is-ancestor origin/fork/main HEAD || { echo "origin/fork/main is not an ancestor of HEAD: the line is never rewritten" >&2; exit 1; }
fi
git tag -a "$TAG" -m "hyperframes $VERSION: upstream $BASE plus the fork's patches" "$COMMIT"
git push -q origin "HEAD:refs/heads/fork/main" "refs/tags/$TAG"
NOTES="$(tmpdir notes)/notes.md"
{
  echo "The \`hyperframes\` CLI \`$VERSION\`: upstream [$BASE](https://github.com/heygen-com/hyperframes/releases/tag/$BASE) plus the patches below. Not published to npm."
  echo
  echo "Patches on top of $BASE:"
  git log --reverse --no-merges --format='- %s (%h)' "$BASE..$COMMIT" -- . ':!fork'
  echo
  echo "Install: \`npm install https://github.com/$REPO/releases/download/$TAG/$TARBALL\`"
  echo
  echo "sha256: \`$(cut -d' ' -f1 "$OUT/$TARBALL.sha256")\`"
} > "$NOTES"
gh release create "$TAG" "$OUT/$TARBALL" "$OUT/$TARBALL.sha256" --repo "$REPO" --title "hyperframes $VERSION" --notes-file "$NOTES" --verify-tag

log "verify the published asset"
CHECK="$(tmpdir check)"
curl -fsSL -o "$CHECK/$TARBALL" "https://github.com/$REPO/releases/download/$TAG/$TARBALL"
(cd "$CHECK" && echo "$(cut -d' ' -f1 "$OUT/$TARBALL.sha256")  $TARBALL" | shasum -a 256 -c -)
log "released $TAG: https://github.com/$REPO/releases/tag/$TAG"
