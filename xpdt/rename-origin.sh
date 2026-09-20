#!/bin/sh
# Print the ORIGINAL path of a staged rename or copy, given the new path - or nothing
# when the path is not the new side of one.
#
# The changes list deliberately shows a rename as a single row for the NEW path (the
# `-z` record that carries the original is consumed by `skip`). Acting on that row with
# the new path alone left the other half of the rename staged: unstaging produced a
# staged `D old.txt` plus an untracked `new.txt`, and DISCARDING removed new.txt from
# the working tree while leaving `D old.txt` staged - the file disappeared entirely
# even though HEAD still had it. Both callers need the pair.
#
# Args: ROOT NEWPATH
ROOT="$1"; WANT="$2"
[ -n "$ROOT" ] && [ -n "$WANT" ] || exit 0
# Newlines are parked on \001 so a path containing one cannot split a record; such
# paths are dropped by git-changes-list.sh and so never reach here anyway.
git -C "$ROOT" status --porcelain -z 2>/dev/null \
  | LC_ALL=C tr '\n' '\001' \
  | LC_ALL=C tr '\0' '\n' \
  | awk -v want="$WANT" '
      take { if ($0 != "") print $0; take = 0; next }
      length($0) > 3 {
        x = substr($0,1,1); y = substr($0,2,1); p = substr($0,4)
        if (x == "R" || x == "C" || y == "R" || y == "C") { if (p == want) take = 1 }
      }'
