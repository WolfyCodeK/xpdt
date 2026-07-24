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
# tree-sitter CLI: the nvim-treesitter `main` branch (required on Neovim 0.11+)
# compiles parsers with it. Needs a C compiler (cc) present too, which macOS
# (Xcode CLT) and Linux build hosts have.
TREESITTER_VERSION=0.26.11

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

Installs pinned xplr, bat, fzf, ripgrep, Neovim and the tree-sitter CLI, then symlinks the xplr and
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
  linux-x86_64) RUST_TARGET=x86_64-unknown-linux-musl; FZF_PLAT=linux_amd64; NVIM_PLAT=linux-x86_64; XPLR_ASSET=xplr-linux.tar.gz; TS_PLAT=linux-x64 ;;
  linux-arm64) RUST_TARGET=aarch64-unknown-linux-gnu; FZF_PLAT=linux_arm64; NVIM_PLAT=linux-arm64; XPLR_ASSET=xplr-linux-aarch64.tar.gz; TS_PLAT=linux-arm64 ;;
  macos-x86_64) RUST_TARGET=x86_64-apple-darwin; FZF_PLAT=darwin_amd64; NVIM_PLAT=macos-x86_64; XPLR_ASSET=xplr-macos.tar.gz; TS_PLAT=macos-x64 ;;
  macos-arm64) RUST_TARGET=aarch64-apple-darwin; FZF_PLAT=darwin_arm64; NVIM_PLAT=macos-arm64; XPLR_ASSET=xplr-macos-aarch64.tar.gz; TS_PLAT=macos-arm64 ;;
esac

# --- integrity ---------------------------------------------------------------
# Every artifact downloaded below is pinned to a SHA-256 and verified before use.
# Version pinning alone only stops accidental drift - it cannot detect a swapped or
# tampered artifact, and what this script installs are binaries you then run. A
# mismatch is fatal; an artifact with no pin here is refused rather than installed.
#
# Provenance: the ripgrep, fzf and xplr hashes were cross-checked against the
# checksum files those projects publish alongside their releases (12/12 matched).
# bat, Neovim and tree-sitter publish no checksums, so theirs - and the bat theme's
# - are trust-on-first-use values recorded from a verified-TLS download.
#
# Bumping a pinned VERSION above therefore REQUIRES adding the new artifact's hash
# here: the filename changes, the lookup misses, and the install fails closed. Get a
# hash with:  curl -fL <url> | sha256sum
expected_sha() { # expected_sha ARTIFACT-FILENAME -> pinned hash, empty if unpinned
  case "$1" in
    ripgrep-14.1.1-aarch64-apple-darwin.tar.gz) echo 24ad76777745fbff131c8fbc466742b011f925bfa4fffa2ded6def23b5b937be ;;
    ripgrep-14.1.1-aarch64-unknown-linux-gnu.tar.gz) echo c827481c4ff4ea10c9dc7a4022c8de5db34a5737cb74484d62eb94a95841ab2f ;;
    ripgrep-14.1.1-x86_64-apple-darwin.tar.gz) echo fc87e78f7cb3fea12d69072e7ef3b21509754717b746368fd40d88963630e2b3 ;;
    ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz) echo 4cf9f2741e6c465ffdb7c26f38056a59e2a2544b51f7cc128ef28337eeae4d8e ;;
    bat-v0.26.1-aarch64-apple-darwin.tar.gz) echo e30beff26779c9bf60bb541e1d79046250cb74378f2757f8eb250afddb19e114 ;;
    bat-v0.26.1-aarch64-unknown-linux-gnu.tar.gz) echo 422eb73e11c854fddd99f5ca8461c2f1d6e6dce0a2a8c3d5daade5ffcb6564aa ;;
    bat-v0.26.1-x86_64-apple-darwin.tar.gz) echo 830d63b0bba1fa040542ec569e3cf77f60d3356b9de75116a344b061e0894245 ;;
    bat-v0.26.1-x86_64-unknown-linux-musl.tar.gz) echo 0dcd8ac79732c0d5b136f11f4ee00e581440e16a44eab5b3105b611bbf2cf191 ;;
    fzf-0.74.0-darwin_amd64.tar.gz) echo e2c470f058ac18615f54c0bebe0fd2956f2aa8e306a11621783a00aaa386eedd ;;
    fzf-0.74.0-darwin_arm64.tar.gz) echo da60e8980e4239a0fc5f1fcfe873f243dfda93a6a13b696b00e1dc8584a77a87 ;;
    fzf-0.74.0-linux_amd64.tar.gz) echo cf919f05b7581b4c744d764eaa704665d61dd6d3ca785f0df2351281dff60cda ;;
    fzf-0.74.0-linux_arm64.tar.gz) echo bd9e6165ebdb702215d42368cbb95b8dd70a4e77ee97925adac8c31660e30ef7 ;;
    nvim-linux-arm64.tar.gz) echo ceb7e88c6b681f0515d135dcdfad54f5eb4373b25ce6172197cd9a69c758063f ;;
    nvim-linux-x86_64.tar.gz) echo 012bf3fcac5ade43914df3f174668bf64d05e049a4f032a388c027b1ebd78628 ;;
    nvim-macos-arm64.tar.gz) echo 51ab83afa66d663627c2ab1be43209b0f4e81360d4598b53efaa4d8195f24c89 ;;
    nvim-macos-x86_64.tar.gz) echo 03fe16f8dd9f1e9eaf52d5e294913a39917b9e2faea30d7fb0fb385fbd36fe59 ;;
    xplr-linux-aarch64.tar.gz) echo 1afc0974ac48de2e1fb700a8cab159949f37df1e4294edd2446bda872b350667 ;;
    xplr-linux.tar.gz) echo 0ad6f8942ee8b6287945752242fc3f115d8f7aa32f859e8083c4df607f29831a ;;
    xplr-macos-aarch64.tar.gz) echo 383e6fbe66d4ded1389b57fbce42865db17f65b4a216eefadefa615777022844 ;;
    xplr-macos.tar.gz) echo 91768837dc4eae4871dc2653aee02c834480d900f46c572c27a75e405dc65c51 ;;
    tree-sitter-linux-arm64.gz) echo e47dd59bf2f21ad7c15771546a724464ee3c008a60fbb61c6860bd19a44b3060 ;;
    tree-sitter-linux-x64.gz) echo 8dac3c89bb632eece700ea7a261ad963b251f2228c4aef3b58458ebea8dbe4eb ;;
    tree-sitter-macos-arm64.gz) echo 0bb646b2a29007233bd44855f00d0b8e238084d5b442f097d841b476318c2c90 ;;
    tree-sitter-macos-x64.gz) echo 0da547d2622ba1583e4c748bb44db5b79af56462da41acf377b9fdc2eb2cd49f ;;
    tokyonight_night.tmTheme) echo 955c14a16b04917428ffa8b567e2d3760f872f1044a1ad157857001274dceecd ;;
  esac
}

sha256_of() { # sha256_of FILE -> lowercase hex, empty if no hashing tool exists
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1   # macOS
  elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 "$1" | awk '{print $NF}'
  fi
}

# --- helpers ----------------------------------------------------------------
dl() { # dl URL DEST - download, then verify against the pin. Non-zero on any failure,
       # so `set -e` aborts the install unless the caller explicitly guards it.
  name=$(basename "$1")
  want=$(expected_sha "$name")
  if [ -z "$want" ]; then
    warn "no pinned checksum for $name - refusing to download it"
    return 1
  fi
  info "downloading $name"
  got=0
  if command -v curl >/dev/null 2>&1; then
    if curl -fL --proto '=https' --tlsv1.2 -sS -o "$2" "$1"; then got=1; fi
  elif command -v wget >/dev/null 2>&1; then
    if wget -q --https-only -O "$2" "$1"; then got=1; fi
  else
    die "need curl or wget"
  fi
  [ "$got" = 1 ] || { warn "download failed: $name"; return 1; }
  have=$(sha256_of "$2")
  [ -n "$have" ] || { rm -f "$2"; die "no sha256 tool (sha256sum / shasum / openssl); cannot verify downloads"; }
  if [ "$have" != "$want" ]; then
    rm -f "$2"
    warn "CHECKSUM MISMATCH for $name - discarded, NOT installed"
    warn "  expected $want"
    warn "  got      $have"
    return 1
  fi
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
install_treesitter() { # the tree-sitter CLI, used by nvim-treesitter (main) to build parsers
  if at_version tree-sitter "$TREESITTER_VERSION"; then info "tree-sitter $TREESITTER_VERSION present"; return; fi
  dl "$(ghrel tree-sitter/tree-sitter "v$TREESITTER_VERSION" "tree-sitter-$TS_PLAT.gz")" "$TMP_DIR/ts.gz"
  gunzip -f "$TMP_DIR/ts.gz"
  install -m0755 "$TMP_DIR/ts" "$BIN_DIR/tree-sitter"; info "tree-sitter -> $BIN_DIR/tree-sitter"
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
# Files under the config dir that hold the USER's state rather than code. They are
# git-ignored, so a clone never carries them: without the copy below, reinstalling
# from a DIFFERENT clone (or over a real ~/.config/xpdt) silently handed the user
# factory defaults and orphaned their real settings at the old path.
USER_STATE=".gate-config .search-scope"

carry_user_state() { # carry_user_state FROM_DIR TO_DIR
  if [ ! -d "$1" ] || [ "$1" = "$2" ]; then
    return 0
  fi
  for f in $USER_STATE; do
    if [ -f "$1/$f" ] && [ ! -e "$2/$f" ]; then
      if cp "$1/$f" "$2/$f" 2>/dev/null; then
        info "kept your existing $f"
      else
        warn "could not copy $1/$f - your settings remain at that path"
      fi
    fi
  done
}

link_config() { # link_config NAME
  target="$HOME/.config/$1"; src="$REPO_DIR/$1"
  [ -d "$src" ] || die "missing $src (run install.sh from inside the xpdt repo)"
  mkdir -p "$HOME/.config"
  if [ -L "$target" ]; then
    # Settings live in whatever directory the symlink points at, so when that is a
    # different clone from this one they have to be brought across before relinking.
    prev=$(readlink "$target" 2>/dev/null || true)
    case "$prev" in /*) carry_user_state "$prev" "$src" ;; esac
    relink "$src" "$target"
  elif [ -e "$target" ]; then
    bak="$target.bak.$(date +%Y%m%d%H%M%S)"
    warn "backing up existing $target -> $bak"; mv "$target" "$bak"; ln -s "$src" "$target"
    carry_user_state "$bak" "$src"
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

# Map the `theme` setting to BAT_THEME + fzf colours for the child tools (bat, fzf).
[ -f "$HOME/.config/xpdt/theme-env.sh" ] && . "$HOME/.config/xpdt/theme-env.sh"
exec "$xplr_bin" -c "$HOME/.config/xpdt/init.lua" "$@"
XPDT_LAUNCHER
  } > "$TMP_DIR/xpdt"
  install -m0755 "$TMP_DIR/xpdt" "$BIN_DIR/xpdt"
  info "xpdt -> $BIN_DIR/xpdt  (launches: xplr -c ~/.config/xpdt/init.lua)"
}

# Seed the settings file so the 2-digit confirm is on for every action by default
# after install. Never overwrite an existing one - it holds the user's choices, and
# link_config has already carried it over from a previous install by this point.
# (gate.sh also treats an absent file/key as on, so this is belt-and-braces: it just
# makes the defaults explicit for the settings menu.)
#
# The default set itself lives in gate.sh (`gate.sh defaults`), which is also what
# the menu's "reset to defaults" row restores - one definition, so the installer and
# the reset can never drift apart.
seed_gate_config() {
  cfg="$HOME/.config/xpdt/.gate-config"
  if [ -e "$cfg" ]; then info "kept existing settings ($cfg)"; return 0; fi
  tmp="$cfg.new.$$"
  if sh "$REPO_DIR/xpdt/gate.sh" defaults > "$tmp" 2>/dev/null && [ -s "$tmp" ] && mv "$tmp" "$cfg"; then
    info "seeded default settings (all confirmations on) -> $cfg"
  else
    rm -f "$tmp" 2>/dev/null
    warn "could not seed $cfg (the 2-digit confirm is still on by default)"
  fi
}

# Build the Tokyo Night bat theme (the other four themes ship with bat). Fetches the
# .tmTheme once into bat's config dir and rebuilds bat's cache. Best-effort: on failure
# (e.g. offline) the Tokyo Night preview/diff falls back to bat's default and every
# other surface is unaffected.
TOKYONIGHT_REF=v4.11.0
install_bat_theme() {
  bat_bin="$BIN_DIR/bat"; [ -x "$bat_bin" ] || bat_bin=$(command -v bat 2>/dev/null)
  [ -n "$bat_bin" ] || { warn "bat not found; skipping the Tokyo Night bat theme"; return 0; }
  themes_dir="$HOME/.config/bat/themes"
  mkdir -p "$themes_dir" 2>/dev/null || return 0
  tn="$themes_dir/tokyonight_night.tmTheme"
  url="https://raw.githubusercontent.com/folke/tokyonight.nvim/$TOKYONIGHT_REF/extras/sublime/tokyonight_night.tmTheme"
  # Not silenced: this one is best-effort (guarded by the `if`), but a CHECKSUM
  # MISMATCH must still be visible rather than looking like an offline skip.
  if dl "$url" "$tn" && [ -s "$tn" ]; then
    if "$bat_bin" cache --build >/dev/null 2>&1; then
      info "built the Tokyo Night bat theme"
    else
      warn "could not build bat's theme cache (Tokyo Night preview falls back to default)"
    fi
  else
    rm -f "$tn" 2>/dev/null
    warn "could not fetch the Tokyo Night bat theme (its preview falls back to default)"
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
  install_ripgrep; install_bat; install_fzf; install_nvim; install_xplr; install_treesitter
fi
if [ "$DO_CONFIG" = 1 ]; then
  step "linking config and launcher"
  link_config xpdt; link_config nvim
  install_launcher
  seed_gate_config
  install_bat_theme
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
