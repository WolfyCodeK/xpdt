#!/bin/sh
# Show a path in the OS file manager - "reveal in Finder", "show in Explorer".
# Arg: PATH (absolute). Bound to ctrl-o in the `/` and `\` searches.
#
# A file is revealed AND selected where the platform can do that; a directory is just
# opened. Per platform:
#
#   macOS   `open -R FILE` reveals and selects it in Finder; `open DIR` opens a window
#           on the directory itself.
#   WSL2    `explorer.exe /select,<windows path>`, with `wslpath -w` converting the
#           Linux path (current Windows handles the \\wsl.localhost\... form). Note
#           explorer.exe exits NON-ZERO even when it worked, so its status is ignored
#           deliberately - checking it would report a false failure every time.
#   Linux   there is no standard "reveal", so: a known file manager's own select flag
#           if one is installed, else `xdg-open` on the containing directory (which
#           opens the folder but cannot highlight the file).
#
# Over plain SSH there is no desktop to open anything in, so with neither $DISPLAY nor
# $WAYLAND_DISPLAY it says so, rather than hanging or looking like a dead key. Opening
# a file manager does not change anything, so this is NOT behind the confirmation gate.
P="$1"
# Braced so the group's stderr is /dev/null BEFORE the >/dev/tty redirect is applied:
# a failed redirect is reported by the shell to the stderr in force at that point, so
# `> /dev/tty 2>/dev/null` would still leak the error when there is no controlling tty.
note() { { printf '\n  %s\n' "$1" > /dev/tty; } 2>/dev/null; sleep 1.4; }
# Detach GUI launches: some file managers stay in the foreground, which would block
# fzf until the window is closed. The subshell double-detaches without nohup.out.
spawn() { ( "$@" >/dev/null 2>&1 & ) ; }

[ -n "$P" ] || exit 0
if [ ! -e "$P" ]; then note "No longer there: $P"; exit 0; fi

if [ -d "$P" ]; then DIR="$P"; SEL=""; else DIR=$(dirname "$P"); SEL="$P"; fi

case "$(uname -s)" in
  Darwin)
    if [ -n "$SEL" ]; then open -R "$SEL"; else open "$DIR"; fi
    ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
      if [ -n "$SEL" ]; then
        W=$(wslpath -w "$SEL" 2>/dev/null)
        [ -n "$W" ] && explorer.exe "/select,$W" >/dev/null 2>&1
      else
        W=$(wslpath -w "$DIR" 2>/dev/null)
        [ -n "$W" ] && explorer.exe "$W" >/dev/null 2>&1
      fi
      exit 0 # explorer.exe's exit status is meaningless; see the header note
    fi
    if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
      note "No desktop session here, so there is no file manager to open."
      exit 0
    fi
    if [ -n "$SEL" ] && command -v nautilus >/dev/null 2>&1; then
      spawn nautilus --select "$SEL"
    elif [ -n "$SEL" ] && command -v dolphin >/dev/null 2>&1; then
      spawn dolphin --select "$SEL"
    elif [ -n "$SEL" ] && command -v nemo >/dev/null 2>&1; then
      spawn nemo "$SEL" # nemo selects a file passed directly
    elif command -v xdg-open >/dev/null 2>&1; then
      spawn xdg-open "$DIR" # opens the folder; cannot highlight the file
    else
      note "No file manager found (no nautilus / dolphin / nemo / xdg-open)."
    fi
    ;;
  *)
    note "Opening a file manager is not supported on $(uname -s)."
    ;;
esac
exit 0
