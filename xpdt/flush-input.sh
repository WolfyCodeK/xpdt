#!/bin/sh
# Discard input buffered on the terminal (unread keystrokes). Run after a full-screen
# program launched from xpdt (Neovim, the diff viewer, the / and \ search) hands
# control back, so buffered keys do not leak into xpdt and fire stray bindings - e.g.
# a held `left` (the left-exits-nvim setting) auto-repeating up through directories,
# or letters typed into the search then aborted ("lms" -> s, m, ...). A fresh keypress
# after control returns still registers normally.
python3 -c 'import termios, sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' < /dev/tty 2>/dev/null || true
