# xpdt config (customised xplr)

A heavily customised [xplr](https://xplr.dev) (v1.1.0) file manager set up as a lightweight, keyboard driven git client and code browser. It adds a git author column, a git status column, a live changes browser (stage / unstage whole files or individual hunks / discard / commit / edit in Neovim), a commit history browser with undo, a stash browser (create / apply / pop / drop / clear), an inline full file diff viewer, recursive file and content search with a persistent scope toggle, a syntax highlighted file preview with indent aware wrapping and clipboard copy, a per-action confirmation gate (type two random digits before an action runs, on by default for every mutating action and toggleable in a settings menu), Nerd Font icons and colours, and on-demand help popups (`h` for the controls, `ctrl-h` for a neovim cheat sheet).

Everything lives in `~/.config/xpdt/`. `init.lua` is the entry point; the rest are small helper scripts it shells out to. It is loaded by the `xpdt` command (`xplr -c ~/.config/xpdt/init.lua`); plain `xplr` is left untouched and runs stock.

## Layout

`init.lua` replaces the default layout with a `Dynamic` custom layout (`custom.render_layout`) stacked vertically:

1. `Table` (the file listing) with custom columns: index, path (tree + icon + name), a one char git modified dot (`M`), git author, size, modified time.
2. `changes` box (`custom.render_git_changes`) listing staged and unstaged changes, auto sized to the number of changes (capped at 30 rows).
3. `git history` box (`custom.render_git_graph`) showing the last 100 commits of the current branch. Sized responsively from the terminal height: on a short window it scales down first (to a ~3 row floor) so the file listing keeps at least ~10 rows; only once the history reaches that floor does the file listing itself start to shrink.
4. `InputAndLogs` (xplr's built in input / log line).

The key legend is no longer an always-on panel (it ran off the side of narrow terminals). It is now an on-demand popup: `h` for the xpdt controls, `ctrl-h` for the neovim cheat sheet.

## Key bindings

Main directory view:

| Key      | Action                                                 |
| -------- | ------------------------------------------------------ |
| `↑ ↓`    | move                                                   |
| `→`      | enter directory, or preview a file (`preview-file.sh`) |
| `←`      | up a directory (xplr built in)                         |
| `enter`  | repo changes browser (`git-changes-browser.sh`)        |
| `;`      | commit history browser (`git-log-browser.sh`)          |
| `s`      | stash browser (`git-stash-browser.sh`)                 |
| `/`      | find files by name (`search.sh files`)                 |
| `\`      | search inside files (`search.sh content`)              |
| `'`      | jump back to the directory xplr was opened from        |
| `,`      | confirmation settings menu (`gate-menu.sh`)            |
| `h`      | controls / help popup (`help.sh`)                      |
| `ctrl-h` | neovim cheat sheet popup (`nvim-cheatsheet.sh`)        |
| `q`      | quit (xplr built in)                                   |

Every mutating action (create / move / delete, stage / hunk / discard / commit, stash apply / pop / drop / new / clear, undo commit, git checkout / pull) runs behind the confirmation gate: by default it asks you to type two random digits first. The `,` menu turns that off globally or per action. See Confirmation gate below.

Changes browser (`enter`): `s` stage/unstage the whole file (toggle, based on where the entry currently is), `p` open the hunk browser to stage/unstage individual hunks of the focused file, `d` discard, `c` commit (prompts for a message), `ctrl-e` edit the file in Neovim, `→` inline diff viewer, `enter` open the diff in VS Code, `←` back. Stage / hunk / discard / commit go through the confirmation gate.

Hunk browser (`p`): a `git add -p` style view of the focused file's hunks. `s` stages the focused hunk (or unstages it, if you opened `p` on a staged entry), `enter` / `←` back. Each hunk shows its diff in the preview; staging a hunk reloads the list so you can work through them one at a time.

Commit history (`;`): `→` open a commit, `ctrl-z` undo the last commit (soft reset, confirms), `←` back. Inside a commit: `→` inline diff viewer, `enter` open the diff in VS Code, `←` back.

Stash browser (`s`): `a` apply (keeps the stash), `p` pop (apply then drop), `d` drop the selected stash, `n` new stash from the working tree (prompts for an optional message, includes untracked files), `x` clear all stashes, `enter` / `→` view the full stash diff in a pager, `←` back. All five actions go through the confirmation gate. The preview shows the stash's diffstat and patch. Actions stay on letter keys so `enter` only ever views, never mutates.

File / content search (`/` `\`): type to filter, `tab` toggle scope (current dir vs whole tree from the launch dir), `→` preview, `enter` select (`/`) or open menu (`\`), `←` cancel. Hits are shown as paths relative to the scope dir (leading `/`, e.g. `/sub/file`), not the full launch path.

File preview: type to filter lines, `ctrl-y` copy the whole file to the clipboard, `enter` file menu (`open-menu.sh`), `←` back.

Inline diff viewer: `→` previous change, `shift-→` next change, `←` back.

## Files

| File                     | Purpose                                                                                                                                                                                                                                                           |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `init.lua`               | Entry point: key bindings, the dynamic layout, the table columns, caches, git helpers written in Lua, and the styling that is not in `theme.lua`. Loads `theme.lua` at the end via `dofile`.                                                                      |
| `theme.lua`              | Generated. Node type icons (Nerd Font) and colours for directories, symlinks and file extensions, plus dimmed styling for `.git`, `node_modules`, `__pycache__`, `.venv`.                                                                                         |
| `git-authors.sh`         | Prints `@@@author` + changed file paths for a directory, used to fill the git author column in one `git log` per folder (see Git author column below).                                                                                                            |
| `git-changes-list.sh`    | Prints the staged / unstaged porcelain list for the changes browser.                                                                                                                                                                                              |
| `git-changes-browser.sh` | The `enter` changes browser: fzf over the change list with stage/unstage toggle / discard / commit / Neovim edit / diff / VS Code bindings, live reload, and a list that resizes as changes are added or removed.                                                 |
| `git-stage.sh`           | Stage or unstage one changes-browser entry, behind the confirmation gate.                                                                                                                                                                                         |
| `git-hunk-browser.sh`    | The `p` hunk browser: fzf over one file's hunks with a `bat`-highlighted diff preview and an `s` stage/unstage-hunk bind, reloading after each.                                                                                                                   |
| `git-hunk.sh`            | The hunk engine: `list` / `show` / `apply` a single hunk. `apply` extracts the file header plus the one `@@` block from the live diff and pipes it to `git apply --cached` (`--reverse` to unstage), behind the confirmation gate.                                |
| `git-log-list.sh`        | Prints the commit list for the `;` browser.                                                                                                                                                                                                                       |
| `git-log-browser.sh`     | The `;` commit history browser (two levels: commits, then files in a commit) with undo.                                                                                                                                                                           |
| `git-stash-list.sh`      | Prints the stash list for the `s` browser (ref, relative date, description).                                                                                                                                                                                      |
| `git-stash-browser.sh`   | The `s` stash browser: fzf over the stash list with a diff+stat preview and apply / pop / drop / new / clear / view bindings, live reload, and a list that resizes to the stash count.                                                                            |
| `git-stash-op.sh`        | Runs one stash operation (push / apply / pop / drop / clear), each behind the confirmation gate.                                                                                                                                                                  |
| `git-commit.sh`          | Commit message prompt (bash `read -e` for arrow key editing); the commit itself is behind the confirmation gate.                                                                                                                                                  |
| `git-discard.sh`         | The actual discard (tracked, untracked, staged variants), behind the confirmation gate.                                                                                                                                                                           |
| `git-undo.sh`            | Undo the last commit (`git reset --soft HEAD~1`), behind the confirmation gate.                                                                                                                                                                                   |
| `gate.sh`                | The confirmation-gate store and confirm helper: `get` / `toggle` a key, `required` / `confirm <action> <msg>` (prompts for the 2 digits when the action is gated, else proceeds), and `menu` (renders the settings rows). State is `~/.config/xpdt/.gate-config`. |
| `gate-menu.sh`           | The `,` settings menu: fzf list of the master switch and each action with an `[x]` / `[ ]` checkbox; enter / space / right toggles the focused row in place.                                                                                                      |
| `open-git-diff.sh`       | Opens a diff in VS Code with clean, ref labelled tab titles (see VS Code diff below).                                                                                                                                                                             |
| `open-menu.sh`           | The file options menu (open in VS Code, preview / open changes, preview / open staged).                                                                                                                                                                           |
| `help.sh`                | The `h` controls help: renders xpdt's key bindings as short vertical lines (so nothing truncates) and shows them in `popup.sh`.                                                                                                                                   |
| `nvim-cheatsheet.sh`     | The `ctrl-h` neovim key cheat sheet, shown in `popup.sh`.                                                                                                                                                                                                         |
| `popup.sh`               | Shared popup window: shows piped-in text in a bordered, scrollable `fzf` box (used by `help.sh` and `nvim-cheatsheet.sh`).                                                                                                                                        |
| `preview-file.sh`        | Full screen file preview: `bat` for colour, `wrap-lines.py` for the gutter and indent aware wrap, fzf to display.                                                                                                                                                 |
| `wrap-lines.py`          | ANSI aware, indent preserving line wrapper for the file preview. Adds the line number gutter and remaps the `\` search jump position.                                                                                                                             |
| `search.sh`              | Backend for `/` (files, mtime sorted) and `\` (content, ripgrep). Scope aware; emits paths relative to the scope dir.                                                                                                                                             |
| `scope.sh`               | Toggles and renders the search scope (`here` vs `root`).                                                                                                                                                                                                          |
| `resolve.sh`             | Turns a base-relative search-result path (as shown in the `/` `\` menus) back into a real path, using the current scope.                                                                                                                                          |
| `diff-view.sh`           | The inline diff viewer: syntax highlights both the before and after versions with `bat` and feeds the hunks to `diff-render.py`.                                                                                                                                  |
| `diff-render.py`         | Interleaves the before / after highlighted lines by the diff hunks into a unified view: removed lines red, added lines green, context grey, with change positions for navigation.                                                                                 |
| `diff-nav.sh`            | Computes the next / previous change position for the diff viewer.                                                                                                                                                                                                 |
| `.gate-config`           | State file for the confirmation gate: `enabled=1/0` plus one `<action>=1/0` line per action. Absent file or key reads as on. Seeded all-on by the installer. Not code.                                                                                            |
| `.search-scope`          | State file holding the current search scope. Persists across sessions. Not code.                                                                                                                                                                                  |

## How the features work

### Git author column (the performance sensitive one)

`fmt_general_table_row_cols_2` fills the author column. Naively this ran one `git log -1` per file per render, which was very slow. Now:

- Results are cached per absolute path for the session (`git_author_cache`), so each entry is computed once.
- On the first cache miss in a directory, `batch_git_authors` calls `git-authors.sh` once for the whole directory (`git_author_dir_done` guards against re running it).
- `git-authors.sh` branches: a leaf directory (no subdirectories) uses one recursive `git log --name-only -- .`; a directory with subdirectories batches only its immediate files (`git ls-tree` + `git log` over those paths) so it never walks the whole repository subtree. This is the fix for the top of the repo taking a couple of seconds to open.
- Anything not covered by the batch (a subdirectory entry, an untracked file) falls back to a single `git log -1` for that entry.

### Git modified column and status

`custom.git_modified` shows a coloured dot when a path is dirty. It reads `git_status`, which caches `git status --porcelain` per repo root with a 1 second TTL. The changes box (`render_git_changes`) and the browser reuse the same porcelain parse.

### .xplrignore

`custom.apply_xplrignore` (run on load and on directory change) reads a `.xplrignore` file in the current directory. Lines beginning with `!` are kept (whitelist), other lines are hidden. This is used to show only the relevant top level folders when xplr is opened at a directory that contains several repos.

### Changes browser (`enter`)

`git-changes-browser.sh` lists staged and unstaged entries and binds single keys (lazygit style, so the list is `--disabled` and `--no-input`, no filter box at all since the keys are actions not text): `s` toggles the entry (stages an unstaged entry with `git add`, unstages a staged entry with `git restore --staged`, based on the entry's group), `d` discard, `c` commit. Each action runs then `reload`s the list in place, and a `load:transform` bind resizes the list to the current entry count (reading `$FZF_TOTAL_COUNT` and calling `change-preview-window`) so it grows and shrinks as changes appear or are staged. `enter` opens the diff in VS Code via `open-git-diff.sh`; `→` opens the inline diff viewer; `ctrl-e` opens the working file in Neovim (then `reload`s the list, since the edit may change the diff). Stage/unstage, discard and commit are separate scripts (`git-stage.sh`, `git-discard.sh`, `git-commit.sh`) so each can run behind the confirmation gate; the stage bind is therefore `execute` (it may need to prompt for the code) rather than the old `execute-silent`.

### Partial staging (hunks) (`p`)

`p` on a focused entry opens `git-hunk-browser.sh`, a `git add -p` style view of that one file's hunks. `git-hunk.sh` is the engine, with three modes over the file's live diff (`git diff` for an unstaged entry, `git diff --cached` for a staged one):

- `list` prints one row per hunk (`N  @@ ...`), the index `N` first so the browser keys off it.
- `show` prints just the Nth hunk for the preview, piped through `bat --language=diff`.
- `apply` rebuilds a one-hunk patch - the file header (the lines before the first `@@`) plus the Nth `@@` block, extracted from the diff with `awk` - and pipes it to `git apply --cached` (adding `--reverse` when the entry is staged, to unstage). It reads the diff live each time, so after a hunk is staged the list `reload`s and the remaining hunks are re-extracted against the new index; sequential hunk staging stays valid even as line numbers shift. A new/untracked file has no diff, so the browser says so and points you at `s` (whole-file stage). Hunk apply goes through the confirmation gate under its own `hunk` action.

### Commit history (`;`) and undo

`git-log-browser.sh` has two levels: the commit list, then the files changed in a commit. `ctrl-z` on the commit list runs `git-undo.sh`, which does `git reset --soft HEAD~1` (the commit is removed but the changes stay staged, matching VS Code's "undo last commit") after a confirm.

### Stash browser (`s`)

`git-stash-browser.sh` is the same lazygit-style, `--disabled --no-input` fzf shell as the changes browser, over `git stash list` (via `git-stash-list.sh`, which emits `stash@{N}` as the first field so every action keys off it). The preview is `git stash show -p --stat` for the focused stash. `a` (apply), `p` (pop), `d` (drop), `n` (new), and `x` (clear) each shell out to `git-stash-op.sh` and then `reload` the list in place; `enter` / `→` pipe the full stash diff into a pager. `git-stash-op.sh` holds the confirms and prompts: `push` refuses a clean tree, prompts for an optional message, and always stashes untracked files too (`--include-untracked`); `apply` / `pop` show git's output and pause only if it fails (a conflict); `drop` is a y/N confirm; `clear` uses the same 2-digit code confirm as the risky git-menu entries. Every action guards on a non-empty ref, so the browser is safe to open (and to press `n` in) even with no stashes.

### Confirmation gate (`,`)

Every mutating action is guarded by a "type two random digits to confirm" gate, on by default for all of them. It is one place - `gate.sh` - so the behaviour and the toggles are uniform:

- Each action script calls `sh gate.sh confirm <action> "<message>"` and only proceeds on exit 0. `confirm` looks the action up in the config: if it is not gated it exits 0 immediately (the action just runs); if it is gated it prints the message, generates a random two-digit code, flushes the tty (so buffered paste cannot auto-answer), and reads the reply - exit 0 only on an exact match, otherwise it prints `Cancelled.` and exits 1. If it cannot open the tty it fails closed (exit 1), so an action never runs unconfirmed.
- The actions covered: `create`, `move`, `delete` (main view); `stage`, `hunk`, `discard`, `commit` (changes browser); `undo` (commit history); `stash-apply`, `stash-pop`, `stash-drop`, `stash-new`, `stash-clear` (stash browser); `checkout`, `pull` (git menu).
- State lives in `~/.config/xpdt/.gate-config` as `enabled=1/0` (the master switch) plus one `<action>=1/0` line each. An absent file or an absent key reads as **on**, so the gate is enabled by default - including immediately after install, before the file exists. The installer also seeds an explicit all-on file (without overwriting an existing one), and `gate.sh` writes the file the first time you toggle anything.
- `,` opens `gate-menu.sh`: an fzf list (lazygit style, `--disabled --no-input`) of the master switch and every action with an `[x]` / `[ ]` checkbox. `enter` / `space` / `→` toggle the focused row via `gate.sh toggle` and reload in place; `←` / `esc` / `q` close. The action key is field 1 of each row, hidden with `--with-nth=2..` and used only by the toggle bind. With the master switch off the action rows are shown dimmed.

Turning a gate off means that action runs on a single key with no prompt, so the master switch off is genuinely "no confirmations anywhere" - the default is deliberately the safe one.

### Inline diff viewer

`diff-view.sh` shows the whole file syntax highlighted by `bat` (the same look as the file preview), with removed lines (red) shown inline next to added lines (green) and context (grey), opened at the first change.

- Both the before and after versions of the file are written to temp files named after the real file (so `bat` detects the language) and syntax highlighted by `bat`.
- `diff-render.py` reads the `git diff -U0` hunks and interleaves the two highlighted versions: context and added lines come from the after version, removed lines from the before version, each gutter coloured by type (grey / green / red). It records the display position of the start of each change block.
- `→` and `shift-→` are bound to `transform` actions that call `diff-nav.sh`, which reads the current line index (`{n}`), finds the previous / next change block, and echoes a `pos(N)` action back to fzf to move the cursor. Both wrap around.

Before / after are `git diff --cached` / index and HEAD for staged, working file and index for unstaged, and the commit and its parent for a commit.

### File and content search (`/` `\`)

`search.sh` is the backend. `/` (files) uses `find` piped through `stat` and `sort` so results are newest modified first, and fzf runs with `--exact` so matches are literal substrings, not fuzzy; it also re-runs on every keystroke (fzf `change:reload`), so files created while the menu is open show up without leaving it. `\` (content) uses `ripgrep --fixed-strings --sortr=modified` (falls back to `grep`), re run on every keystroke via fzf's `change:reload`. Both emit each hit as a path relative to the scope dir (leading `/`) rather than the full launch path; `resolve.sh` turns a shown path back into the real one for the preview and open actions.

Scope: `scope.sh` reads / toggles `.search-scope` (`here` = current directory, `root` = the directory xplr was launched from). `tab` toggles it, and because the state is a file it persists across sessions and is shared by `/` and `\`. The current scope is shown in the fzf header.

### File preview

`preview-file.sh` pipes `bat` (colour, tabs expanded) into `wrap-lines.py`, then into fzf. `wrap-lines.py` is the interesting part: it adds its own line number gutter and wraps long lines so the continuation lines line up under where the original line's content started (indent aware soft wrap), all while preserving `bat`'s ANSI colours across the wrap. It also remaps the target line for the `\` search jump, because wrapping turns one logical line into several display rows. `ctrl-y` copies the file with `pbcopy` and briefly flips the prompt to "copied to clipboard", auto reverting after two seconds via fzf's `--listen` HTTP port.

### VS Code diff (`open-git-diff.sh`)

`code --diff` only accepts two file paths, so historical / staged content is written to temp files. To avoid ugly `/var/folders/...` tab titles, each temp file is named `stem (ref).ext` (the ref, for example a short commit hash, `HEAD`, or `Index`, before the extension so the extension and therefore syntax highlighting is preserved). For unstaged changes the editable side is the real working file.

### Theme

`theme.lua` sets `xplr.config.node_types`: a folder icon and blue for directories, a link icon and cyan for symlinks, and per extension icons and colours for common languages. Icons are Nerd Font glyphs, so the terminal font must be a Nerd Font (Hack Nerd Font and MesloLGS NF are known to work) or they render as boxes. To disable icons, blank the `icon` values.

### Help popups (`h`, `ctrl-h`)

The key legend used to be an always-on `CustomList` panel at the bottom of the screen, but its packed rows ran off the side of narrow terminals. It is now on demand: `h` runs `help.sh` and `ctrl-h` runs `nvim-cheatsheet.sh`, each of which prints coloured, sectioned, one-key-per-line text and pipes it into `popup.sh`. `popup.sh` is a small `fzf` wrapper (`--disabled --no-input`, a rounded border and a margin so it floats over the frame) that shows the text as a scrollable popup; arrows or the mouse wheel scroll, and `q` / `esc` / `left` (or the opening key again) close it. Because the layout no longer reserves those rows, the file listing and git history get the space back.

## Conventions and gotchas

- fzf is doing most of the interactive work. Patterns used: `reload` to refresh a list in place after an action, `execute` (takes over the terminal, for pagers / prompts) vs `execute-silent` (no screen switch), `transform` (its stdout is parsed as fzf actions, used with `pos(N)` for the diff navigation), the `[...]` delimiter instead of `(...)` when a bind's command itself contains parentheses, `--listen` for updating the UI from a background process (the copy toast), and `--disabled` when single letter keys should be actions rather than filter input.
- Pasted input can leak past a `read` prompt and be interpreted by fzf as key presses (which fired stray bindings). All confirm / commit prompts flush the terminal input queue with `termios.tcflush` before / after reading so buffered paste cannot auto answer them.
- macOS captures `ctrl-left` / `ctrl-right` for Mission Control ("move a space"), so they never reach the terminal. That is why the diff viewer's previous / next uses `→` and `shift-→` rather than a ctrl arrow.
- Icons need a Nerd Font selected in the terminal (see Theme).
- Caches: `git_author_cache` and `git_author_dir_done` (session), `git_status_cache` (1s TTL), `repo_root_cache` (session), `git_log_cache` (5s TTL). They are not invalidated on commit, so an author shown can be stale until xplr is reopened.
- Helpers are plain POSIX `sh` except `git-commit.sh` (bash, for `read -e` arrow key line editing) and `wrap-lines.py` (Python). `git-commit.sh` must be invoked as `bash ...`, not `sh ...`, or `read -e` is lost.

## Testing

There is no automated test harness. Changes were verified with `luac -p init.lua` / `theme.lua` (Lua parse), `sh -n` / `bash -n` on the shell helpers, functional tests of the git logic in throwaway repos under `/tmp`, and driving xplr headlessly in a pseudo terminal (Python `pty`) to confirm rendering, colours, icons and that the config loads without error. The live behaviour of interactive fzf key handling can only be confirmed by using it.
