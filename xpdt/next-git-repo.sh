#!/bin/sh
# Print the path of the next sibling git repo to cycle to (or nothing).
# The "workspace" is the parent of the current repo root when you are inside a
# repo, otherwise the given directory. It lists the immediate subdirectories of
# the workspace that are themselves git repos, in sorted order, and returns the
# one after the current repo (wrapping around) - so a single key hops you to the
# top of the next repo. From outside any of them it returns the first.
HERE="${1:-$PWD}"
[ -d "$HERE" ] || HERE=$(dirname "$HERE")
CURREPO=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$CURREPO" ]; then
  W=$(dirname "$CURREPO")
else
  W="$HERE"
fi

REPOS=$(find "$W" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | while IFS= read -r d; do
  [ -e "$d/.git" ] && printf '%s\n' "$d"
done)
[ -z "$REPOS" ] && exit 0

printf '%s\n' "$REPOS" | awk -v cur="$CURREPO" '
  { r[NR] = $0 }
  END {
    n = NR
    if (n == 0) exit
    idx = 0
    for (i = 1; i <= n; i++) if (r[i] == cur) idx = i
    if (idx == 0) print r[1]        # not inside any of them -> first repo
    else print r[(idx % n) + 1]     # next, wrapping around
  }'
