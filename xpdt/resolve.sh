#!/bin/sh
# Turn a base-relative search-result path (e.g. "/sub/file.md" as shown in the / and \ menus)
# back into a real path, using the current search scope.  Args: SCOPE_FILE HERE ROOT REL
# The menus display paths relative to the scope dir (leading "/"); this prepends that dir back.
[ "$(cat "$1" 2>/dev/null)" = root ] && base="$3" || base="$2"
printf '%s%s' "$base" "$4"
