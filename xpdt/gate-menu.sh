#!/bin/sh
# The `,` confirmation-gate settings menu: toggle the master switch and which
# actions require the 2-digit code. Lazygit-style (--disabled --no-input), so the
# keys are actions, not filter text. Field 1 of each row is the hidden action key.
X="$HOME/.config/xpdt"
MENU="sh $X/gate.sh menu"
# Toggle the focused row and reload the list in place, staying on that row.
# gate-toggle.sh does the toggle and emits `reload-sync(...)+pos({n}+1)`; the
# sync reload rebuilds the list before pos() runs, so the cursor does not jump to
# the top. (See gate-toggle.sh for why a plain async reload would jump.)
TOGGLE="transform:sh $X/gate-toggle.sh {1} {n}"

eval "$MENU" | fzf --ansi --no-sort --reverse --cycle --disabled --no-input \
  --with-nth=2.. \
  --prompt='settings > ' \
  --header='[enter/space/→] toggle    [←/esc/q] close' \
  --bind "enter:$TOGGLE" \
  --bind "space:$TOGGLE" \
  --bind "right:$TOGGLE" \
  --bind 'left:abort,esc:abort,q:abort' >/dev/null 2>&1 || true
