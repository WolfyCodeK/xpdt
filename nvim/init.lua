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
vim.api.nvim_create_autocmd("ColorScheme", { callback = bat_palette })

-- plugins
require("lazy").setup({
  { "tanvirtin/monokai.nvim", lazy = false, priority = 1000 },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "python", "javascript", "typescript", "lua", "json", "html", "css",
          "bash", "yaml", "toml", "markdown", "markdown_inline", "vim", "vimdoc",
        },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
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
})

-- theme (fires the ColorScheme autocmd that applies the bat palette)
vim.cmd.colorscheme("monokai")

-- live reload: pick up external changes like the preview does
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "FocusGained", "BufEnter" }, { command = "silent! checktime" })
local reload_timer = (vim.uv or vim.loop).new_timer()
reload_timer:start(1000, 1000, vim.schedule_wrap(function() vim.cmd("silent! checktime") end))

-- ===========================================================================
-- Intellisense (LSP), opt-in per language via xpdt's `,` settings menu.
--
-- That menu writes lsp-<name>=1 to ~/.config/xpdt/.gate-config for each language
-- you turn on. We read it and, for every enabled language whose server binary is
-- on PATH, configure and start it with Neovim's built-in LSP + built-in completion
-- (no extra plugins). Nothing is installed automatically - you install only the
-- handful of servers you want; `:XpdtLsp` shows each one's status and, if it is
-- turned on but missing, the command to install it. Keys here match the menu keys.
-- ===========================================================================
local SERVERS = {
  lua = {
    label = "Lua",
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
    settings = { Lua = { diagnostics = { globals = { "vim" } }, workspace = { checkThirdParty = false } } },
    install = "brew install lua-language-server  (or your package manager)",
  },
  python = {
    label = "Python",
    cmd = { "pyright-langserver", "--stdio" },
    filetypes = { "python" },
    root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
    install = "npm i -g pyright",
  },
  typescript = {
    label = "TypeScript / JavaScript",
    cmd = { "typescript-language-server", "--stdio" },
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
    install = "npm i -g typescript typescript-language-server",
  },
  html = {
    label = "HTML",
    cmd = { "vscode-html-language-server", "--stdio" },
    filetypes = { "html" },
    root_markers = { "package.json", ".git" },
    install = "npm i -g vscode-langservers-extracted",
  },
  css = {
    label = "CSS",
    cmd = { "vscode-css-language-server", "--stdio" },
    filetypes = { "css", "scss", "less" },
    root_markers = { "package.json", ".git" },
    install = "npm i -g vscode-langservers-extracted",
  },
  json = {
    label = "JSON",
    cmd = { "vscode-json-language-server", "--stdio" },
    filetypes = { "json", "jsonc" },
    root_markers = { ".git" },
    install = "npm i -g vscode-langservers-extracted",
  },
  bash = {
    label = "Bash",
    cmd = { "bash-language-server", "start" },
    filetypes = { "sh", "bash" },
    root_markers = { ".git" },
    install = "npm i -g bash-language-server",
  },
  rust = {
    label = "Rust",
    cmd = { "rust-analyzer" },
    filetypes = { "rust" },
    root_markers = { "Cargo.toml", ".git" },
    install = "rustup component add rust-analyzer",
  },
  go = {
    label = "Go",
    cmd = { "gopls" },
    filetypes = { "go", "gomod", "gowork" },
    root_markers = { "go.mod", ".git" },
    install = "go install golang.org/x/tools/gopls@latest",
  },
  tailwind = {
    label = "Tailwind CSS",
    cmd = { "tailwindcss-language-server", "--stdio" },
    filetypes = { "html", "css", "javascriptreact", "typescriptreact", "vue", "svelte" },
    root_markers = { "tailwind.config.js", "tailwind.config.ts", "tailwind.config.cjs", ".git" },
    install = "npm i -g @tailwindcss/language-server",
  },
  svelte = {
    label = "Svelte",
    cmd = { "svelteserver", "--stdio" },
    filetypes = { "svelte" },
    root_markers = { "package.json", ".git" },
    install = "npm i -g svelte-language-server",
  },
  eslint = {
    label = "ESLint",
    cmd = { "vscode-eslint-language-server", "--stdio" },
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte" },
    root_markers = { ".eslintrc", ".eslintrc.js", ".eslintrc.json", "eslint.config.js", "package.json", ".git" },
    install = "npm i -g vscode-langservers-extracted",
  },
}
local SERVER_ORDER = {
  "lua", "python", "typescript", "html", "css", "json",
  "bash", "rust", "go", "tailwind", "svelte", "eslint",
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
    map("n", "K", vim.lsp.buf.hover, "Hover docs")
    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
    map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
    map("n", "gr", vim.lsp.buf.references, "References")
    map("n", "gi", vim.lsp.buf.implementation, "Implementations")
    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("n", "<leader>e", vim.diagnostic.open_float, "Line diagnostics")
    map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Prev diagnostic")
    map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next diagnostic")
    map("n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end, "Format buffer")
    map("i", "<C-Space>", function() vim.lsp.completion.get() end, "Trigger completion")
  end,
})

-- configure + start each enabled server that is installed; note the ones that are not
local function setup_lsp()
  local on = enabled_langs()
  local missing = {}
  for name, spec in pairs(SERVERS) do
    if on[name] then
      if vim.fn.executable(spec.cmd[1]) == 1 then
        vim.lsp.config(name, {
          cmd = spec.cmd,
          filetypes = spec.filetypes,
          root_markers = spec.root_markers,
          settings = spec.settings,
        })
        vim.lsp.enable(name)
      else
        missing[#missing + 1] = spec.label
      end
    end
  end
  if #missing > 0 then
    vim.schedule(function()
      vim.notify(
        "xpdt intellisense: turned on but no server installed for "
          .. table.concat(missing, ", ")
          .. ".  Run :XpdtLsp for the install command(s).",
        vim.log.levels.WARN
      )
    end)
  end
end

vim.api.nvim_create_user_command("XpdtLsp", function()
  local on = enabled_langs()
  local lines = { "xpdt intellisense  -  toggle languages in xpdt's `,` settings menu", "" }
  for _, name in ipairs(SERVER_ORDER) do
    local s = SERVERS[name]
    local status
    if not on[name] then
      status = "off"
    elseif vim.fn.executable(s.cmd[1]) == 1 then
      status = "ON  - installed (" .. s.cmd[1] .. ")"
    else
      status = "ON  - NOT installed:  " .. s.install
    end
    lines[#lines + 1] = string.format("  %-24s %s", s.label, status)
  end
  vim.notify(table.concat(lines, "\n"))
end, { desc = "Show xpdt intellisense (LSP) status and install commands" })

setup_lsp()
