#!/bin/sh
DIR="${XPLR_DIR:-${XPLR_FOCUS_PATH:-$PWD}}"
[ -f "$DIR" ] && DIR="$(dirname "$DIR")"
ROOT="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)"
[ -z "$ROOT" ] && exit 0

X="$HOME/.config/xplr"
LOG="sh $X/git-log-list.sh '$ROOT'"

while : ; do
  LINE=$(eval "$LOG" \
    | fzf --ansi --reverse --prompt='commit > ' \
        --header='[→] open commit    [ctrl-z] undo last commit    [←] back' \
        --preview "git -C '$ROOT' show --stat --color=always {1}" \
        --preview-window 'down,50%' \
        --bind "ctrl-z:execute(sh $X/git-undo.sh '$ROOT')+reload($LOG)" \
        --bind 'right:accept,enter:ignore,left:abort')
  [ -z "$LINE" ] && exit 0
  HASH=$(printf '%s\n' "$LINE" | awk '{print $1}')

  while : ; do
    FILES=$(git -C "$ROOT" diff-tree --no-commit-id --name-status -r "$HASH")
    NFILES=$(printf '%s\n' "$FILES" | grep -c .)
    TERMH=$(stty size </dev/tty 2>/dev/null | awk '{print $1}')
    [ -z "$TERMH" ] && TERMH=$(tput lines 2>/dev/null)
    [ -z "$TERMH" ] && TERMH=40
    MAXFILES=20
    LISTH=$((NFILES + 4)); MAXLIST=$((TERMH - 10))
    [ "$LISTH" -gt $((MAXFILES + 4)) ] && LISTH=$((MAXFILES + 4))
    [ "$LISTH" -gt "$MAXLIST" ] && LISTH="$MAXLIST"
    [ "$LISTH" -lt 3 ] && LISTH=3
    FILELINE=$(printf '%s\n' "$FILES" \
      | fzf --ansi --reverse --prompt="$HASH > " \
          --preview "git -C \"$ROOT\" show --color=always \"$HASH\" -- {-1}" \
          --preview-window "down,$((TERMH - LISTH))" \
          --bind "right:execute(sh $X/diff-view.sh '$ROOT' commit {-1} '$HASH')" \
          --bind 'enter:accept,left:abort')
    [ -z "$FILELINE" ] && break
    FILE=$(printf '%s\n' "$FILELINE" | awk '{print $NF}')
    sh "$HOME/.config/xplr/open-git-diff.sh" "$ROOT" commit "$FILE" "$HASH"
  done
done
