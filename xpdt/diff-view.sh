#!/bin/sh
ROOT="$1"; MODE="$2"; FILE="$3"; HASH="$4"
[ -z "$ROOT" ] || [ -z "$FILE" ] && exit 0
BASE=$(basename "$FILE")
case "$MODE" in
  staged)
    BEFORE=$(git -C "$ROOT" show "HEAD:$FILE" 2>/dev/null)
    AFTER=$(git -C "$ROOT" show ":$FILE" 2>/dev/null)
    DIFF0="git -C \"$ROOT\" diff --cached -U0 -- \"$FILE\"" ;;
  commit)
    BEFORE=$(git -C "$ROOT" show "$HASH^:$FILE" 2>/dev/null)
    AFTER=$(git -C "$ROOT" show "$HASH:$FILE" 2>/dev/null)
    DIFF0="git -C \"$ROOT\" show -U0 \"$HASH\" -- \"$FILE\"" ;;
  *)
    BEFORE=$(git -C "$ROOT" show ":$FILE" 2>/dev/null)
    AFTER=$(cat "$ROOT/$FILE" 2>/dev/null)
    DIFF0="git -C \"$ROOT\" diff -U0 -- \"$FILE\"" ;;
esac
[ -z "$AFTER" ] && [ -z "$BEFORE" ] && exit 0
X="$HOME/.config/xpdt"
COLS=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
[ -z "$COLS" ] && COLS=$(tput cols 2>/dev/null)
[ -z "$COLS" ] && COLS=100
TMPD=$(mktemp -d)
mkdir -p "$TMPD/a" "$TMPD/b"
printf '%s\n' "$AFTER" > "$TMPD/a/$BASE"
printf '%s\n' "$BEFORE" > "$TMPD/b/$BASE"
bat --color=always --style=plain --tabs=4 --wrap=never -- "$TMPD/a/$BASE" > "$TMPD/ab" 2>/dev/null
bat --color=always --style=plain --tabs=4 --wrap=never -- "$TMPD/b/$BASE" > "$TMPD/bb" 2>/dev/null
CHGPOSF=$(mktemp)
RENDERED=$(eval "$DIFF0" 2>/dev/null | W=$((COLS - 4)) CHGPOSFILE="$CHGPOSF" python3 "$X/diff-render.py" "$TMPD/ab" "$TMPD/bb")
FIRST=$(awk '{print $1}' "$CHGPOSF" 2>/dev/null)
POSBIND=""
[ -n "$FIRST" ] && POSBIND="--bind load:pos($FIRST)"
# The bat + diff-render setup above wrote nothing to the screen, so the current view
# stayed put during it; clear leftover output only now, right before fzf paints, so
# there is no blank flash while the viewer is prepared.
printf '\033[2J\033[H' > /dev/tty 2>/dev/null
printf '%s\n' "$RENDERED" | fzf --ansi --no-sort --disabled --reverse --prompt="$BASE > " \
  --scroll-off=9999 \
  $POSBIND \
  --header="$(sh $X/wrap-header.sh '[→] next change    [shift-→] prev change    [←] back')" \
  --bind "right:transform:sh $X/diff-nav.sh next {n} '$CHGPOSF'" \
  --bind "shift-right:transform:sh $X/diff-nav.sh prev {n} '$CHGPOSF'" \
  --bind 'left:abort' \
  --bind 'q:ignore,enter:ignore' || true
rm -rf "$TMPD" "$CHGPOSF"
