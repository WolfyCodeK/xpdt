#!/bin/sh
ROOT="$1"; MODE="$2"; FILE="$3"; HASH="$4"
[ -z "$ROOT" ] || [ -z "$FILE" ] && exit 0
CACHE="${TMPDIR:-/tmp}/xplr-diff"
mkdir -p "$CACHE"

labeled() {
  base=$(basename "$FILE")
  ext="${base##*.}"; stem="${base%.*}"
  if [ "$base" = "$ext" ]; then nm="$base ($2)"; else nm="$stem ($2).$ext"; fi
  out="$CACHE/$nm"
  git -C "$ROOT" show "$1" > "$out" 2>/dev/null || : > "$out"
  printf '%s' "$out"
}

case "$MODE" in
  commit)
    PARENT=$(git -C "$ROOT" rev-parse --short "$HASH^" 2>/dev/null || printf parent)
    SHORT=$(git -C "$ROOT" rev-parse --short "$HASH" 2>/dev/null || printf "$HASH")
    L=$(labeled "$HASH^:$FILE" "$PARENT")
    R=$(labeled "$HASH:$FILE" "$SHORT")
    code --diff "$L" "$R"
    ;;
  staged)
    L=$(labeled "HEAD:$FILE" HEAD)
    R=$(labeled ":$FILE" Index)
    code --diff "$L" "$R"
    ;;
  unstaged)
    L=$(labeled ":$FILE" Index)
    code --diff "$L" "$ROOT/$FILE"
    ;;
esac
