#!/bin/sh
DIR="$1"; CUR="$2"; POSF="$3"
cur=$((CUR + 1))
positions=$(cat "$POSF" 2>/dev/null)
[ -z "$positions" ] && exit 0
if [ "$DIR" = next ]; then
  for p in $positions; do
    [ "$p" -gt "$cur" ] && { echo "pos($p)"; exit 0; }
  done
  set -- $positions
  echo "pos($1)"
else
  prev=
  for p in $positions; do
    [ "$p" -lt "$cur" ] && prev=$p
  done
  if [ -n "$prev" ]; then
    echo "pos($prev)"
  else
    for p in $positions; do last=$p; done
    echo "pos($last)"
  fi
fi
