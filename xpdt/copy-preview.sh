#!/bin/sh
# The file preview's `ctrl-y`: copy the range marked with `ctrl-v` (mapped back through
# the wrap map to real source lines), or the whole file when nothing is marked.
#
# Exits non-zero when there is no clipboard tool, so the caller can say so instead of
# reporting a copy that did not happen - it used to pipe to `pbcopy` unconditionally
# and the preview claimed "copied to clipboard" on every platform without one.
F="$1"; MAPF="$2"; MARKF="$3"; CUR="$4"

# First clipboard tool that exists: macOS, then Wayland, X11, and WSL.
if command -v pbcopy >/dev/null 2>&1; then
  clip() { pbcopy; }
elif command -v wl-copy >/dev/null 2>&1; then
  clip() { wl-copy; }
elif command -v xclip >/dev/null 2>&1; then
  clip() { xclip -selection clipboard; }
elif command -v clip.exe >/dev/null 2>&1; then
  clip() { clip.exe; }
else
  exit 1
fi

mark=$(cat "$MARKF" 2>/dev/null)
if [ -n "$mark" ] && [ -f "$MAPF" ]; then
  a=$(sed -n "$((mark + 1))p" "$MAPF" 2>/dev/null)
  b=$(sed -n "$((CUR + 1))p" "$MAPF" 2>/dev/null)
  : > "$MARKF"
  if [ -n "$a" ] && [ -n "$b" ]; then
    [ "$a" -gt "$b" ] && { t="$a"; a="$b"; b="$t"; }
    sed -n "${a},${b}p" "$F" | clip
    exit 0
  fi
fi
clip < "$F"
