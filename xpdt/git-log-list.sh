#!/bin/sh
# Commit list for the `;` history browser. Optional $2 = a branch/ref to view
# (empty = the current HEAD).
ROOT="$1"; REF="$2"
if [ -n "$REF" ]; then
  git -C "$ROOT" log "$REF" --format='%h  %s  %an' -n 500 2>/dev/null
else
  git -C "$ROOT" log --format='%h  %s  %an' -n 500 2>/dev/null
fi
