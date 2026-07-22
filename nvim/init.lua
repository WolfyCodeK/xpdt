-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- options
vim.g.mapleader = " "
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.autoread = true
vim.opt.updatetime = 1000
vim.opt.clipboard = "unnamedplus"
vim.opt.mouse = "a"
vim.opt.signcolumn = "yes"
vim.opt.wrap = true
vim.opt.breakindent = true

-- The active colour theme, from xpdt's `,` settings menu (~/.config/xpdt/.gate-config,
-- `theme=<name>`, default monokai). Maps to the colorscheme applied below; only Monokai
-- layers the bat-matched palette (the other themes' own colorschemes already match
-- their bat theme).
local function xpdt_theme()
  local t = "monokai"
  local f = io.open(vim.fn.expand("~/.config/xpdt/.gate-config"), "r")
  if f then
    for line in f:lines() do
      local v = line:match("^theme=(%w+)")
      if v then
        t = v
      end
    end
    f:close()
  end
  return t
end
local XPDT_THEME = xpdt_theme()
local XPDT_COLORSCHEME = ({
  monokai = "monokai",
  gruvbox = "gruvbox",
  nord = "nord",
  dracula = "dracula",
  tokyonight = "tokyonight-night",
})[XPDT_THEME] or "monokai"

-- bat Monokai Extended palette, layered over the colorscheme
local function bat_palette()
  local P = {
    pink = "#F92672", green = "#A6E22E", purple = "#BE84FF", yellow = "#E6DB74",
    cyan = "#66D9EF", grey = "#75715E", orange = "#FD971F", fg = "#F8F8F2",
  }
  local hl = vim.api.nvim_set_hl
  hl(0, "Normal", { fg = P.fg, bg = "none" })
  local m = {
    ["@comment"] = P.grey,
    ["@keyword"] = P.pink, ["@keyword.function"] = P.pink, ["@keyword.operator"] = P.pink,
    ["@keyword.return"] = P.pink, ["@keyword.conditional"] = P.pink, ["@keyword.repeat"] = P.pink,
    ["@keyword.exception"] = P.pink, ["@keyword.import"] = P.pink, ["@operator"] = P.pink,
    ["@string"] = P.yellow, ["@string.documentation"] = P.yellow, ["@character"] = P.yellow,
    ["@number"] = P.purple, ["@number.float"] = P.purple, ["@boolean"] = P.purple,
    ["@constant"] = "#FFFFFF", ["@constant.builtin"] = P.purple,
    ["@function"] = P.green, ["@function.method"] = P.green,
    ["@function.call"] = P.fg, ["@function.method.call"] = P.fg, ["@function.builtin"] = P.fg,
    ["@variable.parameter"] = P.orange,
    ["@variable"] = P.fg, ["@variable.member"] = P.fg, ["@property"] = P.fg, ["@module"] = P.fg,
    ["@punctuation.bracket"] = P.fg, ["@punctuation.delimiter"] = P.fg, ["@constructor"] = P.fg,
  }
  for g, c in pairs(m) do hl(0, g, { fg = c }) end
  hl(0, "@type", { fg = P.cyan })
  hl(0, "@type.builtin", { fg = P.cyan })
  hl(0, "@type.definition", { fg = P.cyan, underline = true })
  hl(0, "@type.classdef", { fg = P.cyan, underline = true })
  hl(0, "@type.inherited", { fg = P.green, underline = true })
end
-- Only Monokai uses the hand-tuned bat palette; the other themes stand on their own.
if XPDT_THEME == "monokai" then
  vim.api.nvim_create_autocmd("ColorScheme", { callback = bat_palette })
end

-- plugins
require("lazy").setup({
  { "tanvirtin/monokai.nvim", lazy = false, priority = 1000 },
  -- Extra colour themes, selectable in xpdt's `,` settings menu (only the chosen one
  -- is applied at startup). Small, pure-Lua colorschemes.
  { "ellisonleao/gruvbox.nvim", lazy = false, priority = 1000 },
  { "shaunsingh/nord.nvim", lazy = false, priority = 1000 },
  { "Mofiqul/dracula.nvim", lazy = false, priority = 1000 },
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
  {
    -- The `main` branch, not `master`: master is frozen and only supports Neovim
    -- <= 0.10, so on 0.11+/0.12 its queries error (e.g. opening a markdown file:
    -- "attempt to call method 'range' (a nil value)" from the injection query).
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    config = function()
      local ok, ts = pcall(require, "nvim-treesitter")
      if ok then
        local want = {
          "python", "javascript", "typescript", "tsx", "lua", "json", "html", "css",
          "bash", "yaml", "toml", "markdown", "markdown_inline", "vim", "vimdoc",
        }
        -- Install only the parsers not already built (main's install() would otherwise
        -- re-fetch every startup), and only if the tree-sitter CLI is present to build
        -- them. All wrapped in pcall so a missing CLI never errors on startup.
        local have = {}
        pcall(function()
          for _, p in ipairs(ts.get_installed and ts.get_installed() or {}) do
            have[p] = true
          end
        end)
        if vim.fn.executable("tree-sitter") == 1 then
          local missing = {}
          for _, p in ipairs(want) do
            if not have[p] then
              missing[#missing + 1] = p
            end
          end
          if #missing > 0 then
            pcall(ts.install, missing)
          end
        end
      end
      -- The main branch does not auto-enable highlighting; start it per buffer (the
      -- built-in highlighter, which the bat palette's @capture groups still colour).
      -- pcall so filetypes with no installed parser fall back to Vim syntax quietly.
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
        end,
      })
    end,
  },
  {
    url = "https://codeberg.org/andyg/leap.nvim",
    config = function()
      vim.keymap.set({ "n", "x", "o" }, "s", "<Plug>(leap)")
    end,
  },
  { "kylechui/nvim-surround", version = "*", config = true },
  { "numToStr/Comment.nvim", config = true },
  { "nvim-lualine/lualine.nvim", config = function() require("lualine").setup({ options = { theme = "auto" } }) end },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", config = true },
  -- Installs the language servers you enable in xpdt's settings (see the LSP block
  -- below). Only the servers you pick are fetched, into Mason's own isolated dir.
  { "mason-org/mason.nvim", lazy = false, build = ":MasonUpdate", config = function() require("mason").setup() end },
  -- Per-server LSP configs (the community standard). We keep Neovim's built-in LSP
  -- client + completion and Mason for installs; lspconfig just supplies each server's
  -- correct cmd / root / init_options / settings - e.g. the ESLint and ts_ls quirks a
  -- hand-rolled config gets wrong. vim.lsp.enable() reads its lsp/<name>.lua files.
  { "neovim/nvim-lspconfig", lazy = false },
})

-- theme (for monokai this fires the ColorScheme autocmd that applies the bat palette)
if not pcall(vim.cmd.colorscheme, XPDT_COLORSCHEME) then
  pcall(vim.cmd.colorscheme, "monokai")
end

-- live reload: pick up external changes like the preview does
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "FocusGained", "BufEnter" }, { command = "silent! checktime" })
local reload_timer = (vim.uv or vim.loop).new_timer()
reload_timer:start(1000, 1000, vim.schedule_wrap(function() vim.cmd("silent! checktime") end))

-- Copy the whole file to the system clipboard with <leader>Y (space then shift-Y).
-- clipboard=unnamedplus already routes yanks to the system clipboard (pbcopy on
-- macOS), so this is just a one-key "yank the entire buffer" - the equivalent of the
-- old file preview's ctrl-y, now that files open in Neovim. (Over SSH the clipboard
-- needs an OSC52-capable terminal or provider; locally on macOS it just works.)
vim.keymap.set("n", "<leader>Y", "<cmd>%y+<cr>", { desc = "Copy whole file to clipboard" })

-- Read a boolean xpdt setting from ~/.config/xpdt/.gate-config (key=1 -> true).
local function xpdt_setting_on(key)
  local f = io.open(vim.fn.expand("~/.config/xpdt/.gate-config"), "r")
  if not f then
    return false
  end
  local on = false
  local pat = "^" .. key:gsub("%-", "%%-") .. "=1%s*$"
  for line in f:lines() do
    if line:match(pat) then
      on = true
    end
  end
  f:close()
  return on
end

-- Optional (xpdt setting "nvim-left-exits"): when nothing is modified, <Left> at the
-- start of a line quits back to xpdt - so `left` still means "back" once you can go no
-- further left, matching the file manager. It never fires with unsaved edits (it
-- checks that no buffer is modified), and only rebinds the arrow, not `h`.
if xpdt_setting_on("nvim-left-exits") then
  vim.keymap.set("n", "<Left>", function()
    local no_edits = #vim.fn.getbufinfo({ bufmodified = 1 }) == 0
    if no_edits and vim.fn.col(".") == 1 then
      -- Tell the launcher (flush-input.sh) we left via a (possibly held) left, so it
      -- drains the key's auto-repeat until you release instead of letting it overshoot
      -- xpdt up through directories. The repeats arrive after Neovim closes, so a plain
      -- flush misses them; this flag switches flush-input.sh into drain-until-quiet mode.
      pcall(vim.fn.writefile, {}, "/tmp/xpdt-left-exit")
      vim.cmd("qall")
    else
      vim.cmd("normal! h")
    end
  end, { desc = "Left, or exit to xpdt at line start when there are no edits" })
end

-- Optional (xpdt setting "nvim-help-bar"): a one-line key-hint bar pinned to the top of
-- the window (Neovim's winbar) so the keybinds you keep forgetting stay on screen while
-- you edit. winbar is a single line and cannot wrap, so the hints are width-packed - as
-- many as fit the window, most-useful first - with `ctrl-h` (the full cheat sheet) last.
-- The keys mirror that cheat sheet. Toggle it in xpdt's `,` settings menu.
if xpdt_setting_on("nvim-help-bar") then
  local items = { { "spc Y", "copy file" } }
  -- `<Left>` only leaves Neovim when the left-exits setting is on, so only advertise it then.
  if xpdt_setting_on("nvim-left-exits") then
    items[#items + 1] = { "<-", "back" }
  end
  vim.list_extend(items, {
    { "gd", "def" }, { "gr", "refs" }, { "K", "hover" },
    { "spc rn", "rename" }, { "spc ca", "action" }, { "spc f", "format" }, { "spc e", "error" },
    { "]d [d", "diag" }, { "gc", "comment" }, { "s", "leap" }, { "cs ds ys", "surround" },
    { ":w", "save" }, { ":q", "quit" }, { "u", "undo" }, { "C-r", "redo" }, { "C-h", "all keys" },
  })
  -- key = bright, description = dim; links so they follow whichever colour theme is active.
  vim.api.nvim_set_hl(0, "XpdtHelpKey", { link = "Function" })
  vim.api.nvim_set_hl(0, "XpdtHelpDesc", { link = "Comment" })
  _G.xpdt_help_bar = function()
    local avail = vim.api.nvim_win_get_width(0) - 1
    local out, used = {}, 0
    for _, it in ipairs(items) do
      local disp = #it[1] + 1 + #it[2] -- "<key> <desc>" display width (all ASCII)
      local cost = (used == 0) and disp or (disp + 2) -- +2 for the "  " gap between items
      if used + cost > avail then
        break
      end
      out[#out + 1] = (used == 0 and " " or "  ") .. "%#XpdtHelpKey#" .. it[1] .. "%#XpdtHelpDesc# " .. it[2] .. "%*"
      used = used + cost
    end
    return table.concat(out)
  end
  vim.o.winbar = "%{%v:lua.xpdt_help_bar()%}"
end

-- :XpdtDiff - show the current file's unstaged changes INLINE, in the one editable
-- window (no split): added / changed lines get a sign (+ / ~) and a subtle line tint,
-- and the removed lines appear inline as red virtual lines where they were. It is a
-- diff against the git index recomputed live (vim.diff) as you edit, so the marks track
-- your changes; run :XpdtDiff again to turn it off. xpdt's changes browser runs this on
-- an unstaged entry when the "edit unstaged changes as a diff" setting is on; it also
-- works by hand in any tracked file. (A removed block sitting above the very first line
-- cannot render as a virtual line at the top edge - a Neovim limitation - so a change on
-- line 1 shows the marker but not the old text; every other position shows it. Colours
-- are the theme's Diff{Add,Change,Delete} groups.)
local XPDT_DIFF_NS = vim.api.nvim_create_namespace("xpdt_inline_diff")
local xpdt_diff_index = {} -- bufnr -> the index ("before") lines, while its inline diff is on
local xpdt_diff_timer = {} -- bufnr -> pending debounce timer
local xpdt_diff_hunks = {} -- bufnr -> sorted list of hunk anchor lines (1-based), for ]c / [c

local function xpdt_render_inline_diff(buf)
  local index = xpdt_diff_index[buf]
  if not index or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, XPDT_DIFF_NS, 0, -1)
  local before = table.concat(index, "\n") .. "\n"
  local after = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
  local anchors = {} -- the line to jump to for each hunk (in order, ascending)
  for _, h in ipairs(vim.diff(before, after, { result_type = "indices" }) or {}) do
    local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
    -- where `]c` / `[c` land for this hunk: the first added/changed line, or the line
    -- the removed block sits under for a pure deletion.
    anchors[#anchors + 1] = (cb > 0) and sb or math.max(1, sb)
    if cb > 0 then -- added / changed lines in the working buffer
      local hl = (ca > 0) and "DiffChange" or "DiffAdd"
      local sign = (ca > 0) and "~" or "+"
      for row = sb - 1, sb + cb - 2 do
        pcall(vim.api.nvim_buf_set_extmark, buf, XPDT_DIFF_NS, row, 0, {
          sign_text = sign,
          sign_hl_group = hl,
          line_hl_group = hl,
        })
      end
    end
    if ca > 0 then -- removed lines: show the index text inline as red virtual lines
      local vlines = {}
      for i = sa, sa + ca - 1 do
        vlines[#vlines + 1] = { { "- " .. (index[i] or ""), "DiffDelete" } }
      end
      local row, above = sb - 1, cb > 0 -- above a change; below a pure deletion
      if row < 0 then
        row, above = 0, true
      end
      pcall(vim.api.nvim_buf_set_extmark, buf, XPDT_DIFF_NS, row, 0, {
        virt_lines = vlines,
        virt_lines_above = above,
      })
    end
  end
  xpdt_diff_hunks[buf] = anchors
end

-- Jump to the next (dir=1) or previous (dir=-1) hunk, wrapping, and show "hunk N/M" so
-- you can see how many there are and where you are. Bound to ]c / [c while the inline
-- diff is on.
local function xpdt_diff_jump(buf, dir)
  local hunks = xpdt_diff_hunks[buf] or {}
  if #hunks == 0 then
    vim.api.nvim_echo({ { "XpdtDiff: no changes", "WarningMsg" } }, false, {})
    return
  end
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local target, idx
  if dir > 0 then
    for i, ln in ipairs(hunks) do
      if ln > cur then
        target, idx = ln, i
        break
      end
    end
    if not target then
      target, idx = hunks[1], 1 -- wrap to the first
    end
  else
    for i = #hunks, 1, -1 do
      if hunks[i] < cur then
        target, idx = hunks[i], i
        break
      end
    end
    if not target then
      target, idx = hunks[#hunks], #hunks -- wrap to the last
    end
  end
  target = math.min(target, vim.api.nvim_buf_line_count(buf))
  vim.api.nvim_win_set_cursor(0, { target, 0 })
  vim.cmd("normal! zz") -- centre the hunk so you see the surrounding context
  vim.api.nvim_echo({ { ("hunk %d/%d"):format(idx, #hunks), "Comment" } }, false, {})
end

local function xpdt_inline_diff_off(buf)
  xpdt_diff_index[buf] = nil
  xpdt_diff_hunks[buf] = nil
  if xpdt_diff_timer[buf] then
    pcall(function()
      xpdt_diff_timer[buf]:stop()
    end)
    xpdt_diff_timer[buf] = nil
  end
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, XPDT_DIFF_NS, 0, -1)
    pcall(vim.keymap.del, "n", "]c", { buffer = buf })
    pcall(vim.keymap.del, "n", "[c", { buffer = buf })
  end
  pcall(vim.api.nvim_del_augroup_by_name, "xpdt_inline_diff_" .. buf)
end

vim.api.nvim_create_user_command("XpdtDiff", function()
  local buf = vim.api.nvim_get_current_buf()
  if xpdt_diff_index[buf] then -- already on -> toggle it off
    xpdt_inline_diff_off(buf)
    return
  end
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then
    return
  end
  local dir = vim.fn.fnamemodify(file, ":h")
  local root = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })[1]
  if vim.v.shell_error ~= 0 or not root or root == "" then
    vim.notify("XpdtDiff: not in a git repository", vim.log.levels.WARN)
    return
  end
  local rel = vim.fn.systemlist({ "git", "-C", root, "ls-files", "--full-name", "--", file })[1]
  if not rel or rel == "" then
    rel = file:sub(#root + 2)
  end
  local index = vim.fn.systemlist({ "git", "-C", root, "show", ":" .. rel })
  if vim.v.shell_error ~= 0 then
    vim.notify("XpdtDiff: no index version (file is untracked?)", vim.log.levels.WARN)
    return
  end
  xpdt_diff_index[buf] = index
  vim.wo.signcolumn = "yes" -- so the +/~ signs are visible
  xpdt_render_inline_diff(buf)
  -- Open on the first hunk (the top change), centred, and bind ]c / [c to hop between
  -- hunks (with a "hunk N/M" readout) so the other changes are easy to reach.
  local first = (xpdt_diff_hunks[buf] or {})[1]
  if first then
    vim.api.nvim_win_set_cursor(0, { math.min(first, vim.api.nvim_buf_line_count(buf)), 0 })
    vim.cmd("normal! zz")
  end
  vim.keymap.set("n", "]c", function()
    xpdt_diff_jump(buf, 1)
  end, { buffer = buf, desc = "Next diff hunk (XpdtDiff)" })
  vim.keymap.set("n", "[c", function()
    xpdt_diff_jump(buf, -1)
  end, { buffer = buf, desc = "Prev diff hunk (XpdtDiff)" })
  -- Recompute live as you edit. Debounced (~100ms) so a big file does not re-diff on
  -- every keystroke; TextChanged/InsertLeave cover normal-mode edits and leaving insert.
  local grp = vim.api.nvim_create_augroup("xpdt_inline_diff_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = grp,
    buffer = buf,
    callback = function()
      if xpdt_diff_timer[buf] then
        pcall(function()
          xpdt_diff_timer[buf]:stop()
        end)
      end
      xpdt_diff_timer[buf] = vim.defer_fn(function()
        xpdt_diff_timer[buf] = nil
        xpdt_render_inline_diff(buf)
      end, 100)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = grp,
    buffer = buf,
    callback = function()
      xpdt_inline_diff_off(buf)
    end,
  })
end, { desc = "Toggle an inline diff of the current file vs its git index (unstaged changes)" })

-- ===========================================================================
-- Intellisense (LSP), opt-in per language via xpdt's `,` settings menu.
--
-- That menu writes lsp-<name>=1 to ~/.config/xpdt/.gate-config for each language you
-- turn on. We read it and, for each enabled language, start its server with Neovim's
-- built-in LSP client + built-in completion. nvim-lspconfig supplies each server's
-- config (cmd / root / init_options / settings - the details a hand-rolled config
-- gets wrong for ts_ls, eslint, tailwind, ...) via vim.lsp.enable, and Mason installs
-- the servers you pick (only those) into its own dir. `:XpdtLsp` shows each one's
-- status and, if it cannot be installed, the manual command. Keys match the menu
-- keys; `lsp` is the lspconfig server name, `cmd`/`filetypes` are kept only for the
-- PATH check and the re-attach-on-install nicety (the live config comes from lspconfig).
-- ===========================================================================
-- djlsp (Django templates) collects your project's tags / filters / {% url %} names /
-- context by importing the Django project, which needs the project's virtualenv. But it
-- only looks for a venv in env/.env/venv/.venv under the project root and IGNORES an
-- active venv - so a venv that is activated, or lives elsewhere, or is named anything
-- else, is missed, and you get "Failed to collect project-specific Django data" (generic
-- completions only). Point djlsp at the active venv first ($VIRTUAL_ENV, which venv /
-- poetry / pipenv / conda all export on activation), then the usual in-project dirs.
-- env_directories entries may be absolute paths or names resolved against the project
-- root; djlsp uses the first that has bin/python. Computed once at startup from Neovim's
-- environment, so launch xpdt/Neovim from an activated venv (or keep it in .venv/venv/
-- env/.env at the project root) and project-aware Django completions light up.
local function django_env_directories()
  local dirs = {}
  local venv = vim.env.VIRTUAL_ENV
  if venv and venv ~= "" then
    dirs[#dirs + 1] = venv
  end
  vim.list_extend(dirs, { ".venv", "venv", "env", ".env" })
  return dirs
end

local SERVERS = {
  lua = {
    label = "Lua",
    lsp = "lua_ls",
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
    settings = { Lua = { diagnostics = { globals = { "vim" } }, workspace = { checkThirdParty = false } } },
    install = "brew install lua-language-server  (or your package manager)",
  },
  python = {
    label = "Python",
    lsp = "pyright",
    cmd = { "pyright-langserver", "--stdio" },
    filetypes = { "python" },
    root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
    install = "npm i -g pyright",
  },
  django = {
    -- Django template intellisense (tags, filters, {% url %} names, {% static %}
    -- paths, block names, context vars). Python itself is covered by pyright above.
    label = "Django (templates)",
    lsp = "djlsp",
    cmd = { "djlsp" },
    filetypes = { "html", "htmldjango" },
    root_markers = { "manage.py", "pyproject.toml", ".git" },
    -- Auto-detect the project's virtualenv so djlsp can collect project-specific data
    -- (see django_env_directories above).
    init_options = { env_directories = django_env_directories() },
    install = "pipx install django-template-lsp  (or: pip install --user django-template-lsp)",
  },
  typescript = {
    label = "TypeScript / JavaScript",
    -- vtsls, not typescript-language-server: vtsls bundles its own TypeScript, so it
    -- resolves without a workspace or global `typescript` install. typescript-language-
    -- server otherwise fails to initialise with "Could not find a valid TypeScript
    -- installation" when the project has no typescript on hand.
    lsp = "vtsls",
    cmd = { "vtsls", "--stdio" },
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
    install = "npm i -g @vtsls/language-server",
  },
  html = {
    label = "HTML",
    lsp = "html",
    cmd = { "vscode-html-language-server", "--stdio" },
    filetypes = { "html" },
    root_markers = { "package.json", ".git" },
    install = "npm i -g vscode-langservers-extracted",
  },
  css = {
    label = "CSS",
    lsp = "cssls",
    cmd = { "vscode-css-language-server", "--stdio" },
    filetypes = { "css", "scss", "less" },
    root_markers = { "package.json", ".git" },
    install = "npm i -g vscode-langservers-extracted",
  },
  json = {
    label = "JSON",
    lsp = "jsonls",
    cmd = { "vscode-json-language-server", "--stdio" },
    filetypes = { "json", "jsonc" },
    root_markers = { ".git" },
    install = "npm i -g vscode-langservers-extracted",
  },
  bash = {
    label = "Bash",
    lsp = "bashls",
    cmd = { "bash-language-server", "start" },
    filetypes = { "sh", "bash" },
    root_markers = { ".git" },
    install = "npm i -g bash-language-server",
  },
  rust = {
    label = "Rust",
    lsp = "rust_analyzer",
    cmd = { "rust-analyzer" },
    filetypes = { "rust" },
    root_markers = { "Cargo.toml", ".git" },
    install = "rustup component add rust-analyzer",
  },
  go = {
    label = "Go",
    lsp = "gopls",
    cmd = { "gopls" },
    filetypes = { "go", "gomod", "gowork" },
    root_markers = { "go.mod", ".git" },
    install = "go install golang.org/x/tools/gopls@latest",
  },
  tailwind = {
    label = "Tailwind CSS",
    lsp = "tailwindcss",
    cmd = { "tailwindcss-language-server", "--stdio" },
    filetypes = { "html", "css", "javascriptreact", "typescriptreact", "vue", "svelte" },
    root_markers = { "tailwind.config.js", "tailwind.config.ts", "tailwind.config.cjs", ".git" },
    install = "npm i -g @tailwindcss/language-server",
  },
  svelte = {
    label = "Svelte",
    lsp = "svelte",
    cmd = { "svelteserver", "--stdio" },
    filetypes = { "svelte" },
    root_markers = { "package.json", ".git" },
    install = "npm i -g svelte-language-server",
  },
  eslint = {
    label = "ESLint",
    lsp = "eslint",
    cmd = { "vscode-eslint-language-server", "--stdio" },
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte" },
    root_markers = { ".eslintrc", ".eslintrc.js", ".eslintrc.json", "eslint.config.js", "package.json", ".git" },
    install = "npm i -g vscode-langservers-extracted",
  },
}
local SERVER_ORDER = {
  "lua", "python", "django", "typescript", "html", "css", "json",
  "bash", "rust", "go", "tailwind", "svelte", "eslint",
}

-- xpdt key -> Mason package name. Mason fetches these (only the languages you enable)
-- into its own isolated dir and puts them on PATH via mason.setup(), so the SERVERS
-- `cmd` above then resolves. All are in the Mason registry.
local MASON = {
  lua = "lua-language-server",
  python = "pyright",
  django = "django-template-lsp",
  typescript = "vtsls",
  html = "html-lsp",
  css = "css-lsp",
  json = "json-lsp",
  bash = "bash-language-server",
  rust = "rust-analyzer",
  go = "gopls",
  tailwind = "tailwindcss-language-server",
  svelte = "svelte-language-server",
  eslint = "eslint-lsp",
}

local function enabled_langs()
  local on = {}
  local f = io.open(vim.fn.expand("~/.config/xpdt/.gate-config"), "r")
  if not f then return on end
  for line in f:lines() do
    local k = line:match("^lsp%-([%w_-]+)=1%s*$")
    if k then on[k] = true end
  end
  f:close()
  return on
end

-- how diagnostics look, and how the built-in completion menu behaves.
-- Long messages used to show as inline virtual text at the end of the line, which
-- cannot wrap - a long type error just ran off the right edge with no way to read
-- the rest. Show them as wrapped virtual LINES under the current line instead (the
-- full message, on as many rows as it needs), only for the line the cursor is on so
-- it stays uncluttered. The gutter signs still mark every diagnostic line at a glance,
-- and `<leader>e` opens the full text in a bordered float (which also wraps).
--
-- Neovim's built-in virtual_lines does NOT soft-wrap a long single-line message - it
-- puts it on one virtual line that runs off the right edge. So we pre-wrap the message
-- ourselves in `format`: word-wrap it to the width actually left for the text, which is
-- the window width minus the gutter (`textoff`), minus the column the message is
-- indented under (virtual_lines aligns it below the diagnostic's column), minus the
-- ~6-char connector and a little slack. Existing newlines in the message are kept.
local function wrap_diagnostic(msg, width)
  if width < 20 then
    width = 20
  end
  local out = {}
  for _, para in ipairs(vim.split(tostring(msg), "\n", { plain = true })) do
    local line = ""
    for word in para:gmatch("%S+") do
      if line == "" then
        line = word
      elseif #line + 1 + #word <= width then
        line = line .. " " .. word
      else
        out[#out + 1] = line
        line = word
      end
    end
    out[#out + 1] = line
  end
  return table.concat(out, "\n")
end

local function diag_virt_lines_format(d)
  local width = 80
  local ok, info = pcall(function()
    return vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  end)
  if ok and info then
    width = info.width - (info.textoff or 0) - (d.col or 0) - 8
  end
  return wrap_diagnostic(d.message, width)
end

vim.diagnostic.config({
  virtual_text = false,
  virtual_lines = { current_line = true, format = diag_virt_lines_format },
  underline = true,
  severity_sort = true,
  float = { border = "rounded", source = true, wrap = true, max_width = 100 },
})
vim.opt.completeopt = { "menuone", "noselect", "popup", "fuzzy" }

-- when a server attaches to a buffer: turn on completion and the usual LSP keys
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
    local base = { buffer = ev.buf, silent = true }
    local map = function(m, l, r, d)
      vim.keymap.set(m, l, r, vim.tbl_extend("force", base, { desc = d }))
    end
    -- Only bind an LSP-backed key when a client on this buffer supports the method, so
    -- pressing e.g. `gi` on a server without implementation support does its built-in
    -- Vim thing instead of warning "method ... is not supported". A different client
    -- that does support it binds the key when it attaches.
    local mapm = function(method, m, l, r, d)
      if client and client:supports_method(method) then
        map(m, l, r, d)
      end
    end
    mapm("textDocument/hover", "n", "K", vim.lsp.buf.hover, "Hover docs")
    mapm("textDocument/definition", "n", "gd", vim.lsp.buf.definition, "Go to definition")
    mapm("textDocument/declaration", "n", "gD", vim.lsp.buf.declaration, "Go to declaration")
    mapm("textDocument/references", "n", "gr", vim.lsp.buf.references, "References")
    mapm("textDocument/implementation", "n", "gi", vim.lsp.buf.implementation, "Implementations")
    mapm("textDocument/rename", "n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    mapm("textDocument/codeAction", { "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
    mapm("textDocument/formatting", "n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end, "Format buffer")
    map("n", "<leader>e", vim.diagnostic.open_float, "Line diagnostics")
    map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Prev diagnostic")
    map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next diagnostic")
    map("i", "<C-Space>", function() vim.lsp.completion.get() end, "Trigger completion")
  end,
})

-- Start a server using nvim-lspconfig's config for it (spec.lsp = the lspconfig
-- server name), layering our own settings over it when we have any. vim.lsp.enable
-- reads lspconfig's lsp/<name>.lua from the runtimepath.
local function enable_server(name)
  local spec = SERVERS[name]
  local cfg = {}
  if spec.settings then
    cfg.settings = spec.settings
  end
  if spec.init_options then
    cfg.init_options = spec.init_options
  end
  if next(cfg) then
    vim.lsp.config(spec.lsp, cfg)
  end
  vim.lsp.enable(spec.lsp)
end

-- For each enabled language: if its server is already on PATH, start it now;
-- otherwise ask Mason to install it (only the ones you picked) and start it the
-- moment Mason reports it done - reopening the file or restarting also picks it up.
local function setup_lsp()
  pcall(require, "mason") -- make lazy load Mason + run mason.setup() (puts its bin on PATH)
  local on = enabled_langs()
  local mr_ok, mr = pcall(require, "mason-registry")
  local installing = {}
  local stuck = {}
  for name in pairs(on) do
    local spec = SERVERS[name]
    if spec then
      if vim.fn.executable(spec.cmd[1]) == 1 then
        enable_server(name)
      elseif mr_ok and MASON[name] then
        local ok, pkg = pcall(mr.get_package, MASON[name])
        if ok and pkg then
          installing[MASON[name]] = name
          pcall(function()
            pkg:install()
          end)
        else
          stuck[#stuck + 1] = spec.label
        end
      else
        stuck[#stuck + 1] = spec.label
      end
    end
  end
  if next(installing) and mr_ok then
    pcall(function()
      mr:on("package:install:success", function(pkg)
        local sname = installing[pkg.name]
        if sname then
          installing[pkg.name] = nil
          vim.schedule(function()
            local spec = SERVERS[sname]
            if vim.fn.executable(spec.cmd[1]) == 1 then
              enable_server(sname)
              -- enable() only auto-attaches future buffers, so re-fire FileType on any
              -- already-open buffer of this server's filetypes to attach it now.
              for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if
                  vim.api.nvim_buf_is_loaded(buf)
                  and vim.tbl_contains(spec.filetypes, vim.bo[buf].filetype)
                then
                  vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
                end
              end
              vim.notify("xpdt intellisense: " .. spec.label .. " ready", vim.log.levels.INFO)
            end
          end)
        end
      end)
    end)
    local n = vim.tbl_count(installing)
    vim.schedule(function()
      vim.notify(
        ("xpdt: installing %d intellisense server%s via Mason (:Mason for progress)"):format(
          n,
          n == 1 and "" or "s"
        ),
        vim.log.levels.INFO
      )
    end)
  end
  if #stuck > 0 then
    vim.schedule(function()
      vim.notify(
        ("xpdt: %d intellisense server%s could not be installed (:XpdtLsp)"):format(
          #stuck,
          #stuck == 1 and "" or "s"
        ),
        vim.log.levels.WARN
      )
    end)
  end
end

vim.api.nvim_create_user_command("XpdtLsp", function()
  local on = enabled_langs()
  local mr_ok, mr = pcall(require, "mason-registry")
  local lines = { "xpdt intellisense  -  toggle languages in xpdt's `,` settings menu", "" }
  for _, name in ipairs(SERVER_ORDER) do
    local s = SERVERS[name]
    local status
    if not on[name] then
      status = "off"
    elseif vim.fn.executable(s.cmd[1]) == 1 then
      status = "ON  - installed"
    elseif mr_ok and MASON[name] then
      local ok, pkg = pcall(mr.get_package, MASON[name])
      if ok and pkg and pkg:is_installed() then
        status = "ON  - installed (restart to start)"
      else
        status = "ON  - installing via Mason (:Mason)"
      end
    else
      status = "ON  - not installed: " .. s.install
    end
    lines[#lines + 1] = string.format("  %-24s %s", s.label, status)
  end
  vim.notify(table.concat(lines, "\n"))
end, { desc = "Show xpdt intellisense (LSP) status" })

-- Run inline (not deferred): vim.lsp.enable only auto-attaches to buffers opened
-- AFTER it runs, and the file you launched on is read just after init.lua sources,
-- so deferring would miss it. setup_lsp force-loads Mason itself for the PATH.
setup_lsp()
