#!/bin/sh
MODE="$1"; SCOPE_FILE="$2"; HERE="$3"; ROOT="$4"; QUERY="$5"
scope=$(cat "$SCOPE_FILE" 2>/dev/null)
if [ "$scope" = root ]; then dir="$ROOT"; else dir="$HERE"; fi
cd "$dir" 2>/dev/null || exit 0
# Results are emitted relative to the scope dir with a leading "/" (so the menus show "/sub/file"
# instead of the full launch path). resolve.sh turns a shown path back into the real one.
case "$MODE" in
  files)
    find . -mindepth 1 \( -name .git -o -name node_modules -o -name .venv -o -name venv -o -name __pycache__ \) -prune -o -print0 2>/dev/null \
      | xargs -0 stat -f '%m %N' 2>/dev/null \
      | sort -rn \
      | cut -d' ' -f2- \
      | sed 's|^\.||'
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
