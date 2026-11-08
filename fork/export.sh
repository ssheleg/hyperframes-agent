#!/usr/bin/env bash
# Writes this line's current tree into a checkout of the team's copy, appvillis-com/appvillis-hyperframes-agent, as one commit
# on top of the copy's main (fork/org/README.md says what the copy is and what an export leaves out).
#
#   fork/export.sh <copy-checkout>          write and commit; push nothing
#   fork/export.sh <copy-checkout> --push   also push the copy's main (fast-forward only)
#
# The copy carries no upstream history (upstream's history names a person's address) and none of this line's
# maintenance notes; fork/org/ supplies its README, HANDOFF, NOTICE and the headers of CLAUDE.md, AGENTS.md and
# README.md, which go on top of upstream's own text at the base tag.
set -euo pipefail

COPY_REPO="appvillis-com/appvillis-hyperframes-agent"
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

# A change made in the copy itself (a commit by anyone but the export's author, or an open pull request) would be
# replaced by this export without a trace. It goes back to the line first (copy strategy S3, board thread b91254c4).
# The export's author is a service identity (copy rule S2, board thread 86a85968). Exports up to 2026-11-05 were
# authored `Робот <r@e.com>`; they still count as exports, and the copy's history is never rewritten.
EXPORT_NAME="appvillis-hyperframes-agent"
EXPORT_EMAIL="appvillis-hyperframes-agent@users.noreply.github.com"
LEGACY_EXPORT_EMAIL="r@e.com"
git -C "$DEST" fetch -q origin main
git -C "$DEST" merge-base --is-ancestor origin/main HEAD \
  || { echo "the copy's main is behind origin/main: update the checkout first" >&2; exit 1; }
# Only commits since the last export count, and one the line names in a `Backports: <copy-sha>` line of its own history
# has been taken. The last export is the newest commit by the export's author.
LAST_EXPORT="$(git -C "$DEST" log -1 --format=%H --author="$EXPORT_EMAIL" --author="$LEGACY_EXPORT_EMAIL" HEAD)"
TAKEN="$(git log --format=%B HEAD | awk '/^Backports:/ { for (i = 2; i <= NF; i++) print $i }')"
FOREIGN="$(git -C "$DEST" log --format='%H %ae %s' "${LAST_EXPORT:+$LAST_EXPORT..}HEAD" \
  | awk -v e="$EXPORT_EMAIL" -v l="$LEGACY_EXPORT_EMAIL" '$2 != e && $2 != l' | while read -r sha rest; do
      printf '%s\n' "$TAKEN" | grep -qE "^${sha:0:7}" || printf '%s %s\n' "${sha:0:12}" "$rest"
    done)"
if [ -n "$FOREIGN" ]; then
  printf 'the copy has commits made since the last export; take each into the line and name it in a\n"Backports: <sha>" line of the commit that does, then export again:\n%s\n' "$FOREIGN" >&2
  exit 1
fi
OPEN_PRS="$(gh pr list --repo "$COPY_REPO" --state open --json number,title --jq '.[] | "#\(.number) \(.title)"')"
if [ -n "$OPEN_PRS" ]; then
  printf 'the copy has open pull requests; settle them in the line first:\n%s\n' "$OPEN_PRS" >&2; exit 1
fi

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
rm -rf "$STAGE/.github/workflows" "$STAGE/fork/upstream-prs.md" "$STAGE/fork/migration.md" "$STAGE/fork/signed-branch.py" "$STAGE/fork/export.sh" "$STAGE/fork/status.sh"
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
GIT_AUTHOR_NAME="$EXPORT_NAME" GIT_AUTHOR_EMAIL="$EXPORT_EMAIL" GIT_COMMITTER_NAME="$EXPORT_NAME" GIT_COMMITTER_EMAIL="$EXPORT_EMAIL" \
  git -C "$DEST" -c commit.gpgsign=false commit -q --no-verify -m "export: HyperFrames $BASE with the line's patches ($TODAY)" \
    -m "Source-Revision: line@$(git rev-parse --short=12 HEAD)"
log "committed $(git -C "$DEST" rev-parse --short HEAD) in the copy"
if [ "$PUSH" = 1 ]; then
  git -C "$DEST" push -q origin HEAD:refs/heads/main
  log "pushed $COPY_REPO main"
fi
