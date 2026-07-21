#!/bin/sh
# xpdt confirmation gate: a per-action "type 2 random digits to confirm" guard,
# on by default for every mutating action. State lives in ~/.config/xpdt/.gate-config
# as key=1/0 lines; an absent file or key reads as ON, so the gate is enabled by
# default (including immediately after install, before the file is written).
#
# Every mutating action script calls:  sh gate.sh confirm <action> "<message>"
# and proceeds only on exit 0. The `,` settings menu (gate-menu.sh) toggles the
# master switch and the per-action flags via `toggle`.
CFG="$HOME/.config/xpdt/.gate-config"

# The gateable actions and their menu labels (order = menu order).
action_rows() {
  cat <<'EOF'
create|create file / folder
move|move / rename
delete|delete file / folder
stage|stage / unstage
hunk|stage / unstage hunk
discard|discard changes
commit|commit
undo|undo last commit
cherry-pick|cherry-pick commit
stash-apply|stash: apply
stash-pop|stash: pop
stash-drop|stash: drop
stash-new|stash: new
stash-clear|stash: clear all
checkout|git: checkout branch
pull|git: pull
EOF
}

# Neovim intellisense: the languages / frameworks you can turn on (key|label).
# Each maps to an LSP server nvim starts (see nvim/init.lua SERVERS, same keys);
# the toggle only enables it - you install the few servers you want yourself, so
# it stays lightweight. All default OFF.
lsp_rows() {
  cat <<'EOF'
lua|Lua
python|Python
django|Django (templates)
typescript|TypeScript / JavaScript
html|HTML
css|CSS
json|JSON
bash|Bash
rust|Rust
go|Go
tailwind|Tailwind CSS (framework)
svelte|Svelte (framework)
eslint|ESLint (framework)
EOF
}

# Colour themes (key|label). One applies at a time (radio, not a toggle); it recolours
# xpdt, Neovim, the bat previews/diffs and the fzf browsers. Default monokai.
theme_rows() {
  cat <<'EOF'
monokai|Monokai (default)
gruvbox|Gruvbox
nord|Nord
dracula|Dracula
tokyonight|Tokyo Night
EOF
}

get() { # get KEY -> 1 (on) or 0 (off), or for `theme` the theme name (default monokai).
        # Confirmation actions and show-hidden default on; claude-integration and the
        # lsp-* language toggles are opt-in (off).
  if [ "$1" = theme ]; then
    v=$(sed -n 's/^theme=//p' "$CFG" 2>/dev/null | head -n1)
    [ -n "$v" ] && printf '%s\n' "$v" || echo monokai
    return
  fi
  if [ -f "$CFG" ]; then
    v=$(sed -n "s/^$1=//p" "$CFG" 2>/dev/null | head -n1)
    case "$v" in 0) echo 0; return ;; 1) echo 1; return ;; esac
  fi
  case "$1" in
    claude-integration | lsp-* | preview-before-nvim | nvim-left-exits | nvim-help-bar | nvim-diff-unstaged) echo 0 ;;
    *) echo 1 ;;
  esac
}

ensure_cfg() { # materialise an all-on config the first time one is needed
  [ -f "$CFG" ] && return
  { echo "enabled=1"; action_rows | while IFS='|' read -r k _; do echo "$k=1"; done; } > "$CFG" 2>/dev/null
}

toggle() { # toggle KEY (use __master__ for the master switch)
  key="$1"; [ "$key" = "__master__" ] && key="enabled"
  case "$key" in '#'*) return ;; esac  # section-header rows are not toggleable
  ensure_cfg
  if [ "$(get "$key")" = 1 ]; then new=0; else new=1; fi
  if grep -q "^$key=" "$CFG" 2>/dev/null; then
    tmp="$CFG.$$"; sed "s/^$key=.*/$key=$new/" "$CFG" > "$tmp" && mv "$tmp" "$CFG"
  else
    echo "$key=$new" >> "$CFG"
  fi
}

required() { # exit 0 if ACTION needs the code (master on AND this action on)
  [ "$(get enabled)" = 1 ] && [ "$(get "$1")" = 1 ]
}

box() { [ "$1" = 1 ] && printf '\033[32m[x]\033[0m' || printf '\033[90m[ ]\033[0m'; }
radio() { [ "$1" = 1 ] && printf '\033[32m●\033[0m' || printf '\033[90m○\033[0m'; }

case "${1:-}" in
  get) get "$2" ;;
  toggle) toggle "$2" ;;
  settheme)
    case "$2" in
      monokai | gruvbox | nord | dracula | tokyonight) ;;
      *) exit 1 ;;
    esac
    ensure_cfg
    if grep -q '^theme=' "$CFG" 2>/dev/null; then
      tmp="$CFG.$$"
      sed "s/^theme=.*/theme=$2/" "$CFG" > "$tmp" && mv "$tmp" "$CFG"
    else
      echo "theme=$2" >> "$CFG"
    fi
    ;;
  required) required "$2" ;;
  confirm)
    action="$2"; msg="$3"
    required "$action" || exit 0
    # Clear first so repeated prompts (and any "Cancelled." messages) show once on
    # a clean screen instead of stacking up on the normal screen across presses.
    # \033[?25h re-shows the cursor (fzf/xplr hide it and do not restore it for the
    # read), so there is a visible caret while typing.
    printf '\033[2J\033[H\033[?25h' > /dev/tty 2>/dev/null
    # fzf runs execute() binds with the tty still in raw mode (and restores it
    # inconsistently), which makes the prompt render oddly and Enter arrive as a
    # bare CR that `read` never treats as end-of-line (it shows as ^M). Force the
    # tty back to a sane cooked mode so the prompt reads normally; fzf re-applies
    # its own mode when the bind returns.
    stty sane < /dev/tty 2>/dev/null
    # A 2-digit confirm code, generated with awk (a single BEGIN print) rather than
    # python - no ~16ms python spawn on the confirm path. srand() seeds from the clock,
    # which is plenty for a gate whose job is to stop an accidental keypress or a pasted
    # burst, not to be a secret. (An earlier /dev/urandom + od version emitted a second
    # line under macOS's BSD od, so the "code" became two numbers that could never be
    # typed and the gate always cancelled - hence awk only, which is single-line on
    # every awk.)
    c=$(awk 'BEGIN { srand(); print int(10 + rand() * 90) }')
    # Fail closed if that somehow did not produce exactly two digits (never confirm blind).
    case "$c" in [1-9][0-9]) ;; *) printf 'Cancelled.\n' > /dev/tty; exit 1 ;; esac
    { printf '\n%s\n' "$msg"; printf 'Type %s to confirm (anything else cancels): ' "$c"; } > /dev/tty
    python3 -S -c 'import termios,sys; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)' </dev/tty 2>/dev/null
    IFS= read -r a < /dev/tty || { printf '\n' > /dev/tty; exit 1; }
    [ "$a" = "$c" ] && exit 0
    printf 'Cancelled.\n' > /dev/tty; sleep 0.5; exit 1
    ;;
  menu)
    # Rows are "key  checkbox  label"; field 1 (the key) is hidden by fzf's
    # --with-nth and used only by the toggle bind. Section-header and blank spacer
    # rows use the key `#h` (ignored by the toggle), and a blank line separates each
    # group, so the three - app settings, Neovim intellisense, and the 2-digit-gated
    # actions the master switch governs - read as clearly separate sections.
    hdr() { printf '#h \033[1;38;5;75m%s\033[0m\n' "$1"; }
    sub() { printf '#h \033[38;5;245m%s\033[0m\n' "$1"; }
    gap() { printf '#h \n'; }

    hdr 'GENERAL'
    printf 'show-hidden %s Show hidden files (dotfiles) - applies on next launch\n' "$(box "$(get show-hidden)")"
    printf 'claude-integration %s Claude session list in the git history panel\n' "$(box "$(get claude-integration)")"

    gap
    hdr 'NEOVIM'
    printf 'preview-before-nvim %s Preview a file first, instead of opening it straight in Neovim\n' "$(box "$(get preview-before-nvim)")"
    printf 'nvim-left-exits %s In Neovim, left at the start of a line (no edits) goes back to xpdt\n' "$(box "$(get nvim-left-exits)")"
    printf 'nvim-help-bar %s In Neovim, a key-hint bar across the top of the window (applies next launch)\n' "$(box "$(get nvim-help-bar)")"
    printf 'nvim-diff-unstaged %s Changes browser: open an unstaged file as an editable side-by-side diff\n' "$(box "$(get nvim-diff-unstaged)")"

    gap
    hdr 'THEME'
    sub 'Recolours xpdt, Neovim, bat previews and the fzf browsers (relaunch xpdt to apply)'
    cur=$(get theme)
    theme_rows | while IFS='|' read -r k label; do
      printf 'theme:%s %s   %s\n' "$k" "$(radio "$([ "$k" = "$cur" ] && echo 1 || echo 0)")" "$label"
    done

    gap
    hdr 'NEOVIM INTELLISENSE'
    sub 'Turn on per language; install only the ones you pick (:XpdtLsp in nvim)'
    lsp_rows | while IFS='|' read -r k label; do
      printf '%s %s   %s\n' "lsp-$k" "$(box "$(get "lsp-$k")")" "$label"
    done

    gap
    en=$(get enabled)
    hdr 'CONFIRMATION GATE'
    printf '__master__ %s Require a 2-digit code (master switch for the actions below)\n' "$(box "$en")"
    sub 'Actions guarded by the code:'
    action_rows | while IFS='|' read -r k label; do
      v=$(get "$k")
      if [ "$en" = 1 ]; then
        printf '%s %s   %s\n' "$k" "$(box "$v")" "$label"
      else
        printf '%s \033[90m%s   %s\033[0m\n' "$k" "$([ "$v" = 1 ] && printf '[x]' || printf '[ ]')" "$label"
      fi
    done
    ;;
  *) echo "usage: gate.sh {get|toggle|settheme|required|confirm|menu} ..." >&2; exit 2 ;;
esac
