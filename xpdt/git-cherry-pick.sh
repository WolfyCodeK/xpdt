#!/bin/sh
# Cherry-pick a single commit onto the current branch. Requires a clean working
# tree (git does), is gated by the confirmation code, and auto-aborts on conflict
# so the branch is left exactly as it was.
ROOT="$1"; HASH="$2"
[ -z "$ROOT" ] || [ -z "$HASH" ] && exit 0
printf '\033[2J\033[H' > /dev/tty 2>/dev/null
if [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]; then
  printf 'Working tree has uncommitted changes; commit or stash before cherry-picking.\n' > /dev/tty
  sleep 1.6
  exit 0
fi
CUR=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
SUBJ=$(git -C "$ROOT" log -1 --format='%h %s' "$HASH" 2>/dev/null)
sh "$HOME/.config/xpdt/gate.sh" confirm cherry-pick "Cherry-pick [$SUBJ] onto $CUR?" || exit 0
if git -C "$ROOT" cherry-pick "$HASH" > /dev/tty 2>&1; then
  printf '\nCherry-picked onto %s.\n' "$CUR" > /dev/tty
  sleep 1
else
  git -C "$ROOT" cherry-pick --abort 2>/dev/null
  printf '\nConflict - cherry-pick aborted; %s is unchanged.\n' "$CUR" > /dev/tty
  sleep 1.8
fi
