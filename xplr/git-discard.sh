#!/bin/sh
ROOT="$1"; GROUP="$2"; STATUS="$3"; FILE="$4"
[ -z "$ROOT" ] || [ -z "$FILE" ] && exit 0
python3 -c 'import termios,sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' </dev/tty 2>/dev/null
printf 'Discard changes to %s? [y/N] ' "$FILE" > /dev/tty
read ans < /dev/tty
case "$ans" in
  y|Y) ;;
  *) exit 0 ;;
esac
if [ "$STATUS" = "?" ]; then
  rm -rf -- "$ROOT/$FILE"
elif [ "$GROUP" = staged ]; then
  git -C "$ROOT" restore --staged --worktree -- "$FILE"
else
  git -C "$ROOT" restore -- "$FILE"
fi
