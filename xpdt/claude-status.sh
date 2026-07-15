#!/bin/sh
# Passive Claude Code session indicator for the git-history panel (the
# `claude-integration` setting). Prints a short coloured line like
# "◆ claude · <branch>" when a Claude Code session has been active in the given
# repo within the last ACTIVE_MIN minutes, otherwise nothing.
#
# No tmux / no processes involved: Claude Code stores each session as
# ~/.claude/projects/<encoded-cwd>/<id>.jsonl and records the session `cwd` and
# `gitBranch` on its lines. "Active" = such a file modified recently; we read the
# cwd/branch from the recent ones and keep those under this repo.
ROOT="$1"
[ -z "$ROOT" ] && exit 0
grep -q '^claude-integration=1$' "$HOME/.config/xpdt/.gate-config" 2>/dev/null || exit 0
PROJ="$HOME/.claude/projects"
[ -d "$PROJ" ] || exit 0
ACTIVE_MIN=10

find "$PROJ" -type f -name '*.jsonl' -mmin "-$ACTIVE_MIN" 2>/dev/null \
  | ROOT="$ROOT" python3 -c '
import sys, os, json
root = os.environ["ROOT"].rstrip("/")
count = 0
branches = []
for path in sys.stdin.read().splitlines():
    path = path.strip()
    if not path:
        continue
    cwd = branch = None
    try:
        with open(path, "rb") as f:
            try:
                f.seek(-65536, 2)     # only the tail: the last line carries cwd/gitBranch
            except OSError:
                f.seek(0)
            tail = f.read().decode("utf-8", "replace")
        for line in reversed(tail.splitlines()):
            try:
                d = json.loads(line)
            except Exception:
                continue
            if cwd is None:
                cwd = d.get("cwd")
            if branch is None:
                branch = d.get("gitBranch")
            if cwd and branch:
                break
    except Exception:
        continue
    if not cwd:
        continue
    cwd = cwd.rstrip("/")
    if cwd == root or cwd.startswith(root + "/"):
        count += 1
        b = branch or "?"
        if b not in branches:
            branches.append(b)
if count:
    M = "\033[38;5;209m"; D = "\033[38;5;245m"; Z = "\033[0m"
    label = ", ".join(branches[:3])
    if count > 1:
        label = str(count) + " sessions · " + label
    sys.stdout.write(M + "◆" + Z + " " + D + label + Z)
'
