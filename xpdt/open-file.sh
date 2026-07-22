#!/bin/sh
# Open the focused file in the editor (Neovim). Bound to `right` on a file in the
# main view and to `right` on a hit in the / and \ search (the \ search passes the
# matched line in XPLR_PREVIEW_LINE so the file opens there). Neovim opens in normal
# mode, so it doubles as a reader you can edit in. After the editor exits, refresh
# the git columns/panels in case the file changed.
#
# NVIM_NOTTYFAST=1: skip Neovim's startup terminal-background-colour query. Over a
# remote/SSH terminal that query often gets no reply within Neovim's 100ms wait, which
# prints "E1568: Terminal did not respond to DSR request..." and slows startup. The
# query only auto-detects light/dark + truecolor, and xpdt's Neovim config already
# forces termguicolors and a dark theme, so the result is never needed. (Must be an env
# var set before Neovim starts - `:set nottyfast` in config is too late.)
export NVIM_NOTTYFAST=1
F="$XPLR_FOCUS_PATH"
[ -z "$F" ] && exit 0
case "$F" in /*) ;; *) F="$PWD/$F" ;; esac
[ -d "$F" ] && exit 0
# Optional line to jump to, set by the \ in-files search so a hit opens on its line.
LINE="$XPLR_PREVIEW_LINE"
case "$LINE" in '' | *[!0-9]*) LINE="" ;; esac
if [ -n "$LINE" ]; then
  "${EDITOR:-nvim}" "+$LINE" "$F"
else
  "${EDITOR:-nvim}" "$F"
fi
"$XPLR" -m 'CallLuaSilently: custom.invalidate_git' 2>/dev/null
"$XPLR" -m ExplorePwdAsync 2>/dev/null
# Drop input buffered while Neovim was open (a held `left` from the left-exits-nvim
# setting auto-repeats as the editor closes) so it does not walk xpdt up directories.
sh "$HOME/.config/xpdt/flush-input.sh"
