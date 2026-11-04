#!/usr/bin/env bash
# One reading of the line and the team copy, and the next step of fork/README.md it calls for. Changes nothing but
# fetching upstream's tags.
#
#   fork/status.sh             fetch upstream's tags first
#   fork/status.sh --offline   use the tags already fetched
#
# Exits 0 when nothing waits, 10 when an upstream release or a release of the line or the copy is due, 1 when a
# workflow is active (fork/workflows-guard.sh disables it).
set -euo pipefail

LINE_REPO="ssheleg/hyperframes-agent"
COPY_REPO="appvillis-com/appvillis-hyperframes-agent"
FETCH=1
case "${1:-}" in --offline) FETCH=0 ;; "") ;; *) echo "usage: fork/status.sh [--offline]" >&2; exit 2 ;; esac
cd "$(git rev-parse --show-toplevel)"

stable_tags() { git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname "$@" | awk '!/-/'; }
[ "$FETCH" = 0 ] || git fetch -q upstream --tags
BASE="$(stable_tags --merged main | head -n1)"
NEWEST="$(stable_tags | head -n1)"
newer_than() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" = "$2" ] && [ "$1" != "$2" ]; }
NEWER="$(stable_tags --no-merged main | while read -r t; do if newer_than "$BASE" "$t"; then echo "$t"; fi; done | sort -V | tr '\n' ' ' | sed 's/ $//')"
LINE_TAG="$(gh release list --repo "$LINE_REPO" --limit 1 --json tagName --jq '.[0].tagName')"
COPY_TAG="$(gh release list --repo "$COPY_REPO" --limit 1 --json tagName --jq '.[0].tagName')"
COPY_BASE="$(gh api "repos/$COPY_REPO/contents/fork/line.env" --jq .content | base64 -d | sed -n 's/^LINE_BASE=//p')"

echo "line   $LINE_REPO: main at $BASE ($(git rev-parse --short main)), latest release $LINE_TAG"
echo "copy   $COPY_REPO: tree at $COPY_BASE, latest release $COPY_TAG"
echo "upstream: newest release $NEWEST${NEWER:+; not merged: $NEWER}"

WF=0
for repo in "$LINE_REPO" "$COPY_REPO"; do fork/workflows-guard.sh --check "$repo" || WF=1; done

# The next step, in the order of fork/README.md.
NEXT=""
if [ "$WF" = 1 ]; then
  NEXT="fork/workflows-guard.sh for each repository named above"
elif [ -n "$NEWER" ]; then
  NEXT="take $NEWEST (the newest of $NEWER): fork/README.md, \"Taking an upstream release\""
elif [ "${LINE_TAG#fork-}" = "${LINE_TAG#fork-"$BASE"-}" ]; then
  NEXT="release the line on $BASE: fork/release.sh 1 --publish"
elif [ "$COPY_BASE" != "$BASE" ]; then
  NEXT="refresh the copy: fork/README.md, \"The team copy\""
elif [ "${COPY_TAG#fork-}" = "${COPY_TAG#fork-"$BASE"-}" ]; then
  NEXT="release the copy on $BASE: fork/release.sh 1 --publish in its checkout"
fi
if [ -z "$NEXT" ]; then echo "next: nothing; both lines are on upstream's newest release"; exit 0; fi
echo "next: $NEXT"
[ "$WF" = 1 ] && exit 1
exit 10
