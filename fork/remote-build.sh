#!/usr/bin/env bash
# Builds and checks one release on another machine over SSH, then brings the tarball back here, so that a machine
# short of disk (a release build wants about 8 GB) still publishes. The other machine needs a clone of this
# repository, Bun and Node; it needs no GitHub CLI sign-in, because publishing stays here:
#
#   fork/remote-build.sh <ssh-host> <n> [--skip-deps]
#   fork/release.sh <n> --publish --prebuilt fork/out/<tarball>      what this script prints at the end
#
# FORK_REMOTE_DIR names the clone on the other machine, relative to its home or absolute (required).
# HEAD must be on origin's main already: the other machine builds exactly that commit, which it fetches.
set -euo pipefail

usage() { echo "usage: FORK_REMOTE_DIR=<dir> fork/remote-build.sh <ssh-host> <n> [--skip-deps]" >&2; exit 2; }
[ $# -ge 2 ] || usage
HOST="$1"; N="$2"; shift 2
[[ "$N" =~ ^[1-9][0-9]*$ ]] || { echo "release number must be a positive integer, got: $N" >&2; exit 2; }
EXTRA=""
for arg in "$@"; do
  case "$arg" in
    --skip-deps) EXTRA="--skip-deps" ;;
    *) usage ;;
  esac
done
REMOTE_DIR="${FORK_REMOTE_DIR:-}"
[ -n "$REMOTE_DIR" ] || { echo "set FORK_REMOTE_DIR to the clone on $HOST" >&2; exit 2; }
[[ "$REMOTE_DIR" =~ ^[A-Za-z0-9._/~-]+$ ]] || { echo "FORK_REMOTE_DIR has characters this script will not quote: $REMOTE_DIR" >&2; exit 2; }

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
log() { printf '[fork-remote] %s\n' "$*" >&2; }
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || { echo "release from main" >&2; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "the tree has uncommitted changes" >&2; exit 1; }
COMMIT="$(git rev-parse HEAD)"
git fetch -q origin main
[ "$(git rev-parse origin/main)" = "$COMMIT" ] \
  || { echo "HEAD ${COMMIT:0:12} is not origin/main: push it first (the line is never rewritten, so a fast-forward)" >&2; exit 1; }

log "build ${COMMIT:0:12} on $HOST in $REMOTE_DIR"
# The remote shell is not a login shell: Bun and Homebrew's Node are put on PATH by hand. Its upstream tags (the base
# the release names) come from its own upstream remote, when it has one.
LOG="$(mktemp "${TMPDIR:-/tmp}/hf-fork-remote.XXXXXX")"
trap 'rm -f "$LOG"' EXIT
# shellcheck disable=SC2029  # expanded here on purpose: commit, number and directory are checked above
if ! ssh -o BatchMode=yes "$HOST" "set -euo pipefail
  export PATH=\"\$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH\"
  cd $REMOTE_DIR
  git fetch -q origin main
  if git remote get-url upstream >/dev/null 2>&1; then git fetch -q upstream --tags; fi
  git checkout -q main
  git merge -q --ff-only origin/main
  [ \"\$(git rev-parse HEAD)\" = $COMMIT ] || { echo \"$HOST is at \$(git rev-parse --short=12 HEAD), not ${COMMIT:0:12}\" >&2; exit 1; }
  fork/release.sh $N $EXTRA" 2>&1 | tee "$LOG"; then
  echo "the build on $HOST failed (its output is above)" >&2; exit 1
fi

# release.sh ends with "[fork-release] tarball <path> (<sha256>)": take the path from it rather than rebuilding the
# name here, so the line's own naming (and an exported copy's) stays in one place.
REMOTE_TGZ="$(sed -n 's/^\[fork-release\] tarball \(.*\.tgz\) (.*$/\1/p' "$LOG" | tail -n1)"
[ -n "$REMOTE_TGZ" ] || { echo "the build on $HOST named no tarball" >&2; exit 1; }
TARBALL="$(basename "$REMOTE_TGZ")"
mkdir -p fork/out
rm -f "fork/out/$TARBALL" "fork/out/$TARBALL.sha256"
scp -q -o BatchMode=yes "$HOST:$REMOTE_TGZ" "$HOST:$REMOTE_TGZ.sha256" fork/out/
(cd fork/out && shasum -a 256 -c "$TARBALL.sha256" >/dev/null) || { echo "fork/out/$TARBALL does not match its .sha256" >&2; exit 1; }
log "tarball fork/out/$TARBALL ($(cut -d' ' -f1 "fork/out/$TARBALL.sha256")), built on $HOST from ${COMMIT:0:12}"
log "publish: fork/release.sh $N --publish --prebuilt fork/out/$TARBALL"
