#!/bin/sh
DIR="${XPLR_DIR:-$PWD}"
[ -f "$DIR" ] && DIR="$(dirname "$DIR")"
ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)
[ -z "$ROOT" ] && { printf '\nNot a git repo.\n'; sleep 0.8; exit 0; }

flush() { python3 -c 'import termios, sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' 2>/dev/null; }
confirm() {
  c=$(python3 -c 'import random; print(random.randint(10, 99))')
  printf '%s\n' "$1"
  printf 'Type %s to confirm (anything else cancels): ' "$c"
  flush
  read -r a
  [ "$a" = "$c" ]
}
pause() { printf '\n[enter to continue] '; read -r _; }

CHOICE=$(printf '%s\n' \
  'status' \
  'fetch origin' \
  'checkout branch' \
  'pull (ff-only)' \
  | fzf --height=40% --reverse --cycle --prompt='git > ' --header="$(basename "$ROOT")" \
      --bind 'enter:accept,right:accept,left:abort')
[ -z "$CHOICE" ] && exit 0

case "$CHOICE" in
  'status')
    git -C "$ROOT" -c color.status=always status | less -R
    ;;
  'fetch origin')
    printf '\n'
    git -C "$ROOT" fetch origin
    pause
    ;;
  'checkout branch')
    if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
      printf '\nWorking tree has uncommitted changes; commit or stash before switching.\n'
      pause
      exit 0
    fi
    BR=$({ git -C "$ROOT" branch --format='%(refname:short)'; git -C "$ROOT" branch -r --format='%(refname:short)' | grep -v '/HEAD$' | sed 's#^[^/]*/##'; } | sort -u \
      | fzf --height=60% --reverse --prompt='checkout > ' --header='pick a branch' --bind 'enter:accept,right:accept,left:abort')
    [ -z "$BR" ] && exit 0
    if confirm "Checkout branch: $BR"; then
      printf '\n'
      git -C "$ROOT" checkout "$BR"
      pause
    else
      printf 'Cancelled.\n'
      sleep 0.6
    fi
    ;;
  'pull (ff-only)')
    if confirm "git pull --ff-only"; then
      printf '\n'
      git -C "$ROOT" pull --ff-only
      pause
    else
      printf 'Cancelled.\n'
      sleep 0.6
    fi
    ;;
esac
