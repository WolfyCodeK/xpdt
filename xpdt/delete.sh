#!/bin/sh
F="$XPLR_FOCUS_PATH"
[ -z "$F" ] && exit 0
[ -e "$F" ] || exit 0
NAME=$(basename "$F")
if [ -d "$F" ]; then TYPE="folder"; else TYPE="file"; fi
sh "$HOME/.config/xpdt/gate.sh" confirm delete "Delete $TYPE: $NAME" || exit 0
osascript -e 'on run {p}' -e 'tell application "Finder" to delete (POSIX file p as alias)' -e 'end run' "$F" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  printf 'Moved to Trash: %s\n' "$NAME"
else
  printf 'Delete failed (allow Finder control when macOS asks).\n'
fi
sleep 0.6
