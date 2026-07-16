#!/bin/sh
# Last-commit author per file in a directory, for the author column. `git log
# --name-only` has no way to stop once it has seen each file, so without a bound it
# walks the repo's ENTIRE history every time you enter a directory - the main lag on
# a deep repo. -n caps that walk: a file's last author is almost always in recent
# history, and anything older simply shows no author (cheap and bounded either way).
DEPTH=500
dir="$1"
[ -z "$dir" ] && exit 0
if [ -n "$(git -C "$dir" ls-tree -d --name-only HEAD 2>/dev/null)" ]; then
  files=$(git -C "$dir" ls-tree HEAD 2>/dev/null | awk -F'\t' '$1 ~ /blob/ {print $2}')
  [ -z "$files" ] && exit 0
  printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 git -C "$dir" log -n "$DEPTH" --format='@@@%an' --name-only -- 2>/dev/null
else
  git -C "$dir" log -n "$DEPTH" --format='@@@%an' --name-only -- . 2>/dev/null
fi
