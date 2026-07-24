#!/bin/sh
X="$HOME/.config/xpdt"
DIR="${XPLR_DIR:-${XPLR_FOCUS_PATH:-$PWD}}"
[ -f "$DIR" ] && DIR="$(dirname "$DIR")"
ROOT="$(sh "$X/repo-root.sh" "$DIR")"
[ -z "$ROOT" ] && exit 0

REFF=$(mktemp)   # branch/ref being viewed; empty = current HEAD
trap 'rm -f "$REFF"' EXIT INT TERM
# The repo root and the ref-state file reach the fzf binds through the ENVIRONMENT
# rather than being pasted into their command strings: fzf re-parses each bind with a
# shell, so a path containing a quote or $(...) would otherwise be executed.
XPDT_ROOT="$ROOT"
XPDT_REFF="$REFF"
export XPDT_ROOT XPDT_REFF
LOG="sh \"$X/git-log-view.sh\" \"\$XPDT_ROOT\" \"\$XPDT_REFF\""
HDR="sh \"$X/git-log-header.sh\" \"\$XPDT_ROOT\" \"\$XPDT_REFF\""

while : ; do
  LINE=$(eval "$LOG" \
    | fzf --ansi --no-sort --reverse --prompt='commit > ' \
        --header="$(eval "$HDR")" \
        --preview "git -C \"\$XPDT_ROOT\" show --color=never {1} | python3 -S \"$X/diff-words.py\"" \
        --preview-window 'down,50%,wrap' \
        --bind "ctrl-z:execute(sh \"$X/git-undo.sh\" \"\$XPDT_ROOT\")+reload($LOG)" \
        --bind "b:execute(sh \"$X/git-branch-pick.sh\" \"\$XPDT_ROOT\" \"\$XPDT_REFF\")+reload($LOG)+transform-header($HDR)" \
        --bind "ctrl-p:execute(sh \"$X/git-cherry-pick.sh\" \"\$XPDT_ROOT\" {1})+reload($LOG)" \
        --bind 'right:accept,enter:ignore,left:abort')
  [ -z "$LINE" ] && break
  HASH=$(printf '%s\n' "$LINE" | awk '{print $1}')

  # core.quotePath=false keeps a non-ASCII filename raw; --name-status is TAB-separated,
  # so the file list below is read with a tab delimiter and {-1} (the last field, which
  # is the NEW name for a rename). With fzf's default whitespace delimiter, {-1} took
  # only the text after the last space, so any path with a space opened the wrong file.
  FILES=$(git -c core.quotePath=false -C "$ROOT" diff-tree --no-commit-id --name-status -r "$HASH")
  NFILES=$(printf '%s\n' "$FILES" | grep -c .)
  TERMH=$(stty size </dev/tty 2>/dev/null | awk '{print $1}')
  [ -z "$TERMH" ] && TERMH=$(tput lines 2>/dev/null)
  [ -z "$TERMH" ] && TERMH=40
  MAXFILES=20
  # A normal (filterable) fzf with no custom header: the list yields the prompt line,
  # the info line and the preview's top/bottom border (~4 rows) to chrome; the rest
  # goes to the preview. `right` opens the inline diff viewer; `enter` does nothing.
  N=$NFILES; [ "$N" -gt "$MAXFILES" ] && N=$MAXFILES; [ "$N" -lt 1 ] && N=1
  PW=$((TERMH - N - 4)); [ "$PW" -lt 3 ] && PW=3
  XPDT_HASH="$HASH"; export XPDT_HASH
  printf '%s\n' "$FILES" \
    | fzf --ansi --reverse --prompt="$HASH > " \
        --delimiter '\t' \
        --preview "git -C \"\$XPDT_ROOT\" show --color=never \"\$XPDT_HASH\" -- {-1} | python3 -S \"$X/diff-words.py\"" \
        --preview-window "down,$PW,wrap" \
        --bind "right:execute(sh \"$X/diff-view.sh\" \"\$XPDT_ROOT\" commit {-1} \"\$XPDT_HASH\")" \
        --bind 'enter:ignore,left:abort'
done
