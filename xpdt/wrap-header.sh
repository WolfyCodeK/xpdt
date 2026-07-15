#!/bin/sh
# Wrap an fzf header onto multiple lines so it fits a narrow terminal (fzf itself
# truncates long headers rather than wrapping them). Header "items" are separated
# by runs of 2+ spaces; they are greedily packed into lines no wider than the
# terminal, joined by 2 spaces, so an item is never split across a line break.
# $1 = the header string; $2 = width (defaults to the current tty width).
COLS="$2"
[ -z "$COLS" ] && COLS=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
[ -z "$COLS" ] && COLS=$(tput cols 2>/dev/null)
[ -z "$COLS" ] && COLS=80
printf '%s' "$1" | HW="$COLS" python3 -c '
import os, re, sys
w = max(16, int(os.environ.get("HW", "80")) - 4)   # -4 for the fzf header indent + margin
items = re.split(r"  +", sys.stdin.read().strip())
lines, cur = [], ""
for it in items:
    if not cur:
        cur = it
    elif len(cur) + 2 + len(it) <= w:
        cur += "  " + it
    else:
        lines.append(cur); cur = it
if cur:
    lines.append(cur)
sys.stdout.write("\n".join(lines))
'
