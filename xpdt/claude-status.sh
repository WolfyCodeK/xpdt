#!/bin/sh
# Passive Claude Code session list for the `claude` panel (the `claude-integration`
# setting). Prints one line per recent Claude Code session that has worked in this
# repo, newest/active first, like:
#
#   * Cherry-pick commits between branches      (green dot = Claude is working now)
#   o Minimize downtime during droplet restart  (dim dot   = idle, waiting on you)
#
# No tmux / no processes involved: Claude Code stores each session as
# ~/.claude/projects/<encoded-cwd>/<id>.jsonl and appends a line per event. We read
# only the tail of each recently-modified file to get its name (the `ai-title`),
# which repo it is in (the `cwd`), its branch, and whether it is mid-turn.
#
# "Working now" = the session owes a response (its last user/assistant event is not
# a finished assistant turn) AND the file was written within ACTIVE_SEC (Claude
# appends events continuously while it runs tools/generates). Everything else that
# was touched within SHOWN_MIN is listed as idle. There is no true liveness signal
# in the logs (closing Claude leaves no marker), so recency is the only proxy.
ROOT="$1"
[ -z "$ROOT" ] && exit 0
grep -q '^claude-integration=1$' "$HOME/.config/xpdt/.gate-config" 2>/dev/null || exit 0
PROJ="$HOME/.claude/projects"
[ -d "$PROJ" ] || exit 0
SHOWN_MIN=20   # list sessions modified within this many minutes

find "$PROJ" -type f -name '*.jsonl' -not -path '*/subagents/*' -mmin "-$SHOWN_MIN" 2>/dev/null \
  | ROOT="$ROOT" python3 -c '
import sys, os, json, time

root = os.environ["ROOT"].rstrip("/")
now = time.time()
ACTIVE_SEC = 90      # "working now" freshness window
MAX_ROWS   = 5       # cap rows; overflow collapses into a "+N more" line
NAME_MAX   = 42
BR_MAX     = 14
TAIL       = 262144  # bytes of each file tail to read
HEAD       = 65536   # bytes to re-scan from the top if the title was not in the tail

DONE = ("end_turn", "stop_sequence")   # assistant stop_reasons that end a turn


def clean(s):
    s = "".join(c if c >= " " else " " for c in (s or ""))
    return " ".join(s.split())


def under_root(cwd):
    cwd = (cwd or "").rstrip("/")
    return cwd == root or cwd.startswith(root + "/")


def head_title(path):
    try:
        with open(path, "rb") as f:
            head = f.read(HEAD).decode("utf-8", "replace")
    except OSError:
        return None
    for line in head.splitlines():
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("type") == "ai-title" and d.get("aiTitle"):
            return d["aiTitle"]
    return None


rows = []
for path in sys.stdin.read().splitlines():
    path = path.strip()
    if not path:
        continue
    try:
        age = now - os.stat(path).st_mtime
    except OSError:
        continue
    try:
        with open(path, "rb") as f:
            try:
                f.seek(-TAIL, 2)
            except OSError:
                f.seek(0)
            tail = f.read().decode("utf-8", "replace").splitlines()
    except OSError:
        continue

    title = last_prompt = branch = None
    in_repo = False
    owes = None  # set from the newest user/assistant event
    for line in reversed(tail):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        t = d.get("type")
        if not in_repo and under_root(d.get("cwd")):
            in_repo = True
        if branch is None and d.get("gitBranch"):
            branch = d["gitBranch"]
        if title is None and t == "ai-title":
            title = d.get("aiTitle")
        if last_prompt is None and t == "last-prompt":
            last_prompt = d.get("lastPrompt")
        if owes is None:
            if t == "assistant":
                owes = d.get("message", {}).get("stop_reason") not in DONE
            elif t == "user":
                owes = True  # a user prompt / tool result: Claude owes a response

    if not in_repo:
        continue
    if title is None:
        title = head_title(path)

    name = clean(title) or clean(last_prompt) or os.path.basename(path)[:8]
    if len(name) > NAME_MAX:
        name = name[: NAME_MAX - 1].rstrip() + "…"
    br = clean(branch)
    if br in ("", "HEAD"):
        br = None
    elif len(br) > BR_MAX:
        br = br[: BR_MAX - 1] + "…"
    working = bool(owes) and age < ACTIVE_SEC
    rows.append((working, age, name, br))

if not rows:
    sys.exit(0)

# Working sessions first, then most-recently active.
rows.sort(key=lambda r: (not r[0], r[1]))

GRN = "\033[38;5;42m"   # working
DIM = "\033[38;5;245m"  # idle / branch
FNT = "\033[38;5;240m"  # "+N more"
Z = "\033[0m"

out = []
shown = rows[:MAX_ROWS]
for working, age, name, br in shown:
    if working:
        line = GRN + "●" + Z + " " + name
        if br:
            line += " " + DIM + "· " + br + Z
    else:
        line = DIM + "○ " + name
        if br:
            line += " · " + br
        line += Z
    out.append(line)
extra = len(rows) - len(shown)
if extra > 0:
    out.append(FNT + "  +" + str(extra) + " more" + Z)
sys.stdout.write("\n".join(out))
'
