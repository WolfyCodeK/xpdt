#!/bin/sh
# Turn a base-relative search-result path (e.g. "/sub/file.md" as shown in the / and \ menus)
# back into a real path, using the current search scope.  Arg: REL
# The scope state and the two base directories arrive in the environment
# (XPDT_SCOPE_FILE / XPDT_SCOPE_HERE / XPDT_SCOPE_ROOT) rather than as arguments, so no
# path is baked into the fzf bind strings that call this - see search.sh for why.
# The menus display paths relative to the scope dir (leading "/"); this prepends that dir back.
[ "$(cat "$XPDT_SCOPE_FILE" 2>/dev/null)" = root ] && base="$XPDT_SCOPE_ROOT" || base="$XPDT_SCOPE_HERE"
printf '%s%s' "$base" "$1"
