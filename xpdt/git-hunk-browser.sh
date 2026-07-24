#!/bin/sh
# Hunk browser: stage / unstage / discard individual hunks of one file (git add -p
# style). Opened with `p` on a focused entry in the changes browser.
# Args: ROOT GROUP FILE. GROUP is the entry's group: 'unstaged' -> stage or discard
# hunks, 'staged' -> unstage hunks.
ROOT="$1"; GROUP="$2"; FILE="$3"
if [ -z "$ROOT" ] || [ -z "$FILE" ]; then exit 0; fi
# Clear leftover output (e.g. confirmation prompts) before this browser paints.
printf '\033[2J\033[H' > /dev/tty 2>/dev/null
X="$HOME/.config/xpdt"

# Root, group and file reach the fzf binds through the ENVIRONMENT rather than being
# pasted into their command strings: fzf re-parses each bind with a shell, so a path
# containing a quote or $(...) would otherwise be executed - and a filename with a
# space would split into two arguments.
XPDT_ROOT="$ROOT"; XPDT_GROUP="$GROUP"; XPDT_FILE="$FILE"
export XPDT_ROOT XPDT_GROUP XPDT_FILE
HUNK="sh \"$X/git-hunk.sh\""
ARGS="\"\$XPDT_ROOT\" \"\$XPDT_GROUP\" \"\$XPDT_FILE\""
LIST="$HUNK list $ARGS"

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
  --header="$(sh "$X/wrap-header.sh" "$HDR")" \
  --preview "$HUNK show $ARGS {1} | python3 -S \"$X/diff-words.py\"" \
  --preview-window 'down,72%,wrap' \
  --bind "s:execute($HUNK apply $ARGS {1})+reload($LIST)" \
  --bind "d:execute($HUNK discard $ARGS {1})+reload($LIST)" \
  --bind 'left:abort,esc:abort,q:abort,enter:ignore' || true
