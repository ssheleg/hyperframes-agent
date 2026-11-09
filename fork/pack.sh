#!/usr/bin/env bash
# Packs release archives without what macOS tar adds by itself: AppleDouble twins (`._<name>`, one per file with
# extended attributes) and the packer's account name in every header. Both reached the copy's assets of v0.9.26 (Frame
# Agent's finding, board fe979e90); the account name is the line's, which the organization's copy must not carry.
#
#   fork/pack.sh <dir> <out.tar.gz> <path...>     paths relative to <dir>
set -euo pipefail
[ $# -ge 3 ] || { echo "usage: fork/pack.sh <dir> <out.tar.gz> <path...>" >&2; exit 2; }
DIR="$1"; OUT="$2"; shift 2
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
cd "$DIR"
if tar --version 2>/dev/null | grep -q bsdtar; then
  COPYFILE_DISABLE=1 tar --no-mac-metadata --no-xattrs --uid 0 --gid 0 --uname root --gname root -czf "$OUT" "$@"
else
  tar --owner=0 --group=0 --numeric-owner --no-xattrs -czf "$OUT" "$@"
fi
