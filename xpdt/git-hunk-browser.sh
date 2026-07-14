#!/bin/sh
# Hunk browser: stage / unstage / discard individual hunks of one file (git add -p
# style). Opened with `p` on a focused entry in the changes browser.
# Args: ROOT GROUP FILE. GROUP is the entry's group: 'unstaged' -> stage or discard
# hunks, 'staged' -> unstage hunks.
ROOT="$1"; GROUP="$2"; FILE="$3"
[ -z "$ROOT" ] || [ -z "$FILE" ] && exit 0
# Clear leftover output (e.g. confirmation prompts) before this browser paints.
printf '\033[2J\033[H' > /dev/tty 2>/dev/null
X="$HOME/.config/xpdt"
LIST="sh $X/git-hunk.sh list '$ROOT' $GROUP '$FILE'"

if [ -z "$(eval "$LIST")" ]; then
  printf '\nNo hunks to stage for %s.\n' "$FILE" > /dev/tty
  printf '(A new/untracked file has no diff - use s to stage the whole file.)\n' > /dev/tty
  sleep 1.4
  exit 0
fi

# Discard only makes sense for unstaged hunks (it reverts the working tree); it is
# advertised in the header for that group only, though the bind is harmless either
# way (git-hunk.sh refuses discard on a staged hunk).
if [ "$GROUP" = staged ]; then
  HDR="[s] unstage hunk    [←] back    $FILE ($GROUP)"
else
  HDR="[s] stage hunk    [d] discard hunk    [←] back    $FILE ($GROUP)"
fi

eval "$LIST" | fzf --ansi --no-sort --reverse --disabled --no-input \
  --header="$HDR" \
  --preview "sh $X/git-hunk.sh show '$ROOT' $GROUP '$FILE' {1} | bat --language=diff --color=always --style=plain --paging=never" \
  --preview-window 'down,72%' \
  --bind "s:execute(sh $X/git-hunk.sh apply '$ROOT' $GROUP '$FILE' {1})+reload($LIST)" \
  --bind "d:execute(sh $X/git-hunk.sh discard '$ROOT' $GROUP '$FILE' {1})+reload($LIST)" \
  --bind 'left:abort,esc:abort,q:abort' || true
