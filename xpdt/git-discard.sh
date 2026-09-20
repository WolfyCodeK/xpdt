#!/bin/sh
ROOT="$1"; GROUP="$2"; STATUS="$3"; FILE="$4"
if [ -z "$ROOT" ] || [ -z "$FILE" ]; then exit 0; fi
# A rename is shown as one row for the new path; discarding it has to put the original
# back as well, or the file vanishes from the working tree while HEAD still has it.
ORIG=""
[ "$GROUP" = staged ] && ORIG=$(sh "$HOME/.config/xpdt/rename-origin.sh" "$ROOT" "$FILE")

# Say what will actually happen: an untracked entry is deleted outright (recursively,
# for a directory), and a rename is undone on both sides.
if [ "$STATUS" = "?" ]; then
  MSG="Delete untracked $FILE? This removes it from disk."
elif [ -n "$ORIG" ]; then
  MSG="Undo the rename $ORIG -> $FILE? This restores $ORIG and removes $FILE."
else
  MSG="Discard changes to $FILE?"
fi
sh "$HOME/.config/xpdt/gate.sh" confirm discard "$MSG" || exit 0
if [ "$STATUS" = "?" ]; then
  rm -rf -- "$ROOT/$FILE"
elif [ -n "$ORIG" ]; then
  git -C "$ROOT" restore --staged --worktree -- "$FILE" "$ORIG"
elif [ "$GROUP" = staged ]; then
  git -C "$ROOT" restore --staged --worktree -- "$FILE"
else
  git -C "$ROOT" restore -- "$FILE"
fi
