#!/bin/sh
# Toggle or render the `/` `\` search scope. Arg: ACTION (toggle | header).
# The state file arrives in the environment (XPDT_SCOPE_FILE) rather than as an
# argument, so no path is baked into the fzf bind strings that call this - see
# search.sh for why.
ACTION="$1"
FILE="$XPDT_SCOPE_FILE"
cur=$(cat "$FILE" 2>/dev/null)
[ "$cur" = root ] || cur=here
case "$ACTION" in
  toggle)
    if [ "$cur" = root ]; then echo here > "$FILE"; else echo root > "$FILE"; fi
    ;;
  header)
    if [ "$cur" = root ]; then
      printf 'scope: whole tree from launch dir      [tab] switch to current dir      [→] open      [←] cancel'
    else
      printf 'scope: current dir      [tab] switch to whole tree from launch dir      [→] open      [←] cancel'
    fi
    ;;
esac
