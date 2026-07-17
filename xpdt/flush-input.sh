#!/bin/sh
# Discard input buffered on the terminal (unread keystrokes). Run after a full-screen
# program launched from xpdt (Neovim, the diff viewer) hands control back, so a held
# key - e.g. `left` with the left-exits-nvim setting - does not auto-repeat on into
# xpdt and walk you back up through directories once the editor closes. A fresh
# keypress after control returns still registers normally.
python3 -c 'import termios, sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' < /dev/tty 2>/dev/null || true
