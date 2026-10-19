#!/usr/bin/env bash
# Builds, checks and (with --publish) releases one package of the fork line:
# the `hyperframes` CLI as a tarball, versioned <upstream>-sshlg.<n>, attached to
# a GitHub Release tagged fork-v<version>. Never publishes to npm.
#
#   fork/release.sh <n>              build + check, leave the tarball in fork/out/
#   fork/release.sh <n> --publish    also tag, push the branch and the tag, create the release
#   fork/release.sh <n> --skip-build reuse the built dist/ (the checks still run)
#
# The tag starts with "fork-" on purpose: upstream's publish workflow fires on
# tags matching v*-* and would try to publish to npm.
set -euo pipefail

usage() { echo "usage: fork/release.sh <n> [--publish] [--skip-build]" >&2; exit 2; }
[ $# -ge 1 ] || usage
N="$1"; shift
[[ "$N" =~ ^[1-9][0-9]*$ ]] || { echo "release number must be a positive integer, got: $N" >&2; exit 2; }
PUBLISH=0; BUILD=1
for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=1 ;;
    --skip-build) BUILD=0 ;;
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
VERSION="${BASE#v}-sshlg.${N}"
TAG="fork-v${VERSION}"
OUT="$ROOT/fork/out"
TARBALL="hyperframes-${VERSION}.tgz"
log() { printf '[fork-release] %s\n' "$*" >&2; }

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || [ -n "$(git ls-remote --tags origin "refs/tags/$TAG")" ]; then
  echo "tag $TAG already exists; use the next number" >&2; exit 1
fi
log "base $BASE, commit ${COMMIT:0:12}, version $VERSION, tag $TAG"

if [ "$BUILD" = 1 ]; then
  log "build"
  bun install --frozen-lockfile
  bun run --filter '@hyperframes/{parsers,lint,studio-server}' build
  bun run --filter @hyperframes/core build
  bun run --filter '@hyperframes/{engine,producer,player,studio,shader-transitions,aws-lambda,gcp-cloud-run,sdk,inspector}' build
  bun run --filter @hyperframes/cli build
fi
[ -f packages/cli/dist/cli.js ] || { echo "packages/cli/dist/cli.js is missing: build first" >&2; exit 1; }

log "tests of the fork's patches"
PATCHED_TESTS=$(git diff --name-only "$BASE" HEAD -- 'packages/cli/src/**/*.test.ts')
if [ -n "$PATCHED_TESTS" ]; then
  # shellcheck disable=SC2086
  (cd packages/cli && npx vitest run ${PATCHED_TESTS//packages\/cli\//})
fi

log "pack"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/hf-fork-pack.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
cp -R packages/cli/bin packages/cli/dist packages/cli/package.json "$STAGE/"
for f in README.md LICENSE; do
  if [ -f "packages/cli/$f" ]; then cp "packages/cli/$f" "$STAGE/"; elif [ -f "$f" ]; then cp "$f" "$STAGE/"; fi
done
STAGE="$STAGE" VERSION="$VERSION" BASE="$BASE" COMMIT="$COMMIT" REPO="$REPO" node -e '
  const fs = require("fs");
  const p = process.env.STAGE + "/package.json";
  const pkg = JSON.parse(fs.readFileSync(p, "utf8"));
  pkg.name = "hyperframes"; // the name upstream publishes the CLI under
  pkg.version = process.env.VERSION;
  pkg.hyperframesFork = { repository: process.env.REPO, base: process.env.BASE, commit: process.env.COMMIT };
  fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n");
'
mkdir -p "$OUT"
rm -f "$OUT/$TARBALL" "$OUT/$TARBALL.sha256"
(cd "$STAGE" && npm pack --silent --pack-destination "$OUT" >/dev/null)
[ -f "$OUT/$TARBALL" ] || { echo "npm pack did not produce $TARBALL" >&2; exit 1; }
(cd "$OUT" && shasum -a 256 "$TARBALL" > "$TARBALL.sha256")

log "smoke: install the tarball and run it"
SMOKE="$(mktemp -d "${TMPDIR:-/tmp}/hf-fork-smoke.XXXXXX")"
trap 'rm -rf "$STAGE" "$SMOKE"' EXIT
(cd "$SMOKE" && npm init -y >/dev/null && PUPPETEER_SKIP_DOWNLOAD=1 npm install --silent --no-audit --no-fund "$OUT/$TARBALL" >/dev/null)
mkdir -p "$SMOKE/home/.hyperframes/running"
DEAD=99999999
: > "$SMOKE/home/.hyperframes/running/$DEAD"
GOT="$(cd "$SMOKE" && HOME="$SMOKE/home" HYPERFRAMES_NO_UPDATE_CHECK=1 HYPERFRAMES_NO_TELEMETRY=1 ./node_modules/.bin/hyperframes --version)"
case "$GOT" in *"$VERSION"*) ;; *) echo "smoke: --version printed '$GOT', expected $VERSION" >&2; exit 1 ;; esac
[ ! -e "$SMOKE/home/.hyperframes/running/$DEAD" ] || { echo "smoke: the marker of dead pid $DEAD survived a start" >&2; exit 1; }
FORK_FIELD="$(node -p 'JSON.stringify(require(process.argv[1]).hyperframesFork)' "$SMOKE/node_modules/hyperframes/package.json")"
log "smoke passed: --version '$GOT', dead marker swept, hyperframesFork $FORK_FIELD"
log "tarball $OUT/$TARBALL ($(cut -d' ' -f1 "$OUT/$TARBALL.sha256"))"

[ "$PUBLISH" = 1 ] || { log "not published (no --publish)"; exit 0; }

log "publish"
git fetch -q origin fork/main 2>/dev/null || true
if git rev-parse -q --verify origin/fork/main >/dev/null; then
  git merge-base --is-ancestor origin/fork/main HEAD || { echo "origin/fork/main is not an ancestor of HEAD: refusing to rewrite the line" >&2; exit 1; }
fi
git tag -a "$TAG" -m "hyperframes $VERSION: upstream $BASE plus the fork's patches" "$COMMIT"
git push -q origin "HEAD:refs/heads/fork/main" "refs/tags/$TAG"
NOTES="$(mktemp "${TMPDIR:-/tmp}/hf-fork-notes.XXXXXX")"
{
  echo "The \`hyperframes\` CLI $VERSION: upstream [$BASE](https://github.com/heygen-com/hyperframes/releases/tag/$BASE) plus the patches below. Not published to npm."
  echo
  echo "Patches on top of $BASE:"
  git log --reverse --no-merges --format='- %s (%h)' "$BASE..$COMMIT" -- . ':!fork'
  echo
  echo "Install: \`npm install https://github.com/$REPO/releases/download/$TAG/$TARBALL\`"
  echo
  echo "sha256: \`$(cut -d' ' -f1 "$OUT/$TARBALL.sha256")\`"
} > "$NOTES"
gh release create "$TAG" "$OUT/$TARBALL" "$OUT/$TARBALL.sha256" --repo "$REPO" --title "hyperframes $VERSION" --notes-file "$NOTES" --target "$COMMIT"
rm -f "$NOTES"

log "verify the published asset"
CHECK="$(mktemp -d "${TMPDIR:-/tmp}/hf-fork-check.XXXXXX")"
curl -fsSL -o "$CHECK/$TARBALL" "https://github.com/$REPO/releases/download/$TAG/$TARBALL"
(cd "$CHECK" && shasum -a 256 -c <(sed "s#  .*#  $TARBALL#" "$OUT/$TARBALL.sha256"))
rm -rf "$CHECK"
log "released $TAG: https://github.com/$REPO/releases/tag/$TAG"
