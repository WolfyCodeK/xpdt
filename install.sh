#!/bin/sh
# xpdt installer - pinned xplr + Neovim terminal setup for macOS and Linux
# (and Linux-on-WSL2 for Windows). See README.md for the full story.
#
# We install exact tool releases rather than whatever a package manager ships,
# because the config depends on recent features (fzf --wrap/--listen, the
# xplr 1.1.0 Lua API, Neovim 0.9+ for lazy.nvim). Re-running is safe.
set -eu

# --- pinned versions --------------------------------------------------------
XPLR_VERSION=1.1.0
BAT_VERSION=0.26.1
FZF_VERSION=0.74.0
RIPGREP_VERSION=14.1.1
NVIM_VERSION=0.12.4

# --- options / paths --------------------------------------------------------
PREFIX="${XPDT_PREFIX:-$HOME/.local}"
DO_TOOLS=1
DO_CONFIG=1
DO_NVIM_BOOTSTRAP=1

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# xpdt's own version (independent of the pinned xplr engine); source of truth is
# the VERSION file, baked into the xpdt launcher so `xpdt --version` can report it.
XPDT_VERSION=$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo 0.0.0)

usage() {
  cat <<'EOF'
xpdt installer

Usage: ./install.sh [options]

  --prefix DIR          install tools under DIR (default $HOME/.local; env XPDT_PREFIX)
  --tools-only          install pinned tools, skip config symlinks
  --config-only         symlink configs only, skip tool install
  --no-nvim-bootstrap   skip the headless Neovim plugin install
  -h, --help            show this help

Installs pinned xplr, bat, fzf, ripgrep and Neovim, then symlinks the xplr and
nvim configs into ~/.config. Existing configs are backed up, not overwritten.
EOF
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --prefix=*) PREFIX="${1#*=}"; shift ;;
    --tools-only) DO_CONFIG=0; shift ;;
    --config-only) DO_TOOLS=0; shift ;;
    --no-nvim-bootstrap) DO_NVIM_BOOTSTRAP=0; shift ;;
    -h | --help) usage ;;
    *) printf 'ERROR: unknown option: %s (try --help)\n' "$1" >&2; exit 1 ;;
  esac
done

BIN_DIR="$PREFIX/bin"
OPT_DIR="$PREFIX/xpdt" # Neovim's runtime tree is unpacked here
ORIG_PATH="$PATH"
export PATH="$BIN_DIR:$PATH"
mkdir -p "$BIN_DIR"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

info() { printf '  %s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- platform detection -----------------------------------------------------
case "$(uname -s)" in
  Darwin) PLATFORM=macos ;;
  Linux) PLATFORM=linux ;;
  *) die "unsupported OS $(uname -s); macOS and Linux only (Windows: use WSL2, see README)" ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) ARCH=x86_64 ;;
  arm64 | aarch64) ARCH=arm64 ;;
  *) die "unsupported architecture $(uname -m)" ;;
esac

# Per-tool platform strings for the four supported OS/arch combinations.
case "$PLATFORM-$ARCH" in
  linux-x86_64) RUST_TARGET=x86_64-unknown-linux-musl; FZF_PLAT=linux_amd64; NVIM_PLAT=linux-x86_64; XPLR_ASSET=xplr-linux.tar.gz ;;
  linux-arm64) RUST_TARGET=aarch64-unknown-linux-gnu; FZF_PLAT=linux_arm64; NVIM_PLAT=linux-arm64; XPLR_ASSET=xplr-linux-aarch64.tar.gz ;;
  macos-x86_64) RUST_TARGET=x86_64-apple-darwin; FZF_PLAT=darwin_amd64; NVIM_PLAT=macos-x86_64; XPLR_ASSET=xplr-macos.tar.gz ;;
  macos-arm64) RUST_TARGET=aarch64-apple-darwin; FZF_PLAT=darwin_arm64; NVIM_PLAT=macos-arm64; XPLR_ASSET=xplr-macos-aarch64.tar.gz ;;
esac

# --- helpers ----------------------------------------------------------------
dl() { # dl URL DEST
  info "downloading $(basename "$2")"
  if command -v curl >/dev/null 2>&1; then curl -fL --proto '=https' --tlsv1.2 -sS -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
  else die "need curl or wget"; fi
}
ghrel() { printf 'https://github.com/%s/releases/download/%s/%s' "$1" "$2" "$3"; }
at_version() { command -v "$1" >/dev/null 2>&1 && "$1" --version 2>/dev/null | grep -q "$2"; }
relink() { rm -f "$2"; ln -s "$1" "$2"; } # portable "ln -sfn" for files/symlinks

# --- tool installers --------------------------------------------------------
install_ripgrep() {
  if at_version rg "$RIPGREP_VERSION"; then info "ripgrep $RIPGREP_VERSION present"; return; fi
  d="ripgrep-$RIPGREP_VERSION-$RUST_TARGET"
  dl "$(ghrel BurntSushi/ripgrep "$RIPGREP_VERSION" "$d.tar.gz")" "$TMP_DIR/rg.tgz"
  tar xzf "$TMP_DIR/rg.tgz" -C "$TMP_DIR"
  install -m0755 "$TMP_DIR/$d/rg" "$BIN_DIR/rg"; info "ripgrep -> $BIN_DIR/rg"
}
install_bat() {
  if at_version bat "$BAT_VERSION"; then info "bat $BAT_VERSION present"; return; fi
  d="bat-v$BAT_VERSION-$RUST_TARGET"
  dl "$(ghrel sharkdp/bat "v$BAT_VERSION" "$d.tar.gz")" "$TMP_DIR/bat.tgz"
  tar xzf "$TMP_DIR/bat.tgz" -C "$TMP_DIR"
  install -m0755 "$TMP_DIR/$d/bat" "$BIN_DIR/bat"; info "bat -> $BIN_DIR/bat"
}
install_fzf() {
  if at_version fzf "$FZF_VERSION"; then info "fzf $FZF_VERSION present"; return; fi
  dl "$(ghrel junegunn/fzf "v$FZF_VERSION" "fzf-$FZF_VERSION-$FZF_PLAT.tar.gz")" "$TMP_DIR/fzf.tgz"
  tar xzf "$TMP_DIR/fzf.tgz" -C "$TMP_DIR"
  install -m0755 "$TMP_DIR/fzf" "$BIN_DIR/fzf"; info "fzf -> $BIN_DIR/fzf"
}
install_nvim() {
  if at_version nvim "$NVIM_VERSION"; then info "neovim $NVIM_VERSION present"; return; fi
  dl "$(ghrel neovim/neovim "v$NVIM_VERSION" "nvim-$NVIM_PLAT.tar.gz")" "$TMP_DIR/nvim.tgz"
  mkdir -p "$OPT_DIR"; rm -rf "$OPT_DIR/nvim"
  tar xzf "$TMP_DIR/nvim.tgz" -C "$OPT_DIR"
  mv "$OPT_DIR/nvim-$NVIM_PLAT" "$OPT_DIR/nvim"
  relink "$OPT_DIR/nvim/bin/nvim" "$BIN_DIR/nvim"; info "neovim -> $OPT_DIR/nvim"
}
install_xplr() {
  if at_version xplr "$XPLR_VERSION"; then info "xplr $XPLR_VERSION present"; return; fi
  dl "$(ghrel sayanarijit/xplr "v$XPLR_VERSION" "$XPLR_ASSET")" "$TMP_DIR/xplr.tgz"
  tar xzf "$TMP_DIR/xplr.tgz" -C "$TMP_DIR"
  install -m0755 "$TMP_DIR/xplr" "$BIN_DIR/xplr"
  # The official Linux binary is dynamically linked against a recent glibc.
  # If it will not run on this system, build the pinned version from source.
  if ! "$BIN_DIR/xplr" --version >/dev/null 2>&1; then
    warn "prebuilt xplr $XPLR_VERSION won't run here (needs glibc >= 2.39)"
    if command -v cargo >/dev/null 2>&1; then
      info "building xplr $XPLR_VERSION from source with cargo (a few minutes)"
      cargo install --locked --version "$XPLR_VERSION" --root "$PREFIX" xplr
    else
      rm -f "$BIN_DIR/xplr"
      die "xplr needs glibc >= 2.39, or Rust to build from source.
  Install Rust (https://rustup.rs) and re-run, or use Homebrew / a newer distro."
    fi
  fi
  info "xplr -> $BIN_DIR/xplr"
}

# --- config symlinks --------------------------------------------------------
link_config() { # link_config NAME
  target="$HOME/.config/$1"; src="$REPO_DIR/$1"
  [ -d "$src" ] || die "missing $src (run install.sh from inside the xpdt repo)"
  mkdir -p "$HOME/.config"
  if [ -L "$target" ]; then
    relink "$src" "$target"
  elif [ -e "$target" ]; then
    bak="$target.bak.$(date +%Y%m%d%H%M%S)"
    warn "backing up existing $target -> $bak"; mv "$target" "$bak"; ln -s "$src" "$target"
  else
    ln -s "$src" "$target"
  fi
  info "$target -> $src"
}

# The `xpdt` command is a thin launcher: stock `xplr` loads ~/.config/xplr (which
# we deliberately never create, so it stays out-of-the-box), while `xpdt` points
# xplr at the custom config via -c. `-h`/`--help` print an xpdt-specific blurb and
# then hand off to xplr's own help. The xplr path is baked in with printf; the rest
# is a literal (quoted) heredoc, so nothing expands at generation time.
install_launcher() {
  {
    printf '#!/bin/sh\n'
    printf '# xpdt - xplr running the custom xpdt config. Generated by xpdt install.sh; edits are overwritten.\n'
    printf 'xplr_bin="%s"\n' "$BIN_DIR/xplr"
    printf 'xpdt_version="%s"\n' "$XPDT_VERSION"
    cat <<'XPDT_LAUNCHER'
[ -x "$xplr_bin" ] || xplr_bin=xplr

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      printf 'xpdt %s - customised xplr\n\n' "$xpdt_version"
      cat <<'USAGE'
A customised xplr (terminal file manager) set up as a keyboard-driven git
client and code browser. It runs:  xplr -c ~/.config/xpdt/init.lua

Usage:
  xpdt [PATH] [SELECTION]...   open xpdt, optionally focused on PATH
  xpdt --help                  show this message
  xpdt --version               show the xpdt and xplr versions

Every xplr flag (listed below) passes straight through. Inside xpdt, press
ctrl-h for the keybinding cheat sheet, or read the controls panel at the
bottom of the screen. Plain `xplr` runs stock, out of the box.

--- underlying xplr --help ---
USAGE
      exec "$xplr_bin" --help
      ;;
    -V | --version)
      xplr_ver=$("$xplr_bin" --version 2>/dev/null | head -1)
      printf 'xpdt %s (%s)\n' "$xpdt_version" "${xplr_ver:-xplr}"
      exit 0
      ;;
  esac
done

exec "$xplr_bin" -c "$HOME/.config/xpdt/init.lua" "$@"
XPDT_LAUNCHER
  } > "$TMP_DIR/xpdt"
  install -m0755 "$TMP_DIR/xpdt" "$BIN_DIR/xpdt"
  info "xpdt -> $BIN_DIR/xpdt  (launches: xplr -c ~/.config/xpdt/init.lua)"
}

# Seed the confirmation-gate config so the 2-digit confirm is on for every action
# by default after install. Never overwrite an existing one - it holds the user's
# per-action choices. (gate.sh also treats an absent file/key as on, so this is
# belt-and-braces: it just makes the defaults explicit for the settings menu.)
seed_gate_config() {
  cfg="$HOME/.config/xpdt/.gate-config"
  if [ -e "$cfg" ]; then info "confirm-gate config present ($cfg)"; return 0; fi
  if {
    echo "enabled=1"
    echo "show-hidden=1"
    for k in create move delete stage hunk discard commit undo \
      stash-apply stash-pop stash-drop stash-new stash-clear checkout pull; do
      echo "$k=1"
    done
  } > "$cfg" 2>/dev/null; then
    info "seeded confirm-gate config (all actions on) -> $cfg"
  else
    warn "could not seed $cfg (the 2-digit confirm is still on by default)"
  fi
}

bootstrap_nvim() {
  command -v nvim >/dev/null 2>&1 || { warn "nvim not found; skipping plugin bootstrap"; return; }
  info "installing Neovim plugins (pulls lazy.nvim on first run)"
  nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 \
    || nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 \
    || warn "plugin bootstrap hit an issue; plugins finish installing on first launch"
}

# --- run --------------------------------------------------------------------
step "xpdt installer"
info "platform $PLATFORM/$ARCH   prefix $PREFIX   repo $REPO_DIR"

if [ "$DO_TOOLS" = 1 ]; then
  step "installing pinned tools"
  install_ripgrep; install_bat; install_fzf; install_nvim; install_xplr
fi
if [ "$DO_CONFIG" = 1 ]; then
  step "linking config and launcher"
  link_config xpdt; link_config nvim
  install_launcher
  seed_gate_config
fi
if [ "$DO_TOOLS" = 1 ] && [ "$DO_CONFIG" = 1 ] && [ "$DO_NVIM_BOOTSTRAP" = 1 ]; then
  step "bootstrapping neovim"
  bootstrap_nvim
fi

step "installed"
for t in xplr bat fzf rg nvim; do
  if command -v "$t" >/dev/null 2>&1; then printf '  %-4s %s\n' "$t" "$("$t" --version 2>/dev/null | head -1)"; fi
done
if [ -x "$BIN_DIR/xpdt" ]; then printf '  %-4s %s\n' xpdt "custom config launcher (stock xplr untouched)"; fi

case ":$ORIG_PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) printf '\n'; warn "add $BIN_DIR to your PATH:  export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac
printf '\nDone. Set a Nerd Font as your terminal font, then run: xpdt\n'
