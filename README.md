# xpdt

xpdt is my terminal file manager and editor setup: a heavily customised
[xplr](https://xplr.dev) (a terminal file manager) wired up as a keyboard-driven
git client and code browser, paired with a matching Neovim config. The two share
a Monokai palette and hand off to each other - `ctrl-e` in a file preview opens
Neovim on the exact line.

- **`xplr/`** goes in `~/.config/xplr`. A customised xplr config: git changes and
  log browsers, an inline diff viewer with change-to-change navigation, a
  syntax-highlighted file preview with search and clean line-range copy,
  code-gated file create/delete/move, a git command menu, and full Nerd Font
  theming. Detailed docs are in [`xplr/README.md`](xplr/README.md).
- **`nvim/`** goes in `~/.config/nvim`. A Neovim config (lazy.nvim, Treesitter, a
  Monokai theme colour-matched to bat, plus leap, surround, comment, lualine and
  indent guides) that opens from the xplr preview with `ctrl-e`.

## Install

xpdt installs pinned tool versions (the config relies on recent xplr, fzf and
Neovim features, so exact releases matter), then symlinks the two configs into
`~/.config`:

| Tool    | Version |
| ------- | ------- |
| xplr    | 1.1.0   |
| bat     | 0.26.1  |
| fzf     | 0.74.0  |
| ripgrep | 14.1.1  |
| Neovim  | 0.12.4  |

### macOS and Linux

```sh
git clone https://github.com/WolfyCodeK/xpdt.git ~/.config/xpdt
cd ~/.config/xpdt
./install.sh
```

`install.sh` downloads the pinned release binaries into `~/.local` (override with
`--prefix DIR` or the `XPDT_PREFIX` env var), backs up any existing
`~/.config/xplr` or `~/.config/nvim`, symlinks this repo in their place, and
bootstraps the Neovim plugins. Ensure `~/.local/bin` is on your `PATH`, and set a
[Nerd Font](https://www.nerdfonts.com/) (for example Hack Nerd Font) as your
terminal font so the icons render. Re-running is safe and idempotent.

Flags: `--prefix DIR`, `--tools-only`, `--config-only`, `--no-nvim-bootstrap`.

Once it is on your `PATH`, start it with **`xpdt`** (a thin alias for the pinned
`xplr` binary, so `xplr` still works too).

### Windows (WSL2)

xplr publishes no native Windows build and the config is POSIX-shell based, so
xpdt runs under [WSL2](https://learn.microsoft.com/windows/wsl/install):

```powershell
wsl --install        # first time only; reboot, then open the Ubuntu shell
```

Inside the Ubuntu (WSL) shell, follow the macOS and Linux steps above. Set a
Nerd Font in Windows Terminal (Settings -> your profile -> Appearance -> Font
face). If you only want the editor, the `nvim/` config also runs on native
Windows Neovim.

### Linux notes

The pinned xplr binary is dynamically linked against a recent glibc (2.39+ -
Ubuntu 24.04, Debian 13, Fedora 39 and newer). On older systems `install.sh`
builds xplr 1.1.0 from source with Rust ([rustup.rs](https://rustup.rs)) when
`cargo` is available. macOS is unaffected.

Three features are macOS-only and simply do nothing elsewhere: clipboard copy
(`pbcopy`), delete-to-Trash (Finder), and the preview's external-change
auto-reload (`stat -f`). Everything else is portable.

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
