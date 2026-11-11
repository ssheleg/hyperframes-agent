#!/usr/bin/env bash
# One reading of the line and the organizations' copies, and the next step of fork/README.md it calls for. Changes nothing but
# fetching upstream's tags.
#
#   fork/status.sh             fetch upstream's tags first
#   fork/status.sh --offline   use the tags already fetched
#
# Exits 0 when nothing waits, 10 when an upstream release or a release of the line or a copy is due, 1 when a
# workflow is active (fork/workflows-guard.sh disables it).
set -euo pipefail

LINE_REPO="ssheleg/hyperframes-agent"
# Each copy with its organization, the name fork/export.sh --org takes.
COPIES="appvillis:appvillis-com/appvillis-hyperframes-agent passioncode:passioncode-ai/passioncode-hyperframes-agent"
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
echo "line   $LINE_REPO: main at $BASE ($(git rev-parse --short main)), latest release $LINE_TAG"
COPY_NEXT=""
for entry in $COPIES; do
  org="${entry%%:*}"; repo="${entry#*:}"
  tag="$(gh release list --repo "$repo" --limit 1 --json tagName --jq '.[0].tagName // ""')"
  copy_base="$(gh api "repos/$repo/contents/fork/line.env" --jq .content 2>/dev/null | base64 -d | sed -n 's/^LINE_BASE=//p')"
  echo "copy   $repo: tree at ${copy_base:-nothing}, latest release ${tag:-none}"
  [ -z "$COPY_NEXT" ] || continue
  if [ "$copy_base" != "$BASE" ]; then
    COPY_NEXT="refresh the $org copy: fork/README.md, \"The team copy\" (fork/export.sh --org $org)"
  elif [ -z "$tag" ] || [ "${tag#fork-}" = "${tag#fork-"$BASE"-}" ]; then
    COPY_NEXT="release the $org copy on $BASE: fork/release.sh 1 --publish in its checkout"
  fi
done
echo "upstream: newest release $NEWEST${NEWER:+; not merged: $NEWER}"

WF=0
for repo in "$LINE_REPO" $(for entry in $COPIES; do printf '%s ' "${entry#*:}"; done); do
  fork/workflows-guard.sh --check "$repo" || WF=1
done

# The next step, in the order of fork/README.md.
NEXT=""
if [ "$WF" = 1 ]; then
  NEXT="fork/workflows-guard.sh for each repository named above"
elif [ -n "$NEWER" ]; then
  NEXT="take $NEWEST (the newest of $NEWER): fork/README.md, \"Taking an upstream release\""
elif [ "${LINE_TAG#fork-}" = "${LINE_TAG#fork-"$BASE"-}" ]; then
  NEXT="release the line on $BASE: fork/release.sh 1 --publish"
elif [ -n "$COPY_NEXT" ]; then
  NEXT="$COPY_NEXT"
fi
if [ -z "$NEXT" ]; then echo "next: nothing; the line and every copy are on upstream's newest release"; exit 0; fi
echo "next: $NEXT"
[ "$WF" = 1 ] && exit 1
exit 10
