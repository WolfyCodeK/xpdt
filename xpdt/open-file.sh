#!/bin/sh
# Open the focused file in the editor (Neovim) from the main view. Neovim opens in
# normal mode, so it doubles as a reader you can edit in - which is why `right` on a
# file goes straight here now instead of the read-only preview. After the editor
# exits, refresh the git columns/panels in case the file was changed.
F="$XPLR_FOCUS_PATH"
[ -z "$F" ] && exit 0
case "$F" in /*) ;; *) F="$PWD/$F" ;; esac
[ -d "$F" ] && exit 0
"${EDITOR:-nvim}" "$F"
"$XPLR" -m 'CallLuaSilently: custom.invalidate_git' 2>/dev/null
"$XPLR" -m ExplorePwdAsync 2>/dev/null
