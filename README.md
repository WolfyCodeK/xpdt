# xplr-config

My terminal file manager and editor setup.

- **`xplr/`** goes in `~/.config/xplr`. A customised [xplr](https://xplr.dev)
  config: git changes and log browsers, an inline diff viewer with change to
  change navigation, a syntax highlighted file preview with search and clean line
  range copy, code gated file create, delete and move, a git command menu, and
  full Nerd Font theming. Detailed docs are in [`xplr/README.md`](xplr/README.md).
- **`nvim/`** goes in `~/.config/nvim`. A Neovim config (lazy.nvim, Treesitter, a
  Monokai theme colour matched to bat, plus leap, surround, comment, lualine and
  indent guides) that opens from the xplr preview with ctrl-e.

## Install

Dependencies: `xplr`, `bat`, `fzf`, `ripgrep`, `neovim`, and a Nerd Font set as
your terminal font. On macOS:

```sh
brew install xplr bat fzf ripgrep neovim
```

Then link the configs into place:

```sh
ln -s "$PWD/xplr" ~/.config/xplr
ln -s "$PWD/nvim" ~/.config/nvim
```

Neovim installs its plugins on first launch. The setup is tuned for macOS (copy
to clipboard via `pbcopy`, delete to the Finder Trash); everything else is
portable.

## Credits and license

This is a personal, heavily customised setup for [xplr](https://xplr.dev) - the
open-source terminal file manager by
[sayanarijit](https://github.com/sayanarijit/xplr) (MIT licensed). It is
essentially a modded xplr: everything here is built on top of xplr's Lua API and
would not exist without that project. The Neovim side is likewise built on
[lazy.nvim](https://github.com/folke/lazy.nvim), nvim-treesitter, the
[monokai.nvim](https://github.com/tanvirtin/monokai.nvim) theme, and the other
plugins listed in [`nvim/init.lua`](nvim/init.lua).

The files in this repository - the configs, shell scripts, and theme - are
released into the public domain under [The Unlicense](LICENSE): copy, modify, and
reuse them freely, with or without attribution. xplr, Neovim, and the bundled
plugins remain under their own licenses.
