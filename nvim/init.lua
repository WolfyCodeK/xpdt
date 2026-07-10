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
