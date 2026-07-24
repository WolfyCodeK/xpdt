#!/bin/sh
# Stage or unstage one changes-browser entry, behind the confirmation gate.
# Args: ROOT GROUP(staged|unstaged) FILE
ROOT="$1"; GROUP="$2"; FILE="$3"
if [ -z "$ROOT" ] || [ -z "$FILE" ]; then exit 0; fi
sh "$HOME/.config/xpdt/gate.sh" confirm stage "Stage / unstage $FILE?" || exit 0
if [ "$GROUP" = staged ]; then
  git -C "$ROOT" restore --staged -- "$FILE"
else
  git -C "$ROOT" add -- "$FILE"
fi
