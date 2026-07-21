#!/bin/sh
# Discard terminal input that would otherwise leak into xpdt as stray key presses
# after a full-screen program launched from xpdt hands control back.
#
# Two cases:
#
# 1. A left-exit where the key may still be HELD: leaving Neovim via the left-exits-nvim
#    mapping, or backing out of the / \ search (left deletes the query, then a final left
#    at the empty query aborts). Both leave the flag file. Auto-repeat has an initial
#    delay, so the repeats arrive *after* the program has closed - a one-shot flush runs
#    too early and misses them. So on the flag we sit here draining LEFT-arrow repeats
#    until the key is released, keeping xpdt suspended meanwhile, so it resumes only once
#    you let go - no shooting back up through directories. Only left-arrow repeats hold
#    the drain open: a plain tap clears in ~`quiet` seconds, and unrelated input (mouse
#    moves, focus events, terminal report replies) is discarded without stalling it, so a
#    normal exit stays snappy. `cap` is a hard ceiling so it can never feel stuck.
#
# 2. Any other buffered burst (e.g. letters typed into the / or \ search then aborted):
#    the bytes are already queued, so a single tcflush clears them.
FLAG="/tmp/xpdt-left-exit"
if [ -f "$FLAG" ]; then
  rm -f "$FLAG"
  python3 -S -c '
import termios, tty, os, select, time
try:
    fd = os.open("/dev/tty", os.O_RDWR)
except OSError:
    raise SystemExit
LEFT = (b"\x1b[D", b"\x1bOD")  # left arrow: normal (CSI D) and application-cursor (SS3 D)
old = termios.tcgetattr(fd)
try:
    tty.setcbreak(fd)
    quiet = 0.1                # resume once no left-repeat has arrived for this long
    cap = time.time() + 1.0    # hard ceiling, so a long hold cannot freeze xpdt
    deadline = time.time() + quiet
    while time.time() < deadline and time.time() < cap:
        timeout = min(deadline, cap) - time.time()
        if timeout <= 0 or not select.select([fd], [], [], timeout)[0]:
            break
        try:
            data = os.read(fd, 8192)
        except OSError:
            break
        if any(s in data for s in LEFT):
            deadline = time.time() + quiet   # still held - keep draining
        # unrelated input (mouse / focus / terminal reports): discard, do not prolong
finally:
    termios.tcsetattr(fd, termios.TCSANOW, old)
    termios.tcflush(fd, termios.TCIFLUSH)
    os.close(fd)
' 2>/dev/null || true
else
  python3 -S -c 'import termios, sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' < /dev/tty 2>/dev/null || true
fi
