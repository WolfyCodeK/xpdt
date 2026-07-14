#!/bin/sh
# The `s` stash browser: fzf over `git stash list` with a diff+stat preview and
# single-key actions (apply / pop / drop / new / clear), lazygit style, so the
# list is --disabled --no-input and the letters are actions, not filter text.
# Mirrors git-changes-browser.sh (list resize on load, reload after each action).
DIR="${XPLR_DIR:-${XPLR_FOCUS_PATH:-$PWD}}"
[ -f "$DIR" ] && DIR="$(dirname "$DIR")"
ROOT="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)"
[ -z "$ROOT" ] && exit 0

X="$HOME/.config/xpdt"
LIST="sh $X/git-stash-list.sh '$ROOT'"

NENTRIES=$(git -C "$ROOT" stash list 2>/dev/null | grep -c .)
TERMH=$(stty size </dev/tty 2>/dev/null | awk '{print $1}')
[ -z "$TERMH" ] && TERMH=$(tput lines 2>/dev/null)
[ -z "$TERMH" ] && TERMH=40
MAXLIST=15
LISTH=$((NENTRIES + 3)); MAXH=$((TERMH - 10))
[ "$LISTH" -gt $((MAXLIST + 3)) ] && LISTH=$((MAXLIST + 3))
[ "$LISTH" -gt "$MAXH" ] && LISTH="$MAXH"
[ "$LISTH" -lt 4 ] && LISTH=4
# {1} is the stash ref; empty when there are no stashes, so guard every action
# and show a hint in the preview instead of a git error.
VIEW="git -C '$ROOT' stash show -p --stat --color=always {1}"
PREVIEW="[ -n {1} ] && $VIEW || echo 'No stashes. Press n to stash your current changes.'"
RESIZE="lh=\$((FZF_TOTAL_COUNT + 3)); [ \$lh -gt $((MAXLIST + 3)) ] && lh=$((MAXLIST + 3)); [ \$lh -gt $((TERMH - 10)) ] && lh=$((TERMH - 10)); [ \$lh -lt 4 ] && lh=4; echo \"change-preview-window(down,\$(($TERMH - lh)))\""

eval "$LIST" \
  | fzf --ansi --no-sort --reverse --disabled --no-input \
      --header='[a] apply  [p] pop  [d] drop  [n] new  [x] clear all  [enter/→] view  [←] back' \
      --preview "$PREVIEW" \
      --preview-window "down,$((TERMH - LISTH))" \
      --bind "load:transform:$RESIZE" \
      --bind "a:execute([ -n {1} ] && sh $X/git-stash-op.sh '$ROOT' apply {1})+reload($LIST)" \
      --bind "p:execute([ -n {1} ] && sh $X/git-stash-op.sh '$ROOT' pop {1})+reload($LIST)" \
      --bind "d:execute([ -n {1} ] && sh $X/git-stash-op.sh '$ROOT' drop {1})+reload($LIST)" \
      --bind "n:execute(sh $X/git-stash-op.sh '$ROOT' push)+reload($LIST)" \
      --bind "x:execute(sh $X/git-stash-op.sh '$ROOT' clear)+reload($LIST)" \
      --bind "enter:execute([ -n {1} ] && $VIEW | less -R)" \
      --bind "right:execute([ -n {1} ] && $VIEW | less -R)" \
      --bind 'left:abort' || true
