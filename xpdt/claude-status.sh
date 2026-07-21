#!/bin/sh
# Passive Claude Code session panel (the `claude-integration` setting). Shows ALL
# your recent Claude Code sessions across every repo - not just the current one -
# grouped by repo, newest/busiest first, e.g.:
#
#   xpdt (main)
#     * Cherry-pick commits between branches   58%  2m   (green * = working now)
#     ! Minimize downtime during restart       12%  9m   (amber ! = waiting on you)
#   gilded (economy-fix)  2 on this branch
#     o Refactor the payout ledger             91% 1h    (dim o = idle / stale)
#   2 working - 1 waiting - 1 idle
#
# Everything comes from the session logs (~/.claude/projects/<enc>/<id>.jsonl) - no
# tmux, no process inspection. Per session we read only the tail for: name
# (ai-title), current task (last-prompt), cwd, branch, model, token usage (-> a
# rough context %), the newest user/assistant event (-> working/waiting/idle) and
# recency. The repo is the git top-level of the session's main cwd.
ROOT="$1"
grep -q '^claude-integration=1$' "$HOME/.config/xpdt/.gate-config" 2>/dev/null || exit 0
PROJ="$HOME/.claude/projects"
[ -d "$PROJ" ] || exit 0
SHOWN_MIN=180 # list sessions active within this many minutes

# Terminal width, so a session name truncates at the window edge rather than a fixed
# cap. Invoked via io.popen at render time (stdout is a pipe, not a tty), so read the
# size from the controlling terminal directly.
COLS=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
[ -z "$COLS" ] && COLS=$(tput cols 2>/dev/null)
[ -z "$COLS" ] && COLS=100

find "$PROJ" -type f -name '*.jsonl' -not -path '*/subagents/*' -mmin "-$SHOWN_MIN" 2>/dev/null \
  | ROOT="$ROOT" COLS="$COLS" python3 -S -c '
import sys, os, json, time, subprocess

root = os.environ.get("ROOT", "").rstrip("/")
now = time.time()
ACTIVE = 90         # "working now" freshness
WAIT = 30 * 60      # a finished turn newer than this = "waiting on you"
MAX_ROWS = 6        # cap sessions shown; the rest collapse into "+N more"
TAIL = 262144
HEAD = 65536
DONE = ("end_turn", "stop_sequence")

# colours
GRN = "\033[38;5;42m"    # working
AMB = "\033[38;5;214m"   # waiting on you
DIM = "\033[38;5;245m"   # idle / branch / metrics
FNT = "\033[38;5;240m"   # footer / task
HDR = "\033[1;38;5;110m" # repo header
WARN = "\033[38;5;209m"  # conflict
RED = "\033[38;5;203m"   # near-full context
Z = "\033[0m"

COLS = int(os.environ.get("COLS") or 100)
INNER = max(24, COLS - 4)  # claude panel content width (allow for borders/padding)

def truncate(s, width):
    width = max(4, width)
    if len(s) <= width:
        return s
    return s[:width - 1].rstrip() + "…"

_toplevel = {}
def repo_of(cwd):
    if not cwd:
        return ""
    if cwd in _toplevel:
        return _toplevel[cwd]
    try:
        r = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, timeout=2)
        top = r.stdout.strip() if r.returncode == 0 else cwd
    except Exception:
        top = cwd
    _toplevel[cwd] = top
    return top

def clean(s):
    s = "".join(c if c >= " " else " " for c in (s or ""))
    return " ".join(s.split())

def fmt_age(sec):
    sec = int(sec)
    if sec < 60: return "%ds" % sec
    if sec < 3600: return "%dm" % (sec // 60)
    if sec < 86400: return "%dh" % (sec // 3600)
    return "%dd" % (sec // 86400)

def ctx_pct(u):
    if not u:
        return None
    tot = (u.get("input_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0) + (u.get("cache_read_input_tokens") or 0)
    if tot <= 0:
        return None
    window = 1000000 if tot > 200000 else 200000  # best-effort: 1M vs 200k
    return max(1, round(100 * tot / window))

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
            try: f.seek(-TAIL, 2)
            except OSError: f.seek(0)
            tail = f.read().decode("utf-8", "replace").splitlines()
    except OSError:
        continue
    title = last_prompt = branch = model = None
    usage = None
    owes = None
    cwd_counts = {}
    for line in reversed(tail):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        t = d.get("type")
        c = d.get("cwd")
        if c and not c.startswith(os.path.expanduser("~/.claude")):
            cwd_counts[c] = cwd_counts.get(c, 0) + 1
        if branch is None and d.get("gitBranch"):
            branch = d["gitBranch"]
        if t == "ai-title" and title is None:
            title = d.get("aiTitle")
        elif t == "last-prompt" and last_prompt is None:
            last_prompt = d.get("lastPrompt")
        elif t == "assistant":
            m = d.get("message", {})
            if model is None:
                model = m.get("model")
            if usage is None and m.get("usage"):
                usage = m.get("usage")
            if owes is None:
                owes = m.get("stop_reason") not in DONE
        elif t == "user" and owes is None:
            owes = True
    cwd = max(cwd_counts, key=cwd_counts.get) if cwd_counts else ""
    repo = repo_of(cwd)
    if title is None:
        title = head_title(path)
    name = clean(title) or clean(last_prompt) or os.path.basename(path)[:8]
    if owes and age < ACTIVE:
        status = "working"
    elif (owes is False) and age < WAIT:
        status = "waiting"
    else:
        status = "idle"
    rows.append({
        "status": status, "age": age, "name": name, "repo": repo,
        "branch": clean(branch), "model": (model or "").split("-")[1] if model and "-" in model else "",
        "pct": ctx_pct(usage), "task": clean(last_prompt),
    })

if not rows:
    sys.exit(0)

order = {"working": 0, "waiting": 1, "idle": 2}
rows.sort(key=lambda r: (order[r["status"]], r["age"]))
shown = rows[:MAX_ROWS]
extra = len(rows) - len(shown)

# group by repo, current repo first, then by the busiest session in each
groups = {}
for r in shown:
    groups.setdefault(r["repo"], []).append(r)
def group_key(item):
    repo, rs = item
    return (repo != root, min(order[r["status"]] for r in rs), min(r["age"] for r in rs))

out = []
tasks_left = 2  # only annotate the top couple of working sessions with their task
for repo, rs in sorted(groups.items(), key=group_key):
    label = os.path.basename(repo) or repo or "(no repo)"
    branches = {r["branch"] for r in rs if r["branch"] and r["branch"] != "HEAD"}
    head = HDR + label
    if len(branches) == 1:
        head += " (" + next(iter(branches)) + ")"
    head += Z
    active = [r for r in rs if r["status"] in ("working", "waiting")]
    if len(active) > 1 and len({r["branch"] for r in active}) == 1:
        head += "  " + WARN + str(len(active)) + " on this branch" + Z
    out.append(head)
    for r in rs:
        if r["status"] == "working":
            dot, col = GRN + "●", GRN
        elif r["status"] == "waiting":
            dot, col = AMB + "◆", AMB
        else:
            dot, col = DIM + "○", DIM
        # Metadata (context %, age, non-default model), built twice: plain to measure
        # its width, coloured to print - so the name can fill the row to the window
        # edge and only truncate what would not fit before the metadata.
        meta_plain, meta_col = [], []
        if r["pct"] is not None:
            pc = RED if r["pct"] >= 85 else (AMB if r["pct"] >= 60 else DIM)
            meta_plain.append(str(r["pct"]) + "%")
            meta_col.append(pc + str(r["pct"]) + "%" + Z)
        meta_plain.append(fmt_age(r["age"]))
        meta_col.append(DIM + fmt_age(r["age"]) + Z)
        if r["model"] and r["model"] not in ("opus",):
            meta_plain.append(r["model"])
            meta_col.append(FNT + r["model"] + Z)
        meta_w = len(" ".join(meta_plain)) + 2  # + the "  " gap before the metadata
        name = truncate(r["name"], INNER - 4 - meta_w)  # 4 = "  " + dot + " "
        line = "  " + dot + Z + " " + col + name + Z
        if meta_col:
            line += "  " + " ".join(meta_col)
        out.append(line)
        if r["status"] == "working" and r["task"] and tasks_left > 0:
            tasks_left -= 1
            out.append("    " + FNT + truncate(r["task"], INNER - 4) + Z)

nw = sum(1 for r in rows if r["status"] == "working")
nq = sum(1 for r in rows if r["status"] == "waiting")
ni = sum(1 for r in rows if r["status"] == "idle")
summary = []
if nw: summary.append(GRN + str(nw) + " working" + Z)
if nq: summary.append(AMB + str(nq) + " waiting" + Z)
if ni: summary.append(DIM + str(ni) + " idle" + Z)
foot = FNT + " · ".join(s for s in summary) if summary else ""
if extra > 0:
    foot = (foot + FNT + "   +" + str(extra) + " more" + Z) if foot else FNT + "+" + str(extra) + " more" + Z
if foot:
    out.append(foot)

sys.stdout.write("\n".join(out))
'
