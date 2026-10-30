#!/usr/bin/env bash
# Lists what a consumer that confines the engine must look at between two upstream tags (fork/README.md, "Door audit"):
# new CLI commands and flags, environment variables read in shipped code, new child processes and network calls, packages
# installed at run time, and changed skills. It reports; a person or agent reads each hit and decides.
#
#   fork/door-audit.sh v0.8.181 v0.8.184
#
# Tests, fixtures and test-only perf harnesses are left out: they never ship in the CLI tarball.
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: fork/door-audit.sh <from-tag> <to-tag>" >&2; exit 2; }
FROM="$1"; TO="$2"
cd "$(git rev-parse --show-toplevel)"
for t in "$FROM" "$TO"; do git rev-parse -q --verify "refs/tags/$t" >/dev/null || { echo "no tag $t (git fetch upstream --tags)" >&2; exit 2; }; done

SHIPPED=(packages ':(exclude)**/*.test.ts' ':(exclude)**/*.fixture.ts' ':(exclude)**/tests/**' ':(exclude)**/test/**' ':(exclude)**/*.spec.ts' ':(exclude)**/__goldens__/**')
added() { git diff "$FROM" "$TO" -- "${SHIPPED[@]}" | awk '/^\+\+\+ b\//{f=substr($0,7)} /^\+[^+]/{print f": "substr($0,2)}'; }
section() { printf '\n## %s\n' "$1"; }

echo "# Door audit $FROM..$TO ($(git rev-list --count --no-merges "$FROM..$TO") commits)"

section "CLI commands (new files or registrations under packages/cli/src/commands)"
git diff --name-status "$FROM" "$TO" -- packages/cli/src/commands ':(exclude)**/*.test.ts' ':(exclude)**/__fixtures__/**' | awk '$1=="A"{print "new file: "$2}'
added | grep -E 'packages/cli/src/(cli|commands/index|commands/registry)[^:]*: .*(command|name:)' || true

section "CLI flags (new argument definitions under packages/cli/src/commands)"
# A flag is a citty argument: `name: {` with `type: "..."` on the same line or one of the next two added lines.
git diff "$FROM" "$TO" -- packages/cli/src/commands ':(exclude)**/*.test.ts' ':(exclude)**/__fixtures__/**' | awk '
  /^\+\+\+ b\// { f = substr($0, 7); pending = ""; next }
  !/^\+/ { pending = ""; next }
  match($0, /^\+[ \t]+"?[a-z][a-zA-Z0-9-]*"?: \{/) {
    name = substr($0, RSTART, RLENGTH); sub(/^\+[ \t]+"?/, "", name); sub(/"?: \{$/, "", name)
    if ($0 ~ /type: "/) { print "--" name "  (" f ")"; pending = "" } else { pending = name; left = 2 }
    next
  }
  pending != "" && /type: "/ { print "--" pending "  (" f ")"; pending = ""; next }
  pending != "" && --left == 0 { pending = "" }
' | sort -u

section "Environment variables read in shipped code"
added | grep -oE '^[^:]+: .*(process\.env\.[A-Z][A-Z0-9_]+|env\[["'"'"'][A-Z][A-Z0-9_]+["'"'"']\])' \
  | sed -E 's/^([^:]+): .*(process\.env\.|env\[["'"'"'])([A-Z][A-Z0-9_]+).*/\3  (\1)/' | sort -u || true
# Names kept in a constant and read through process.env[name] elsewhere (const URL_ENV = "HYPERFRAMES_...").
added | grep -E '^[^:]+: .*(env|ENV).*["'"'"'][A-Z][A-Z0-9]*_[A-Z0-9_]+["'"'"']' \
  | sed -E 's/^([^:]+): .*["'"'"']([A-Z][A-Z0-9]*_[A-Z0-9_]+)["'"'"'].*/\2  (\1, named in a constant)/' | sort -u || true

section "Child processes and network calls"
# `fetch(` must start a word (`.fetch(` counts, `startPrefetch(` does not).
added | grep -E '(^|[^.[:alnum:]_])(spawn|spawnSync|execFile|execFileSync|execSync|exec)\(|(^|[^[:alnum:]_])fetch\(' | cut -c1-200 || true
# A detached or unref'd child outlives the command that started it (the warm `check` since v0.8.182 did, unnoticed).
echo
echo "Processes that outlive their command (detached or unref):"
added | grep -E 'detached: *true|\.unref\(\)' | cut -c1-200 || true

section "GitHub workflows added (active on this repository until disabled)"
# A workflow upstream adds arrives enabled here; every inherited one is disabled (fork/README.md).
git diff --name-only --diff-filter=A "$FROM" "$TO" -- .github/workflows || true

section "Packages installed at run time"
added | grep -E 'npm (i|install)|buildNpmCommand|loadOptionalPackage|OPTIONAL_PACKAGES|installAndLoad' | cut -c1-200 || true

section "Skills"
git diff --stat "$FROM" "$TO" -- skills | tail -n +1
echo
echo "Changed skill lines that name a hyperframes command:"
git diff "$FROM" "$TO" -- skills | grep -E '^\+.*(npx )?hyperframes [a-z-]+' | grep -oE 'hyperframes [a-z-]+' | sort | uniq -c || true
