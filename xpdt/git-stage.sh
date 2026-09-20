#!/bin/sh
# Stage or unstage one changes-browser entry, behind the confirmation gate.
# Args: ROOT GROUP(staged|unstaged) FILE
ROOT="$1"; GROUP="$2"; FILE="$3"
if [ -z "$ROOT" ] || [ -z "$FILE" ]; then exit 0; fi
sh "$HOME/.config/xpdt/gate.sh" confirm stage "Stage / unstage $FILE?" || exit 0
if [ "$GROUP" = staged ]; then
  # A rename is one row for the new path, but both halves have to be unstaged together
  # or the deletion of the original is left staged (see rename-origin.sh).
  ORIG=$(sh "$HOME/.config/xpdt/rename-origin.sh" "$ROOT" "$FILE")
  if [ -n "$ORIG" ]; then
    git -C "$ROOT" restore --staged -- "$FILE" "$ORIG"
  else
    git -C "$ROOT" restore --staged -- "$FILE"
  fi
else
  git -C "$ROOT" add -- "$FILE"
fi
