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
    # Sorted with git's OWN version sort, descending, so the largest numbers are at the
    # top (feature-10 above feature-9, v1.10.0 above v1.9.0) and multi-digit numbers
    # order correctly - a plain reverse sort would put 9 above 10. git does the sort, so
    # this does not rely on `sort -V`, which BSD/macOS `sort` may not have. Locals first,
    # then remote-only branches; `awk !seen` dedupes while preserving that order (it
    # replaces the old `sort -u`, which sorted ascending and lexically).
    BR=$({ git -C "$ROOT" branch --format='%(refname:short)' --sort=-version:refname
           git -C "$ROOT" branch -r --format='%(refname:short)' --sort=-version:refname | grep -v '/HEAD$' | sed 's#^[^/]*/##'
         } | awk '!seen[$0]++' \
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
