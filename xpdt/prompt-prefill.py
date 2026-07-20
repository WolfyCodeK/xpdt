#!/usr/bin/env python3
# Prompt for a line of input pre-filled with an initial value the user can edit in
# place (readline: arrows, backspace, ctrl-a/e, ...). This is the portable way to
# pre-fill an editable prompt: bash's `read -e -i` needs bash 4+, which macOS does not
# ship, whereas python's readline works on macOS and Linux alike.
#
# Args: INITIAL OUTFILE [PROMPT]. The prompt renders on stdout (point stdout at the tty
# so it shows), and the (possibly edited) result is written to OUTFILE - so the caller
# can capture the result without the prompt text leaking into it. An empty result, or
# ctrl-c / ctrl-d, means "cancelled".
import sys

initial = sys.argv[1] if len(sys.argv) > 1 else ""
outfile = sys.argv[2] if len(sys.argv) > 2 else "/dev/stdout"
prompt = sys.argv[3] if len(sys.argv) > 3 else "> "

hooked = False
try:
    import readline

    readline.set_startup_hook(lambda: readline.insert_text(initial))
    hooked = True
except Exception:
    pass  # no readline (or libedit without insert_text): fall back to an empty prompt

try:
    value = input(prompt)
except (EOFError, KeyboardInterrupt):
    value = ""
finally:
    if hooked:
        try:
            readline.set_startup_hook()
        except Exception:
            pass

with open(outfile, "w") as f:
    f.write(value)
