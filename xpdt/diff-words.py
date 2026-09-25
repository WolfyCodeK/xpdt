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

MAX_GROUPS = 8  # bat processes per side

# A backstop against a wedged bat, not a performance budget - it is deliberately far
# above any real cost so that the same diff always renders the same way. A tight
# timeout was tried and reverted: bat's cost is a property of the language, not of the
# input size (47 kB of Lua highlights in 0.10s and 19 kB of Python in 0.08s, while
# 14 kB of long-line Markdown takes 0.70s and 400 such lines take 2.85s - syntect is
# pathological on long Markdown lines, and the same bytes named .txt take 0.02s), so
# no single cutoff separates "slow language" from "slow machine". At 0.6s this README's
# own diffs landed right on the boundary and highlighting flickered on and off between
# renders. Letting it finish costs at worst a few hundred ms of preview lag, which fzf
# renders asynchronously anyway - it never delays a keypress - and is the same cost the
# changes browser has always paid on the same files.
BAT_TIMEOUT = 5


def _bat_cmd(bat, path):
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


def _collect(proc, lines, timeout=BAT_TIMEOUT):
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
        out, _ = proc.communicate(input="\n".join(lines) + "\n", timeout=timeout)
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


def _group_key(path):
    """Group paths by what bat keys its language off: the extension, or the whole name
    when there is none (Makefile, Dockerfile)."""
    name = os.path.basename(path)
    ext = os.path.splitext(name)[1]
    return ext.lower() if ext else name


# A hunk is a fragment of a file, so bat starts parsing it with no state. When the
# fragment opens on the CLOSING half of a multi-line construct - the `"""` that ends a
# Python docstring, a `*/`, a `-->` - syntect reads it as an opening one instead and
# colours everything after it as string or comment content, which on screen reads as no
# highlighting at all. Feeding bat the matching opener first puts it in the state the
# real file would have had at that line, and the extra line is dropped from the output.
#
# Only a first line that is the delimiter and nothing else counts. A fragment starting
# `"""Module docstring.` really is opening one and highlights correctly already, and a
# lone `"""` further down is usually a docstring being opened under a `def`, where a
# primer would make things worse - so the fix is deliberately limited to the case the
# state is unambiguous.
OPENER_FOR = {
    '"""': '"""',
    "'''": "'''",
    "*/": "/*",
    "-->": "<!--",
    "*)": "(*",
    "=end": "=begin",
}


def _primer(lines):
    """The opener a fragment is missing, or None if it is not missing one.

    Only a first line that is the delimiter and nothing else is considered, because
    that is where the fragment's state is decidable. A fragment starting
    `\"\"\"Module docstring.` is genuinely opening one and already highlights correctly.
    """
    if not lines:
        return None
    first = lines[0].strip()
    opener = OPENER_FOR.get(first)
    if opener is None:
        return None
    if opener != first:
        # An asymmetric pair (*/ closes /*): a closing token on the first line cannot
        # have been opened inside the fragment, so the construct began above it.
        return opener
    # A symmetric pair (\"\"\" both opens and closes), so count them instead. An odd
    # number means the first one has no partner in the fragment and is closing
    # something that started above - prime it. An even number means they pair up here
    # and the first is opening a docstring under a def, where a primer would push
    # every line one state out and make the colouring worse rather than better.
    return opener if sum(ln.strip() == first for ln in lines) % 2 else None


def _spawn(cmd):
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


def highlight_sides(old, new, path, old_paths, new_paths):
    """Syntax-colour the old and new sides, returning a list per side the same length as
    its input, holding the coloured line or None where colouring was not possible. A
    None falls back to flat colouring at the point of use, so one file failing does not
    cost the rest of the diff its highlighting.

    `path` (from --syntax) forces one language over the whole diff, which is what a
    caller previewing a single file passes. Without it the language is taken per file
    from the diff's own `---` / `+++` headers, so a commit or a stash touching several
    files - which is most of what the history and stash browsers show - is coloured file
    by file instead of not at all. Lines are grouped by extension rather than by file so
    that a commit touching twenty shell scripts still costs one bat process per side,
    and the groups are capped: past MAX_GROUPS the biggest are the ones that get
    coloured, since they are the bulk of what is on screen.

    This is an fzf --preview, so it re-runs on every arrow key and bat's startup
    dominates. Every process is therefore started before any of them is fed, and they
    are fed and read on threads - communicate() owns stdin, so collecting in sequence
    would leave each process blocked on an unfed pipe until the one before it finished.
    """
    bat = shutil.which("bat")
    if not bat:
        return None, None

    jobs = []  # (side, indices, the lines to feed bat, a path, whether a primer was added)
    for side, lines, paths in (("old", old, old_paths), ("new", new, new_paths)):
        groups = {}
        for i in range(len(lines)):
            # paths can be shorter than lines only if classify() and this function ever
            # disagree; index defensively rather than mis-colour the whole side.
            src = path or (paths[i] if i < len(paths) else None)
            if not src:
                continue
            group = groups.setdefault(_group_key(src), [src, []])
            group[1].append(i)
        ranked = sorted(groups.values(), key=lambda g: len(g[1]), reverse=True)
        for src, idxs in ranked[:MAX_GROUPS]:
            sub = [lines[i] for i in idxs]
            primer = _primer(sub)
            jobs.append(
                (side, idxs, ([primer] + sub) if primer else sub, src, bool(primer))
            )

    if not jobs:
        return None, None

    procs = [_spawn(_bat_cmd(bat, src)) for _, _, _, src, _ in jobs]

    results = [None] * len(jobs)

    def collect(j):
        results[j] = _collect(procs[j], jobs[j][2])

    threads = [threading.Thread(target=collect, args=(j,)) for j in range(len(jobs))]
    for t in threads:
        t.start()
    for t in threads:
        # Past the point where _collect would itself have given up and killed bat; a
        # thread still running here is wedged, and its group stays flat.
        t.join(timeout=BAT_TIMEOUT + 1)

    out = {"old": [None] * len(old), "new": [None] * len(new)}
    for j, (side, idxs, sub, _, primed) in enumerate(jobs):
        got = results[j]
        if got is None:
            continue
        if primed:
            got = got[1:]
        target = out[side]
        for k, i in enumerate(idxs):
            target[i] = got[k]
    return out["old"], out["new"]


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
            if (
                hl is not None
                and idx is not None
                and idx < len(hl)
                and hl[idx] is not None
            ):
                out.append(
                    tint(
                        hl[idx], column_mask(toks, mask), sign, sign_fg, base_bg, str_bg
                    )
                )
            else:
                out.append(render_line(sign, sign_fg, base_bg, str_bg, toks, mask))

    emit(dels, masks_d, old_hl, 2, "-", DEL_SIGN, DEL_BG, DEL_STR)
    emit(adds, masks_a, new_hl, 3, "+", ADD_SIGN, ADD_BG, ADD_STR)


def _path_of(line):
    """The file path from a `---` / `+++` diff header, or None for /dev/null. Only the
    name matters here - it is handed to bat purely to pick a language."""
    path = line[4:]
    if "\t" in path:  # some diff producers append a timestamp
        path = path.split("\t", 1)[0]
    if path == "/dev/null":
        return None
    if path[:2] in ("a/", "b/"):
        path = path[2:]
    if len(path) > 1 and path[0] == '"' and path[-1] == '"':
        path = path[1:-1]  # git C-quotes a path holding a byte >= 0x80
    return path or None


def classify(lines):
    """Split the diff into records and tag each body line with its position in the
    old-side and new-side content streams (a context line is in both). Those two
    streams are what gets syntax-highlighted, so each side is coloured with its own
    correct context instead of with the two interleaved. Each content line is also
    tagged with the file it came from, so a diff spanning several files can be
    highlighted a language at a time rather than all as one."""
    recs, old, new = [], [], []
    old_paths, new_paths = [], []
    in_hunk = False
    old_p = new_p = cur = None
    for line in lines:
        if line.startswith("diff --git ") or line.startswith("diff --cc "):
            in_hunk = False
            old_p = new_p = cur = None
        if not in_hunk:
            # Outside a hunk these are headers; inside one the first character is the
            # marker and a `--- ` line is just deleted content (see the note below).
            # Prefer the new-side name, falling back to the old one for a deletion.
            if line.startswith("--- "):
                old_p = _path_of(line)
                cur = new_p or old_p
            elif line.startswith("+++ "):
                new_p = _path_of(line)
                cur = new_p or old_p
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
                old_paths.append(cur)
                continue
            if line.startswith("+"):
                recs.append(("add", line, None, len(new)))
                new.append(expand(line[1:]))
                new_paths.append(cur)
                continue
            if line.startswith("\\"):
                # "\ No newline at end of file" - a marker, not content.
                recs.append(("hdr", line, None, None))
                continue
            if line.startswith(" ") or line == "":
                recs.append(("ctx", line, len(old), len(new)))
                old.append(expand(line[1:]))
                new.append(expand(line[1:]))
                old_paths.append(cur)
                new_paths.append(cur)
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
    return recs, old, new, old_paths, new_paths


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

    recs, old, new, old_paths, new_paths = classify(lines)
    old_hl, new_hl = highlight_sides(old, new, path, old_paths, new_paths)

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
            if (
                new_hl is not None
                and ni is not None
                and ni < len(new_hl)
                and new_hl[ni] is not None
            ):
                out.append(" " + new_hl[ni] + RESET)
            else:
                out.append(CTX + expand(line) + RESET)
        else:
            out.append(GREY + expand(line) + RESET)
        i += 1
    sys.stdout.write("\n".join(out) + ("\n" if out else ""))


main()
