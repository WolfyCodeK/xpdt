#!/bin/sh
F="$1"; MAPF="$2"; MARKF="$3"; CUR="$4"
mark=$(cat "$MARKF" 2>/dev/null)
if [ -n "$mark" ] && [ -f "$MAPF" ]; then
  a=$(sed -n "$((mark + 1))p" "$MAPF" 2>/dev/null)
  b=$(sed -n "$((CUR + 1))p" "$MAPF" 2>/dev/null)
  : > "$MARKF"
  if [ -n "$a" ] && [ -n "$b" ]; then
    [ "$a" -gt "$b" ] && { t="$a"; a="$b"; b="$t"; }
    sed -n "${a},${b}p" "$F" | pbcopy
    exit 0
  fi
fi
pbcopy < "$F"
