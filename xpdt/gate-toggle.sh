#!/bin/sh
# Toggle a settings-menu row, then emit fzf actions to reload the menu in place
# and keep the cursor on the same row. Used by gate-menu.sh as a `transform` bind:
#   transform:sh gate-toggle.sh {1} {n}
# {1} = the row's (hidden) key; {n} = the 0-based cursor index.
#
# reload-sync (not the async reload) guarantees the list is rebuilt before pos()
# runs - a plain reload is asynchronous, so pos() could fire first and then get
# wiped when the reload lands, jumping the cursor to the top. pos() uses {n}+1
# (fzf's own index, always substituted) rather than $FZF_POS.
X="$HOME/.config/xpdt"
sh "$X/gate.sh" toggle "$1"
printf 'reload-sync(sh %s/gate.sh menu)+pos(%s)' "$X" "$(( ${2:-0} + 1 ))"
