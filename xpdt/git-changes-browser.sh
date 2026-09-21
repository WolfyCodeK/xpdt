#!/bin/sh
export NVIM_NOTTYFAST=1 # nvim (edit / :XpdtDiff) inherits this: skip the slow startup bg-colour query over SSH (E1568); see open-file.sh
X="$HOME/.config/xpdt"
. "$X/tmpflag.sh" # $XPDT_LEFT_EXIT, inherited by the nvim we launch below
DIR="${XPLR_DIR:-${XPLR_FOCUS_PATH:-$PWD}}"
[ -f "$DIR" ] && DIR="$(dirname "$DIR")"
ROOT="$(sh "$X/repo-root.sh" "$DIR")"
[ -z "$ROOT" ] && exit 0

# The repo root is handed to the fzf binds through the environment rather than being
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

TERMH=$({ stty size </dev/tty; } 2>/dev/null | awk '{print $1}')
[ -z "$TERMH" ] && TERMH=$(tput lines 2>/dev/null)
[ -z "$TERMH" ] && TERMH=40
MAXFILES=20

# Context line above the keys: which repo, which branch, and where inside it you
# opened this from. The list covers the WHOLE repo, not the directory you were in, so
# without this it is easy to lose track of which repo you are acting on - particularly
# after `w` has hopped you between sibling repos.
#
# symbolic-ref, not rev-parse --abbrev-ref: the latter prints the literal "HEAD" on a
# detached or unborn head, where the short sha is what you actually want to see.
BRANCH=$(git -C "$ROOT" symbolic-ref --short -q HEAD 2>/dev/null)
[ -n "$BRANCH" ] || BRANCH=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)
# The path shown is relative to the repo root (empty at the root itself), which stays
# short and says more than an absolute path that is mostly $HOME.
REL=${DIR#"$ROOT"}
REL=${REL#/}
CTX="$(basename "$ROOT")${BRANCH:+ ($BRANCH)}${REL:+  $REL}"
HDR="$(printf '\033[38;5;110m%s\033[0m\n%s' "$CTX" "$(sh "$X/wrap-header.sh" '[s] stage/unstage  [p] hunks  [d] discard  [c] commit  [r] refresh  [ctrl-u/d] scroll diff  [→] edit (unstaged) / diff (staged)')")"
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
# `--` before the path: nvim parses a leading `+` as a startup COMMAND, so a file
# named `+!touch X` ran `:!touch X` on open - a filename in a cloned repo was enough.
# open-file.sh and edit-at.sh are safe because they absolutise the path first; this is
# the one invocation that passes a repo-relative name straight through.
UNSTAGED_OPEN="cd \"\$XPDT_ROOT\" && nvim -- {3..}"
[ "$(sh "$X/gate.sh" get nvim-diff-unstaged)" = 1 ] && UNSTAGED_OPEN="cd \"\$XPDT_ROOT\" && nvim -c XpdtDiff -- {3..}"

# An untracked file ({2} = ?) is in no diff at all, so `git diff` printed nothing and
# the preview sat empty. --no-index against /dev/null gives it a real diff - every line
# an addition - so a new file previews as pure green like any other add. It exits 1 when
# the files differ (always, here), hence the `|| true`. Tracked entries are unchanged.
#
# A wholly-untracked DIRECTORY is collapsed by porcelain to a single `dir/` entry, and
# --no-index on it made git resolve /dev/null relative to the directory and print
# `error: Could not access 'dir/null'` into the preview. Those get a file listing
# instead, which is what you actually want to see before staging a new folder.
DIFF="{ if [ {1} = staged ]; then git -C \"\$XPDT_ROOT\" diff --cached --color=never -- {3..}; elif [ {2} = '?' ] && [ -d \"\$XPDT_ROOT\"/{3..} ]; then printf 'untracked directory\\n\\n'; ( cd \"\$XPDT_ROOT\" && find {3..} -type f | sort | head -200 ); elif [ {2} = '?' ]; then git -C \"\$XPDT_ROOT\" diff --no-index --color=never -- /dev/null {3..} || true; else git -C \"\$XPDT_ROOT\" diff --color=never -- {3..}; fi; } | python3 -S \"$X/diff-words.py\" --syntax {3..}"
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
      --bind 'ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down' \
      --bind 'shift-up:preview-up,shift-down:preview-down' \
      --bind "right:execute([ -n {1} ] && { if [ {1} = unstaged ]; then $UNSTAGED_OPEN; else sh \"$X/diff-view.sh\" \"\$XPDT_ROOT\" {1} {3..}; fi; sh \"$X/flush-input.sh\"; })+reload($LIST)" \
      --bind 'enter:ignore,left:abort' >/dev/null 2>&1 || true
