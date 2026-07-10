#!/bin/sh
dir="$1"
[ -z "$dir" ] && exit 0
if [ -n "$(git -C "$dir" ls-tree -d --name-only HEAD 2>/dev/null)" ]; then
  files=$(git -C "$dir" ls-tree HEAD 2>/dev/null | awk -F'\t' '$1 ~ /blob/ {print $2}')
  [ -z "$files" ] && exit 0
  printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 git -C "$dir" log --format='@@@%an' --name-only -- 2>/dev/null
else
  git -C "$dir" log --format='@@@%an' --name-only -- . 2>/dev/null
fi
