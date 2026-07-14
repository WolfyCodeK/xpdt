#!/bin/sh
# Hunk-level (git add -p style) staging for the changes browser.
#   git-hunk.sh list    ROOT GROUP FILE
#   git-hunk.sh show    ROOT GROUP FILE INDEX
#   git-hunk.sh apply   ROOT GROUP FILE INDEX   (stage, or unstage if GROUP=staged)
#   git-hunk.sh discard ROOT GROUP FILE INDEX   (unstaged only; revert in the worktree)
# GROUP ('staged' | 'unstaged') picks the source diff and the direction:
#   unstaged -> stage the hunk into the index   (git apply --cached)
#   staged   -> unstage the hunk from the index (git apply --cached --reverse)
# A one-hunk patch = the file header (the lines before the first @@) plus the one
# @@ block; extracted from the live diff each time, so sequential hunk ops stay
# valid as line numbers shift.
MODE="$1"; ROOT="$2"; GROUP="$3"; FILE="$4"; INDEX="$5"
[ -z "$ROOT" ] || [ -z "$FILE" ] && exit 0

src() {
  if [ "$GROUP" = staged ]; then
    git -C "$ROOT" diff --cached -- "$FILE"
  else
    git -C "$ROOT" diff -- "$FILE"
  fi
}

# Read a diff on stdin, emit a one-hunk patch (file header + the Nth @@ block).
extract_patch() {
  awk -v w="$1" '
    /^diff --git/ { hdr = 1 }
    /^@@/         { hn++; hdr = 0 }
    { if (hdr) { print; next } if (hn == w) print }
  '
}

case "$MODE" in
  list)
    src | awk '/^@@/ { hn++; printf "%d  %s\n", hn, $0 }'
    ;;
  show)
    # Just the Nth hunk (@@ header + body), for the preview.
    src | awk -v w="$INDEX" '/^@@/ { hn++ } hn == w { print }'
    ;;
  apply)
    [ -z "$INDEX" ] && exit 0
    if [ "$GROUP" = staged ]; then verb=Unstage; rev=--reverse; else verb=Stage; rev=; fi
    sh "$HOME/.config/xpdt/gate.sh" confirm hunk "$verb hunk $INDEX of $FILE?" || exit 0
    if src | extract_patch "$INDEX" | git -C "$ROOT" apply --cached $rev --whitespace=nowarn - 2>/dev/null; then
      :
    else
      printf 'Could not %s that hunk (try the whole file with s).\n' \
        "$(printf %s "$verb" | tr 'A-Z' 'a-z')" > /dev/tty
      sleep 1
    fi
    ;;
  discard)
    [ -z "$INDEX" ] && exit 0
    if [ "$GROUP" != unstaged ]; then
      printf 'Discard applies to unstaged hunks only (unstage it first).\n' > /dev/tty
      sleep 1
      exit 0
    fi
    sh "$HOME/.config/xpdt/gate.sh" confirm discard "Discard hunk $INDEX of $FILE? (removes it from the working tree)" || exit 0
    # --reverse without --cached reverts the hunk in the working tree.
    if src | extract_patch "$INDEX" | git -C "$ROOT" apply --reverse --whitespace=nowarn - 2>/dev/null; then
      :
    else
      printf 'Could not discard that hunk.\n' > /dev/tty
      sleep 1
    fi
    ;;
esac
