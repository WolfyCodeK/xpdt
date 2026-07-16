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
  -- Installs the language servers you enable in xpdt's settings (see the LSP block
  -- below). Only the servers you pick are fetched, into Mason's own isolated dir.
  { "mason-org/mason.nvim", lazy = false, build = ":MasonUpdate", config = function() require("mason").setup() end },
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
  django = {
    -- Django template intellisense (tags, filters, {% url %} names, {% static %}
    -- paths, block names, context vars). Python itself is covered by pyright above.
    label = "Django (templates)",
    cmd = { "djlsp" },
    filetypes = { "html", "htmldjango" },
    root_markers = { "manage.py", "pyproject.toml", ".git" },
    install = "pipx install django-template-lsp  (or: pip install --user django-template-lsp)",
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

local function enable_server(name)
  local spec = SERVERS[name]
  vim.lsp.config(name, {
    cmd = spec.cmd,
    filetypes = spec.filetypes,
    root_markers = spec.root_markers,
    settings = spec.settings,
  })
  vim.lsp.enable(name)
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
