#!/bin/sh
ROOT="$1"; GROUP="$2"; STATUS="$3"; FILE="$4"
[ -z "$ROOT" ] || [ -z "$FILE" ] && exit 0
sh "$HOME/.config/xpdt/gate.sh" confirm discard "Discard changes to $FILE?" || exit 0
if [ "$STATUS" = "?" ]; then
  rm -rf -- "$ROOT/$FILE"
elif [ "$GROUP" = staged ]; then
  git -C "$ROOT" restore --staged --worktree -- "$FILE"
else
  git -C "$ROOT" restore -- "$FILE"
fi
