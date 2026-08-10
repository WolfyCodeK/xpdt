#!/bin/sh
# Render stdin as a scrollable, bordered popup window. Shared by the `h` controls
# help (help.sh), the `ctrl-h` neovim cheat sheet (nvim-cheatsheet.sh) and the `c`
# Claude window (claude-window.sh).
# Arrows / page keys / mouse wheel scroll; q, esc, left, h or ctrl-h close it.
# $1 is the header title. $2 is an OPTIONAL extra --bind spec (e.g. a refresh key);
# it is added after the close binds, so a caller cannot accidentally unbind the
# closing keys. Content is read from stdin.
EXTRA="${2:-}"
# shellcheck disable=SC2086  # $EXTRA is a deliberate, caller-supplied bind spec
fzf --ansi --no-sort --reverse --disabled --no-input --info=hidden --prompt='' \
  --border=rounded --margin=3%,6% --padding=0,1 \
  --pointer=' ' --color='bg+:-1,gutter:-1,pointer:-1' \
  --header="${1:-}" --header-first \
  --bind 'q:abort,esc:abort,left:abort,h:abort,ctrl-h:abort' \
  ${EXTRA:+--bind "$EXTRA"} >/dev/null 2>&1 || true
