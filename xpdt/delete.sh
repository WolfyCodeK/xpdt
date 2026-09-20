#!/bin/sh
# The `d` delete, behind the confirmation gate. Prefers the platform's Trash so a
# mistake is recoverable, and only falls back to an unrecoverable delete when no trash
# tool exists - and says which one it did.
#
# It used to call Finder unconditionally, so on Linux and WSL2 `d` silently did nothing
# and then advised the user to "allow Finder control when macOS asks".
F="$XPLR_FOCUS_PATH"
[ -z "$F" ] && exit 0
[ -e "$F" ] || exit 0
NAME=$(basename "$F")
if [ -d "$F" ]; then TYPE="folder"; else TYPE="file"; fi

# Pick the method first so the prompt can say what will actually happen: moving to the
# Trash and deleting outright are not the same promise.
METHOD=""
case "$(uname -s)" in
  Darwin) command -v osascript >/dev/null 2>&1 && METHOD=finder ;;
esac
if [ -z "$METHOD" ]; then
  if command -v trash-put >/dev/null 2>&1; then
    METHOD=trash-put
  elif command -v gio >/dev/null 2>&1; then
    METHOD=gio
  else
    METHOD=rm
  fi
fi

if [ "$METHOD" = rm ]; then
  sh "$HOME/.config/xpdt/gate.sh" confirm delete "Delete $TYPE: $NAME - permanently (no Trash tool found)" || exit 0
else
  sh "$HOME/.config/xpdt/gate.sh" confirm delete "Delete $TYPE: $NAME" || exit 0
fi

OK=1
case "$METHOD" in
  finder)
    osascript -e 'on run {p}' -e 'tell application "Finder" to delete (POSIX file p as alias)' -e 'end run' "$F" >/dev/null 2>&1 && OK=0
    [ $OK -eq 0 ] && WHERE="Trash" || FAILMSG="Delete failed (allow Finder control when macOS asks)."
    ;;
  trash-put)
    trash-put -- "$F" >/dev/null 2>&1 && OK=0
    [ $OK -eq 0 ] && WHERE="Trash" || FAILMSG="Delete failed (trash-put returned an error)."
    ;;
  gio)
    gio trash -- "$F" >/dev/null 2>&1 && OK=0
    [ $OK -eq 0 ] && WHERE="Trash" || FAILMSG="Delete failed (gio trash returned an error)."
    ;;
  rm)
    rm -rf -- "$F" && OK=0
    [ $OK -eq 0 ] && WHERE="deleted permanently" || FAILMSG="Delete failed."
    ;;
esac

if [ $OK -eq 0 ]; then
  if [ "$WHERE" = "Trash" ]; then
    printf 'Moved to Trash: %s\n' "$NAME"
  else
    printf 'Deleted permanently: %s\n' "$NAME"
  fi
else
  printf '%s\n' "$FAILMSG"
fi
sleep 0.6
