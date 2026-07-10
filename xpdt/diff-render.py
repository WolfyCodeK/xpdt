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


def _is_reset(code):
    return code in ("\x1b[0m", "\x1b[m")


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

    merged = []  # (content, type, lineno)
    ai = 1
    for a, b, c, d in hunks:
        ctx_end = (c - 1) if d > 0 else c
        while ai <= ctx_end and ai <= len(after):
            merged.append((after[ai - 1], "ctx", ai))
            ai += 1
        for j in range(a, a + b):
            if 1 <= j <= len(before):
                merged.append((before[j - 1], "del", j))
        for j in range(c, c + d):
            if 1 <= j <= len(after):
                merged.append((after[j - 1], "add", j))
        ai = (c + d) if d > 0 else (c + 1)
    while ai <= len(after):
        merged.append((after[ai - 1], "ctx", ai))
        ai += 1

    numw = max(len(str(max(len(after), len(before), 1))), 3)
    gutw = numw + 2
    codew = max(width - gutw, MINW)
    out, rows, chgpos, prev_changed = [], 0, [], False
    for content, typ, lineno in merged:
        ind, body = strip_indent(content)
        ind_disp = min(ind, max(0, codew - MINW))
        cw = max(codew - ind_disp, MINW)
        chunks = split_visible(body, cw) if body else [""]
        if typ == "add":
            bg = ADD_BG
            sign = GREEN + "+" + RESET
            numstr = GREY + str(lineno).rjust(numw) + RESET
        elif typ == "del":
            bg = DEL_BG
            sign = RED + "-" + RESET
            numstr = GREY + (" " * numw) + RESET
        else:
            bg = ""
            sign = " "
            numstr = GREY + str(lineno).rjust(numw) + RESET
        is_changed = typ != "ctx"
        if is_changed and not prev_changed:
            chgpos.append(rows + 1)
        prev_changed = is_changed
        contsign = sign if is_changed else " "
        gut0 = numstr + sign + " "
        gutc = GREY + (" " * numw) + RESET + contsign + " "
        for k, chunk in enumerate(chunks):
            prefix = gut0 if k == 0 else gutc
            if k > 0:
                chunk = lstrip_visible(chunk)
            code_part = (" " * ind_disp) + chunk
            if is_changed:
                pad = max(0, codew - visible_len(code_part))
                tint = bg + code_part.replace(RESET, RESET + bg) + (" " * pad) + RESET
                out.append(prefix + tint)
            else:
                out.append(prefix + code_part)
        rows += len(chunks)

    sys.stdout.write("\n".join(out) + ("\n" if out else ""))
    if chgposfile and chgpos:
        try:
            with open(chgposfile, "w") as handle:
                handle.write(" ".join(str(p) for p in chgpos))
        except OSError:
            pass


main()
