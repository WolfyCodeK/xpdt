#!/bin/sh
# Discard terminal input that would otherwise leak into xpdt as stray key presses
# after a full-screen program launched from xpdt hands control back.
#
# Two cases:
#
# 1. A left-exit from Neovim (the left-exits-nvim setting) where the key may still be
#    HELD. Auto-repeat has an initial delay, so the repeats arrive *after* Neovim has
#    closed - a one-shot flush runs too early and misses them. So when the Neovim
#    left-exit mapping leaves its flag file, we instead sit here draining the terminal
#    until the key is released (input goes quiet), keeping xpdt suspended meanwhile, so
#    it resumes only once you let go - no shooting back up through directories. `first`
#    waits out the auto-repeat's initial delay; `quiet` detects the release.
#
# 2. Any other buffered burst (e.g. letters typed into the / or \ search then aborted):
#    the bytes are already queued, so a single tcflush clears them.
FLAG="/tmp/xpdt-nvim-left-exit"
if [ -f "$FLAG" ]; then
  rm -f "$FLAG"
  python3 -c '
import termios, tty, os, select, time
try:
    fd = os.open("/dev/tty", os.O_RDWR)
except OSError:
    raise SystemExit
old = termios.tcgetattr(fd)
try:
    tty.setcbreak(fd)
    first = 0.5   # wait up to this long for the (delayed) first auto-repeat
    quiet = 0.08  # then resume once input has been silent this long (key released)
    cap = time.time() + 2.5
    if select.select([fd], [], [], first)[0]:
        try:
            os.read(fd, 8192)
        except OSError:
            pass
        deadline = time.time() + quiet
        while time.time() < deadline and time.time() < cap:
            if select.select([fd], [], [], quiet)[0]:
                try:
                    os.read(fd, 8192)
                except OSError:
                    pass
                deadline = time.time() + quiet
finally:
    termios.tcsetattr(fd, termios.TCSANOW, old)
    termios.tcflush(fd, termios.TCIFLUSH)
    os.close(fd)
' 2>/dev/null || true
else
  python3 -c 'import termios, sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' < /dev/tty 2>/dev/null || true
fi
