#!/bin/sh
# The `,` confirmation-gate settings menu: toggle the master switch and which
# actions require the 2-digit code. Lazygit-style (--disabled --no-input), so the
# keys are actions, not filter text. Field 1 of each row is the hidden action key.
X="$HOME/.config/xpdt"
MENU="sh $X/gate.sh menu"
# Toggle the focused row and reload the list in place. A plain reload() resets
# the cursor to the top; wrapping it in a transform lets us capture the current
# position and restore it with pos($FZF_POS) afterwards, so you stay on the row
# you just toggled (the rows never change order or count).
TOGGLE="transform:echo \"execute-silent(sh $X/gate.sh toggle {1})+reload($MENU)+pos(\$FZF_POS)\""

eval "$MENU" | fzf --ansi --no-sort --reverse --cycle --disabled --no-input \
  --with-nth=2.. \
  --prompt='settings > ' \
  --header='[enter/space/→] toggle    [←/esc/q] close' \
  --bind "enter:$TOGGLE" \
  --bind "space:$TOGGLE" \
  --bind "right:$TOGGLE" \
  --bind 'left:abort,esc:abort,q:abort' >/dev/null 2>&1 || true
