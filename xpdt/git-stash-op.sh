#!/bin/sh
# Stash operations for the stash browser (git-stash-browser.sh).
# Args: ROOT OP [REF]   OP in: push apply pop drop clear
# push/apply/pop are safe (nothing is lost); drop and clear are destructive and
# confirm first (drop: y/N like a discard; clear: 2-digit code like the risky
# entries in the git menu).
ROOT="$1"; OP="$2"; REF="$3"
[ -z "$ROOT" ] && exit 0

flush() { python3 -c 'import termios,sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' </dev/tty 2>/dev/null; }
pause() { printf '\n[enter to continue] ' > /dev/tty; read -r _ < /dev/tty; }

case "$OP" in
  push)
    if [ -z "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]; then
      printf 'Nothing to stash - working tree is clean. ' > /dev/tty
      sleep 1
      exit 0
    fi
    flush
    printf 'Stash message (optional, enter to skip): ' > /dev/tty
    read -r msg < /dev/tty || exit 0
    if [ -n "$msg" ]; then
      git -C "$ROOT" stash push --include-untracked -m "$msg" > /dev/tty 2>&1
    else
      git -C "$ROOT" stash push --include-untracked > /dev/tty 2>&1
    fi
    sleep 0.8
    ;;
  apply|pop)
    [ -z "$REF" ] && exit 0
    # On success move on quickly; on conflict/error keep the output on screen.
    if git -C "$ROOT" stash "$OP" "$REF" > /dev/tty 2>&1; then
      sleep 0.8
    else
      pause
    fi
    ;;
  drop)
    [ -z "$REF" ] && exit 0
    flush
    printf 'Drop %s? (kept only in the reflog, hard to recover) [y/N] ' "$REF" > /dev/tty
    read -r ans < /dev/tty || exit 0
    case "$ans" in
      y|Y) git -C "$ROOT" stash drop "$REF" > /dev/tty 2>&1; sleep 0.8 ;;
      *) exit 0 ;;
    esac
    ;;
  clear)
    n=$(git -C "$ROOT" stash list 2>/dev/null | grep -c .)
    [ "$n" -eq 0 ] && { printf 'No stashes to clear. ' > /dev/tty; sleep 0.8; exit 0; }
    c=$(python3 -c 'import random; print(random.randint(10, 99))')
    flush
    printf 'Delete ALL %s stash(es)? Type %s to confirm (anything else cancels): ' "$n" "$c" > /dev/tty
    read -r a < /dev/tty || exit 0
    if [ "$a" = "$c" ]; then
      git -C "$ROOT" stash clear
      printf 'Cleared all stashes.\n' > /dev/tty
      sleep 0.8
    else
      printf 'Cancelled.\n' > /dev/tty
      sleep 0.6
    fi
    ;;
esac
