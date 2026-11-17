#!/usr/bin/env bash
# How far an organization's copy is behind the line's main, read from the line revision its last export names
# (`Source-Revision: line@<sha12>`, written by fork/export.sh). Changes nothing.
#
#   fork/copy-lag.sh <org> <source-sha|""> [--json] [--now <unix-seconds>]
#
# A commit counts when it is on main's first-parent chain after the source and changes a file that travels to the copy
# (fork/export.sh leaves out this line's notes and maintenance scripts, the workflows and the other organization's
# folder). The lag runs from the first such commit (its commit time): the copy has lacked it since then.
#
#   ok       nothing that travels is missing, or it has been missing for a day or less
#   warn     missing for more than a day (the rule: every copy follows main within a day), or the source is not on main
#   fail     missing for more than three days
#   unknown  no source revision could be read; never reported as ok
#
# Prints one line, or with --json one object of counts only. Exits 0 for ok, 1 for warn, fail or unknown, 2 on misuse.
set -euo pipefail

usage() { echo "usage: fork/copy-lag.sh <org> <source-sha> [--json] [--now <unix-seconds>]" >&2; exit 2; }
[ $# -ge 2 ] || usage
ORG="$1"; SOURCE="$2"; shift 2
JSON=0; NOW="$(date +%s)"
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --now) [ $# -ge 2 ] || usage; NOW="$2"; shift ;;
    *) usage ;;
  esac
  shift
done
case "$ORG" in
  appvillis) OTHER=passioncode ;;
  passioncode) OTHER=appvillis ;;
  *) echo "unknown organization: $ORG (appvillis or passioncode)" >&2; exit 2 ;;
esac
cd "$(git rev-parse --show-toplevel)"
WARN_H="${FORK_COPY_WARN_HOURS:-24}"; FAIL_H="${FORK_COPY_FAIL_HOURS:-72}"

# What fork/export.sh does not carry into a copy, or replaces with the organization's own text.
NOT_TRAVELLING=(
  ':(exclude).github/workflows' ':(exclude)fork/HANDOFF.md' ':(exclude)fork/README.md' ':(exclude)fork/HISTORY.md'
  ':(exclude)fork/upstream-prs.md' ':(exclude)fork/migration.md' ':(exclude)fork/agent-type-plan.md'
  ':(exclude)fork/test.sh' ':(exclude)fork/signed-branch.py' ':(exclude)fork/export.sh' ':(exclude)fork/status.sh'
  ':(exclude)fork/copy-lag.sh' ":(exclude)fork/org/$OTHER" ':(exclude)AGENTS.md' ':(exclude)CLAUDE.md' ':(exclude)README.md'
)

report() { # report <state> <behind> <hours> <why>
  local state="$1" behind="$2" hours="$3" why="$4"
  if [ "$JSON" = 1 ]; then
    printf '{"check":"copies","org":"%s","state":"%s","source":"%s","behind":%s,"lagHours":%s}\n' \
      "$ORG" "$state" "${SOURCE:0:12}" "$behind" "$hours"
  else
    printf 'copies %s: %s, %s\n' "$ORG" "$state" "$why"
  fi
  [ "$state" = ok ] && exit 0
  exit 1
}

[ -n "$SOURCE" ] || report unknown null null "no Source-Revision read from the copy"
FULL="$(git rev-parse -q --verify "$SOURCE^{commit}" 2>/dev/null)" \
  || report unknown null null "line@$SOURCE is not a commit of this line (fetch it, or the copy names another line)"
git merge-base --is-ancestor "$FULL" main || report warn null null "line@${SOURCE:0:12} is not on main"

MISSING="$(git log --first-parent --format='%ct' "$FULL..main" -- . "${NOT_TRAVELLING[@]}")"
BEHIND="$(printf '%s' "$MISSING" | grep -c . || true)"
[ "$BEHIND" -gt 0 ] || report ok 0 0 "line@${SOURCE:0:12}, nothing that travels is missing"
OLDEST="$(printf '%s\n' "$MISSING" | tail -n1)"
HOURS=$(( (NOW - OLDEST) / 3600 ))
WHY="line@${SOURCE:0:12}, $BEHIND commit(s) of main missing, the oldest for ${HOURS} h"
if [ "$HOURS" -gt "$FAIL_H" ]; then report fail "$BEHIND" "$HOURS" "$WHY (over ${FAIL_H} h)"
elif [ "$HOURS" -gt "$WARN_H" ]; then report warn "$BEHIND" "$HOURS" "$WHY (over ${WARN_H} h)"
else report ok "$BEHIND" "$HOURS" "$WHY (export due within ${WARN_H} h)"; fi
