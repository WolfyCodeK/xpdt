import os
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;]*m")
BG = "\x1b[48;5;238m"
RESET = "\x1b[0m"
MINW = 8


def _is_reset(code):
    return code in ("\x1b[0m", "\x1b[m")


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


def main():
    width = int(os.environ.get("W", "100"))
    hl = os.environ.get("HL", "")
    hl = int(hl) if hl.isdigit() else 0
    posfile = os.environ.get("POSFILE", "")
    mapfile = os.environ.get("MAPFILE", "")

    lines = sys.stdin.buffer.read().decode("utf-8", "replace").split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    total = max(len(lines), 1)
    numw = max(len(str(total)), 3)
    gutw = numw + 3

    out, rows, pos, rowmap = [], 0, 0, []
    for idx, raw in enumerate(lines, 1):
        line = raw.rstrip("\r")
        ind, body = strip_indent(line)
        ind_disp = min(ind, max(0, width - gutw - MINW))
        cw = max(width - gutw - ind_disp, MINW)
        chunks = split_visible(body, cw) if body else [""]
        gutter = "\x1b[90m" + str(idx).rjust(numw) + " │ " + RESET
        gpad = " " * gutw
        if idx == hl:
            pos = rows + 1
        for k, chunk in enumerate(chunks):
            prefix = gutter if k == 0 else gpad
            if k > 0:
                chunk = lstrip_visible(chunk)
            row = prefix + (" " * ind_disp) + chunk
            if idx == hl:
                row = BG + row.replace(RESET, RESET + BG) + RESET
            out.append(row)
            rowmap.append(idx)
        rows += len(chunks)

    if not out:
        # Empty file: emit one blank gutter line (mapped to line 1) so the preview is non-empty
        # and stays editable - fzf needs an item present for the ctrl-e edit binding to fire.
        out.append("\x1b[90m" + "1".rjust(numw) + " │ " + RESET)
        rowmap.append(1)

    sys.stdout.write("\n".join(out) + ("\n" if out else ""))
    if posfile and pos:
        try:
            with open(posfile, "w") as handle:
                handle.write(str(pos))
        except OSError:
            pass
    if mapfile:
        try:
            with open(mapfile, "w") as handle:
                handle.write("\n".join(str(x) for x in rowmap))
        except OSError:
            pass


main()
