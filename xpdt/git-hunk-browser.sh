#!/bin/sh
# Hunk browser: stage or unstage individual hunks of one file (git add -p style).
# Opened with `p` on a focused entry in the changes browser. Args: ROOT GROUP FILE
# GROUP is the entry's group: 'unstaged' -> stage hunks, 'staged' -> unstage hunks.
ROOT="$1"; GROUP="$2"; FILE="$3"
[ -z "$ROOT" ] || [ -z "$FILE" ] && exit 0
X="$HOME/.config/xpdt"
LIST="sh $X/git-hunk.sh list '$ROOT' $GROUP '$FILE'"

if [ -z "$(eval "$LIST")" ]; then
  printf '\nNo hunks to stage for %s.\n' "$FILE" > /dev/tty
  printf '(A new/untracked file has no diff - use s to stage the whole file.)\n' > /dev/tty
  sleep 1.4
  exit 0
fi

if [ "$GROUP" = staged ]; then verb=unstage; else verb=stage; fi
eval "$LIST" | fzf --ansi --no-sort --reverse --disabled --no-input \
  --header="[s] $verb hunk    [←] back    $FILE ($GROUP)" \
  --preview "sh $X/git-hunk.sh show '$ROOT' $GROUP '$FILE' {1} | bat --language=diff --color=always --style=plain --paging=never" \
  --preview-window 'down,72%' \
  --bind "s:execute(sh $X/git-hunk.sh apply '$ROOT' $GROUP '$FILE' {1})+reload($LIST)" \
  --bind 'left:abort,esc:abort,q:abort'
