#!/bin/sh
MAPF="$1"; CUR="$2"; F="$3"
LINE=$(sed -n "$((CUR + 1))p" "$MAPF" 2>/dev/null)
case "$LINE" in ''|*[!0-9]*) LINE=1 ;; esac
ED="${EDITOR:-nvim}"
case "$(basename "$ED")" in
  vim|vi) exec "$ED" -S "$HOME/.config/xpdt/edit.vim" "+$LINE" "$F" ;;
  *) exec "$ED" "+$LINE" "$F" ;;
esac
