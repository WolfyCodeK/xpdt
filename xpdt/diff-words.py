#!/usr/bin/env python3
# Word-level diff highlighter for the fzf diff previews. Reads an UNCOLOURED
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
import sys
import re
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
    return s.replace("\t", "    ")


# A del/add pair is only word-diffed when the two lines are similar enough to be
# an edit of each other. Below this, a delete and an unrelated insert that merely
# landed next to each other would light up almost every word; treat those as a
# plain delete + plain insert (dim background, no word highlights) instead.
SIMILAR = 0.5


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


def emit_group(out, dels, adds):
    # dels/adds are the raw lines (including their leading -/+). Pair them up for
    # word-diffing; extra lines on either side are pure add/delete (dim bg only).
    n = min(len(dels), len(adds))
    masks_d = [None] * len(dels)
    masks_a = [None] * len(adds)
    for i in range(n):
        (dt, dm), (at, am), ratio = changed_masks(
            expand(dels[i][1:]), expand(adds[i][1:])
        )
        if ratio >= SIMILAR:
            masks_d[i] = (dt, dm)
            masks_a[i] = (at, am)
    for i, line in enumerate(dels):
        if masks_d[i] is not None:
            toks, mask = masks_d[i]
        else:
            toks, mask = TOKEN.findall(expand(line[1:])), None
        out.append(
            render_line(
                "-", DEL_SIGN, DEL_BG, DEL_STR, toks, mask or [False] * len(toks)
            )
        )
    for i, line in enumerate(adds):
        if masks_a[i] is not None:
            toks, mask = masks_a[i]
        else:
            toks, mask = TOKEN.findall(expand(line[1:])), None
        out.append(
            render_line(
                "+", ADD_SIGN, ADD_BG, ADD_STR, toks, mask or [False] * len(toks)
            )
        )


def main():
    lines = sys.stdin.read().split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    out = []
    i, n = 0, len(lines)
    while i < n:
        line = lines[i]
        is_del = line.startswith("-") and not line.startswith("---")
        is_add = line.startswith("+") and not line.startswith("+++")
        if is_del or is_add:
            dels, adds = [], []
            while i < n and lines[i].startswith("-") and not lines[i].startswith("---"):
                dels.append(lines[i])
                i += 1
            while i < n and lines[i].startswith("+") and not lines[i].startswith("+++"):
                adds.append(lines[i])
                i += 1
            emit_group(out, dels, adds)
            continue
        if line.startswith("@@"):
            out.append(HUNK + expand(line) + RESET)
        elif line.startswith(HDR_PREFIXES):
            out.append(HDR + expand(line) + RESET)
        elif line.startswith(META_PREFIXES):
            out.append(META + expand(line) + RESET)
        elif line.startswith(" "):
            out.append(CTX + expand(line) + RESET)
        else:
            out.append(GREY + expand(line) + RESET)
        i += 1
    sys.stdout.write("\n".join(out) + ("\n" if out else ""))


main()
