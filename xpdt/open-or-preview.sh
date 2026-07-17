#!/bin/sh
# Open the focused file, honouring the "preview file before opening in neovim"
# setting: when it is on, show the full-screen preview first (preview-file.sh, whose
# ctrl-e then opens Neovim at the line); when off, go straight to Neovim
# (open-file.sh). Used by the main-view `right` and by `right` on a hit in the / and
# \ search, so the choice is consistent everywhere. XPLR_FOCUS_PATH (and, from the \
# search, XPLR_PREVIEW_LINE) are inherited and pass through to whichever runs.
if grep -q '^preview-before-nvim=1$' "$HOME/.config/xpdt/.gate-config" 2>/dev/null; then
  exec sh "$HOME/.config/xpdt/preview-file.sh"
else
  exec sh "$HOME/.config/xpdt/open-file.sh"
fi
