#!/bin/sh
# Wrap an fzf header onto multiple lines so it fits a narrow terminal (fzf itself
# truncates long headers rather than wrapping them). Header "items" are separated
# by runs of 2+ spaces; they are greedily packed into lines no wider than the
# terminal, joined by 2 spaces, so an item is never split across a line break.
# $1 = the header string; $2 = width (defaults to the current tty width).
#
# Pure awk (no python): this runs on every browser/menu open, and a python spawn
# there cost ~25ms of startup just to wrap a line of text. awk does it in ~4ms.
COLS="$2"
[ -z "$COLS" ] && COLS=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
[ -z "$COLS" ] && COLS=$(tput cols 2>/dev/null)
[ -z "$COLS" ] && COLS=80
printf '%s' "$1" | awk -v w="$COLS" '
BEGIN { w = w - 4; if (w < 16) w = 16 }   # -4 for the fzf header indent + margin
{
  # Split on 2+ spaces (single spaces inside an item are kept). "  +" avoids the
  # {2,} interval so it works on every awk (gawk / mawk / BSD awk).
  m = split($0, items, /  +/)
  line = ""
  for (i = 1; i <= m; i++) {
    it = items[i]
    if (it == "") continue
    if (line == "") line = it
    else if (length(line) + 2 + length(it) <= w) line = line "  " it
    else { print line; line = it }
  }
  if (line != "") print line
}'
