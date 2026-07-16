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
#
# The marking is done in pure POSIX shell, not awk: awk's handling of a multibyte
# literal (the ○/●) in the *program source* varies by platform (it left the list
# empty on some awk builds, e.g. macOS's), whereas a shell here just passes those
# bytes straight through printf. No awk keeps it portable.
ROOT="$1"
REF="$2"
REFARG="${REF:-HEAD}"

# Local-only commits = reachable from the ref but not from any remote. With no
# remote-tracking branches to compare against we cannot tell, so leave the set
# empty (every commit a plain ●), like the git-history box's no-upstream case.
UNPUSHED=""
if [ -n "$(git -C "$ROOT" rev-list --remotes -n1 2>/dev/null)" ]; then
  UNPUSHED=$(git -C "$ROOT" rev-list "$REFARG" --not --remotes 2>/dev/null)
fi

ESC=$(printf '\033')
TAB=$(printf '\t')
NL='
'
LOCAL="$ESC[33m○$ESC[0m" # hollow yellow: local / not pushed
PUSHED="●"               # filled: on a remote

# %s (subject) is placed last so any tab it might contain cannot shift fields.
git -C "$ROOT" log "$REFARG" --format="%H$TAB%h$TAB%an$TAB%s" -n 500 2>/dev/null \
  | while IFS="$TAB" read -r full short author subject; do
      case "$NL$UNPUSHED$NL" in
        *"$NL$full$NL"*) dot="$LOCAL" ;;
        *) dot="$PUSHED" ;;
      esac
      printf '%s  %s  %s  %s\n' "$short" "$dot" "$subject" "$author"
    done
