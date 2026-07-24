#!/bin/sh
# File/folder create, rename and move for the main-view keys: `a` newfile, `f`
# newfolder, `m` rename (name pre-filled to edit), `M` move (fuzzy-pick the target
# folder). Rename and move both go through the confirmation gate's `move` action.
OP="$1"
DIR="$PWD"
F="$XPLR_FOCUS_PATH"
case "$F" in
  /*) ;;
  *) [ -n "$F" ] && F="$DIR/$F" ;;
esac

X="$HOME/.config/xpdt"
. "$X/tmpflag.sh" # $XPDT_LEFT_EXIT, written by the `M` folder picker's left-exit
GATE="$X/gate.sh"
flush() { python3 -S -c 'import termios, sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' 2>/dev/null; }

# Clear leftover output and re-show the cursor (xplr hides it) so a prompt is typed on
# a clean screen with a visible caret.
printf '\033[2J\033[H\033[?25h' > /dev/tty 2>/dev/null
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
  rename)
    # Rename the focused item: prompt pre-filled with its current name (edit it, no
    # retyping). An edited name with no slash stays in this directory; a path moves it.
    { [ -z "$F" ] || [ ! -e "$F" ]; } && { printf 'Nothing focused to rename.\n'; sleep 0.6; exit 0; }
    SRC=$(basename "$F")
    printf 'Renaming: %s\n' "$SRC"
    flush
    TMP=$(mktemp)
    trap 'rm -f "$TMP"' EXIT INT TERM
    python3 -S "$X/prompt-prefill.py" "$SRC" "$TMP" 'New name: ' < /dev/tty > /dev/tty 2>&1
    NEW=$(cat "$TMP" 2>/dev/null); rm -f "$TMP"
    [ -z "$NEW" ] && { printf 'Cancelled.\n'; sleep 0.5; exit 0; }
    [ "$NEW" = "$SRC" ] && { printf 'Unchanged.\n'; sleep 0.5; exit 0; }
    case "$NEW" in /*) FINAL="$NEW" ;; *) FINAL="$DIR/$NEW" ;; esac
    [ -d "$FINAL" ] && FINAL="$FINAL/$SRC"
    [ -e "$FINAL" ] && { printf 'Already exists: %s\n' "$FINAL"; sleep 0.7; exit 0; }
    if sh "$GATE" confirm move "Rename $SRC -> $NEW"; then
      mkdir -p "$(dirname "$FINAL")" 2>/dev/null
      mv -- "$F" "$FINAL" && printf 'Renamed to: %s\n' "$NEW" || printf 'Rename failed.\n'
    fi
    ;;
  move)
    # Move the focused item into a folder chosen by fuzzy-filtering the tree from the
    # launch dir - no path typing. Folders are shown relative to that root.
    { [ -z "$F" ] || [ ! -e "$F" ]; } && { printf 'Nothing focused to move.\n'; sleep 0.6; exit 0; }
    SRC=$(basename "$F")
    ROOT="${XPLR_INITIAL_PWD:-$DIR}"
    REL=$(
      cd "$ROOT" 2>/dev/null && find . \
        \( -name .git -o -name node_modules -o -name __pycache__ -o -name .venv -o -name venv \) -prune \
        -o -type d -print 2>/dev/null \
        | LC_ALL=C sort \
        | fzf --reverse --prompt='move to folder > ' \
            --header="$(sh "$X/wrap-header.sh" "move '$SRC' into a folder    [enter] pick    [esc] cancel")" \
            --bind 'enter:accept,right:accept,esc:abort' \
            --bind 'left:execute-silent(: > "$XPDT_LEFT_EXIT")+abort'
    )
    sh "$X/flush-input.sh"
    [ -z "$REL" ] && { printf '\nCancelled.\n'; sleep 0.4; exit 0; }
    REL="${REL#./}"
    if [ "$REL" = "." ] || [ -z "$REL" ]; then DEST="$ROOT"; else DEST="$ROOT/$REL"; fi
    case "$DEST/" in "$F/"*) printf '\nCannot move a folder into itself.\n'; sleep 0.8; exit 0 ;; esac
    FINAL="$DEST/$SRC"
    [ "$FINAL" = "$F" ] && { printf '\nAlready in that folder.\n'; sleep 0.6; exit 0; }
    [ -e "$FINAL" ] && { printf '\nDestination already has %s\n' "$SRC"; sleep 0.8; exit 0; }
    if sh "$GATE" confirm move "Move $SRC -> $DEST/"; then
      mv -- "$F" "$FINAL" && printf 'Moved to: %s/\n' "$DEST" || printf 'Move failed.\n'
    fi
    ;;
esac
sleep 0.6
