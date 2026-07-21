#!/bin/bash
trap 'exit 0' INT
ROOT="$1"
[ -z "$ROOT" ] && exit 0
# Clear leftover output and re-show the cursor (fzf hides it and does not restore
# it for the read), so the commit message is typed on a clean screen with a caret.
printf '\033[2J\033[H\033[?25h' > /dev/tty 2>/dev/null
if git -C "$ROOT" diff --cached --quiet; then
  printf 'Nothing staged to commit. ' > /dev/tty
  sleep 1
  exit 0
fi
read -e -r -p 'Commit message (empty to cancel): ' msg < /dev/tty || exit 0
python3 -S -c 'import termios,sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' </dev/tty 2>/dev/null
[ -z "$msg" ] && exit 0
sh "$HOME/.config/xpdt/gate.sh" confirm commit "Commit: $msg" || exit 0
git -C "$ROOT" commit -m "$msg" > /dev/tty 2>&1
sleep 1.5
