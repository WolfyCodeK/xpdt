#!/bin/sh
MODE="$1"; SCOPE_FILE="$2"; HERE="$3"; ROOT="$4"; QUERY="$5"
scope=$(cat "$SCOPE_FILE" 2>/dev/null)
if [ "$scope" = root ]; then dir="$ROOT"; else dir="$HERE"; fi
case "$MODE" in
  files)
    find "$dir" -mindepth 1 \( -name .git -o -name node_modules -o -name .venv -o -name venv -o -name __pycache__ \) -prune -o -print0 2>/dev/null \
      | xargs -0 stat -f '%m %N' 2>/dev/null \
      | sort -rn \
      | cut -d' ' -f2-
    ;;
  content)
    [ -z "$QUERY" ] && exit 0
    if command -v rg >/dev/null 2>&1; then
      rg --no-ignore --hidden --glob=!.git --glob=!node_modules --glob=!.venv --glob=!venv --glob=!__pycache__ \
         --line-number --no-heading --color=always --smart-case --fixed-strings --sortr=modified -- "$QUERY" "$dir"
    else
      grep -rIn --color=always --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=venv --exclude-dir=__pycache__ --fixed-strings -- "$QUERY" "$dir"
    fi
    ;;
esac
