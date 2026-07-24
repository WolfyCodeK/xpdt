#!/bin/sh
export NVIM_NOTTYFAST=1 # nvim (edit / :XpdtDiff) inherits this: skip the slow startup bg-colour query over SSH (E1568); see open-file.sh
X="$HOME/.config/xpdt"
. "$X/tmpflag.sh" # $XPDT_LEFT_EXIT, inherited by the nvim we launch below
DIR="${XPLR_DIR:-${XPLR_FOCUS_PATH:-$PWD}}"
[ -f "$DIR" ] && DIR="$(dirname "$DIR")"
ROOT="$(sh "$X/repo-root.sh" "$DIR")"
[ -z "$ROOT" ] && exit 0

# The repo root is handed to the fzf binds through the ENVIRONMENT rather than being
# pasted into their command strings. fzf re-parses each bind with a shell, so a root
# path containing a quote or $(...) would otherwise be executed; "$XPDT_ROOT" is
# expanded by that shell from the inherited value instead.
XPDT_ROOT="$ROOT"
export XPDT_ROOT
LIST="sh \"$X/git-changes-list.sh\" \"\$XPDT_ROOT\""

# Open the browser even with no changes (you can sit here and press r to refresh
# as changes land, or left to go back). Being in a git repo is still required - the
# ROOT guard above handles that. An empty list shows a hint in the preview.
ENTRIES=$(eval "$LIST")
NENTRIES=$(printf '%s\n' "$ENTRIES" | grep -c .)

TERMH=$(stty size </dev/tty 2>/dev/null | awk '{print $1}')
[ -z "$TERMH" ] && TERMH=$(tput lines 2>/dev/null)
[ -z "$TERMH" ] && TERMH=40
MAXFILES=20

HDR="$(sh "$X/wrap-header.sh" '[s] stage/unstage  [p] hunks  [d] discard  [c] commit  [r] refresh  [→] edit (unstaged) / diff (staged)')"
# Rows the list must yield to chrome: the (possibly wrapped) header lines plus the
# preview window's top and bottom border. Sizing the list to the item count means
# giving the preview whatever is left: preview = TERMH - items - OVER. Getting OVER
# wrong is what used to collapse the list to a couple of rows on a narrow terminal
# (the header wraps to several lines there, but the old code budgeted a flat +3).
OVER=$(( $(printf '%s\n' "$HDR" | wc -l) + 2 ))

# preview size for a given item count (clamped so the preview never fully vanishes)
pv() { n=$1; [ "$n" -gt "$MAXFILES" ] && n=$MAXFILES; p=$((TERMH - n - OVER)); [ "$p" -lt 3 ] && p=3; echo "$p"; }
PW=$(pv "$NENTRIES")

# `right` on an unstaged entry opens the working file in Neovim to edit. With the
# "nvim-diff-unstaged" setting on it opens with its changes shown inline against the
# index instead (:XpdtDiff, defined in nvim/init.lua), so you review the green/red diff
# and edit in place. Read once here; a toggle applies the next time you open the browser.
UNSTAGED_OPEN="cd \"\$XPDT_ROOT\" && nvim {3..}"
[ "$(sh "$X/gate.sh" get nvim-diff-unstaged)" = 1 ] && UNSTAGED_OPEN="cd \"\$XPDT_ROOT\" && nvim -c XpdtDiff {3..}"

DIFF="{ if [ {1} = staged ]; then git -C \"\$XPDT_ROOT\" diff --cached --color=never -- {3..}; else git -C \"\$XPDT_ROOT\" diff --color=never -- {3..}; fi; } | python3 -S \"$X/diff-words.py\""
# Re-run on every (re)load so the list keeps matching the current change count.
RESIZE="n=\$FZF_TOTAL_COUNT; [ \$n -gt $MAXFILES ] && n=$MAXFILES; p=\$(($TERMH - n - $OVER)); [ \$p -lt 3 ] && p=3; echo \"change-preview-window(down,\$p,wrap)\""

# Feed fzf the entries, or truly empty input when there are none (printf '%s\n' ""
# would emit one blank line, i.e. a phantom row). Every action is guarded on a
# non-empty focus so the keys are harmless no-ops on an empty list; r (refresh) is
# not guarded, so it always works.
{ [ -n "$ENTRIES" ] && printf '%s\n' "$ENTRIES"; } \
  | fzf --ansi --no-sort --reverse --disabled --no-input \
      --header="$HDR" \
      --preview "$DIFF" \
      --preview-window "down,$PW,wrap" \
      --bind "load:transform:$RESIZE" \
      --bind "s:execute([ -n {1} ] && sh \"$X/git-stage.sh\" \"\$XPDT_ROOT\" {1} {3..})+reload($LIST)" \
      --bind "d:execute([ -n {1} ] && sh \"$X/git-discard.sh\" \"\$XPDT_ROOT\" {1} {2} {3..})+reload($LIST)" \
      --bind "c:execute([ -n {1} ] && bash \"$X/git-commit.sh\" \"\$XPDT_ROOT\")+reload($LIST)" \
      --bind "p:execute([ -n {1} ] && sh \"$X/git-hunk-browser.sh\" \"\$XPDT_ROOT\" {1} {3..})+reload($LIST)" \
      --bind "r:reload($LIST)" \
      --bind "right:execute([ -n {1} ] && { if [ {1} = unstaged ]; then $UNSTAGED_OPEN; else sh \"$X/diff-view.sh\" \"\$XPDT_ROOT\" {1} {3..}; fi; sh \"$X/flush-input.sh\"; })+reload($LIST)" \
      --bind 'enter:ignore,left:abort' >/dev/null 2>&1 || true
