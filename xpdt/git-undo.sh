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
# Name the branch as well as the commit: `ctrl-z` always acts on the CURRENT branch,
# but the `;` browser can be viewing another one (via `b`), and the header said only
# "[ctrl-z] undo" over that other branch's commits.
BR=$(git -C "$ROOT" symbolic-ref --short -q HEAD || git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)
sh "$HOME/.config/xpdt/gate.sh" confirm undo "Undo the last commit on ${BR:-HEAD} [$SUBJ]? changes are kept and staged." || exit 0
git -C "$ROOT" reset --soft HEAD~1 > /dev/tty 2>&1
sleep 1
