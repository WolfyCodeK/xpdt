#!/bin/sh
# Backend for the `/` (files) and `\` (content) searches. Args: MODE [QUERY].
# The scope state, the current dir and the launch dir arrive in the environment
# (XPDT_SCOPE_FILE / XPDT_SCOPE_HERE / XPDT_SCOPE_ROOT), not as arguments, so no
# path is ever interpolated into the fzf command strings that call this - one of
# those containing a quote or $(...) would be executed by the shell that re-parses
# the bind. init.lua exports them before opening fzf.
MODE="$1"; QUERY="$2"
scope=$(cat "$XPDT_SCOPE_FILE" 2>/dev/null)
if [ "$scope" = root ]; then dir="$XPDT_SCOPE_ROOT"; else dir="$XPDT_SCOPE_HERE"; fi
cd "$dir" 2>/dev/null || exit 0
# Results are emitted relative to the scope dir with a leading "/" (so the menus show "/sub/file"
# instead of the full launch path). resolve.sh turns a shown path back into the real one.
case "$MODE" in
  files)
    # Newest-modified first. `stat`'s format flag differs by platform, and not merely
    # in spelling: GNU (Linux, WSL2) is `-c FORMAT`, while BSD (macOS) is `-f FORMAT`
    # and GNU's `-f` means "filesystem status" and takes no format at all. Assuming
    # the BSD form therefore did not just mis-sort on Linux - it printed block counts
    # and free space INSTEAD of file paths, so this search was entirely broken there.
    # Probe for the working form once; if neither works, fall back to an unsorted
    # listing rather than emitting nothing.
    if stat -c '%Y' . >/dev/null 2>&1; then
      SFLAG=-c; SFMT='%Y %n'
    elif stat -f '%m %N' . >/dev/null 2>&1; then
      SFLAG=-f; SFMT='%m %N'
    else
      SFLAG=; SFMT=
    fi
    if [ -n "$SFLAG" ]; then
      find . -mindepth 1 \( -name .git -o -name node_modules -o -name .venv -o -name venv -o -name __pycache__ \) -prune -o -print0 2>/dev/null \
        | xargs -0 stat "$SFLAG" "$SFMT" 2>/dev/null \
        | sort -rn \
        | cut -d' ' -f2- \
        | sed 's|^\.||'
    else
      find . -mindepth 1 \( -name .git -o -name node_modules -o -name .venv -o -name venv -o -name __pycache__ \) -prune -o -print 2>/dev/null \
        | sed 's|^\.||'
    fi
    ;;
  content)
    [ -z "$QUERY" ] && exit 0
    ESC=$(printf '\033')
    # rg outputs relative paths cleanly; the grep fallback prefixes "./" and emits erase-line
    # escapes. Strip the erase-line (\e[K), drop a leading "./" that sits after the path colour,
    # then prepend "/", so both branches show "/sub/file:line:match".
    { if command -v rg >/dev/null 2>&1; then
        rg --no-ignore --hidden --glob=!.git --glob=!node_modules --glob=!.venv --glob=!venv --glob=!__pycache__ \
           --line-number --no-heading --color=always --smart-case --fixed-strings --sortr=modified -- "$QUERY"
      else
        grep -rIn --color=always --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=venv --exclude-dir=__pycache__ --fixed-strings -- "$QUERY" .
      fi
    } | sed "s|${ESC}\[K||g; s|\(${ESC}\[[0-9;]*m\)\./|\1|; s|^|/|"
    ;;
esac
