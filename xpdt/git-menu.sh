#!/bin/sh
DIR="${XPLR_DIR:-$PWD}"
[ -f "$DIR" ] && DIR="$(dirname "$DIR")"
ROOT=$(sh "$HOME/.config/xpdt/repo-root.sh" "$DIR")
[ -z "$ROOT" ] && { printf '\nNot a git repo.\n'; sleep 0.8; exit 0; }

GATE="$HOME/.config/xpdt/gate.sh"
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
    sh "$GATE" confirm checkout "Checkout branch: $BR" || exit 0
    printf '\n'
    git -C "$ROOT" checkout "$BR"
    pause
    ;;
  'pull (ff-only)')
    sh "$GATE" confirm pull "git pull --ff-only" || exit 0
    printf '\n'
    git -C "$ROOT" pull --ff-only
    pause
    ;;
esac
