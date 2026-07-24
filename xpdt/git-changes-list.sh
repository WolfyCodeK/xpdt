#!/bin/sh
# Change list for the `enter` browser. One row per staged / unstaged change:
#
#   <group>  <status>  <path>
#
# -z is what makes a filename containing a space or a non-ASCII byte usable. The
# default porcelain format C-quotes those paths ("my notes.txt", "caf\303\251.txt"),
# and every action fed that quoted string straight back to git as a pathspec - so
# stage / discard / hunks / diff all failed with "pathspec did not match any files",
# and `right` opened a NEW empty buffer literally named with the quote characters.
# -z emits raw paths instead, NUL-separated; a rename/copy record is followed by one
# extra record holding the ORIGINAL path, which `skip` consumes.
#
# NUL is translated to newline because fzf wants one row per line, so a path with a
# literal newline in it is the one case still not representable - it is dropped
# rather than mis-split (git's own porcelain v1 has the same limitation).
git -C "$1" status --porcelain -z 2>/dev/null \
  | tr '\0' '\n' \
  | awk '
      skip { skip = 0; next }
      length($0) > 3 {
        x = substr($0,1,1); y = substr($0,2,1); p = substr($0,4)
        if (x == "R" || x == "C" || y == "R" || y == "C") skip = 1
        if (x != " " && x != "?") s[++ns] = sprintf("%-8s %s %s", "staged", x, p)
        if (y != " ")             u[++nu] = sprintf("%-8s %s %s", "unstaged", y, p)
      }
      END { for (i = 1; i <= ns; i++) print s[i]; for (i = 1; i <= nu; i++) print u[i] }'
