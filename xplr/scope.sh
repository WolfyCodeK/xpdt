#!/bin/sh
ACTION="$1"; FILE="$2"
cur=$(cat "$FILE" 2>/dev/null)
[ "$cur" = root ] || cur=here
case "$ACTION" in
  toggle)
    if [ "$cur" = root ]; then echo here > "$FILE"; else echo root > "$FILE"; fi
    ;;
  header)
    if [ "$cur" = root ]; then
      printf 'scope: whole tree from launch dir      [tab] switch to current dir      [→] preview      [←] cancel'
    else
      printf 'scope: current dir      [tab] switch to whole tree from launch dir      [→] preview      [←] cancel'
    fi
    ;;
esac
