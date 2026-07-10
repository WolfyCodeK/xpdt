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
