#!/bin/sh
F="$XPLR_FOCUS_PATH"
[ -z "$F" ] && exit 0
case "$F" in /*) ;; *) F="$PWD/$F" ;; esac
[ -d "$F" ] && exit 0
COLS=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
[ -z "$COLS" ] && COLS=$(tput cols 2>/dev/null)
[ -z "$COLS" ] && COLS=100
TMP=$(mktemp); POSF=$(mktemp); PORTF=$(mktemp); MAPF=$(mktemp); MARKF=$(mktemp)
LASTPOSF=$(mktemp); QLENF=$(mktemp)
WATCHER=""
# Clean up on any exit, not just the normal one: a ctrl-c out of the viewer used to
# leave seven temp files and the background watcher behind.
cleanup() {
  [ -n "$WATCHER" ] && kill "$WATCHER" 2>/dev/null
  rm -f "$TMP" "$POSF" "$PORTF" "$MAPF" "$MARKF" "$LASTPOSF" "$QLENF"
}
trap cleanup EXIT INT TERM
# Render into $TMP first (bat + wrap can take a moment on a big file) WITHOUT
# touching the screen, so the current view stays put until the preview is ready
# instead of flashing blank for the whole prep. The screen is cleared only once,
# right before fzf paints (see below).
bat --color=always --style=plain --tabs=4 --wrap=never -- "$F" \
  | W=$((COLS - 4)) HL="$XPLR_PREVIEW_LINE" POSFILE="$POSF" MAPFILE="$MAPF" python3 -S "$HOME/.config/xpdt/wrap-lines.py" > "$TMP"
POSBIND=""
POS=$(cat "$POSF" 2>/dev/null)
[ -n "$POS" ] && POSBIND="--bind load:pos($POS)"
BASE="$(basename "$F")"
RELOAD="bat --color=always --style=plain --tabs=4 --wrap=never -- '$F' | W=$((COLS - 4)) MAPFILE='$MAPF' python3 -S '$HOME/.config/xpdt/wrap-lines.py'"
# Reload the preview when the file changes underneath it. `stat`'s format flag is
# GNU `-c` (Linux, WSL2) or BSD `-f` (macOS) - probe for the working one instead of
# assuming BSD, which on Linux printed filesystem info that never changed, so the
# auto-reload silently did nothing there. No usable stat -> skip the watcher entirely
# rather than spin a pointless loop.
if stat -c '%Y' "$F" >/dev/null 2>&1; then
  MFLAG=-c; MFMT='%Y'
elif stat -f '%m' "$F" >/dev/null 2>&1; then
  MFLAG=-f; MFMT='%m'
else
  MFLAG=; MFMT=
fi
if [ -n "$MFLAG" ]; then
  (
    i=0
    while [ ! -s "$PORTF" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
    PORT=$(cat "$PORTF" 2>/dev/null)
    [ -z "$PORT" ] && exit 0
    last=$(stat "$MFLAG" "$MFMT" "$F" 2>/dev/null)
    while :; do
      sleep 0.5
      cur=$(stat "$MFLAG" "$MFMT" "$F" 2>/dev/null)
      if [ -n "$cur" ] && [ "$cur" != "$last" ]; then
        last="$cur"
        curl -s --max-time 1 -XPOST "localhost:$PORT" -d "reload($RELOAD)" >/dev/null 2>&1
      fi
    done
  ) &
  WATCHER=$!
fi
# Clear leftover output (e.g. a prior confirmation prompt) only now that the preview
# is built, so fzf paints over it in the same instant instead of after a blank gap.
printf '\033[2J\033[H' > /dev/tty 2>/dev/null
fzf --ansi --no-sort --exact --reverse --wrap --listen --prompt="$BASE > " \
    $POSBIND \
    --header="$(sh "$HOME/.config/xpdt/wrap-header.sh" 'type to search    [ctrl-v] select    [ctrl-y] copy    [→/ctrl-e] edit    [←] back')" \
    --bind "start:execute-silent(echo \$FZF_PORT > '$PORTF')" \
    --bind "result:transform:sh '$HOME/.config/xpdt/preview-track.sh' '$LASTPOSF' '$QLENF' {n} {q}" \
    --bind 'left:abort' \
    --bind 'enter:ignore' \
    --bind "ctrl-v:execute-silent(echo {n} > '$MARKF')+change-prompt(select: move to end line, ctrl-y > )" \
    --bind "right:execute(sh '$HOME/.config/xpdt/edit-at.sh' '$MAPF' {n} '$F')+reload($RELOAD)" \
    --bind "ctrl-e:execute(sh '$HOME/.config/xpdt/edit-at.sh' '$MAPF' {n} '$F')+reload($RELOAD)" \
    --bind "ctrl-y:execute-silent[sh '$HOME/.config/xpdt/copy-preview.sh' '$F' '$MAPF' '$MARKF' {n}; ( sleep 2; curl -s --max-time 1 -XPOST localhost:\$FZF_PORT -d 'change-prompt($BASE > )' ) & ]+change-prompt(copied to clipboard > )" \
    < "$TMP" || true
