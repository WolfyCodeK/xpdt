#!/bin/sh
# Pick a branch/ref for the `;` history browser to view; write it to the state
# file. Lists the current branch, other local branches, then remote branches.
# esc keeps the current view (state file unchanged).
ROOT="$1"; REFF="$2"
[ -z "$ROOT" ] && exit 0
printf '\033[2J\033[H' > /dev/tty 2>/dev/null
CUR=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
BR=$({
    printf '%s (current)\n' "$CUR"
    git -C "$ROOT" branch --format='%(refname:short)' | grep -vx "$CUR"
    git -C "$ROOT" branch -r --format='%(refname:short)' | grep -v '/HEAD$'
  } | fzf --height=60% --reverse --prompt='view branch > ' \
        --header='pick a branch/ref to view (esc keeps current)' \
        --bind 'enter:accept,right:accept,left:abort' || true)
[ -z "$BR" ] && exit 0
case "$BR" in
  "$CUR (current)") : > "$REFF" ;;            # empty state = current HEAD
  *) printf '%s' "$BR" > "$REFF" ;;
esac
