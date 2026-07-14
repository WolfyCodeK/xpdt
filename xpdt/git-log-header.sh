#!/bin/sh
# Header for the `;` history browser: shows the keys, the branch being viewed and
# the current branch (the cherry-pick target). REFF empty = viewing current HEAD.
ROOT="$1"; REFF="$2"
CUR=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
REF=$(cat "$REFF" 2>/dev/null); [ -z "$REF" ] && REF="$CUR"
printf '[→] files   [ctrl-p] cherry-pick onto %s   [b] view branch (%s)   [ctrl-z] undo   [←] back' "$CUR" "$REF"
