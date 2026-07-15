#!/bin/sh
# Header for the `;` history browser: shows the keys, the branch being viewed and
# the current branch (the cherry-pick target). Long branch names are truncated
# with a trailing … so the header does not run off the screen. REFF empty =
# viewing the current HEAD.
ROOT="$1"; REFF="$2"
CUR=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
REF=$(cat "$REFF" 2>/dev/null); [ -z "$REF" ] && REF="$CUR"

trunc() {  # trunc STRING MAX -> STRING, truncated with a trailing … if over MAX
  if [ "${#1}" -gt "$2" ]; then
    printf '%.*s…' "$(($2 - 1))" "$1"
  else
    printf '%s' "$1"
  fi
}

HDR=$(printf '[→] files   [ctrl-p] cherry-pick onto %s   [b] view branch (%s)   [ctrl-z] undo   [←] back' \
  "$(trunc "$CUR" 20)" "$(trunc "$REF" 20)")
sh "$HOME/.config/xpdt/wrap-header.sh" "$HDR"
