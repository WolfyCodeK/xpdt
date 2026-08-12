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
    # Wrapped through wrap-header.sh (like git-log-header.sh) because fzf truncates a
    # long header rather than wrapping it, and these lines no longer fit a narrow
    # terminal on one row.
    if [ "$cur" = root ]; then
      HDR='scope: whole tree from launch dir      [tab] switch to current dir      [→] open      [ctrl-o] file manager      [←] cancel'
    else
      HDR='scope: current dir      [tab] switch to whole tree from launch dir      [→] open      [ctrl-o] file manager      [←] cancel'
    fi
    sh "$HOME/.config/xpdt/wrap-header.sh" "$HDR"
    ;;
esac
