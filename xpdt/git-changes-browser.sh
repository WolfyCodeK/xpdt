#!/bin/sh
DIR="${XPLR_DIR:-${XPLR_FOCUS_PATH:-$PWD}}"
[ -f "$DIR" ] && DIR="$(dirname "$DIR")"
ROOT="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)"
[ -z "$ROOT" ] && exit 0

X="$HOME/.config/xpdt"
LIST="sh $X/git-changes-list.sh '$ROOT'"

while : ; do
  ENTRIES=$(eval "$LIST")
  [ -z "$ENTRIES" ] && exit 0
  NENTRIES=$(printf '%s\n' "$ENTRIES" | grep -c .)
  TERMH=$(stty size </dev/tty 2>/dev/null | awk '{print $1}')
  [ -z "$TERMH" ] && TERMH=$(tput lines 2>/dev/null)
  [ -z "$TERMH" ] && TERMH=40
  MAXFILES=20
  LISTH=$((NENTRIES + 3)); MAXLIST=$((TERMH - 10))
  [ "$LISTH" -gt $((MAXFILES + 3)) ] && LISTH=$((MAXFILES + 3))
  [ "$LISTH" -gt "$MAXLIST" ] && LISTH="$MAXLIST"
  [ "$LISTH" -lt 4 ] && LISTH=4
  DIFF="if [ {1} = staged ]; then git -C '$ROOT' diff --cached --color=always -- {3..}; else git -C '$ROOT' diff --color=always -- {3..}; fi"
  RESIZE="lh=\$((FZF_TOTAL_COUNT + 3)); [ \$lh -gt $((MAXFILES + 3)) ] && lh=$((MAXFILES + 3)); [ \$lh -gt $((TERMH - 10)) ] && lh=$((TERMH - 10)); [ \$lh -lt 4 ] && lh=4; echo \"change-preview-window(down,\$(($TERMH - lh)))\""
  LINE=$(printf '%s\n' "$ENTRIES" \
    | fzf --ansi --no-sort --reverse --disabled --no-input \
        --header='[s] stage/unstage  [p] hunks  [d] discard  [c] commit  [ctrl-e] edit  [enter] vscode  [→] preview' \
        --preview "$DIFF" \
        --preview-window "down,$((TERMH - LISTH))" \
        --bind "load:transform:$RESIZE" \
        --bind "s:execute(sh $X/git-stage.sh '$ROOT' {1} {3..})+reload($LIST)" \
        --bind "d:execute(sh $X/git-discard.sh '$ROOT' {1} {2} {3..})+reload($LIST)" \
        --bind "c:execute(bash $X/git-commit.sh '$ROOT')+reload($LIST)" \
        --bind "p:execute(sh $X/git-hunk-browser.sh '$ROOT' {1} {3..})+reload($LIST)" \
        --bind "right:execute(sh $X/diff-view.sh '$ROOT' {1} {3..})" \
        --bind "ctrl-e:execute(cd '$ROOT' && nvim {3..})+reload($LIST)" \
        --bind 'enter:accept,left:abort')
  [ -z "$LINE" ] && exit 0
  GROUP=$(printf '%s\n' "$LINE" | awk '{print $1}')
  FILE=$(printf '%s\n' "$LINE" | awk '{$1=""; $2=""; sub(/^ +/,""); print}')
  sh "$X/open-git-diff.sh" "$ROOT" "$GROUP" "$FILE"
done
