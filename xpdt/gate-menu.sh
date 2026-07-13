#!/bin/sh
# The `,` confirmation-gate settings menu: toggle the master switch and which
# actions require the 2-digit code. Lazygit-style (--disabled --no-input), so the
# keys are actions, not filter text. Field 1 of each row is the hidden action key.
X="$HOME/.config/xpdt"
MENU="sh $X/gate.sh menu"
TOGGLE="execute-silent(sh $X/gate.sh toggle {1})+reload($MENU)"

eval "$MENU" | fzf --ansi --no-sort --reverse --cycle --disabled --no-input \
  --with-nth=2.. \
  --prompt='confirm-gate > ' \
  --header='[enter/space/→] toggle    [←/esc/q] close' \
  --bind "enter:$TOGGLE" \
  --bind "space:$TOGGLE" \
  --bind "right:$TOGGLE" \
  --bind 'left:abort,esc:abort,q:abort' >/dev/null 2>&1
