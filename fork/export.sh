#!/usr/bin/env bash
# Writes this line's current tree into a checkout of the team's copy, appvillis-com/hyperframes-agent, as one commit
# on top of the copy's main (fork/org/README.md says what the copy is and what an export leaves out).
#
#   fork/export.sh <copy-checkout>          write and commit; push nothing
#   fork/export.sh <copy-checkout> --push   also push the copy's main (fast-forward only)
#
# The copy carries no upstream history (upstream's history names a person's address) and none of this line's
# maintenance notes; fork/org/ supplies its README, HANDOFF, NOTICE and the headers of CLAUDE.md, AGENTS.md and
# README.md, which go on top of upstream's own text at the base tag.
set -euo pipefail

COPY_REPO="appvillis-com/hyperframes-agent"
usage() { echo "usage: fork/export.sh <copy-checkout> [--push]" >&2; exit 2; }
[ $# -ge 1 ] || usage
DEST="$(cd "$1" && pwd)"; shift
PUSH=0
for arg in "$@"; do case "$arg" in --push) PUSH=1 ;; *) usage ;; esac; done

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || { echo "export from main" >&2; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "the tree has uncommitted changes" >&2; exit 1; }
case "$(git -C "$DEST" remote get-url origin 2>/dev/null)" in
  *"$COPY_REPO"*) ;;
  *) echo "$DEST is not a checkout of $COPY_REPO" >&2; exit 1 ;;
esac
[ -z "$(git -C "$DEST" status --porcelain --untracked-files=no)" ] || { echo "the copy has uncommitted changes" >&2; exit 1; }

BASE="$(git tag --merged HEAD --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | awk '!/-/' | head -n1)"
[ -n "$BASE" ] || { echo "no upstream release tag is merged into HEAD" >&2; exit 1; }
TODAY="$(date -u +%Y-%m-%d)"
log() { printf '[fork-export] %s\n' "$*" >&2; }
log "line at $BASE, commit $(git rev-parse --short HEAD), into $DEST"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/hf-fork-export.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
git archive HEAD | tar -x -C "$STAGE"

# What the copy does not carry: every file an LFS rule covers (pointers without their objects, and regression
# fixtures upstream keeps as plain blobs under the same rules), upstream's workflows, this line's notes.
git ls-files | git check-attr --stdin filter | awk -F': filter: ' '$2 == "lfs" { print $1 }' \
  | while IFS= read -r f; do rm -f "$STAGE/$f"; done
rm -rf "$STAGE/.github/workflows" "$STAGE/fork/upstream-prs.md" "$STAGE/fork/signed-branch.py" "$STAGE/fork/export.sh" "$STAGE/fork/status.sh"
# Nor LFS rules: with them, `git add` in the copy would turn a file into a pointer whose object goes to the
# organisation's LFS store.
find "$STAGE" -name .gitattributes -type f -exec sed -i.bak '/filter=lfs/d' {} +
find "$STAGE" -name '.gitattributes.bak' -type f -delete

PATCHES="$(git log --reverse --no-merges --format='- %s' "$BASE..HEAD" -- packages)"
TESTS="$(git diff --name-only "$BASE" HEAD -- 'packages/cli/src/**/*.test.ts' | tr '\n' ' ' | sed 's/ $//')"
for f in CLAUDE.md AGENTS.md; do
  { cat fork/org/header.md; git show "$BASE:$f"; } > "$STAGE/$f"
done
{ cat fork/org/readme-header.md; git show "$BASE:README.md"; } > "$STAGE/README.md"
cp fork/org/NOTICE "$STAGE/NOTICE"
cp fork/org/gitleaks.toml "$STAGE/.gitleaks.toml"
cp fork/org/README.md "$STAGE/fork/README.md"
BASE="$BASE" TODAY="$TODAY" PATCHES="$PATCHES" node -e '
  const fs = require("fs");
  const [src, dst] = process.argv.slice(1);
  fs.writeFileSync(dst, fs.readFileSync(src, "utf8").replaceAll("@BASE@", process.env.BASE)
    .replaceAll("@DATE@", process.env.TODAY).replaceAll("@PATCHES@", process.env.PATCHES));
' fork/org/HANDOFF.md "$STAGE/fork/HANDOFF.md"
rm -rf "$STAGE/fork/org"
sed -i.bak -e "s#ssheleg/hyperframes-agent#$COPY_REPO#g" -e 's/sshlg/appvillis/g' "$STAGE/fork/release.sh"
rm -f "$STAGE/fork/release.sh.bak"
{
  echo "# Written by the line's export script; fork/release.sh reads it. The copy has no upstream tags or history."
  printf 'LINE_BASE=%q\n' "$BASE"
  printf 'LINE_TESTS=%q\n' "$TESTS"
  printf 'LINE_PATCHES=%q\n' "$PATCHES"
} > "$STAGE/fork/line.env"

# This line's own name must not travel, anywhere in the tree: a release's version stamp (`+sshlg.<n>` in
# packages/cli/package.json) once reached a commit of the line and would have gone with it.
if grep -rIl -e 'ssheleg' -e 'sshlg' "$STAGE"; then
  echo "the files above still name this line" >&2; exit 1
fi

# Replace the copy's tracked files; ignored ones (node_modules, builds, fork/out) stay.
git -C "$DEST" ls-files -z | (cd "$DEST" && xargs -0 rm -f)
cp -R "$STAGE/." "$DEST/"
git -C "$DEST" add -A
if git -C "$DEST" diff --cached --quiet; then log "the copy already holds this tree"; exit 0; fi
GIT_AUTHOR_NAME="Робот" GIT_AUTHOR_EMAIL="r@e.com" GIT_COMMITTER_NAME="Робот" GIT_COMMITTER_EMAIL="r@e.com" \
  git -C "$DEST" -c commit.gpgsign=false commit -q --no-verify -m "export: HyperFrames $BASE with the line's patches ($TODAY)"
log "committed $(git -C "$DEST" rev-parse --short HEAD) in the copy"
if [ "$PUSH" = 1 ]; then
  git -C "$DEST" push -q origin HEAD:refs/heads/main
  log "pushed $COPY_REPO main"
fi
