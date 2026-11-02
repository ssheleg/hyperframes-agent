#!/usr/bin/env bash
# Keeps every GitHub workflow of a repository of the line disabled (fork/README.md, "Branches"): disables each one that
# is active and cancels its queued and running runs. A workflow file an upstream release adds arrives enabled, and
# its push-triggered runs start the moment the merge is pushed; four ran here unnoticed before 2026-10-30.
#
#   fork/workflows-guard.sh                 the repository of this checkout's origin
#   fork/workflows-guard.sh <owner/name>    another one
#   fork/workflows-guard.sh --check [...]   report only; exits 1 when one is active
#
# fork/release.sh --publish runs it right after its push.
set -euo pipefail

CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi
[ $# -le 1 ] || { echo "usage: fork/workflows-guard.sh [--check] [<owner/name>]" >&2; exit 2; }
# From origin, not `gh repo view`: in a fork gh resolves to the parent, heygen-com/hyperframes.
REPO="${1:-$(git remote get-url origin | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')}"
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "not a GitHub repository: $REPO" >&2; exit 2; }
case "$REPO" in heygen-com/*) echo "refusing $REPO: upstream's workflows are not ours to change" >&2; exit 2 ;; esac
log() { printf '[fork-workflows] %s\n' "$*" >&2; }

ACTIVE="$(gh workflow list --all --repo "$REPO" --json id,name,state,path \
  --jq '.[] | select(.state == "active") | "\(.id)\t\(.path)"')"
if [ -z "$ACTIVE" ]; then log "$REPO: no active workflow"; exit 0; fi

if [ "$CHECK" = 1 ]; then
  printf '%s\n' "$ACTIVE" | while IFS=$'\t' read -r _ path; do log "$REPO: active $path"; done
  exit 1
fi
printf '%s\n' "$ACTIVE" | while IFS=$'\t' read -r id path; do
  gh workflow disable "$id" --repo "$REPO"
  log "$REPO: disabled $path"
  for status in queued in_progress waiting pending requested; do
    gh run list --repo "$REPO" --workflow "$id" --status "$status" --json databaseId --jq '.[].databaseId'
  done | while read -r run; do
    if gh run cancel "$run" --repo "$REPO" >/dev/null; then log "$REPO: cancelled run $run of $path"
    else log "$REPO: run $run of $path could not be cancelled (it may have just ended)"; fi
  done
done
