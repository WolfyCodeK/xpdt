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
      vim.cmd("qall")
    else
      vim.cmd("normal! h")
    end
  end, { desc = "Left, or exit to xpdt at line start when there are no edits" })
end

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
    install = "pipx install django-template-lsp  (or: pip install --user django-template-lsp)",
  },
  typescript = {
    label = "TypeScript / JavaScript",
    lsp = "ts_ls",
    cmd = { "typescript-language-server", "--stdio" },
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
    install = "npm i -g typescript typescript-language-server",
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
  typescript = "typescript-language-server",
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

-- how diagnostics look, and how the built-in completion menu behaves
vim.diagnostic.config({
  virtual_text = { spacing = 2 },
  underline = true,
  severity_sort = true,
  float = { border = "rounded", source = true },
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
  if spec.settings then
    vim.lsp.config(spec.lsp, { settings = spec.settings })
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
