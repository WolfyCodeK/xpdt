#!/bin/sh
F="$XPLR_FOCUS_PATH"
[ -z "$F" ] && exit 0
[ -e "$F" ] || exit 0
NAME=$(basename "$F")
if [ -d "$F" ]; then TYPE="folder"; else TYPE="file"; fi
CODE=$(python3 -c 'import random; print(random.randint(10, 99))')
printf '\n'
printf 'Delete %s: %s\n' "$TYPE" "$NAME"
printf 'Type %s to confirm (anything else cancels): ' "$CODE"
python3 -c 'import termios, sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' 2>/dev/null
read -r ANS
if [ "$ANS" = "$CODE" ]; then
  osascript -e 'on run {p}' -e 'tell application "Finder" to delete (POSIX file p as alias)' -e 'end run' "$F" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    printf 'Moved to Trash: %s\n' "$NAME"
  else
    printf 'Delete failed (allow Finder control when macOS asks).\n'
  fi
else
  printf 'Cancelled.\n'
fi
sleep 0.6
