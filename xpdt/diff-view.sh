#!/bin/sh
ROOT="$1"; MODE="$2"; FILE="$3"; HASH="$4"
if [ -z "$ROOT" ] || [ -z "$FILE" ]; then exit 0; fi
BASE=$(basename "$FILE")
X="$HOME/.config/xpdt"

# The zero-context diff, run as a command with arguments rather than built as a string
# and eval'd. The string form executed whatever a path contained: a file named
# `p$(touch X).txt` ran `touch X` the moment you opened its diff, with no keypress.
diff0() {
  case "$MODE" in
    staged) git -C "$ROOT" diff --cached -U0 -- "$FILE" ;;
    commit) git -C "$ROOT" show -U0 "$HASH" -- "$FILE" ;;
    *) git -C "$ROOT" diff -U0 -- "$FILE" ;;
  esac
}

COLS=$({ stty size </dev/tty; } 2>/dev/null | awk '{print $2}')
[ -z "$COLS" ] && COLS=$(tput cols 2>/dev/null)
[ -z "$COLS" ] && COLS=100
TMPD=$(mktemp -d)
CHGPOSF=$(mktemp)
# Clean up on any exit, not just the normal one: a ctrl-c out of the viewer used to
# leave the temp tree behind.
trap 'rm -rf "$TMPD" "$CHGPOSF"' EXIT INT TERM
# The change-position file reaches the nav binds through the environment, not their
# command strings (fzf re-parses each bind with a shell).
XPDT_CHGPOS="$CHGPOSF"
export XPDT_CHGPOS
mkdir -p "$TMPD/a" "$TMPD/b"
# Written straight to disk rather than captured into a variable first: a $(...) round
# trip strips EVERY trailing newline, so a change that only adds blank lines produced
# two identical-looking sides and the viewer rendered no change at all. It also
# mangles NUL bytes, and invents a trailing newline on a file that has none.
case "$MODE" in
  staged)
    git -C "$ROOT" show "HEAD:$FILE" > "$TMPD/b/$BASE" 2>/dev/null
    git -C "$ROOT" show ":$FILE" > "$TMPD/a/$BASE" 2>/dev/null ;;
  commit)
    git -C "$ROOT" show "$HASH^:$FILE" > "$TMPD/b/$BASE" 2>/dev/null
    git -C "$ROOT" show "$HASH:$FILE" > "$TMPD/a/$BASE" 2>/dev/null ;;
  *)
    git -C "$ROOT" show ":$FILE" > "$TMPD/b/$BASE" 2>/dev/null
    cat "$ROOT/$FILE" > "$TMPD/a/$BASE" 2>/dev/null ;;
esac
[ -s "$TMPD/a/$BASE" ] || [ -s "$TMPD/b/$BASE" ] || exit 0
bat --color=always --style=plain --tabs=4 --wrap=never -- "$TMPD/a/$BASE" > "$TMPD/ab" 2>/dev/null
bat --color=always --style=plain --tabs=4 --wrap=never -- "$TMPD/b/$BASE" > "$TMPD/bb" 2>/dev/null
RENDERED=$(diff0 2>/dev/null | W=$((COLS - 4)) CHGPOSFILE="$CHGPOSF" python3 -S "$X/diff-render.py" "$TMPD/ab" "$TMPD/bb")
FIRST=$(awk '{print $1}' "$CHGPOSF" 2>/dev/null)
POSBIND=""
[ -n "$FIRST" ] && POSBIND="--bind load:pos($FIRST)"
# The bat + diff-render setup above wrote nothing to the screen, so the current view
# stayed put during it; clear leftover output only now, right before fzf paints, so
# there is no blank flash while the viewer is prepared.
{ printf '\033[2J\033[H' > /dev/tty; } 2>/dev/null
printf '%s\n' "$RENDERED" | fzf --ansi --no-sort --disabled --reverse --prompt="$BASE > " \
  --scroll-off=9999 \
  $POSBIND \
  --header="$(sh "$X/wrap-header.sh" '[→] next change    [shift-→] prev change    [←] back')" \
  --bind "right:transform:sh \"$X/diff-nav.sh\" next {n} \"\$XPDT_CHGPOS\"" \
  --bind "shift-right:transform:sh \"$X/diff-nav.sh\" prev {n} \"\$XPDT_CHGPOS\"" \
  --bind 'left:abort' \
  --bind 'q:ignore,enter:ignore' || true
