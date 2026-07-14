#!/bin/sh
# Preview search position memory. fzf resets the cursor to the top on every query
# change, so clearing a search jumps you back to the top. This remembers the line
# the search lands on while you type, and restores it when the query is cleared.
# Bound to fzf's `change` event as a transform (its stdout is parsed as actions).
# Args: POSFILE QLENFILE CUR_N QUERY   (CUR_N is {n}, the absolute item index; QUERY is {q})
POSFILE="$1"; QLENF="$2"; CUR_N="$3"; QUERY="$4"
prev=$(cat "$QLENF" 2>/dev/null); [ -z "$prev" ] && prev=0
cur=${#QUERY}
printf '%s' "$cur" > "$QLENF"
if [ "$cur" -eq 0 ]; then
  # Query cleared: jump back to the line the search had landed on.
  p=$(cat "$POSFILE" 2>/dev/null)
  [ -n "$p" ] && printf 'pos(%s)' "$p"
elif [ "$cur" -gt "$prev" ] && [ "${CUR_N:-0}" -ge 0 ]; then
  # Typing (narrowing the search): remember where the top match is (1-based).
  printf '%s' "$((CUR_N + 1))" > "$POSFILE"
fi
