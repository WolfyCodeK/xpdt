# xpdt config (customised xplr)

A heavily customised [xplr](https://xplr.dev) (v1.1.0) file manager set up as a lightweight, keyboard driven git client and code browser. It adds a git author column, a git status column, a live changes browser (stage / unstage / discard / commit / edit in Neovim), a commit history browser with undo, an inline full file diff viewer, recursive file and content search with a persistent scope toggle, a syntax highlighted file preview with indent aware wrapping and clipboard copy, Nerd Font icons and colours, and a colour coded controls legend at the bottom of the screen.

Everything lives in `~/.config/xpdt/`. `init.lua` is the entry point; the rest are small helper scripts it shells out to. It is loaded by the `xpdt` command (`xplr -c ~/.config/xpdt/init.lua`); plain `xplr` is left untouched and runs stock.

## Layout

`init.lua` replaces the default layout with a `Dynamic` custom layout (`custom.render_layout`) stacked vertically:

1. `Table` (the file listing) with custom columns: index, path (tree + icon + name), a one char git modified dot (`M`), git author, size, modified time.
2. `changes` box (`custom.render_git_changes`) listing staged and unstaged changes, auto sized to the number of changes (capped at 30 rows).
3. `git history` box (`custom.render_git_graph`) showing the last 100 commits of the current branch. Sized responsively from the terminal height: on a short window it scales down first (to a ~3 row floor) so the file listing keeps at least ~10 rows; only once the history reaches that floor does the file listing itself start to shrink.
4. `InputAndLogs` (xplr's built in input / log line).
5. `controls` box (`custom.render_controls`), a colour coded key legend.

## Key bindings

Main directory view:

| Key     | Action                                                 |
| ------- | ------------------------------------------------------ |
| `↑ ↓`   | move                                                   |
| `→`     | enter directory, or preview a file (`preview-file.sh`) |
| `←`     | up a directory (xplr built in)                         |
| `enter` | repo changes browser (`git-changes-browser.sh`)        |
| `;`     | commit history browser (`git-log-browser.sh`)          |
| `/`     | find files by name (`search.sh files`)                 |
| `\`     | search inside files (`search.sh content`)              |
| `'`     | jump back to the directory xplr was opened from        |
| `q`     | quit (xplr built in)                                   |

Changes browser (`enter`): `s` stage/unstage (toggle, based on where the entry currently is), `d` discard (confirms), `c` commit (prompts), `ctrl-e` edit the file in Neovim, `→` inline diff viewer, `enter` open the diff in VS Code, `←` back.

Commit history (`;`): `→` open a commit, `ctrl-z` undo the last commit (soft reset, confirms), `←` back. Inside a commit: `→` inline diff viewer, `enter` open the diff in VS Code, `←` back.

File / content search (`/` `\`): type to filter, `tab` toggle scope (current dir vs whole tree from the launch dir), `→` preview, `enter` select (`/`) or open menu (`\`), `←` cancel.

File preview: type to filter lines, `ctrl-y` copy the whole file to the clipboard, `enter` file menu (`open-menu.sh`), `←` back.

Inline diff viewer: `→` previous change, `shift-→` next change, `←` back.

## Files

| File                     | Purpose                                                                                                                                                                                                           |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `init.lua`               | Entry point: key bindings, the dynamic layout, the table columns, caches, git helpers written in Lua, and the styling that is not in `theme.lua`. Loads `theme.lua` at the end via `dofile`.                      |
| `theme.lua`              | Generated. Node type icons (Nerd Font) and colours for directories, symlinks and file extensions, plus dimmed styling for `.git`, `node_modules`, `__pycache__`, `.venv`.                                         |
| `git-authors.sh`         | Prints `@@@author` + changed file paths for a directory, used to fill the git author column in one `git log` per folder (see Git author column below).                                                            |
| `git-changes-list.sh`    | Prints the staged / unstaged porcelain list for the changes browser.                                                                                                                                              |
| `git-changes-browser.sh` | The `enter` changes browser: fzf over the change list with stage/unstage toggle / discard / commit / Neovim edit / diff / VS Code bindings, live reload, and a list that resizes as changes are added or removed. |
| `git-log-list.sh`        | Prints the commit list for the `;` browser.                                                                                                                                                                       |
| `git-log-browser.sh`     | The `;` commit history browser (two levels: commits, then files in a commit) with undo.                                                                                                                           |
| `git-commit.sh`          | Commit message prompt (bash `read -e` for arrow key editing).                                                                                                                                                     |
| `git-discard.sh`         | Discard confirm and the actual discard (tracked, untracked, staged variants).                                                                                                                                     |
| `git-undo.sh`            | Undo the last commit (`git reset --soft HEAD~1`) with a confirm.                                                                                                                                                  |
| `open-git-diff.sh`       | Opens a diff in VS Code with clean, ref labelled tab titles (see VS Code diff below).                                                                                                                             |
| `open-menu.sh`           | The file options menu (open in VS Code, preview / open changes, preview / open staged).                                                                                                                           |
| `preview-file.sh`        | Full screen file preview: `bat` for colour, `wrap-lines.py` for the gutter and indent aware wrap, fzf to display.                                                                                                 |
| `wrap-lines.py`          | ANSI aware, indent preserving line wrapper for the file preview. Adds the line number gutter and remaps the `\` search jump position.                                                                             |
| `search.sh`              | Backend for `/` (files, mtime sorted) and `\` (content, ripgrep). Scope aware.                                                                                                                                    |
| `scope.sh`               | Toggles and renders the search scope (`here` vs `root`).                                                                                                                                                          |
| `diff-view.sh`           | The inline diff viewer: syntax highlights both the before and after versions with `bat` and feeds the hunks to `diff-render.py`.                                                                                  |
| `diff-render.py`         | Interleaves the before / after highlighted lines by the diff hunks into a unified view: removed lines red, added lines green, context grey, with change positions for navigation.                                 |
| `diff-nav.sh`            | Computes the next / previous change position for the diff viewer.                                                                                                                                                 |
| `.search-scope`          | State file holding the current search scope. Persists across sessions. Not code.                                                                                                                                  |

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

`git-changes-browser.sh` lists staged and unstaged entries and binds single keys (lazygit style, so the list is `--disabled` and `--no-input`, no filter box at all since the keys are actions not text): `s` toggles the entry (stages an unstaged entry with `git add`, unstages a staged entry with `git restore --staged`, based on the entry's group), `d` discard, `c` commit. Each action runs then `reload`s the list in place, and a `load:transform` bind resizes the list to the current entry count (reading `$FZF_TOTAL_COUNT` and calling `change-preview-window`) so it grows and shrinks as changes appear or are staged. `enter` opens the diff in VS Code via `open-git-diff.sh`; `→` opens the inline diff viewer; `ctrl-e` opens the working file in Neovim (then `reload`s the list, since the edit may change the diff). Discard and commit are separate scripts because they need a confirm / prompt.

### Commit history (`;`) and undo

`git-log-browser.sh` has two levels: the commit list, then the files changed in a commit. `ctrl-z` on the commit list runs `git-undo.sh`, which does `git reset --soft HEAD~1` (the commit is removed but the changes stay staged, matching VS Code's "undo last commit") after a confirm.

### Inline diff viewer

`diff-view.sh` shows the whole file syntax highlighted by `bat` (the same look as the file preview), with removed lines (red) shown inline next to added lines (green) and context (grey), opened at the first change.

- Both the before and after versions of the file are written to temp files named after the real file (so `bat` detects the language) and syntax highlighted by `bat`.
- `diff-render.py` reads the `git diff -U0` hunks and interleaves the two highlighted versions: context and added lines come from the after version, removed lines from the before version, each gutter coloured by type (grey / green / red). It records the display position of the start of each change block.
- `→` and `shift-→` are bound to `transform` actions that call `diff-nav.sh`, which reads the current line index (`{n}`), finds the previous / next change block, and echoes a `pos(N)` action back to fzf to move the cursor. Both wrap around.

Before / after are `git diff --cached` / index and HEAD for staged, working file and index for unstaged, and the commit and its parent for a commit.

### File and content search (`/` `\`)

`search.sh` is the backend. `/` (files) uses `find` piped through `stat` and `sort` so results are newest modified first, and fzf runs with `--exact` so matches are literal substrings, not fuzzy. `\` (content) uses `ripgrep --fixed-strings --sortr=modified` (falls back to `grep`), re run on every keystroke via fzf's `change:reload`.

Scope: `scope.sh` reads / toggles `.search-scope` (`here` = current directory, `root` = the directory xplr was launched from). `tab` toggles it, and because the state is a file it persists across sessions and is shared by `/` and `\`. The current scope is shown in the fzf header.

### File preview

`preview-file.sh` pipes `bat` (colour, tabs expanded) into `wrap-lines.py`, then into fzf. `wrap-lines.py` is the interesting part: it adds its own line number gutter and wraps long lines so the continuation lines line up under where the original line's content started (indent aware soft wrap), all while preserving `bat`'s ANSI colours across the wrap. It also remaps the target line for the `\` search jump, because wrapping turns one logical line into several display rows. `ctrl-y` copies the file with `pbcopy` and briefly flips the prompt to "copied to clipboard", auto reverting after two seconds via fzf's `--listen` HTTP port.

### VS Code diff (`open-git-diff.sh`)

`code --diff` only accepts two file paths, so historical / staged content is written to temp files. To avoid ugly `/var/folders/...` tab titles, each temp file is named `stem (ref).ext` (the ref, for example a short commit hash, `HEAD`, or `Index`, before the extension so the extension and therefore syntax highlighting is preserved). For unstaged changes the editable side is the real working file.

### Theme

`theme.lua` sets `xplr.config.node_types`: a folder icon and blue for directories, a link icon and cyan for symlinks, and per extension icons and colours for common languages. Icons are Nerd Font glyphs, so the terminal font must be a Nerd Font (Hack Nerd Font and MesloLGS NF are known to work) or they render as boxes. To disable icons, blank the `icon` values.

### Controls box

`render_controls` builds the legend programmatically and colours it with ANSI escape codes, which xplr's `CustomList` body parses. Section labels are one colour, keys another, descriptions default.

## Conventions and gotchas

- fzf is doing most of the interactive work. Patterns used: `reload` to refresh a list in place after an action, `execute` (takes over the terminal, for pagers / prompts) vs `execute-silent` (no screen switch), `transform` (its stdout is parsed as fzf actions, used with `pos(N)` for the diff navigation), the `[...]` delimiter instead of `(...)` when a bind's command itself contains parentheses, `--listen` for updating the UI from a background process (the copy toast), and `--disabled` when single letter keys should be actions rather than filter input.
- Pasted input can leak past a `read` prompt and be interpreted by fzf as key presses (which fired stray bindings). All confirm / commit prompts flush the terminal input queue with `termios.tcflush` before / after reading so buffered paste cannot auto answer them.
- macOS captures `ctrl-left` / `ctrl-right` for Mission Control ("move a space"), so they never reach the terminal. That is why the diff viewer's previous / next uses `→` and `shift-→` rather than a ctrl arrow.
- Icons need a Nerd Font selected in the terminal (see Theme).
- Caches: `git_author_cache` and `git_author_dir_done` (session), `git_status_cache` (1s TTL), `repo_root_cache` (session), `git_log_cache` (5s TTL). They are not invalidated on commit, so an author shown can be stale until xplr is reopened.
- Helpers are plain POSIX `sh` except `git-commit.sh` (bash, for `read -e` arrow key line editing) and `wrap-lines.py` (Python). `git-commit.sh` must be invoked as `bash ...`, not `sh ...`, or `read -e` is lost.

## Testing

There is no automated test harness. Changes were verified with `luac -p init.lua` / `theme.lua` (Lua parse), `sh -n` / `bash -n` on the shell helpers, functional tests of the git logic in throwaway repos under `/tmp`, and driving xplr headlessly in a pseudo terminal (Python `pty`) to confirm rendering, colours, icons and that the config loads without error. The live behaviour of interactive fzf key handling can only be confirmed by using it.
