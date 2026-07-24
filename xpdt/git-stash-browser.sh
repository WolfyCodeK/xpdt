#!/bin/sh
# The `s` stash browser: fzf over `git stash list` with a diff+stat preview and
# single-key actions (apply / pop / drop / new / clear), lazygit style, so the
# list is --disabled --no-input and the letters are actions, not filter text.
# Mirrors git-changes-browser.sh (list resize on load, reload after each action).
X="$HOME/.config/xpdt"
DIR="${XPLR_DIR:-${XPLR_FOCUS_PATH:-$PWD}}"
[ -f "$DIR" ] && DIR="$(dirname "$DIR")"
ROOT="$(sh "$X/repo-root.sh" "$DIR")"
[ -z "$ROOT" ] && exit 0

# The repo root reaches the fzf binds through the ENVIRONMENT rather than being pasted
# into their command strings - fzf re-parses each bind with a shell, so a root path
# containing a quote or $(...) would otherwise be executed.
XPDT_ROOT="$ROOT"
export XPDT_ROOT
LIST="sh \"$X/git-stash-list.sh\" \"\$XPDT_ROOT\""

NENTRIES=$(git -C "$ROOT" stash list 2>/dev/null | grep -c .)
TERMH=$(stty size </dev/tty 2>/dev/null | awk '{print $1}')
[ -z "$TERMH" ] && TERMH=$(tput lines 2>/dev/null)
[ -z "$TERMH" ] && TERMH=40
MAXLIST=15

# {1} is the stash ref; empty when there are no stashes, so guard every action
# and show a hint in the preview instead of a git error.
HDR="$(sh "$X/wrap-header.sh" '[a] apply  [p] pop  [d] drop  [n] new  [x] clear all  [→] view  [←] back')"
# The list yields the (possibly wrapped) header lines plus the preview's top/bottom
# border to chrome; the preview gets the rest (see git-changes-browser.sh for why).
OVER=$(( $(printf '%s\n' "$HDR" | wc -l) + 2 ))
pv() { n=$1; [ "$n" -gt "$MAXLIST" ] && n=$MAXLIST; [ "$n" -lt 1 ] && n=1; p=$((TERMH - n - OVER)); [ "$p" -lt 3 ] && p=3; echo "$p"; }
PW=$(pv "$NENTRIES")

VIEW="git -C \"\$XPDT_ROOT\" stash show -p --color=never {1} | python3 -S \"$X/diff-words.py\""
PREVIEW="[ -n {1} ] && $VIEW || echo 'No stashes. Press n to stash your current changes.'"
RESIZE="n=\$FZF_TOTAL_COUNT; [ \$n -gt $MAXLIST ] && n=$MAXLIST; [ \$n -lt 1 ] && n=1; p=\$(($TERMH - n - $OVER)); [ \$p -lt 3 ] && p=3; echo \"change-preview-window(down,\$p,wrap)\""

eval "$LIST" \
  | fzf --ansi --no-sort --reverse --disabled --no-input \
      --header="$HDR" \
      --preview "$PREVIEW" \
      --preview-window "down,$PW,wrap" \
      --bind "load:transform:$RESIZE" \
      --bind "a:execute([ -n {1} ] && sh \"$X/git-stash-op.sh\" \"\$XPDT_ROOT\" apply {1})+reload($LIST)" \
      --bind "p:execute([ -n {1} ] && sh \"$X/git-stash-op.sh\" \"\$XPDT_ROOT\" pop {1})+reload($LIST)" \
      --bind "d:execute([ -n {1} ] && sh \"$X/git-stash-op.sh\" \"\$XPDT_ROOT\" drop {1})+reload($LIST)" \
      --bind "n:execute(sh \"$X/git-stash-op.sh\" \"\$XPDT_ROOT\" push)+reload($LIST)" \
      --bind "x:execute(sh \"$X/git-stash-op.sh\" \"\$XPDT_ROOT\" clear)+reload($LIST)" \
      --bind "right:execute([ -n {1} ] && $VIEW | less -R)" \
      --bind 'enter:ignore,left:abort' || true
