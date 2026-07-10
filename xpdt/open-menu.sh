#!/bin/sh
F="$XPLR_FOCUS_PATH"
[ -z "$F" ] && exit 0
[ -d "$F" ] && exit 0

CHOICE=$(printf '%s\n' \
  'open file' \
  'preview changes' \
  'open changes' \
  'preview staged' \
  'open staged' \
  | fzf --height=40% --reverse --cycle --prompt='open > ' --header="$(basename "$F")" \
      --bind 'right:accept,enter:ignore,left:abort')
[ -z "$CHOICE" ] && exit 0

ROOT=$(git -C "$(dirname "$F")" rev-parse --show-toplevel 2>/dev/null)
REL=""
[ -n "$ROOT" ] && REL="${F#$ROOT/}"
CACHE="${TMPDIR:-/tmp}/xplr-head"
mkdir -p "$CACHE"
HEADFILE="$CACHE/HEAD_$(basename "$F")"
STAGEDFILE="$CACHE/STAGED_$(basename "$F")"

case "$CHOICE" in
  'open file')
    open -a "Visual Studio Code" "$F"
    ;;
  'preview changes')
    [ -n "$ROOT" ] && git -C "$ROOT" diff HEAD --color=always -- "$REL" | less -R
    ;;
  'open changes')
    if [ -n "$ROOT" ]; then
      git -C "$ROOT" show "HEAD:$REL" > "$HEADFILE" 2>/dev/null || : > "$HEADFILE"
      code --diff "$HEADFILE" "$F"
    else
      open -a "Visual Studio Code" "$F"
    fi
    ;;
  'preview staged')
    [ -n "$ROOT" ] && git -C "$ROOT" diff --cached --color=always -- "$REL" | less -R
    ;;
  'open staged')
    if [ -n "$ROOT" ]; then
      git -C "$ROOT" show "HEAD:$REL" > "$HEADFILE" 2>/dev/null || : > "$HEADFILE"
      if git -C "$ROOT" show ":$REL" > "$STAGEDFILE" 2>/dev/null; then
        code --diff "$HEADFILE" "$STAGEDFILE"
      fi
    fi
    ;;
esac
