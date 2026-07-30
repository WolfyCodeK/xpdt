#!/bin/sh
# Stash operations for the stash browser (git-stash-browser.sh).
# Args: ROOT OP [REF]   OP in: push apply pop drop clear
# Confirmation for each op is centralised in gate.sh (the 2-digit code gate, on
# by default, per-action toggleable via the `,` settings menu).
ROOT="$1"; OP="$2"; REF="$3"
[ -z "$ROOT" ] && exit 0
X="$HOME/.config/xpdt"
GATE="$X/gate.sh"
pause() { printf '\n[enter to continue] ' > /dev/tty; read -r _ < /dev/tty; }

# Clear the normal screen first, so transient messages (e.g. "Nothing to stash")
# and git output show once per press instead of piling up across repeated ops.
# \033[?25h re-shows the cursor (fzf hides it) so the stash-message prompt has a caret.
printf '\033[2J\033[H\033[?25h' > /dev/tty 2>/dev/null

case "$OP" in
  push)
    if [ -z "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]; then
      printf 'Nothing to stash - working tree is clean. ' > /dev/tty
      sleep 1
      exit 0
    fi
    sh "$GATE" confirm stash-new "Stash all working-tree changes (including untracked)?" || exit 0
    python3 -S -c 'import termios,sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' </dev/tty 2>/dev/null
    # Read the message through prompt-prefill.py (python readline), not a bare `read`.
    # A bare `read` has no line editing, so arrow keys arrive as their raw escape
    # bytes (^[[D, ^[[B, ...) and print into the message instead of moving the cursor.
    # readline gives arrows / backspace / ctrl-a/e, and is portable where bash's
    # `read -e` is not (macOS ships bash 3.2). Empty (or ctrl-c/ctrl-d) = no message,
    # which is exactly the "enter to skip" path. The result goes to a temp file so the
    # prompt text cannot leak into it.
    MSGF=$(mktemp)
    trap 'rm -f "$MSGF"' EXIT INT TERM
    python3 -S "$X/prompt-prefill.py" "" "$MSGF" 'Stash message (optional, enter to skip): ' < /dev/tty > /dev/tty 2>&1
    msg=$(cat "$MSGF" 2>/dev/null); rm -f "$MSGF"; trap - EXIT INT TERM
    if [ -n "$msg" ]; then
      git -C "$ROOT" stash push --include-untracked -m "$msg" > /dev/tty 2>&1
    else
      git -C "$ROOT" stash push --include-untracked > /dev/tty 2>&1
    fi
    sleep 0.8
    ;;
  apply|pop)
    [ -z "$REF" ] && exit 0
    if [ "$OP" = pop ]; then label="Pop $REF (apply then remove)?"; else label="Apply $REF (keeps the stash)?"; fi
    sh "$GATE" confirm "stash-$OP" "$label" || exit 0
    # On success move on quickly; on conflict/error keep the output on screen.
    if git -C "$ROOT" stash "$OP" "$REF" > /dev/tty 2>&1; then
      sleep 0.8
    else
      pause
    fi
    ;;
  drop)
    [ -z "$REF" ] && exit 0
    sh "$GATE" confirm stash-drop "Drop $REF? (kept only in the reflog, hard to recover)" || exit 0
    git -C "$ROOT" stash drop "$REF" > /dev/tty 2>&1
    sleep 0.8
    ;;
  clear)
    n=$(git -C "$ROOT" stash list 2>/dev/null | grep -c .)
    [ "$n" -eq 0 ] && { printf 'No stashes to clear. ' > /dev/tty; sleep 0.8; exit 0; }
    sh "$GATE" confirm stash-clear "Delete ALL $n stash(es)?" || exit 0
    git -C "$ROOT" stash clear
    printf 'Cleared all stashes.\n' > /dev/tty
    sleep 0.8
    ;;
esac
