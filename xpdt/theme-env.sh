#!/bin/sh
# Sourced by the xpdt launcher (see install.sh). Maps the `theme` setting from
# ~/.config/xpdt/.gate-config to the environment the child tools read: BAT_THEME for
# bat (the file preview and every diff view) and fzf's colours (every browser and
# popup) via FZF_DEFAULT_OPTS. xpdt's own listing (theme.lua) and Neovim read the
# setting directly at their own startup. Changing the theme therefore takes effect on
# the next `xpdt` launch. All five themes' bat themes are built in except Tokyo
# Night, whose theme (tokyonight_night) install.sh builds into bat's cache.
THEME=$(sed -n 's/^theme=//p' "$HOME/.config/xpdt/.gate-config" 2>/dev/null | head -n1)
[ -n "$THEME" ] || THEME=monokai

case "$THEME" in
  gruvbox)
    BAT_THEME="gruvbox-dark"
    _c="fg:#ebdbb2,hl:#fabd2f,fg+:#ebdbb2,bg+:#3c3836,hl+:#fe8019,border:#665c54,header:#928374,info:#928374,prompt:#83a598,pointer:#fb4934,marker:#b8bb26,spinner:#fabd2f"
    ;;
  nord)
    BAT_THEME="Nord"
    _c="fg:#d8dee9,hl:#88c0d0,fg+:#eceff4,bg+:#3b4252,hl+:#8fbcbb,border:#4c566a,header:#616e88,info:#616e88,prompt:#81a1c1,pointer:#bf616a,marker:#a3be8c,spinner:#88c0d0"
    ;;
  dracula)
    BAT_THEME="Dracula"
    _c="fg:#f8f8f2,hl:#bd93f9,fg+:#f8f8f2,bg+:#44475a,hl+:#ff79c6,border:#6272a4,header:#6272a4,info:#6272a4,prompt:#8be9fd,pointer:#ff79c6,marker:#50fa7b,spinner:#bd93f9"
    ;;
  tokyonight)
    BAT_THEME="tokyonight_night"
    _c="fg:#c0caf5,hl:#7aa2f7,fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff,border:#565f89,header:#565f89,info:#565f89,prompt:#7dcfff,pointer:#f7768e,marker:#9ece6a,spinner:#7aa2f7"
    ;;
  *)
    # monokai (the default)
    BAT_THEME="Monokai Extended"
    _c="fg:#f8f8f2,hl:#a6e22e,fg+:#f8f8f2,bg+:#3e3d32,hl+:#a6e22e,border:#75715e,header:#75715e,info:#75715e,prompt:#66d9ef,pointer:#f92672,marker:#a6e22e,spinner:#fd971f"
    ;;
esac

export BAT_THEME
# Prepend our palette so a browser's own --color flags still win where they set one.
FZF_DEFAULT_OPTS="--color=$_c${FZF_DEFAULT_OPTS:+ $FZF_DEFAULT_OPTS}"
export FZF_DEFAULT_OPTS
