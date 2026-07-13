#!/bin/sh
OP="$1"
DIR="$PWD"
F="$XPLR_FOCUS_PATH"
case "$F" in
  /*) ;;
  *) [ -n "$F" ] && F="$DIR/$F" ;;
esac

GATE="$HOME/.config/xpdt/gate.sh"
flush() { python3 -c 'import termios, sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' 2>/dev/null; }

printf '\n'
case "$OP" in
  newfile)
    printf 'New file name (empty cancels): '
    flush; read -r NAME
    [ -z "$NAME" ] && { printf 'Cancelled.\n'; sleep 0.5; exit 0; }
    T="$DIR/$NAME"
    [ -e "$T" ] && { printf 'Already exists: %s\n' "$NAME"; sleep 0.7; exit 0; }
    if sh "$GATE" confirm create "Create file: $NAME"; then
      ( mkdir -p "$(dirname "$T")" && : > "$T" ) && printf 'Created file: %s\n' "$NAME" || printf 'Create failed.\n'
    fi
    ;;
  newfolder)
    printf 'New folder name (empty cancels): '
    flush; read -r NAME
    [ -z "$NAME" ] && { printf 'Cancelled.\n'; sleep 0.5; exit 0; }
    T="$DIR/$NAME"
    [ -e "$T" ] && { printf 'Already exists: %s\n' "$NAME"; sleep 0.7; exit 0; }
    if sh "$GATE" confirm create "Create folder: $NAME"; then
      mkdir -p "$T" && printf 'Created folder: %s\n' "$NAME" || printf 'Create failed.\n'
    fi
    ;;
  move)
    { [ -z "$F" ] || [ ! -e "$F" ]; } && { printf 'Nothing focused to move.\n'; sleep 0.6; exit 0; }
    SRC=$(basename "$F")
    printf 'Move/rename %s to (path, empty cancels): ' "$SRC"
    flush; read -r DEST
    [ -z "$DEST" ] && { printf 'Cancelled.\n'; sleep 0.5; exit 0; }
    case "$DEST" in /*) ;; *) DEST="$DIR/$DEST" ;; esac
    if [ -d "$DEST" ]; then FINAL="$DEST/$SRC"; else FINAL="$DEST"; fi
    [ -e "$FINAL" ] && { printf 'Destination exists: %s\n' "$FINAL"; sleep 0.7; exit 0; }
    if sh "$GATE" confirm move "Move $SRC -> $FINAL"; then
      mv -- "$F" "$FINAL" && printf 'Moved to: %s\n' "$FINAL" || printf 'Move failed.\n'
    fi
    ;;
esac
sleep 0.6
