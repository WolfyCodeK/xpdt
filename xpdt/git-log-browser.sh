#!/bin/sh
DIR="${XPLR_DIR:-${XPLR_FOCUS_PATH:-$PWD}}"
[ -f "$DIR" ] && DIR="$(dirname "$DIR")"
ROOT="$(sh "$HOME/.config/xpdt/repo-root.sh" "$DIR")"
[ -z "$ROOT" ] && exit 0

X="$HOME/.config/xpdt"
REFF=$(mktemp)   # branch/ref being viewed; empty = current HEAD
LOG="sh $X/git-log-view.sh '$ROOT' '$REFF'"
HDR="sh $X/git-log-header.sh '$ROOT' '$REFF'"

while : ; do
  LINE=$(eval "$LOG" \
    | fzf --ansi --reverse --prompt='commit > ' \
        --header="$(eval "$HDR")" \
        --preview "git -C '$ROOT' show --color=never {1} | python3 '$X/diff-words.py'" \
        --preview-window 'down,50%,wrap' \
        --bind "ctrl-z:execute(sh $X/git-undo.sh '$ROOT')+reload($LOG)" \
        --bind "b:execute(sh $X/git-branch-pick.sh '$ROOT' '$REFF')+reload($LOG)+transform-header($HDR)" \
        --bind "ctrl-p:execute(sh $X/git-cherry-pick.sh '$ROOT' {1})+reload($LOG)" \
        --bind 'right:accept,enter:ignore,left:abort')
  [ -z "$LINE" ] && break
  HASH=$(printf '%s\n' "$LINE" | awk '{print $1}')

  FILES=$(git -C "$ROOT" diff-tree --no-commit-id --name-status -r "$HASH")
  NFILES=$(printf '%s\n' "$FILES" | grep -c .)
  TERMH=$(stty size </dev/tty 2>/dev/null | awk '{print $1}')
  [ -z "$TERMH" ] && TERMH=$(tput lines 2>/dev/null)
  [ -z "$TERMH" ] && TERMH=40
  MAXFILES=20
  # A normal (filterable) fzf with no custom header: the list yields the prompt line,
  # the info line and the preview's top/bottom border (~4 rows) to chrome; the rest
  # goes to the preview. `right` opens the inline diff viewer; `enter` does nothing.
  N=$NFILES; [ "$N" -gt "$MAXFILES" ] && N=$MAXFILES; [ "$N" -lt 1 ] && N=1
  PW=$((TERMH - N - 4)); [ "$PW" -lt 3 ] && PW=3
  printf '%s\n' "$FILES" \
    | fzf --ansi --reverse --prompt="$HASH > " \
        --preview "git -C \"$ROOT\" show --color=never \"$HASH\" -- {-1} | python3 \"$X/diff-words.py\"" \
        --preview-window "down,$PW,wrap" \
        --bind "right:execute(sh $X/diff-view.sh '$ROOT' commit {-1} '$HASH')" \
        --bind 'enter:ignore,left:abort'
done
rm -f "$REFF"
