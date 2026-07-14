#!/bin/sh
# List the log for the ref stored in the state file (empty file = current HEAD).
# A thin adapter so the browser's reload command has no parentheses of its own.
ROOT="$1"; REFF="$2"
sh "$HOME/.config/xpdt/git-log-list.sh" "$ROOT" "$(cat "$REFF" 2>/dev/null)"
