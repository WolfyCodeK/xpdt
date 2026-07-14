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
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["a"] = {
  help = "create file (2 digit code)",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/file-op.sh\" newfile" },
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["f"] = {
  help = "create folder (2 digit code)",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/file-op.sh\" newfolder" },
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["m"] = {
  help = "move/rename (2 digit code)",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/file-op.sh\" move" },
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["g"] = {
  help = "git menu",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/git-menu.sh\"" },
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["s"] = {
  help = "git stash browser",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/git-stash-browser.sh\"" },
    "ExplorePwdAsync",
  }
}

xplr.config.modes.builtin.default.key_bindings.on_key["h"] = {
  help = "controls / help",
  messages = {
    { BashExec = "sh \"$HOME/.config/xpdt/help.sh\"" },
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
  help = "enter dir or preview file",
  messages = {
    {
      BashExecSilently = [===[
        if [ -d "$XPLR_FOCUS_PATH" ]; then
          echo 'Enter' >> "${XPLR_PIPE_MSG_IN:?}"
        else
          "$XPLR" -m 'BashExec: %q' "sh $HOME/.config/xpdt/preview-file.sh"
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
        SF="$X/.search-scope"; [ -f "$SF" ] || echo here > "$SF"
        HERE="$(pwd)"; ROOT="${XPLR_INITIAL_PWD:-$HERE}"
        GEN="sh $X/search.sh files '$SF' '$HERE' '$ROOT'"
        FILE=$(eval "$GEN" | fzf --no-sort --exact \
          --header="$(sh $X/scope.sh header "$SF")" \
          --bind "tab:execute-silent(sh $X/scope.sh toggle '$SF')+transform-header(sh $X/scope.sh header '$SF')+reload:$GEN" \
          --bind "change:reload:sleep 0.1; $GEN" \
          --bind 'left:abort' \
          --bind "right:execute(XPLR_FOCUS_PATH=\"\$(sh $X/resolve.sh '$SF' '$HERE' '$ROOT' {})\" sh $X/preview-file.sh)" \
          --bind 'enter:accept')
        if [ -n "$FILE" ]; then
          FULL=$(sh "$X/resolve.sh" "$SF" "$HERE" "$ROOT" "$FILE")
          echo 'ResetNodeFilters' >> "${XPLR_PIPE_MSG_IN:?}"
          echo "CallLuaSilently: 'custom.clear_xplrignore_flag'" >> "${XPLR_PIPE_MSG_IN:?}"
          echo "FocusPath: '$FULL'" >> "${XPLR_PIPE_MSG_IN:?}"
        fi
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
        SF="$X/.search-scope"; [ -f "$SF" ] || echo here > "$SF"
        HERE="$(pwd)"; ROOT="${XPLR_INITIAL_PWD:-$HERE}"
        GENQ="sh $X/search.sh content '$SF' '$HERE' '$ROOT'"
        RESULT=$(
          : | fzf --ansi --disabled --no-sort \
            --header="$(sh $X/scope.sh header "$SF")" \
            --bind "change:reload:sleep 0.1; $GENQ {q}" \
            --bind "tab:execute-silent(sh $X/scope.sh toggle '$SF')+transform-header(sh $X/scope.sh header '$SF')+reload:$GENQ {q}" \
            --bind 'left:abort' \
            --bind "right:execute(XPLR_FOCUS_PATH=\"\$(sh $X/resolve.sh '$SF' '$HERE' '$ROOT' {1})\" XPLR_PREVIEW_LINE={2} sh $X/preview-file.sh)" \
            --bind 'enter:accept' \
            --delimiter : \
            --preview "F=\$(sh $X/resolve.sh '$SF' '$HERE' '$ROOT' {1}); bat --style=numbers --color=always --highlight-line {2} \"\$F\" 2>/dev/null || cat -n \"\$F\"" \
            --preview-window 'up,60%,+{2}-5'
        )
        if [ -n "$RESULT" ]; then
          FILE=$(sh "$X/resolve.sh" "$SF" "$HERE" "$ROOT" "${RESULT%%:*}")
          XPLR_FOCUS_PATH="$FILE" sh "$X/open-menu.sh"
        fi
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

local git_author_cache = {}
local git_author_dir_done = {}
local git_status_cache = {}
local repo_root_cache = {}
local git_log_cache = {}

local STATUS_TTL = 1
local GIT_LOG_TTL = 5
local xplrignore_active = false

local function dir_of(path)
  local parent = path:match("^(.*)/[^/]+$")
  if parent == nil or parent == "" then
    return "/"
  end
  return parent
end

local function base_of(path)
  return path:match("[^/]+$") or path
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

local function repo_root_of(dir)
  local cached = repo_root_cache[dir]
  if cached ~= nil then
    return cached
  end
  local handle = io.popen('git -C "' .. dir .. '" rev-parse --show-toplevel 2>/dev/null')
  local root = handle:read("*a"):gsub("%s+$", "")
  handle:close()
  if root == "" then
    root = false
  end
  repo_root_cache[dir] = root
  return root
end

local function git_status(root)
  local cached = git_status_cache[root]
  local now = now_secs()
  if cached and (now - cached.time) < STATUS_TTL then
    return cached
  end
  local dirty = {}
  local lines = {}
  local handle = io.popen('git -C "' .. root .. '" status --porcelain 2>/dev/null')
  for line in handle:lines() do
    if #line > 3 then
      lines[#lines + 1] = line
      local rel = line:sub(4)
      local arrow = rel:find(" -> ", 1, true)
      if arrow then
        rel = rel:sub(arrow + 4)
      end
      rel = rel:gsub('^"', ''):gsub('"$', '')
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
  handle:close()
  git_status_cache[root] = { time = now, dirty = dirty, lines = lines }
  return git_status_cache[root]
end

local function git_changes_body(root)
  local lines = git_status(root).lines
  local staged = {}
  local unstaged = {}
  for _, line in ipairs(lines) do
    local x = line:sub(1, 1)
    local y = line:sub(2, 2)
    local path = line:sub(4)
    if x ~= " " and x ~= "?" then
      staged[#staged + 1] = "  " .. x .. " " .. path
    end
    if y ~= " " then
      unstaged[#unstaged + 1] = "  " .. y .. " " .. path
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
  local handle = io.popen('sh "' .. os.getenv("HOME") .. '/.config/xpdt/git-authors.sh" "' .. dirabs .. '" 2>/dev/null')
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

xplr.fn.builtin.fmt_general_table_row_cols_2 = function(m)
  local path = m.absolute_path
  local cached = git_author_cache[path]
  if cached ~= nil then
    return cached
  end

  local dir = dir_of(path)
  local root = repo_root_of(dir)
  if not root then
    git_author_cache[path] = ""
    return ""
  end

  if not git_author_dir_done[dir] then
    batch_git_authors(dir, root)
    git_author_dir_done[dir] = true
  end

  local a = git_author_cache[path]
  if a == nil then
    local handle = io.popen('git -C "' .. dir .. '" log -1 --format="%an" -- "' .. base_of(path) .. '" 2>/dev/null')
    a = handle:read("*a"):gsub("%s+$", "")
    handle:close()
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

xplr.fn.custom.refresh_git_status = function()
  for key in pairs(git_status_cache) do
    git_status_cache[key] = nil
  end
end

xplr.fn.custom.open_git_browser = function(app)
  return {
    { BashExec = "XPLR_DIR='" .. app.pwd .. "' sh \"$HOME/.config/xpdt/git-log-browser.sh\"" },
  }
end

xplr.fn.custom.open_changes_browser = function(app)
  return {
    { BashExec = "XPLR_DIR='" .. app.pwd .. "' sh \"$HOME/.config/xpdt/git-changes-browser.sh\"" },
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

xplr.fn.custom.render_git_graph = function(ctx)
  local root = repo_root_of(ctx.app.pwd)
  if not root then
    return { CustomList = { ui = { title = { format = " git history " } }, body = {} } }
  end
  local now = now_secs()
  local cached = git_log_cache[root]
  if not (cached and (now - cached.time) < GIT_LOG_TTL) then
    local branch = ""
    local bh = io.popen('git -C "' .. root .. '" rev-parse --abbrev-ref HEAD 2>/dev/null')
    if bh then
      branch = bh:read("*a"):gsub("%s+$", "")
      bh:close()
    end
    local ab = ""
    local abh = io.popen('git -C "' .. root .. '" rev-list --left-right --count "@{u}...HEAD" 2>/dev/null')
    if abh then
      local counts = abh:read("*a"):gsub("%s+$", "")
      abh:close()
      local behind, ahead = counts:match("^(%d+)%s+(%d+)$")
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
    end
    local lines = {}
    local lh = io.popen('git -C "' .. root .. '" log --format="● %s  %an" -n 100 2>/dev/null')
    if lh then
      for line in lh:lines() do
        lines[#lines + 1] = line
      end
      lh:close()
    end
    git_log_cache[root] = { time = now, branch = branch, ab = ab, lines = lines }
    cached = git_log_cache[root]
  end
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
  return { CustomList = { ui = { title = { format = title } }, body = body } }
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
  -- Git history yields vertical space before the file explorer: when the window is short the
  -- history graph shrinks (down to GRAPH_MIN rows) while the file-explorer Table keeps at least
  -- TABLE_MIN rows. Only once the history is at its floor does the Table itself start to shrink.
  local GRAPH_MAX, GRAPH_MIN, TABLE_MIN = 14, 3, 10
  local graph_height = GRAPH_MAX
  local h = ctx.layout_size and ctx.layout_size.height
  if h then
    graph_height = h - TABLE_MIN - changes_height - 3 -- 3 = InputAndLogs (controls are now the `h` popup)
    if graph_height > GRAPH_MAX then
      graph_height = GRAPH_MAX
    elseif graph_height < GRAPH_MIN then
      graph_height = GRAPH_MIN
    end
  end
  return {
    CustomLayout = {
      Vertical = {
        config = {
          constraints = {
            { Min = 1 },
            { Length = changes_height },
            { Length = graph_height },
            { Length = 3 },
          },
        },
        splits = {
          "Table",
          { Dynamic = "custom.render_git_changes" },
          { Dynamic = "custom.render_git_graph" },
          "InputAndLogs",
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
    { CallLuaSilently = "custom.refresh_git_status" },
    { CallLuaSilently = "custom.apply_xplrignore" },
  },
}
