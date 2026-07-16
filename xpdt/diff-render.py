import difflib
import os
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;]*m")
RESET = "\x1b[0m"
MINW = 8
GREY = "\x1b[90m"
GREEN = "\x1b[1;38;5;114m"
RED = "\x1b[1;38;5;168m"
ADD_BG = "\x1b[48;2;40;72;48m"
DEL_BG = "\x1b[48;2;84;40;44m"
ADD_STR = "\x1b[48;2;56;116;76m"  # brighter green: the exact words that changed
DEL_STR = "\x1b[48;2;132;54;60m"  # brighter red
SIMILAR = 0.5  # only word-diff a del/add pair this similar; else keep it flat
TOKEN = re.compile(r"\s+|\w+|[^\w\s]")


def _is_reset(code):
    return code in ("\x1b[0m", "\x1b[m")


def word_masks(a_plain, b_plain):
    # Per-visible-character "changed" masks for a paired removed/added line, so the
    # exact edited words can get the bright background. Returns (None, None) when the
    # two lines are too dissimilar to be an edit of each other (an unrelated delete
    # and insert that happened to pair up), leaving them a flat dim tint.
    at = TOKEN.findall(a_plain)
    bt = TOKEN.findall(b_plain)
    sm = difflib.SequenceMatcher(None, at, bt, autojunk=False)
    if sm.ratio() < SIMILAR:
        return None, None
    a_changed, b_changed = set(), set()
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag != "equal":
            a_changed.update(range(i1, i2))
            b_changed.update(range(j1, j2))

    def char_mask(tokens, changed):
        mask = []
        for idx, tok in enumerate(tokens):
            mask.extend([idx in changed] * len(tok))
        return mask

    return char_mask(at, a_changed), char_mask(bt, b_changed)


def tint_masked(chunk, base_bg, strong_bg, mask, voff):
    # Emit chunk (bat-highlighted, so ANSI fg codes are interleaved) with the
    # background switched to strong_bg over the visible characters the mask marks and
    # base_bg elsewhere. Never resets the background mid-line - it just swaps between
    # the two tints and re-applies the active one after bat's own resets - so the
    # foreground syntax colours are preserved and the tint survives soft-wrap.
    out = []
    cur = base_bg  # the caller has already emitted base_bg (on the gutter indent)
    j = voff
    consumed = 0
    i, n = 0, len(chunk)
    while i < n:
        m = ANSI.match(chunk, i)
        if m:
            code = m.group()
            out.append(code)
            if _is_reset(code):
                out.append(cur)
            i = m.end()
        else:
            want = strong_bg if (j < len(mask) and mask[j]) else base_bg
            if want != cur:
                out.append(want)
                cur = want
            out.append(chunk[i])
            j += 1
            consumed += 1
            i += 1
    return "".join(out), consumed


def visible_len(s):
    return len(ANSI.sub("", s))


def strip_indent(s):
    active = ""
    i, n, ind = 0, len(s), 0
    while i < n:
        m = ANSI.match(s, i)
        if m:
            code = m.group()
            active = "" if _is_reset(code) else active + code
            i = m.end()
        elif s[i] == " ":
            ind += 1
            i += 1
        else:
            break
    return ind, active + s[i:]


def plain_body(content):
    # The line's visible text after the indent is stripped, with ANSI removed - the
    # exact sequence of characters the mask (and the render) index into.
    return ANSI.sub("", strip_indent(content)[1])


def lstrip_visible(s):
    i, n, prefix = 0, len(s), []
    while i < n:
        m = ANSI.match(s, i)
        if m:
            prefix.append(m.group())
            i = m.end()
        elif s[i] == " ":
            i += 1
        else:
            break
    return "".join(prefix) + s[i:]


def split_visible(s, width):
    chunks, cur, curw, active = [], [], 0, ""
    i, n = 0, len(s)
    while i < n:
        m = ANSI.match(s, i)
        if m:
            code = m.group()
            cur.append(code)
            active = "" if _is_reset(code) else active + code
            i = m.end()
        else:
            if curw >= width:
                if active:
                    cur.append(RESET)
                chunks.append("".join(cur))
                cur = [active] if active else []
                curw = 0
            cur.append(s[i])
            curw += 1
            i += 1
    chunks.append("".join(cur))
    return chunks


def read_lines(path):
    try:
        data = open(path, "rb").read().decode("utf-8", "replace")
    except OSError:
        return []
    lines = data.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return lines


def main():
    after = read_lines(sys.argv[1])
    before = read_lines(sys.argv[2])
    width = int(os.environ.get("W", "100"))
    chgposfile = os.environ.get("CHGPOSFILE", "")

    hunks = []
    for line in sys.stdin:
        m = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
        if m:
            a = int(m.group(1))
            b = 1 if m.group(2) is None else int(m.group(2))
            c = int(m.group(3))
            d = 1 if m.group(4) is None else int(m.group(4))
            hunks.append((a, b, c, d))

    merged = []  # (content, type, lineno, mask)
    ai = 1
    for a, b, c, d in hunks:
        ctx_end = (c - 1) if d > 0 else c
        while ai <= ctx_end and ai <= len(after):
            merged.append((after[ai - 1], "ctx", ai, None))
            ai += 1
        del_items = [
            (before[j - 1], j) for j in range(a, a + b) if 1 <= j <= len(before)
        ]
        add_items = [(after[j - 1], j) for j in range(c, c + d) if 1 <= j <= len(after)]
        # Pair the i-th removed line with the i-th added line and word-diff them so
        # only the changed words get the bright tint; unpaired lines stay flat.
        del_masks = [None] * len(del_items)
        add_masks = [None] * len(add_items)
        for i in range(min(len(del_items), len(add_items))):
            dm, am = word_masks(
                plain_body(del_items[i][0]), plain_body(add_items[i][0])
            )
            del_masks[i], add_masks[i] = dm, am
        for i, (ln, no) in enumerate(del_items):
            merged.append((ln, "del", no, del_masks[i]))
        for i, (ln, no) in enumerate(add_items):
            merged.append((ln, "add", no, add_masks[i]))
        ai = (c + d) if d > 0 else (c + 1)
    while ai <= len(after):
        merged.append((after[ai - 1], "ctx", ai, None))
        ai += 1

    numw = max(len(str(max(len(after), len(before), 1))), 3)
    gutw = numw + 2
    codew = max(width - gutw, MINW)
    out, rows, chgpos, prev_changed = [], 0, [], False
    for content, typ, lineno, mask in merged:
        ind, body = strip_indent(content)
        ind_disp = min(ind, max(0, codew - MINW))
        cw = max(codew - ind_disp, MINW)
        chunks = split_visible(body, cw) if body else [""]
        if typ == "add":
            bg, strong = ADD_BG, ADD_STR
            sign = GREEN + "+" + RESET
            numstr = GREY + str(lineno).rjust(numw) + RESET
        elif typ == "del":
            bg, strong = DEL_BG, DEL_STR
            sign = RED + "-" + RESET
            numstr = GREY + (" " * numw) + RESET
        else:
            bg, strong = "", ""
            sign = " "
            numstr = GREY + str(lineno).rjust(numw) + RESET
        is_changed = typ != "ctx"
        if is_changed and not prev_changed:
            chgpos.append(rows + 1)
        prev_changed = is_changed
        contsign = sign if is_changed else " "
        gut0 = numstr + sign + " "
        gutc = GREY + (" " * numw) + RESET + contsign + " "
        voff = 0  # visible offset into the line body, for indexing the word mask
        for k, chunk in enumerate(chunks):
            prefix = gut0 if k == 0 else gutc
            if k > 0:
                before_vis = visible_len(chunk)
                chunk = lstrip_visible(chunk)
                voff += before_vis - visible_len(
                    chunk
                )  # soft-wrap drops leading spaces
            if is_changed and mask is not None:
                body_tinted, consumed = tint_masked(chunk, bg, strong, mask, voff)
                voff += consumed
                pad = max(0, codew - ind_disp - consumed)
                out.append(
                    prefix
                    + bg
                    + (" " * ind_disp)
                    + body_tinted
                    + bg
                    + (" " * pad)
                    + RESET
                )
            elif is_changed:
                code_part = (" " * ind_disp) + chunk
                pad = max(0, codew - visible_len(code_part))
                tint = bg + code_part.replace(RESET, RESET + bg) + (" " * pad) + RESET
                out.append(prefix + tint)
            else:
                out.append(prefix + (" " * ind_disp) + chunk)
        rows += len(chunks)

    sys.stdout.write("\n".join(out) + ("\n" if out else ""))
    if chgposfile and chgpos:
        try:
            with open(chgposfile, "w") as handle:
                handle.write(" ".join(str(p) for p in chgpos))
        except OSError:
            pass


main()
