#!/usr/bin/env python3
# Word-level diff highlighter for the fzf diff previews. Reads an uncoloured
# unified diff on stdin (git show/diff/stash show with --color=never) and writes
# it back coloured so that:
#   - a removed line gets a dim red background, an added line a dim green one
#     (the whole "sentence" is tinted, matching the inline diff viewer);
#   - within a changed line, the exact words that differ get a brighter, bolder
#     background (bright red for what was removed, bright green for what is new),
#     so a one-word edit stands out instead of the whole line reading as changed.
#
# Removed/added lines are paired positionally inside each hunk (the i-th `-` line
# with the i-th `+` line) and word-diffed with difflib; lines with no counterpart
# (a pure add or delete) keep just the dim background. Operating on the plain diff
# (no ANSI in) keeps this simple and lossless - we own every colour we emit.
#
# With `--syntax PATH` the line content is additionally syntax-highlighted by bat,
# using PATH only to pick the language, so a diff reads as code rather than as two
# flat colours. The add/remove backgrounds and the word-level highlights are then
# overlaid on top of bat's colouring (see tint). bat is optional: if it is missing,
# fails, or returns the wrong number of lines, every line falls back to the flat
# colouring below, so the preview degrades instead of breaking.
import sys
import os
import re
import shutil
import subprocess
import threading
import difflib

RESET = "\x1b[0m"
NOBOLD = "\x1b[22m"

CTX = "\x1b[38;5;250m"  # context lines
GREY = "\x1b[38;5;244m"  # blank / message body
HDR = "\x1b[1;38;5;110m"  # file headers (diff --git, ---, +++, index, ...)
HUNK = "\x1b[38;5;73m"  # @@ ... @@ hunk headers
META = "\x1b[38;5;179m"  # commit / Author / Date (git show)

DEL_BG = "\x1b[48;2;74;38;42m"  # dim red line background
DEL_STR = "\x1b[48;2;140;46;54m"  # bright red word background
ADD_BG = "\x1b[48;2;34;64;44m"  # dim green line background
ADD_STR = "\x1b[48;2;50;120;70m"  # bright green word background
DEL_SIGN = "\x1b[38;5;203m"  # the leading - sign
ADD_SIGN = "\x1b[38;5;114m"  # the leading + sign
LINE_FG = "\x1b[38;5;252m"  # text on a tinted line
STR_FG = "\x1b[1;38;5;231m"  # text of a changed word (white + bold)

TOKEN = re.compile(r"\s+|\w+|[^\w\s]")

HDR_PREFIXES = (
    "diff --git",
    "index ",
    "--- ",
    "+++ ",
    "old mode",
    "new mode",
    "new file",
    "deleted file",
    "copy from",
    "copy to",
    "rename from",
    "rename to",
    "similarity index",
    "dissimilarity index",
    "Binary files",
    "\\ No newline",
)
META_PREFIXES = (
    "commit ",
    "Author:",
    "AuthorDate:",
    "Commit:",
    "CommitDate:",
    "Date:",
    "Merge:",
)


def expand(s):
    # ESC is stripped, not just tabs. `--color=never` only stops git adding colour; a
    # file that itself contains an ESC byte (a terminal capture, an icon preview) still
    # carries it through. Tokenising raw text and splicing our own codes in at token
    # boundaries then landed them INSIDE a content escape, tearing it in half, and a
    # content reset mid-line killed the row tint and broke fzf soft-wrap. It also
    # desynchronised the word mask from bat's output, which has consumed those escapes.
    return s.replace("\t", "    ").replace("\x1b", "")


# A del/add pair is only word-diffed when the two lines are similar enough to be
# an edit of each other. Below this, a delete and an unrelated insert that merely
# landed next to each other would light up almost every word; treat those as a
# plain delete + plain insert (dim background, no word highlights) instead.
SIMILAR = 0.5


ANSI = re.compile(r"\x1b\[[0-9;]*m")


def _bat_cmd(path):
    bat = shutil.which("bat")
    if not bat:
        return None
    return [
        bat,
        "--color=always",
        "--plain",
        "--paging=never",
        # A user ~/.config/bat/config is otherwise honoured here: a --wrap or
        # --terminal-width in it changes the line count, the length check below
        # fails, and syntax highlighting silently disappears for good.
        "--no-config",
        "--wrap=never",
        "--tabs=0",  # tabs are already expanded, so do not expand them twice
        "--file-name",
        os.path.basename(path),
    ]


def _collect(proc, lines):
    """Feed one bat process its input and map its output back onto `lines`, or None if
    anything is off - callers then fall back to flat colouring rather than mis-colour
    the diff.

    communicate() does the writing: feeding stdin by hand and closing it before calling
    communicate() makes communicate() raise on the closed handle, which the guard below
    then swallowed - syntax highlighting silently vanished while everything still
    rendered, because the flat fallback produces identical visible text. Letting
    communicate() own stdin also avoids deadlocking on a diff larger than the pipe
    buffer."""
    if proc is None:
        return None
    try:
        # Trailing newline matters: without it, a side whose last line is EMPTY loses
        # that line (bat emits N-1 terminated lines, the split-and-pop then yields
        # N-1), the length check below fails, and syntax highlighting silently falls
        # back to flat - which is most multi-file diffs, since a hunk commonly ends on
        # a blank line.
        out, _ = proc.communicate(input="\n".join(lines) + "\n", timeout=5)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass
        return None
    if proc.returncode != 0:
        return None
    got = out.split("\n")
    if got and got[-1] == "":
        got.pop()
    # A length mismatch means the mapping back onto diff lines would be wrong.
    return got if len(got) == len(lines) else None


def highlight_sides(old, new, path):
    """Syntax-colour the old and new sides, with both bat processes started up front.

    This is an fzf --preview, so it re-runs on every arrow key in the changes browser
    and bat's startup dominates: starting the second before waiting on the first
    overlaps that cost. Either side may be empty (a new file has no old side), and that
    side is not spawned at all."""
    if not path:
        return None, None
    cmd = _bat_cmd(path)
    if cmd is None:
        return None, None

    def spawn(lines):
        if not lines:
            return None
        try:
            return subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
        except Exception:
            return None

    po, pn = spawn(old), spawn(new)
    # Collected on threads so both bat processes are fed and read at the same time.
    # Collecting them in sequence does not overlap: communicate() owns stdin, so the
    # second process just sits blocked on an unfed pipe until the first finishes, and
    # the concurrency is only in the spawn.
    out = {}

    def collect(key, proc, lines):
        out[key] = _collect(proc, lines)

    to = threading.Thread(target=collect, args=("old", po, old))
    tn = threading.Thread(target=collect, args=("new", pn, new))
    to.start()
    tn.start()
    to.join(timeout=10)
    tn.join(timeout=10)
    return out.get("old"), out.get("new")


def column_mask(toks, mask):
    """Turn a per-token changed-mask into a per-visible-column one, so the word
    highlights can be located inside a string that also contains escape codes."""
    cols = []
    for tok, ch in zip(toks, mask):
        cols.extend([ch] * len(tok))
    return cols


def tint(ansi, cols, sign, sign_fg, base_bg, str_bg):
    """Overlay the line background - and the brighter word backgrounds - onto an
    already syntax-coloured line. bat emits a reset after every token, which would
    drop our background, so it is re-asserted after each one; the word spans are
    located by visible column, stepping over escape sequences."""
    out = [base_bg, sign_fg, sign]
    cur = base_bg
    out.append(cur)
    i, col = 0, 0
    while i < len(ansi):
        m = ANSI.match(ansi, i)
        if m:
            out.append(m.group(0))
            if m.group(0) == RESET:
                out.append(cur)  # bat reset our background away; put it back
            i = m.end()
            continue
        want = str_bg if (col < len(cols) and cols[col]) else base_bg
        if want != cur:
            out.append(want)
            cur = want
        out.append(ansi[i])
        col += 1
        i += 1
    out.append(RESET)
    return "".join(out)


def changed_masks(a, b):
    at, bt = TOKEN.findall(a), TOKEN.findall(b)
    am = [False] * len(at)
    bm = [False] * len(bt)
    sm = difflib.SequenceMatcher(None, at, bt, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag != "equal":
            for k in range(i1, i2):
                am[k] = True
            for k in range(j1, j2):
                bm[k] = True
    return (at, am), (bt, bm), sm.ratio()


def render_line(sign, sign_fg, base_bg, str_bg, toks, mask):
    # bg stays active for the whole line; changed tokens swap to the bright bg and
    # back without ever emitting a full RESET mid-line (so it survives soft-wrap).
    parts = [base_bg, sign_fg, sign, LINE_FG]
    for tok, ch in zip(toks, mask):
        if ch:
            parts.append(str_bg + STR_FG + tok + NOBOLD + base_bg + LINE_FG)
        else:
            parts.append(tok)
    parts.append(RESET)
    return "".join(parts)


def emit_group(out, dels, adds, old_hl, new_hl):
    # dels/adds are classify() records. Pair them up for word-diffing; extra lines on
    # either side are pure add/delete (dim bg only).
    n = min(len(dels), len(adds))
    masks_d = [None] * len(dels)
    masks_a = [None] * len(adds)
    for i in range(n):
        (dt, dm), (at, am), ratio = changed_masks(
            expand(dels[i][1][1:]), expand(adds[i][1][1:])
        )
        if ratio >= SIMILAR:
            masks_d[i] = (dt, dm)
            masks_a[i] = (at, am)

    def emit(side, masks, hl, col, sign, sign_fg, base_bg, str_bg):
        for i, rec in enumerate(side):
            text = expand(rec[1][1:])
            if masks[i] is not None:
                toks, mask = masks[i]
            else:
                toks, mask = TOKEN.findall(text), None
            mask = mask or [False] * len(toks)
            idx = rec[col]
            if hl is not None and idx is not None and idx < len(hl):
                out.append(
                    tint(
                        hl[idx], column_mask(toks, mask), sign, sign_fg, base_bg, str_bg
                    )
                )
            else:
                out.append(render_line(sign, sign_fg, base_bg, str_bg, toks, mask))

    emit(dels, masks_d, old_hl, 2, "-", DEL_SIGN, DEL_BG, DEL_STR)
    emit(adds, masks_a, new_hl, 3, "+", ADD_SIGN, ADD_BG, ADD_STR)


def classify(lines):
    """Split the diff into records and tag each body line with its position in the
    old-side and new-side content streams (a context line is in both). Those two
    streams are what gets syntax-highlighted, so each side is coloured with its own
    correct context instead of with the two interleaved."""
    recs, old, new = [], [], []
    in_hunk = False
    for line in lines:
        if line.startswith("diff --git ") or line.startswith("diff --cc "):
            in_hunk = False
        if line.startswith("@@"):
            in_hunk = True
            recs.append(("hunk", line, None, None))
            continue
        if in_hunk:
            # Position, not prefix. Classifying `---`/`+++` as headers anywhere meant a
            # deleted line whose own text starts with `-- ` (a Lua, SQL or Haskell
            # comment, YAML front matter) arrived as `--- ...` and rendered as a blue
            # file header with no red tint and no word diff - and an added `++i;`
            # arrived as `+++i;` and rendered grey. Inside a hunk the first character
            # is always the marker, so there is nothing to disambiguate.
            if line.startswith("-"):
                recs.append(("del", line, len(old), None))
                old.append(expand(line[1:]))
                continue
            if line.startswith("+"):
                recs.append(("add", line, None, len(new)))
                new.append(expand(line[1:]))
                continue
            if line.startswith("\\"):
                # "\ No newline at end of file" - a marker, not content.
                recs.append(("hdr", line, None, None))
                continue
            if line.startswith(" ") or line == "":
                recs.append(("ctx", line, len(old), len(new)))
                old.append(expand(line[1:]))
                new.append(expand(line[1:]))
                continue
            in_hunk = False
        if line.startswith(HDR_PREFIXES):
            recs.append(("hdr", line, None, None))
        elif line.startswith(META_PREFIXES):
            recs.append(("meta", line, None, None))
        elif line.startswith(" "):
            recs.append(("ctx", line, None, None))
        else:
            recs.append(("other", line, None, None))
    return recs, old, new


def main():
    path = None
    argv = sys.argv[1:]
    if "--syntax" in argv:
        k = argv.index("--syntax")
        if k + 1 < len(argv):
            path = argv[k + 1]

    lines = sys.stdin.read().split("\n")
    if lines and lines[-1] == "":
        lines.pop()

    recs, old, new = classify(lines)
    old_hl, new_hl = highlight_sides(old, new, path)

    out = []
    i, n = 0, len(recs)
    while i < n:
        kind, line, oi, ni = recs[i]
        if kind in ("del", "add"):
            dels, adds = [], []
            while i < n and recs[i][0] == "del":
                dels.append(recs[i])
                i += 1
            while i < n and recs[i][0] == "add":
                adds.append(recs[i])
                i += 1
            emit_group(out, dels, adds, old_hl, new_hl)
            continue
        if kind == "hunk":
            out.append(HUNK + expand(line) + RESET)
        elif kind == "hdr":
            out.append(HDR + expand(line) + RESET)
        elif kind == "meta":
            out.append(META + expand(line) + RESET)
        elif kind == "ctx":
            # Context keeps the syntax colour with no background, so the eye reads the
            # tinted add/remove rows as the changes and everything else as plain code.
            if new_hl is not None and ni is not None and ni < len(new_hl):
                out.append(" " + new_hl[ni] + RESET)
            else:
                out.append(CTX + expand(line) + RESET)
        else:
            out.append(GREY + expand(line) + RESET)
        i += 1
    sys.stdout.write("\n".join(out) + ("\n" if out else ""))


main()
