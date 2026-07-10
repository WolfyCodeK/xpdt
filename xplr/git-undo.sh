#!/bin/sh
trap 'exit 0' INT
ROOT="$1"
[ -z "$ROOT" ] && exit 0
if ! git -C "$ROOT" rev-parse --verify -q HEAD~1 >/dev/null 2>&1; then
  printf 'No earlier commit to undo. ' > /dev/tty
  sleep 1
  exit 0
fi
SUBJ=$(git -C "$ROOT" log -1 --format='%h %s')
python3 -c 'import termios,sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' </dev/tty 2>/dev/null
printf 'Undo last commit [%s]? changes are kept and staged. [y/N] ' "$SUBJ" > /dev/tty
read ans < /dev/tty || exit 0
case "$ans" in
  y|Y) ;;
  *) exit 0 ;;
esac
git -C "$ROOT" reset --soft HEAD~1 > /dev/tty 2>&1
sleep 1
