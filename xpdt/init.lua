version = "1.1.0"

-- Persisted xpdt settings live in ~/.config/xpdt/.gate-config as key=1/0 lines
-- (the confirmation-gate keys use the same file; see gate.sh). An absent file or
-- key reads as the default.
local function read_bool_setting(key, default)
  local f = io.open(os.getenv("HOME") .. "/.config/xpdt/.gate-config", "r")
  if not f then
    return default
  end
  local result = default
  local pat = "^" .. key:gsub("%-", "%%-") .. "=(%d)"
  for line in f:lines() do
    local v = line:match(pat)
    if v then
      result = (v == "1")
    end
  end
  f:close()
  return result
end

-- Same file, for the settings whose value is not a 0/1 flag (currently the git
-- history width). Returns the raw string so the caller can validate it.
local function read_value_setting(key, default)
  local f = io.open(os.getenv("HOME") .. "/.config/xpdt/.gate-config", "r")
  if not f then
    return default
  end
  local result = default
  local pat = "^" .. key:gsub("%-", "%%-") .. "=(.+)$"
  for line in f:lines() do
    local v = line:match(pat)
    if v then
      result = v
    end
  end
  f:close()
  return result
end

-- Showing hidden files (dotfiles) is a setting toggled in the `,` menu, not a
-- runtime key. xplr 1.1.0 has no runtime message to change show_hidden, so it is
-- read here at load and a toggle takes effect on the next launch.
xplr.config.general.show_hidden = read_bool_setting("show-hidden", true)

xplr.config.layouts.builtin.default = { Dynamic = "custom.render_layout" }

xplr.config.modes.builtin.default.key_bindings.on_key["enter"] = {
  help = "repo changes browser",
  messages = {
    { CallLua = "custom.open_changes_browser" },
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key[";"] = {
  help = "git log browser",
  messages = {
    { CallLua = "custom.open_git_browser" },
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["d"] = {
  help = "delete (2 digit code)",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/delete.sh\"" },
    { CallLuaSilently = "custom.invalidate_git" },
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["a"] = {
  help = "create file (2 digit code)",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/file-op.sh\" newfile" },
    { CallLuaSilently = "custom.invalidate_git" },
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["f"] = {
  help = "create folder (2 digit code)",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/file-op.sh\" newfolder" },
    { CallLuaSilently = "custom.invalidate_git" },
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["m"] = {
  help = "rename (2 digit code)",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/file-op.sh\" rename" },
    { CallLuaSilently = "custom.invalidate_git" },
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["M"] = {
  help = "move to a folder (2 digit code)",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/file-op.sh\" move" },
    { CallLuaSilently = "custom.invalidate_git" },
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["g"] = {
  help = "git menu",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/git-menu.sh\"" },
    { CallLuaSilently = "custom.invalidate_git" },
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["s"] = {
  help = "git stash browser",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/git-stash-browser.sh\"" },
    { CallLuaSilently = "custom.invalidate_git" },
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["h"] = {
  help = "controls / help",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/help.sh\"" },
  }
}

-- The full-screen Claude session window. Bound unconditionally; claude-window.sh
-- checks the claude-integration setting itself and says so when it is off, which is
-- friendlier than a dead key and needs no relaunch after toggling the setting.
xplr.config.modes.builtin.default.key_bindings.on_key["c"] = {
  help = "claude sessions (when enabled)",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/claude-window.sh\"" },
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["ctrl-h"] = {
  help = "neovim cheat sheet",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/nvim-cheatsheet.sh\"" },
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key[","] = {
  help = "settings",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/gate-menu.sh\"" },
  }
}

-- Showing hidden files is a setting (the `,` menu), not a runtime toggle; unbind
-- xplr's default `.` so it cannot flip them by accident.
xplr.config.modes.builtin.default.key_bindings.on_key["."] = nil

xplr.config.modes.builtin.default.key_bindings.on_key["right"] = {
  help = "enter dir or open file in neovim",
  messages = {
    {
      BashExecSilently = [===[
        if [ -d "$XPLR_FOCUS_PATH" ]; then
          echo 'Enter' >> "${XPLR_PIPE_MSG_IN:?}"
        else
          "$XPLR" -m 'BashExec: %q' "sh $HOME/.config/xpdt/open-or-preview.sh"
        fi
      ]===]
    }
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["/"] = {
  help = "find files",
  messages = {
    {
      BashExec = [===[
        X="$HOME/.config/xpdt"
        . "$X/tmpflag.sh"
        # The scope dir, the launch dir and the scope-state file are passed to the
        # helpers through the environment, not baked into the fzf command strings.
        # Those strings are re-parsed by a shell for every bind, so an embedded path
        # containing a quote or $(...) - i.e. a directory name - would be executed.
        XPDT_SCOPE_FILE="$X/.search-scope"; [ -f "$XPDT_SCOPE_FILE" ] || echo here > "$XPDT_SCOPE_FILE"
        XPDT_SCOPE_HERE="$(pwd)"; XPDT_SCOPE_ROOT="${XPLR_INITIAL_PWD:-$XPDT_SCOPE_HERE}"
        export XPDT_SCOPE_FILE XPDT_SCOPE_HERE XPDT_SCOPE_ROOT
        GEN="sh \"$X/search.sh\" files"
        FILE=$(eval "$GEN" | fzf --no-sort --exact \
          --header="$(sh "$X/scope.sh" header)" \
          --bind "tab:execute-silent(sh \"$X/scope.sh\" toggle)+transform-header(sh \"$X/scope.sh\" header)+reload:$GEN" \
          --bind "change:reload:sleep 0.1; $GEN" \
          --bind 'left:transform:[ -n {q} ] && echo backward-delete-char || { : > "$XPDT_LEFT_EXIT"; echo abort; }' \
          --bind 'right:accept' \
          --bind "ctrl-o:execute(sh \"$X/reveal.sh\" \"\$(sh \"$X/resolve.sh\" {})\")" \
          --bind 'enter:ignore')
        if [ -n "$FILE" ]; then
          FULL=$(sh "$X/resolve.sh" "$FILE")
          # `right` (only - never enter) confirms the focused hit: a folder is entered
          # (like the main view), a file opens in Neovim (or the preview first, per the
          # setting).
          # ChangeDirectory fires on_directory_change -> apply_xplrignore, so filters
          # are reset/reapplied for the new directory just like normal navigation.
          if [ -d "$FULL" ]; then
            echo "ChangeDirectory: '$FULL'" >> "${XPLR_PIPE_MSG_IN:?}"
          else
            XPLR_FOCUS_PATH="$FULL" sh "$X/open-or-preview.sh"
          fi
        fi
        # Drain keystrokes buffered while fzf was open (e.g. you typed "lms" then backed
        # out) so they do not leak into xpdt afterwards and fire key bindings (s, m, ...).
        sh "$X/flush-input.sh"
      ]===]
    }
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["\\"] = {
  help = "search in files",
  messages = {
    {
      BashExec = [===[
        X="$HOME/.config/xpdt"
        . "$X/tmpflag.sh"
        # Scope state goes through the environment, not the fzf command strings - see
        # the `/` bind above for why.
        XPDT_SCOPE_FILE="$X/.search-scope"; [ -f "$XPDT_SCOPE_FILE" ] || echo here > "$XPDT_SCOPE_FILE"
        XPDT_SCOPE_HERE="$(pwd)"; XPDT_SCOPE_ROOT="${XPLR_INITIAL_PWD:-$XPDT_SCOPE_HERE}"
        export XPDT_SCOPE_FILE XPDT_SCOPE_HERE XPDT_SCOPE_ROOT
        GENQ="sh \"$X/search.sh\" content"
        # `right` opens the focused hit in Neovim at the matched line; `enter` does
        # nothing (opening a file is right-only, across the whole app). `left` walks
        # back through the query and exits the search once it is empty.
        : | fzf --ansi --disabled --no-sort \
          --header="$(sh "$X/scope.sh" header)" \
          --bind "change:reload:sleep 0.1; $GENQ {q}" \
          --bind "tab:execute-silent(sh \"$X/scope.sh\" toggle)+transform-header(sh \"$X/scope.sh\" header)+reload:$GENQ {q}" \
          --bind 'left:transform:[ -n {q} ] && echo backward-delete-char || { : > "$XPDT_LEFT_EXIT"; echo abort; }' \
          --bind "right:execute(XPLR_FOCUS_PATH=\"\$(sh \"$X/resolve.sh\" {1})\" XPLR_PREVIEW_LINE={2} sh \"$X/open-or-preview.sh\")" \
          --bind "ctrl-o:execute(sh \"$X/reveal.sh\" \"\$(sh \"$X/resolve.sh\" {1})\")" \
          --bind 'enter:ignore' \
          --delimiter : \
          --preview "F=\$(sh \"$X/resolve.sh\" {1}); bat --style=numbers --color=always --highlight-line {2} \"\$F\" 2>/dev/null || cat -n \"\$F\"" \
          --preview-window 'up,60%,+{2}-5' >/dev/null 2>&1 || true
        # Drain keystrokes buffered while fzf was open so they do not leak into xpdt
        # afterwards and fire key bindings.
        sh "$X/flush-input.sh"
      ]===]
    }
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["'"] = {
  help = "back to start dir",
  messages = {
    {
      BashExecSilently = [===[
        "$XPLR" -m 'ChangeDirectory: %q' "${XPLR_INITIAL_PWD:?}"
      ]===]
    }
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["w"] = {
  help = "next git repo",
  messages = {
    {
      BashExecSilently = [===[
        next=$(sh "$HOME/.config/xpdt/next-git-repo.sh" "$PWD")
        [ -n "$next" ] && "$XPLR" -m 'ChangeDirectory: %q' "$next"
      ]===]
    }
  }
}

xplr.config.general.table.header.cols = {
  { format = " index" },
  { format = " ╭─── path" },
  { format = "M" },
  { format = " git author" },
  { format = "size" },
  { format = "modified" },
}

xplr.config.general.table.row.cols = {
  { format = "builtin.fmt_general_table_row_cols_0", style = { add_modifiers = { "Dim" } } },
  { format = "builtin.fmt_general_table_row_cols_1", style = {} },
  { format = "custom.git_modified", style = { fg = "Yellow" } },
  { format = "builtin.fmt_general_table_row_cols_2", style = { fg = "DarkGray" } },
  { format = "builtin.fmt_general_table_row_cols_3", style = { fg = "DarkGray" } },
  { format = "builtin.fmt_general_table_row_cols_4", style = { fg = "DarkGray" } },
}

xplr.config.general.table.col_widths = {
  { Percentage = 10 },
  { Percentage = 41 },
  { Length = 1 },
  { Percentage = 18 },
  { Percentage = 10 },
  { Percentage = 20 },
}

xplr.config.general.focus_ui = {
  prefix = "▌ ",
  suffix = "",
  style = { add_modifiers = { "Bold" } },
}

xplr.config.general.default_ui = {
  prefix = "  ",
  suffix = "",
  style = {},
}

xplr.config.general.table.header.style = { fg = "DarkGray", add_modifiers = { "Bold" } }

-- Shown wherever a column has nothing to report, so no cell in the table is ever
-- blank and "nothing here" is distinguishable from "not computed yet".
local NO_VALUE = "N/A"

local git_author_cache = {}
local git_author_dir_done = {}
local git_state_cache = {}
local repo_root_cache = {}
local claude_cache = {}

-- Git state is repo-wide and cached across directory navigation (it is dropped
-- explicitly by invalidate_git after an xpdt action, not on every directory change).
-- GIT_TTL is the backstop for changes made outside xpdt (e.g. edits in another
-- terminal): the panels catch up within this many seconds even without an action.
-- Reaching the TTL no longer costs a frame - it only schedules a background refresh,
-- so the panels go a little stale rather than the whole app going unresponsive.
local GIT_TTL = 10
local CLAUDE_TTL = 5
local xplrignore_active = false

-- Quote a value for POSIX sh. Paths reach the helper scripts as command strings
-- (neither io.popen nor xplr's BashExec takes an argument vector), so anything
-- interpolated into one must go through this: a directory named `x$(cmd)` or
-- ``x`cmd` `` would otherwise be executed by the shell simply because xpdt was
-- pointed at it (render_layout resolves the repo root on every render). Single
-- quotes make the shell treat every byte literally; an embedded ' is closed,
-- escaped and reopened.
local function shq(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function dir_of(path)
  local parent = path:match("^(.*)/[^/]+$")
  if parent == nil or parent == "" then
    return "/"
  end
  return parent
end

local function now_secs()
  if os and os.time then
    return os.time()
  end
  return 0
end

local function regex_escape(s)
  local escaped = s:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%{}|\\]", "\\%0")
  return escaped
end

-- Where git-state.sh leaves this repo's state. The path is derived here, in Lua, and
-- handed to the script as an argument, so the two sides never have to agree on a hash
-- implementation - Lua names the file, the script writes where it is told. It lives
-- under the cache dir and not in ~/.config/xpdt because that directory is a symlink
-- into the xpdt repo, where cache files would surface as untracked changes.
local state_dir = (os.getenv("XDG_CACHE_HOME") or ((os.getenv("HOME") or "") .. "/.cache")) .. "/xpdt"

local function state_base(root)
  local h = 5381
  for i = 1, #root do
    h = (h * 33 + root:byte(i)) % 4294967296
  end
  local name = root:match("([^/]+)$") or "root"
  name = name:gsub("[^%w%-_.]", "_")
  return state_dir .. "/git-" .. name .. "-" .. string.format("%08x", math.floor(h))
end

local function refresh_cmd(root)
  return 'sh "$HOME/.config/xpdt/git-state.sh" ' .. shq(root) .. " " .. shq(state_base(root))
end

local refresh_requested = {}

-- Start a refresh and do not wait for it. This is what keeps git off the render path:
-- the trailing & makes the shell fork the job and exit, so closing the handle waits
-- only for that short-lived sh, never for git. The redirections matter - without them
-- the detached job keeps the pipe open and the close blocks on it, which would put the
-- stall straight back.
local function request_refresh(root)
  local now = now_secs()
  local last = refresh_requested[root]
  if last and (now - last) < 2 then
    return
  end
  refresh_requested[root] = now
  local h = io.popen(refresh_cmd(root) .. " >/dev/null 2>&1 &")
  if h then
    h:close()
  end
end

-- Refresh and wait. Only for the two moments where a stale frame would be wrong
-- rather than merely late: the first sighting of a repo (the alternative is painting
-- an empty panel) and immediately after an xpdt action changed git state. Never
-- called from a render that already has something to draw.
local function refresh_blocking(root)
  local h = io.popen(refresh_cmd(root) .. " >/dev/null 2>&1")
  if h then
    h:read("*a")
    h:close()
  end
  refresh_requested[root] = now_secs()
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local data = f:read("*a")
  f:close()
  return data
end

-- Resolve the git repo root for a directory. Uses repo-root.sh rather than a bare
-- `git -C ... rev-parse` so a symlinked location keeps the git context of the real
-- directory the symlink lives in (where you entered it from), instead of jumping to
-- the symlink target's own repo - git -C would chdir through the symlink and resolve
-- it physically. Cached per dir for the session.
-- Native, no-fork checks; guarded so a missing util just means the script runs, as before.
local HAVE_UTIL = type(xplr.util) == "table"
  and type(xplr.util.is_symlink) == "function"
  and type(xplr.util.exists) == "function"

local function repo_root_of(dir)
  local cached = repo_root_cache[dir]
  if cached ~= nil then
    return cached
  end

  -- Fast path: inherit the parent's answer, which saves the one spawn per directory
  -- that used to be paid on the way into every new folder. This is exact, not a
  -- guess: repo-root.sh anchors on the deepest symlinked path component, and adding
  -- one more non-symlink component cannot change which component that is, so the
  -- anchor - and therefore the repo it resolves to - is identical to the parent's.
  -- Two cases would break that and so still run the script: a symlinked leaf, which
  -- introduces a new deepest symlink and moves the anchor, and a directory that is
  -- itself a repo root (nested repo, submodule or worktree - `.git` can be a file),
  -- where git would stop here instead of carrying on up to the parent's root. A
  -- cached `false` (parent is in no repo) is inherited too, which is why this tests
  -- for nil rather than for truthiness. `.git` itself is excluded because git refuses
  -- to report a work tree from inside the git directory, so the script answers "no
  -- repo" there while the parent has one; everything below `.git` then inherits that
  -- "no repo" correctly.
  --
  -- Known limit: a mount point nested inside a repo. Git stops discovery at a
  -- filesystem boundary, so the child is in no repo while the parent is, and nothing
  -- in xplr.util exposes a device id to detect it. The panels would show the outer
  -- repo there. It is rare, and the effect is cosmetic - paths under the wrong root
  -- simply do not match, so the columns come out blank rather than wrong.
  if HAVE_UTIL then
    local parent = dir_of(dir)
    if parent ~= dir and dir:match("([^/]+)$") ~= ".git" then
      local inherited = repo_root_cache[parent]
      if
        inherited ~= nil
        and not xplr.util.is_symlink(dir)
        and not xplr.util.exists(dir .. "/.git")
      then
        repo_root_cache[dir] = inherited
        return inherited
      end
    end
  end

  local handle = io.popen('sh "$HOME/.config/xpdt/repo-root.sh" ' .. shq(dir) .. " 2>/dev/null")
  -- io.popen returns nil when the fork fails (process limit, out of memory). Indexing
  -- it raised, and because render_layout is the top-level Dynamic layout that error
  -- replaced the ENTIRE screen with a debug string. Nothing is cached on this path, so
  -- the next render simply tries again.
  if not handle then
    return false
  end
  -- Only the trailing newline is stripped: %s+$ would also eat a real trailing space
  -- in a directory name.
  local root = handle:read("*a"):gsub("\n$", "")
  handle:close()
  if root == "" then
    root = false
  end
  repo_root_cache[dir] = root
  return root
end

-- Parse one `git status --porcelain --ignored -z` blob. Split out of the old inline
-- git call so the exact same record walk now runs over bytes read from the cache file.
local function parse_status_blob(root, out)
  local dirty = {}
  local entries = {} -- { x = , y = , path = } per changed path, in git's order
  local ignored = {} -- exact ignored file paths
  local ignored_dirs = {} -- ignored directories (git collapses them; treated as prefixes)
  local pos, skip = 1, false
  while true do
    local nul = out:find("\0", pos, true)
    if not nul then
      break
    end
    local rec = out:sub(pos, nul - 1)
    pos = nul + 1
    if skip then
      skip = false
    elseif #rec > 3 then
      local x = rec:sub(1, 1)
      local y = rec:sub(2, 2)
      local rel = rec:sub(4)
      if x == "R" or x == "C" or y == "R" or y == "C" then
        skip = true -- the next record is this rename's original path
      end
      if x == "!" and y == "!" then
        if rel:sub(-1) == "/" then
          ignored_dirs[#ignored_dirs + 1] = root .. "/" .. rel:sub(1, -2)
        else
          ignored[root .. "/" .. rel] = true
        end
      else
        entries[#entries + 1] = { x = x, y = y, path = rel }
        local abs = root .. "/" .. rel
        dirty[abs] = true
        local d = dir_of(abs)
        while #d >= #root do
          dirty[d] = true
          if d == root then
            break
          end
          local parent = dir_of(d)
          if parent == d then
            break
          end
          d = parent
        end
      end
    end
  end
  return { dirty = dirty, entries = entries, ignored = ignored, ignored_dirs = ignored_dirs }
end

-- Parse the line-based half of the cache (branch, ahead/behind, the commit list).
local function parse_meta_blob(data)
  local branch, ab, lines = "", "", {}
  local unpushed, has_remotes = {}, false
  for line in data:gmatch("[^\n]+") do
    local key, rest = line:match("^(%a+) ?(.*)$")
    if key == "branch" then
      branch = rest
    elseif key == "ab" then
      local behind, ahead = rest:match("^(%d+)%s+(%d+)$")
      if ahead and behind then
        local parts = {}
        if tonumber(ahead) > 0 then
          parts[#parts + 1] = "↑" .. ahead
        end
        if tonumber(behind) > 0 then
          parts[#parts + 1] = "↓" .. behind
        end
        if #parts > 0 then
          ab = " " .. table.concat(parts, " ")
        end
      end
    elseif key == "remotes" then
      has_remotes = rest == "1"
    elseif key == "unpushed" then
      unpushed[rest] = true
    elseif key == "log" then
      local sha, tail = rest:match("^(%x+)\t(.*)$")
      if sha then
        -- A commit not reachable from any remote-tracking branch is local: hollow
        -- yellow dot. With no remotes at all we cannot tell, so everything stays filled.
        local marker = (has_remotes and unpushed[sha]) and "\27[33m○\27[0m" or "●"
        lines[#lines + 1] = marker .. " " .. tail:gsub("\t", "  ")
      else
        lines[#lines + 1] = rest
      end
    end
  end
  return branch, ab, lines
end

local EMPTY_STATE = {
  ts = 0,
  checked = -1,
  dirty = {},
  entries = {},
  ignored = {},
  ignored_dirs = {},
  branch = "",
  ab = "",
  lines = {},
}

-- One snapshot of the repo's git state, read from the two files git-state.sh writes.
-- Rendering never shells out: it reads files (no fork) and, when the snapshot is older
-- than GIT_TTL, schedules a background refresh and draws what it already has. The
-- previous version called git from inside the Dynamic render functions, so the first
-- keypress after a TTL expiry had to wait for six git invocations before xplr could
-- paint a frame - that was the stall on coming back to the window.
--
-- allow_blocking is set only by callers that must not paint a blank panel.
local function load_state(root, allow_blocking)
  local now = now_secs()
  local cached = git_state_cache[root]
  -- The per-row column functions ask for this once per visible row, so the files are
  -- re-read at most once a second; within the same second the in-memory copy answers.
  if cached and cached.checked == now then
    return cached
  end

  local base = state_base(root)
  local meta = read_file(base .. ".meta")
  if meta == nil and allow_blocking and not cached then
    refresh_blocking(root)
    meta = read_file(base .. ".meta")
  end

  local ts = 0
  if meta then
    ts = tonumber(meta:match("^ts (%d+)")) or 0
  end

  local state = cached
  if meta and (not cached or ts > cached.ts) then
    -- .status is written first and .meta (which carries the timestamp) last, so a
    -- torn read looks stale and simply refreshes again rather than showing nonsense.
    local status = parse_status_blob(root, read_file(base .. ".status") or "")
    local branch, ab, lines = parse_meta_blob(meta)
    state = {
      ts = ts,
      dirty = status.dirty,
      entries = status.entries,
      ignored = status.ignored,
      ignored_dirs = status.ignored_dirs,
      branch = branch,
      ab = ab,
      lines = lines,
    }
  end

  if not state then
    -- Cache the miss rather than returning EMPTY_STATE uncached. Uncached, every caller
    -- re-entered the blocking branch above, so a repo whose refresh keeps failing - a
    -- corrupt index, another window holding the lock, an unwritable cache dir - paid one
    -- blocking git-state.sh PER VISIBLE ROW on every frame: the exact stall 1.41.1
    -- removed, multiplied by the row count. Cached, the `checked == now` gate and
    -- request_refresh's own throttle bound it to one attempt per root every 2s.
    state = {
      ts = 0,
      dirty = {},
      entries = {},
      ignored = {},
      ignored_dirs = {},
      branch = "",
      ab = "",
      lines = {},
    }
  end
  if (now - state.ts) >= GIT_TTL then
    request_refresh(root)
  end
  state.checked = now
  git_state_cache[root] = state
  return state
end

local function git_status(root)
  return load_state(root, true)
end

-- Is `path` git-ignored, per the cached status? True for an exactly-ignored file, or
-- anything under an ignored directory (git reports those collapsed as `dir/`).
local function path_ignored(st, path)
  if st.ignored and st.ignored[path] then
    return true
  end
  for _, d in ipairs(st.ignored_dirs or {}) do
    if path == d or path:sub(1, #d + 1) == (d .. "/") then
      return true
    end
  end
  return false
end

local function git_changes_body(root)
  local staged = {}
  local unstaged = {}
  for _, e in ipairs(git_status(root).entries) do
    if e.x ~= " " and e.x ~= "?" then
      staged[#staged + 1] = "  " .. e.x .. " " .. e.path
    end
    if e.y ~= " " then
      unstaged[#unstaged + 1] = "  " .. e.y .. " " .. e.path
    end
  end
  local body = {}
  if #staged > 0 then
    body[#body + 1] = "Staged Changes (" .. #staged .. ")"
    for _, s in ipairs(staged) do
      body[#body + 1] = s
    end
  end
  if #unstaged > 0 then
    body[#body + 1] = "Changes (" .. #unstaged .. ")"
    for _, u in ipairs(unstaged) do
      body[#body + 1] = u
    end
  end
  return body
end

local function batch_git_authors(dirabs, root)
  local handle = io.popen('sh "$HOME/.config/xpdt/git-authors.sh" ' .. shq(dirabs) .. " 2>/dev/null")
  if not handle then
    return
  end
  local author = ""
  for line in handle:lines() do
    if line:sub(1, 3) == "@@@" then
      author = line:sub(4)
    elseif line ~= "" then
      local abs = root .. "/" .. line
      if git_author_cache[abs] == nil then
        git_author_cache[abs] = author
      end
    end
  end
  handle:close()
end

-- xplr's builtin size column returns "" for a directory, leaving a gap down the
-- column. Every row should carry a value, so a directory reports its own size - the
-- directory entry's, exactly what `ls -l` shows - rather than a recursive total:
-- walking a tree per row per render is the kind of work that was deliberately taken
-- off the render path, and it would be paid again on every keypress.
xplr.fn.builtin.fmt_general_table_row_cols_3 = function(m)
  local size = m.human_size
  if size == nil or size == "" then
    return NO_VALUE
  end
  return size
end

xplr.fn.builtin.fmt_general_table_row_cols_2 = function(m)
  local path = m.absolute_path
  local cached = git_author_cache[path]
  if cached ~= nil then
    return cached
  end

  local dir = dir_of(path)
  local root = repo_root_of(dir)
  if not root then
    git_author_cache[path] = NO_VALUE
    return NO_VALUE
  end

  -- Inside a symlinked directory the repo root is the logical origin (where the
  -- symlink lives), which does not track the symlink's contents, so there is no
  -- author to attribute - and the batch would query the wrong (physical) repo. There is
  -- nothing to show, so it reads as unknown rather than as a blank.
  if path:sub(1, #root + 1) ~= (root .. "/") then
    git_author_cache[path] = NO_VALUE
    return NO_VALUE
  end

  -- A gitignored path has no author to show; say "ignored" in bold red instead.
  if path_ignored(git_status(root), path) then
    local s = "\27[1;38;5;203mignored\27[0m"
    git_author_cache[path] = s
    return s
  end

  if not git_author_dir_done[dir] then
    batch_git_authors(dir, root)
    git_author_dir_done[dir] = true
  end

  local a = git_author_cache[path]
  if a == nil then
    -- Missed by the (bounded) batch: an untracked file, or one whose last commit is
    -- older than the author walk depth. Reported as unknown rather than looked up -
    -- spawning a git process per file on render was a big part of the lag when first
    -- entering a directory (especially one with many untracked files).
    a = NO_VALUE
    git_author_cache[path] = a
  end
  return a
end

xplr.fn.custom.git_modified = function(m)
  local path = m.absolute_path
  local root = repo_root_of(dir_of(path))
  if not root then
    return " "
  end
  if git_status(root).dirty[path] then
    return "●"
  end
  return " "
end

-- Called after an xpdt action that can change git state (stage / commit / discard /
-- stash / checkout / pull / undo / cherry-pick / create / delete / move), so the M
-- column, changes box, history graph and author column refresh on the next render.
-- Navigation does not invalidate: git status/log are repo-wide, so this is no longer
-- run on every directory change - moving between directories used to re-run
-- `git status` over the whole worktree each time, the main "exploring directories"
-- lag on a big repo. The caches now persist across navigation (see the TTLs) and are
-- only dropped here, on an actual change.
xplr.fn.custom.invalidate_git = function(app)
  -- Refresh synchronously here rather than leaving it to the next render: this runs
  -- after an action the user just took (where a short pause is expected and was
  -- already being paid), and it means the frame drawn straight afterwards shows the
  -- new state instead of one stale frame. Navigation never reaches this path.
  --
  -- Only the CURRENT repo is refreshed. git_state_cache accumulates an entry for every
  -- repo visited this session, and blocking on all of them made each action cost one
  -- full `git status --ignored` per repo browsed - about a second more for every extra
  -- repo, for snapshots the next frame will not even draw. The rest are dropped so they
  -- re-read lazily when they are next rendered.
  local current = app and app.pwd and repo_root_of(app.pwd) or nil
  for key in pairs(git_state_cache) do
    git_state_cache[key] = nil
  end
  if current then
    refresh_blocking(current)
  end
  for key in pairs(git_author_cache) do
    git_author_cache[key] = nil
  end
  for key in pairs(git_author_dir_done) do
    git_author_dir_done[key] = nil
  end
end

xplr.fn.custom.open_git_browser = function(app)
  return {
    { BashExec = "XPLR_DIR=" .. shq(app.pwd) .. ' sh "$HOME/.config/xpdt/git-log-browser.sh"' },
    { CallLuaSilently = "custom.invalidate_git" },
  }
end

xplr.fn.custom.open_changes_browser = function(app)
  return {
    { BashExec = "XPLR_DIR=" .. shq(app.pwd) .. ' sh "$HOME/.config/xpdt/git-changes-browser.sh"' },
    { CallLuaSilently = "custom.invalidate_git" },
  }
end

xplr.fn.custom.apply_xplrignore = function(app)
  if not app.pwd then
    return
  end
  local handle = io.open(app.pwd .. "/.xplrignore", "r")
  if not handle and not xplrignore_active then
    return
  end
  local msgs = { "ResetNodeFilters" }
  xplrignore_active = false
  if handle then
    local keeps = {}
    local hides = {}
    for raw in handle:lines() do
      local line = raw:gsub("^%s+", ""):gsub("%s+$", "")
      if line ~= "" and line:sub(1, 1) ~= "#" and line ~= "*" then
        if line:sub(1, 1) == "!" then
          keeps[#keeps + 1] = regex_escape(line:sub(2))
        else
          hides[#hides + 1] = line
        end
      end
    end
    handle:close()
    if #keeps > 0 then
      msgs[#msgs + 1] = {
        AddNodeFilter = { filter = "RelativePathDoesMatchRegex", input = "^(" .. table.concat(keeps, "|") .. ")/?$" },
      }
      xplrignore_active = true
    end
    for _, h in ipairs(hides) do
      msgs[#msgs + 1] = { AddNodeFilter = { filter = "RelativePathIsNot", input = h } }
      xplrignore_active = true
    end
  end
  msgs[#msgs + 1] = "ExplorePwd"
  return msgs
end

xplr.fn.custom.clear_xplrignore_flag = function()
  xplrignore_active = false
end

xplr.fn.custom.render_git_changes = function(ctx)
  local root = repo_root_of(ctx.app.pwd)
  if not root then
    return { CustomList = { ui = { title = { format = " changes " } }, body = {} } }
  end
  local body = git_changes_body(root)
  local max = ctx.layout_size.height
  if max and max > 0 and #body > max then
    local sliced = {}
    for i = 1, max do
      sliced[i] = body[i]
    end
    body = sliced
  end
  return { CustomList = { ui = { title = { format = " changes " } }, body = body } }
end

-- Passive Claude Code session indicator for the git-history panel: a short line
-- (marker + branch) shown when a session has recently been active in this repo.
-- Off unless the claude-integration setting is on - when off it returns "" without
-- spawning anything. Cached per repo (CLAUDE_TTL). claude-status.sh does the scan
-- of ~/.claude/projects.
local function claude_indicator(root)
  if not root or not read_bool_setting("claude-integration", false) then
    return ""
  end
  local now = now_secs()
  local cached = claude_cache[root]
  if cached and (now - cached.time) < CLAUDE_TTL then
    return cached.text
  end
  local text = ""
  local handle = io.popen('sh "$HOME/.config/xpdt/claude-status.sh" ' .. shq(root) .. " 2>/dev/null")
  if handle then
    text = handle:read("*a"):gsub("%s+$", "")
    handle:close()
  end
  claude_cache[root] = { time = now, text = text }
  return text
end

-- Trim a history row to `max` visible characters. The rows carry ANSI (the hollow
-- yellow dot on an unpushed commit), so escape sequences are stepped over rather than
-- counted, and UTF-8 is advanced a whole character at a time so a multi-byte glyph is
-- never split down the middle. The result is closed with a reset, and the ellipsis
-- occupies the last column so the row is exactly `max` wide.
local function truncate_visible(s, max)
  local width, i = 0, 1
  while i <= #s do
    local esc = s:match("^\27%[[0-9;]*m", i)
    if esc then
      i = i + #esc
    else
      local b = s:byte(i)
      local n = 1
      if b >= 0xF0 then
        n = 4
      elseif b >= 0xE0 then
        n = 3
      elseif b >= 0xC0 then
        n = 2
      end
      width = width + 1
      i = i + n
    end
  end
  if width <= max then
    return s
  end

  local out, col = {}, 0
  i = 1
  while i <= #s do
    local esc = s:match("^\27%[[0-9;]*m", i)
    if esc then
      out[#out + 1] = esc
      i = i + #esc
    else
      if col >= max - 1 then
        break
      end
      local b = s:byte(i)
      local n = 1
      if b >= 0xF0 then
        n = 4
      elseif b >= 0xE0 then
        n = 3
      elseif b >= 0xC0 then
        n = 2
      end
      out[#out + 1] = s:sub(i, i + n - 1)
      col = col + 1
      i = i + n
    end
  end
  return table.concat(out) .. "…\27[0m"
end

-- How many columns wide the git history panel should be. `off` (the default) means
-- full width, which is what xpdt has always done. Anything else is a column count from
-- the `,` menu; gate.sh validates it on the way out, so a junk config reads as off.
local function history_width()
  -- Floored to an integer: a Lua float reaches xplr as a Number rather than an Integer,
  -- and ratatui's Constraint::Length(u16) then fails to deserialize, which blanks the
  -- whole UI. gate.sh only ever writes the validated values, but a hand-edited
  -- `history-width=80.5` should degrade, not take the screen down.
  local n = tonumber(read_value_setting("history-width", "off"))
  if not n or n < 1 then
    return 0
  end
  return math.floor(n)
end

xplr.fn.custom.render_git_graph = function(ctx)
  local root = repo_root_of(ctx.app.pwd)
  if not root then
    return { CustomList = { ui = { title = { format = " git history " } }, body = {} } }
  end
  local cached = load_state(root, true)
  local title = " git history "
  if cached.branch ~= "" then
    title = " git history (" .. cached.branch .. (cached.ab or "") .. ") "
  end
  local body = cached.lines
  local max = ctx.layout_size.height
  if max and max > 0 and #body > max then
    local sliced = {}
    for i = 1, max do
      sliced[i] = body[i]
    end
    body = sliced
  end
  -- When the panel has been narrowed, trim the rows to the width it actually got minus
  -- its two border columns, so a cut row ends in an ellipsis instead of being clipped
  -- mid-word at the border. The renderer reads its own layout_size rather than the
  -- setting, so it is always right even where the requested width was clamped.
  --
  -- Trimming builds a new table: `body` may still be the snapshot's own `lines`, which
  -- is shared with the cache, and trimming it in place would corrupt it for every
  -- later render (and make a width change look permanent until the next git refresh).
  local width = 0
  if history_width() > 0 and ctx.layout_size and ctx.layout_size.width then
    width = ctx.layout_size.width - 2
  end
  if width > 0 then
    local trimmed = {}
    for i = 1, #body do
      trimmed[i] = truncate_visible(body[i], width)
    end
    body = trimmed
  end
  return { CustomList = { ui = { title = { format = title } }, body = body } }
end

-- The `claude` box below git history: shows the active-session indicator when the
-- claude-integration setting is on and a session is active in this repo; empty
-- (and given 0 height by render_layout) otherwise.
xplr.fn.custom.render_claude = function(ctx)
  local root = repo_root_of(ctx.app.pwd)
  local ci = root and claude_indicator(root) or ""
  local body = {}
  if ci ~= "" then
    for line in (ci .. "\n"):gmatch("(.-)\n") do
      body[#body + 1] = line
    end
  end
  return { CustomList = { ui = { title = { format = " claude " } }, body = body } }
end

-- A one-line note pinned under everything else, pointing at the `h` controls popup
-- so the keybindings are discoverable without already knowing the key. Turned off
-- with the help-hint setting in the `,` menu, which gives the row back to the layout.
--
-- The text is the panel's title, not its body, and that is the only way to get it onto
-- a single row. xplr's block() always attaches a title span (an empty one when the
-- panel gives no title), and ratatui reserves the top row of a block for its title
-- even when no borders are drawn - so a custom panel's body can never reach row 1, and
-- a body-based note needs two rows with the first one blank. A title renders on
-- exactly that reserved row, so putting the text there makes the panel genuinely one
-- row tall. Borders still have to be cleared, and an empty Lua table cannot express
-- that: `{}` serialises as a JSON object rather than an empty list, which leaves the
-- default borders in place - hence from_json.
local NO_BORDERS = xplr.util.from_json("[]")
local NO_MODIFIERS = xplr.util.from_json("[]")

xplr.fn.custom.render_hint = function(_)
  return {
    CustomParagraph = {
      ui = {
        borders = NO_BORDERS,
        title = {
          format = "  [h] keybindings",
          -- panel_ui.default's title style is bold; the note should recede, not shout,
          -- so the modifiers are cleared rather than inherited.
          style = { fg = { Rgb = { 128, 128, 128 } }, add_modifiers = NO_MODIFIERS },
        },
      },
      body = "",
    },
  }
end

local function hint_height()
  return read_bool_setting("help-hint", true) and 1 or 0
end

-- Height of xplr's built-in InputAndLogs strip. Hiding it is a setting, but that panel
-- is also where xplr draws its input line, so hiding it unconditionally would leave you
-- typing blind into a prompt you cannot see (`duplicate as`, for one, creates files).
-- It therefore comes back on its own whenever xplr is in any mode other than `default`
-- - xpdt binds every one of its own actions in `default` and does its prompting through
-- external scripts, so a non-default mode means a builtin wants the input line. Testing
-- showed `input_buffer` is still nil on the frame a prompt opens and only fills once
-- there is text, so the mode is the signal and the buffer is only a backstop.
local LOGS_HEIGHT = 3

local function logs_height(ctx)
  if read_bool_setting("show-logs", true) then
    return LOGS_HEIGHT
  end
  local mode = ctx.app.mode
  if (mode and mode.name and mode.name ~= "default") or ctx.app.input_buffer ~= nil then
    return LOGS_HEIGHT
  end
  return 0
end

xplr.fn.custom.render_layout = function(ctx)
  local root = repo_root_of(ctx.app.pwd)
  local n = 0
  if root then
    n = #git_changes_body(root)
  end
  local changes_height = 0
  if n > 0 then
    changes_height = n + 2
    if changes_height > 30 then
      changes_height = 30
    end
  end
  -- The claude box is only present (and only takes rows) when the indicator has content.
  local claude_height = 0
  if root then
    local ci = claude_indicator(root)
    if ci ~= "" then
      local nc = 1
      for _ in ci:gmatch("\n") do
        nc = nc + 1
      end
      claude_height = nc + 2
    end
  end
  -- Git history yields vertical space before the file explorer: when the window is short the
  -- history graph shrinks (down to GRAPH_MIN rows) while the file-explorer Table keeps at least
  -- TABLE_MIN rows. Only once the history is at its floor does the Table itself start to shrink.
  local GRAPH_MAX, GRAPH_MIN, TABLE_MIN = 14, 3, 10
  local hint = hint_height()
  local logs = logs_height(ctx)
  local graph_height = GRAPH_MAX
  local h = ctx.layout_size and ctx.layout_size.height

  -- The boxes above also have to fit. Only graph_height was clamped against the
  -- terminal, so a dirty repo in a short window demanded more rows than existed:
  -- ratatui weights Min above Length, which pinned the Table to its 1-row minimum and
  -- left the file listing with ZERO visible rows (draw_table subtracts a 3-row header
  -- and chrome). On a 24-row terminal that began at about 14 modified files - an
  -- ordinary working state. The changes and claude boxes now yield first, in that
  -- order, so the listing always keeps TABLE_MIN.
  if h then
    local spare = h - TABLE_MIN - GRAPH_MIN - logs - hint
    if claude_height > 0 and claude_height > spare then
      claude_height = spare > 0 and spare or 0
    end
    local left = spare - claude_height
    if changes_height > left then
      changes_height = left > 0 and left or 0
    end
  end

  if h then
    -- logs = InputAndLogs, 0 when hidden (controls are the `h` popup);
    -- hint = the bottom note, 0 when off
    graph_height = h - TABLE_MIN - changes_height - claude_height - logs - hint
    if graph_height > GRAPH_MAX then
      graph_height = GRAPH_MAX
    elseif graph_height < GRAPH_MIN then
      graph_height = GRAPH_MIN
    end
  end
  -- Capping the panel's width means putting it in a horizontal split of its own row and
  -- letting `Nothing` take the rest, since a vertical split's rows are always full
  -- width. Skipped when the terminal is already narrower than the requested width, so a
  -- small window is never given a pointless empty column.
  local history_split = { Dynamic = "custom.render_git_graph" }
  local hw = history_width()
  local avail = ctx.layout_size and ctx.layout_size.width or 0
  if hw > 0 and avail > 0 and hw < avail then
    history_split = {
      Horizontal = {
        config = { constraints = { { Length = hw }, { Min = 0 } } },
        splits = {
          { Dynamic = "custom.render_git_graph" },
          -- Not the `Nothing` layout: xplr's draw_nothing renders an empty paragraph
          -- inside the default block, which has all four borders, so it paints a second
          -- empty box beside the panel. A borderless static paragraph leaves the space
          -- genuinely blank.
          { Static = { CustomParagraph = { ui = { borders = NO_BORDERS }, body = "" } } },
        },
      },
    }
  end

  return {
    CustomLayout = {
      Vertical = {
        config = {
          constraints = {
            { Min = 1 },
            { Length = changes_height },
            { Length = graph_height },
            { Length = claude_height },
            { Length = logs },
            { Length = hint },
          },
        },
        splits = {
          "Table",
          { Dynamic = "custom.render_git_changes" },
          history_split,
          { Dynamic = "custom.render_claude" },
          "InputAndLogs",
          { Dynamic = "custom.render_hint" },
        },
      },
    },
  }
end

dofile(os.getenv("HOME") .. "/.config/xpdt/theme.lua")

return {
  on_load = {
    { CallLuaSilently = "custom.apply_xplrignore" },
  },
  on_directory_change = {
    { CallLuaSilently = "custom.apply_xplrignore" },
  },
}
