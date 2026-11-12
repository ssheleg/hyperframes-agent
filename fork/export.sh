#!/usr/bin/env bash
# Writes this line's current tree into a checkout of an organization's copy as one commit on top of the copy's main
# (fork/org/<org>/README.md says what the copy is and what an export leaves out). Two organizations have one:
#
#   appvillis     appvillis-com/appvillis-hyperframes-agent        (the default, the first copy)
#   passioncode   passioncode-ai/passioncode-hyperframes-agent
#
#   fork/export.sh <copy-checkout> [--org <org>]          write and commit; push nothing
#   fork/export.sh <copy-checkout> [--org <org>] --push   also push the copy's main (fast-forward only)
#
# The copy carries no upstream history (upstream's history names a person's address) and none of this line's
# maintenance notes; fork/org/<org>/ supplies its README, HANDOFF and the headers of CLAUDE.md, AGENTS.md and README.md,
# which go on top of upstream's own text at the base tag, and fork/org/ the NOTICE, the gitleaks rules and the audit's
# allow list every copy shares. An organization's files/ folder is copied over the tree as it is, and its
# gitignore-append is added to the copy's .gitignore. The first export into an empty repository makes its first commit.
#
# Every export is checked before it is committed, and again before it is pushed (the template's order: check, commit
# once, push only after the gate). ORG_TRANSFER_AUDIT names the shared transfer audit and ORG_TRANSFER_MARKERS its
# marker file (both outside this repository); fork/org/audit-allow-literals.txt is its allow list. gitleaks scans the
# exported files with fork/org/gitleaks.toml.
set -euo pipefail

usage() { echo "usage: fork/export.sh <copy-checkout> [--org appvillis|passioncode] [--push]" >&2; exit 2; }
[ $# -ge 1 ] || usage
DEST="$(cd "$1" && pwd)"; shift
PUSH=0; ORG=appvillis
while [ $# -gt 0 ]; do
  case "$1" in
    --push) PUSH=1 ;;
    --org) [ $# -ge 2 ] || usage; ORG="$2"; shift ;;
    *) usage ;;
  esac
  shift
done
# The export's author is a service identity per copy (copy rule S2, board thread 86a85968). The Appvillis copy's exports
# up to 2026-11-05 were authored `Робот <r@e.com>`; they still count as exports, and its history is never rewritten.
case "$ORG" in
  appvillis) COPY_REPO="appvillis-com/appvillis-hyperframes-agent"; LEGACY_EXPORT_EMAIL="r@e.com" ;;
  passioncode) COPY_REPO="passioncode-ai/passioncode-hyperframes-agent"; LEGACY_EXPORT_EMAIL="" ;;
  *) echo "unknown organization: $ORG (appvillis or passioncode)" >&2; exit 2 ;;
esac
LABEL="$ORG"
EXPORT_NAME="${COPY_REPO#*/}"
EXPORT_EMAIL="$EXPORT_NAME@users.noreply.github.com"
LEGACY_EXPORT_EMAIL="${LEGACY_EXPORT_EMAIL:-$EXPORT_EMAIL}"
ORG_DIR="fork/org/$ORG"

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
AUDIT="${ORG_TRANSFER_AUDIT:-}"; MARKERS="${ORG_TRANSFER_MARKERS:-}"
[ -n "$AUDIT" ] && [ -f "$AUDIT" ] || { echo "set ORG_TRANSFER_AUDIT to the shared transfer audit (org-transfer-audit.py)" >&2; exit 2; }
[ -n "$MARKERS" ] && [ -f "$MARKERS" ] || { echo "set ORG_TRANSFER_MARKERS to its marker file" >&2; exit 2; }
command -v gitleaks >/dev/null || { echo "gitleaks is not installed" >&2; exit 2; }
ALLOW=()
while IFS= read -r l; do case "$l" in ''|'#'*) ;; *) ALLOW+=(--allow-literal "$l") ;; esac; done < fork/org/audit-allow-literals.txt
# Prints the verdict line and the counts; returns 0 only on "ready".
audit_copy() {
  local out
  out="$(nice -n 10 python3 "$AUDIT" "$DEST" --marker-file "$MARKERS" "${ALLOW[@]}" "$@" 2>&1)" || true
  printf '%s\n' "$out" | sed -n '1,4p' | sed 's/^/[fork-export]   /' >&2
  printf '%s\n' "$out" | head -n1 | grep -q ': ready$'
}
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || { echo "export from main" >&2; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "the tree has uncommitted changes" >&2; exit 1; }
case "$(git -C "$DEST" remote get-url origin 2>/dev/null)" in
  *"$COPY_REPO"*) ;;
  *) echo "$DEST is not a checkout of $COPY_REPO" >&2; exit 1 ;;
esac
[ -z "$(git -C "$DEST" status --porcelain --untracked-files=no)" ] || { echo "the copy has uncommitted changes" >&2; exit 1; }

# A change made in the copy itself (a commit by anyone but the export's author, or an open pull request) would be
# replaced by this export without a trace. It goes back to the line first (copy strategy S3, board thread b91254c4).
# A repository with no main yet takes its first export as its first commit.
FIRST=0
if git -C "$DEST" ls-remote --exit-code -q origin refs/heads/main >/dev/null; then
  git -C "$DEST" fetch -q origin main
  git -C "$DEST" merge-base --is-ancestor origin/main HEAD \
    || { echo "the copy's main is behind origin/main: update the checkout first" >&2; exit 1; }
elif git -C "$DEST" rev-parse -q --verify HEAD >/dev/null; then
  echo "origin has no main but the checkout has commits: push nothing by hand, start from an empty clone" >&2; exit 1
else
  FIRST=1
fi
if [ "$FIRST" = 0 ]; then
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
fi
OPEN_PRS="$(gh pr list --repo "$COPY_REPO" --state open --json number,title --jq '.[] | "#\(.number) \(.title)"')"
if [ -n "$OPEN_PRS" ]; then
  printf 'the copy has open pull requests; settle them in the line first:\n%s\n' "$OPEN_PRS" >&2; exit 1
fi

BASE="$(git tag --merged HEAD --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | awk '!/-/' | head -n1)"
[ -n "$BASE" ] || { echo "no upstream release tag is merged into HEAD" >&2; exit 1; }
TODAY="$(date -u +%Y-%m-%d)"
log() { printf '[fork-export] %s\n' "$*" >&2; }
log "line at $BASE, commit $(git rev-parse --short HEAD), into $DEST ($ORG)"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/hf-fork-export.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
# With the LFS filter off: every file it covers is removed below, so its objects (the regression videos) are never
# written out. Smudged, they filled the stage until the disk ran out on 2026-11-11.
git -c filter.lfs.smudge= -c filter.lfs.process= -c filter.lfs.required=false archive HEAD | tar -x -C "$STAGE"

# What the copy does not carry: every file an LFS rule covers (pointers without their objects, and regression
# fixtures upstream keeps as plain blobs under the same rules), upstream's workflows, this line's notes.
git ls-files | git check-attr --stdin filter | awk -F': filter: ' '$2 == "lfs" { print $1 }' \
  | while IFS= read -r f; do rm -f "$STAGE/$f"; done
rm -rf "$STAGE/.github/workflows" "$STAGE/fork/upstream-prs.md" "$STAGE/fork/migration.md" "$STAGE/fork/agent-type-plan.md" "$STAGE/fork/test.sh" "$STAGE/fork/HISTORY.md" "$STAGE/fork/signed-branch.py" "$STAGE/fork/export.sh" "$STAGE/fork/status.sh"
# Nor LFS rules: with them, `git add` in the copy would turn a file into a pointer whose object goes to the
# organisation's LFS store.
find "$STAGE" -name .gitattributes -type f -exec sed -i.bak '/filter=lfs/d' {} +
find "$STAGE" -name '.gitattributes.bak' -type f -delete

# The patches the line still carries: a commit whose files all read as in the base again (upstream took it under
# another commit, or a later commit reverted it) changes nothing and is left out (README, "Taking an upstream release",
# step 4). `fork-v0.9.26-sshlg.1`'s notes listed the running-markers sweep that v0.8.193 had carried for a month.
carried_patches() { # carried_patches <base> <head> <git log format> <pathspec...>
  local base="$1" head="$2" fmt="$3" c
  shift 3
  git log --reverse --no-merges --format='%H' "$base..$head" -- "$@" | while read -r c; do
    [ -n "$(git diff-tree --no-commit-id --name-only -r "$c" -- "$@")" ] || continue
    git diff-tree --no-commit-id --name-only -r -z "$c" -- "$@" | xargs -0 git diff --quiet "$base" "$head" -- \
      || git log -1 --format="$fmt" "$c"
  done
}
PATCHES="$(carried_patches "$BASE" HEAD '- %s' packages)"
TESTS="$(git diff --name-only "$BASE" HEAD -- 'packages/cli/src/**/*.test.ts' | tr '\n' ' ' | sed 's/ $//')"
{ cat "$ORG_DIR/header.md"; echo; git show "$BASE:AGENTS.md"; } > "$STAGE/AGENTS.md"
CLAUDE_HEADER="$ORG_DIR/claude-header.md"; [ -f "$CLAUDE_HEADER" ] || CLAUDE_HEADER="$ORG_DIR/header.md"
{ cat "$CLAUDE_HEADER"; echo; git show "$BASE:CLAUDE.md"; } > "$STAGE/CLAUDE.md"
{ cat "$ORG_DIR/readme-header.md"; echo; git show "$BASE:README.md"; } > "$STAGE/README.md"
cp fork/org/NOTICE "$STAGE/NOTICE"
cp fork/org/gitleaks.toml "$STAGE/.gitleaks.toml"
cp "$ORG_DIR/README.md" "$STAGE/fork/README.md"
if [ -d "$ORG_DIR/files" ]; then cp -R "$ORG_DIR/files/." "$STAGE/"; fi
if [ -f "$ORG_DIR/gitignore-append" ]; then cat "$ORG_DIR/gitignore-append" >> "$STAGE/.gitignore"; fi
BASE="$BASE" TODAY="$TODAY" PATCHES="$PATCHES" node -e '
  const fs = require("fs");
  const [src, dst] = process.argv.slice(1);
  fs.writeFileSync(dst, fs.readFileSync(src, "utf8").replaceAll("@BASE@", process.env.BASE)
    .replaceAll("@DATE@", process.env.TODAY).replaceAll("@PATCHES@", process.env.PATCHES));
' "$ORG_DIR/HANDOFF.md" "$STAGE/fork/HANDOFF.md"
rm -rf "$STAGE/fork/org"
sed -i.bak -e "s#ssheleg/hyperframes-agent#$COPY_REPO#g" -e "s/sshlg/$LABEL/g" "$STAGE/fork/release.sh"
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

# An empty repository gets a root commit first, by the export's author and empty, so the transfer audit has a HEAD to
# read (it runs `git rev-parse HEAD`) and the first export is checked like every other one.
if [ "$FIRST" = 1 ]; then
  GIT_AUTHOR_NAME="$EXPORT_NAME" GIT_AUTHOR_EMAIL="$EXPORT_EMAIL" GIT_COMMITTER_NAME="$EXPORT_NAME" GIT_COMMITTER_EMAIL="$EXPORT_EMAIL" \
    git -C "$DEST" -c commit.gpgsign=false commit -q --no-verify --allow-empty -m "export: start the copy"
fi
# Replace the copy's tracked files; ignored ones (node_modules, builds, fork/out) stay.
git -C "$DEST" ls-files -z | (cd "$DEST" && xargs -0 rm -f)
cp -R "$STAGE/." "$DEST/"
git -C "$DEST" add -A
# Upstream tracks some files its own .gitignore names (136 on v0.9.38: docs/contracts/, producer test compositions,
# the generated font data). `add -A` leaves them out, so they are added by name: exactly the line's tracked ignored
# files the stage holds, never the copy's own ignored build output.
git ls-files -z -ci --exclude-standard | (cd "$STAGE" && xargs -0 -I{} sh -c 'test -f "$1" && printf "%s\0" "$1"' _ {}) \
  | xargs -0 -r git -C "$DEST" add -f --
if git -C "$DEST" diff --cached --quiet; then log "the copy already holds this tree"; exit 0; fi
# Before the commit: the exported tree (the audit reads the files the index lists) and a secret scan of the same files.
# A refusal puts the copy back on its own HEAD: nothing was committed, its tree was clean before this run.
refuse_tree() {
  # A refused first export leaves the clone as empty as it was: no root commit, no file (-x: upstream tracks files its
  # own .gitignore names, and those are ignored here).
  if [ "$FIRST" = 1 ]; then
    git -C "$DEST" update-ref -d HEAD; git -C "$DEST" read-tree --empty; git -C "$DEST" clean -fdxq
  else git -C "$DEST" reset -q --hard HEAD; fi
  echo "$1; the copy is back on its HEAD, nothing committed" >&2; exit 1
}
log "check the exported tree"
audit_copy --no-history || refuse_tree "the transfer audit of the exported tree is not ready"
# From inside the stage: gitleaks reports the paths it was given, and the allow list's paths are relative to the root.
# Niced like the audit: a scan of the whole tree took 365% CPU on a shared machine on 2026-11-08 (board thread 52228175).
(cd "$STAGE" && nice -n 10 gitleaks dir . --config "$ROOT/fork/org/gitleaks.toml" --no-banner --redact --log-level error) >&2 \
  || refuse_tree "gitleaks found a secret in the exported files"
GIT_AUTHOR_NAME="$EXPORT_NAME" GIT_AUTHOR_EMAIL="$EXPORT_EMAIL" GIT_COMMITTER_NAME="$EXPORT_NAME" GIT_COMMITTER_EMAIL="$EXPORT_EMAIL" \
  git -C "$DEST" -c commit.gpgsign=false commit -q --no-verify -m "export: HyperFrames $BASE with the line's patches ($TODAY)" \
    -m "Source-Revision: line@$(git rev-parse --short=12 HEAD)"
log "committed $(git -C "$DEST" rev-parse --short HEAD) in the copy"
if [ "$PUSH" = 1 ]; then
  # Before the push: the whole copy, history included (its gitleaks pass covers the new commit).
  log "check the copy with its history"
  audit_copy || { echo "the transfer audit of the copy is not ready: not pushed (the commit stays local)" >&2; exit 1; }
  git -C "$DEST" push -q origin HEAD:refs/heads/main
  log "pushed $COPY_REPO main"
fi
