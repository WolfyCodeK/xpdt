#!/bin/sh
# The `c` full-screen Claude window: every recent Claude Code session, in full, in a
# scrollable popup. The small `claude` box in the layout stays as the at-a-glance
# indicator; this is the same data with nothing capped or truncated - all sessions
# (not the box's top 6), full titles and full current-task text (wrapped, not cut),
# each session's context %, age and model, grouped by repo with the current repo
# first, over a 7-day window rather than the box's 3 hours.
#
# Read-only: it shows sessions, it never touches them. claude-status.sh does the scan
# and the rendering in its `full` mode, so the box and this window can never disagree
# about a session's state.
#
# Gated on the claude-integration setting, but bound unconditionally: pressing `c`
# with the feature off says so and points at the `,` menu, which is friendlier than a
# dead key. The setting is read at each press, so toggling it needs no relaunch.
X="$HOME/.config/xpdt"

if [ "$(sh "$X/gate.sh" get claude-integration)" != 1 ]; then
  { printf '\033[2J\033[H' > /dev/tty; } 2>/dev/null
  printf '\n  The Claude session list is off.\n' > /dev/tty
  printf '  Turn on "Claude session list" in the , settings menu (GENERAL).\n' > /dev/tty
  sleep 2
  exit 0
fi

# Group the current repo first, like the box does. Falls back to the plain directory
# when we are not in a repo, which claude-status.sh treats as "no current repo".
ROOT="$(sh "$X/repo-root.sh" "$PWD")"
[ -z "$ROOT" ] && ROOT="$PWD"

BODY=$(sh "$X/claude-status.sh" "$ROOT" full)
if [ -z "$BODY" ]; then
  { printf '\033[2J\033[H' > /dev/tty; } 2>/dev/null
  printf '\n  No Claude Code sessions in the last 7 days.\n' > /dev/tty
  sleep 1.6
  exit 0
fi

# `r` re-runs the scan in place. reload-sync so the list is rebuilt before fzf
# repaints, matching how the settings menu reloads.
printf '%s\n' "$BODY" | sh "$X/popup.sh" \
  "claude sessions      [r] refresh    [←/q] close" \
  "r:reload-sync(sh \"$X/claude-status.sh\" \"$ROOT\" full)"
