#!/bin/sh
# Change list for the `enter` browser. One row per staged / unstaged change:
#
#   <group>  <status>  <path>
#
# -z is what makes a filename containing a space or a non-ASCII byte usable. The
# default porcelain format C-quotes those paths ("my notes.txt", "caf\303\251.txt"),
# and every action fed that quoted string straight back to git as a pathspec - so
# stage / discard / hunks / diff all failed with "pathspec did not match any files",
# and `right` opened a new empty buffer literally named with the quote characters.
# -z emits raw paths instead, NUL-separated; a rename/copy record is followed by one
# extra record holding the original path, which `skip` consumes.
#
# NUL is translated to newline because fzf wants one row per line, so a path with a
# literal newline in it is the one case still not representable - it is dropped
# rather than mis-split (git's own porcelain v1 has the same limitation).
git -C "$1" status --porcelain -z 2>/dev/null \
  | LC_ALL=C tr '\n' '\001' \
  | LC_ALL=C tr '\0' '\n' \
  | awk '
      skip { skip = 0; next }
      length($0) > 3 {
        x = substr($0,1,1); y = substr($0,2,1); p = substr($0,4)
        if (x == "R" || x == "C" || y == "R" || y == "C") skip = 1
        # A path containing a newline is genuinely dropped here, as the comment above
        # promises. Translating NUL to newline on its own used to SPLIT such a path
        # across rows, which produced phantom entries and - worse - a row labelled with
        # only the first half of the name, so discarding it deleted a different,
        # unrelated file. Real newlines are parked on \001 first so they survive the
        # NUL translation and can be detected here.
        if (index(p, "\001") > 0) next
        if (x != " " && x != "?") s[++ns] = sprintf("%-8s %s %s", "staged", x, p)
        if (y != " ")             u[++nu] = sprintf("%-8s %s %s", "unstaged", y, p)
      }
      END { for (i = 1; i <= ns; i++) print s[i]; for (i = 1; i <= nu; i++) print u[i] }'
