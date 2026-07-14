#!/bin/sh
# Render stdin as a scrollable, bordered popup window. Shared by the `h` controls
# help (help.sh) and the `ctrl-h` neovim cheat sheet (nvim-cheatsheet.sh).
# Arrows / page keys / mouse wheel scroll; q, esc, left, h or ctrl-h close it.
# $1 is the header title. Content is read from stdin.
fzf --ansi --no-sort --reverse --disabled --no-input --info=hidden --prompt='' \
  --border=rounded --margin=3%,6% --padding=0,1 \
  --pointer=' ' --color='bg+:-1,gutter:-1,pointer:-1' \
  --header="${1:-}" --header-first \
  --bind 'q:abort,esc:abort,left:abort,h:abort,ctrl-h:abort' >/dev/null 2>&1 || true
