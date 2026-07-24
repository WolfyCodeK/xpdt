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
POS=$(( ${2:-0} + 1 ))
RELOAD=$(printf 'reload-sync(sh %s/gate.sh menu)+pos(%s)' "$X" "$POS")

# Section-header rows carry the key `#h` and are not toggleable - skip the toggle
# but still reload+pos so the cursor stays put when one is (harmlessly) activated.
case "${1:-}" in
  ''|'#'*) : ;;
  __reset__)
    # Reset must run as an fzf `execute` ACTION rather than inline here. This script
    # is a `transform`, so its stdout is parsed by fzf as a list of actions and it is
    # never handed the terminal - printing a confirmation prompt from here would be
    # read as actions and the read would have no tty. `execute` does hand over the
    # terminal, so the 2-digit prompt behaves like every other gated action's.
    printf 'execute(sh %s/gate.sh reset)+%s' "$X" "$RELOAD"
    exit 0
    ;;
  theme:*) sh "$X/gate.sh" settheme "${1#theme:}" ;;
  *) sh "$X/gate.sh" toggle "$1" ;;
esac
printf '%s' "$RELOAD"
