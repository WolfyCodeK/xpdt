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
# A probe character (U+2192, the → in every header) supplied as a byte string, so the
# awk program source stays pure ASCII - a multibyte literal in awk SOURCE is exactly
# what left the commit list empty on some awk builds once before.
printf '%s' "$1" | awk -v w="$COLS" -v probe="$(printf '\342\206\222')" '
# awk length() counts characters on a UTF-8-aware awk (gawk) but BYTES on one without
# multibyte support (older macOS awk, mawk, busybox). Since the headers are full of
# 3-byte glyphs (→ ← …), a byte count made every arrow look 2 columns wider than it
# is and wrapped the header early. Detect which kind of awk this is from the probe,
# and in byte mode count only the non-continuation bytes (0x80-0xBF are UTF-8
# continuation bytes, never the start of a character).
function dwidth(s,   i, n, c) {
  if (!bytes) return length(s)
  n = 0
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (c < "\200" || c > "\277") n++
  }
  return n
}
BEGIN {
  bytes = (length(probe) > 1)
  w = w - 4                               # -4 for the fzf header indent + margin
  if (w < 16) w = 16
}
{
  # Split on 2+ spaces (single spaces inside an item are kept). "  +" avoids the
  # {2,} interval so it works on every awk (gawk / mawk / BSD awk).
  m = split($0, items, /  +/)
  line = ""; lw = 0
  for (i = 1; i <= m; i++) {
    it = items[i]
    if (it == "") continue
    iw = dwidth(it)
    if (line == "") { line = it; lw = iw }
    else if (lw + 2 + iw <= w) { line = line "  " it; lw = lw + 2 + iw }
    else { print line; line = it; lw = iw }
  }
  if (line != "") print line
}'
