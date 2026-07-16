#!/bin/sh
# Commit list for the `;` history browser. Optional $2 = a branch/ref to view
# (empty = the current HEAD). Each row is:
#
#   <short-hash>  <dot>  <subject>  <author>
#
# where <dot> marks local vs pushed the same way the git-history box does: a hollow
# yellow ○ for a local commit (reachable from the viewed ref but not on any
# remote-tracking branch), a filled ● for a pushed one. Field 1 stays the short
# hash so the browser's {1} / preview / cherry-pick binds are unaffected.
ROOT="$1"; REF="$2"
REFARG="${REF:-HEAD}"

# Local-only commits = reachable from the ref but not from any remote. With no
# remote-tracking branches to compare against we cannot tell, so (like the box)
# leave every commit a plain ● by keeping the set empty.
UNPUSHED=""
if [ -n "$(git -C "$ROOT" rev-list --remotes -n1 2>/dev/null)" ]; then
  UNPUSHED=$(git -C "$ROOT" rev-list "$REFARG" --not --remotes 2>/dev/null)
fi

git -C "$ROOT" log "$REFARG" --format='%H%x09%h%x09%s%x09%an' -n 500 2>/dev/null \
  | awk -F'\t' -v up="$UNPUSHED" '
    BEGIN { n = split(up, a, "\n"); for (i = 1; i <= n; i++) if (a[i] != "") U[a[i]] = 1 }
    {
      dot = ($1 in U) ? "\033[33m○\033[0m" : "●"
      printf "%s  %s  %s  %s\n", $2, dot, $3, $4
    }'
