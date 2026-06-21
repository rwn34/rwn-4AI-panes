# Activity Log

Newest entries at the top. Each CLI prepends an entry after completing substantive work.

**Timestamp rule:** the `HH:MM` in each entry heading is local wall-clock time at the
moment of prepending (i.e. when the work finished, not when it started). CLIs on
different local clocks may produce timestamps that don't sort monotonically;
**prepend order is the authoritative sequencing**, timestamps are annotations.

**Archive:** older entries live in `.ai/activity/archive/YYYY-MM.md` (one file per
calendar month). See `.ai/activity/archive/README.md` for the rollover protocol.

---

## 2026-06-21 10:13 — kimi-cli
- Action: Hardened `Install-Framework` fallback and added an automated E2E test for subfolder framework injection.
- Files: Selector.ps1, test-selector-e2e.ps1
- Decisions: Added `$fwSource` resolution so the script prefers `$frameworkRepo` but falls back to the launcher directory when the configured repo is missing or empty. Removed the early return when Git Bash is missing so the direct-copy fallback still runs. Changed fallback trigger from "`.ai` missing" to "any required template item missing" so partial installs are completed. Added `test-selector-e2e.ps1` which runs two scenarios (launcher source with missing installer, and real skills repo whose installer fails verification) and verifies all required framework items land in the selected empty subfolder.
  - `rg -n "fwSource" Selector.ps1` → source resolution and fallback path
  - `rg -n "missingItems" Selector.ps1` → completeness check before fallback
  - `rg -n "Git Bash not found; will try direct template copy fallback" Selector.ps1` → no-early-return behavior
  - `rg -n "Test-FrameworkInjection" test-selector-e2e.ps1` → test harness

## 2026-06-21 09:42 — kimi-cli
- Action: Added a PowerShell fallback to `Install-Framework` that copies the core framework template files directly when the bash installer fails to create `.ai`.
- Files: Selector.ps1
- Decisions: After `install-template.sh` runs, if `$targetDir\.ai` still doesn't exist, the script copies `.ai`, `.claude`, `.kimi`, `.kiro`, `.archive`, `CLAUDE.md`, `AGENTS.md`, `docs/architecture/0001-root-file-exceptions.md`, `.github/workflows/framework-check.yml`, and `.codegraph/config.json` from the template repo, resets the activity log, and writes a minimal `.ai/.framework-version` marker. Verified with a standalone temp-target test.
  - `rg -n "Fallback: copying core framework template files" Selector.ps1` → fallback block
  - `rg -n "Framework files injected" Selector.ps1` → fallback success message

## 2026-06-21 09:35 — kimi-cli
- Action: Added local git identity and persistent debug logging to `Install-Framework` to diagnose empty-folder installs that appear to copy no files.
- Files: Selector.ps1
- Decisions: Newly-initialized repos now get `user.email`/`user.name` locally so commits succeed even when the user has no global git identity. Every `Install-Framework` run appends step-by-step details (target dir, bash path, git state, installer exit code, whether `.ai` exists after) to `install-framework.log` in the launcher directory.
  - `rg -n "Write-InstallLog" Selector.ps1` → logging calls inside `Install-Framework`
  - `rg -n "config user\.email" Selector.ps1` → local git identity setup

## 2026-06-21 09:27 — kimi-cli
- Action: Reverted the git-root framework install change so the framework is installed into the selected folder (including subfolders), matching user expectation that `.ai/`, `.kimi/`, etc. are copied where the CLIs open.
- Files: Selector.ps1
- Decisions: `Install-Framework` now uses `$targetDir` directly again; if the selected folder lacks `.git`, it initializes one there so `install-template.sh` can run. Verified with a real temp project that selecting `project/src` copies `.ai`, `.claude`, `.kimi`, `.kiro`, `.archive`, `AGENTS.md`, `CLAUDE.md`, etc. into `src`.
  - `rg -n "\$bashTarget = \$targetDir" Selector.ps1` → installer receives the selected folder
  - `rg -n "Test-Path \(Join-Path \$targetDir" Selector.ps1` → `.ai/.framework-version` and `.git` checks use selected folder

## 2026-06-21 09:17 — kimi-cli
- Action: Fixed framework install so it targets the git repo root when a subfolder is selected, instead of failing/landing inside the subfolder.
- Files: Selector.ps1
- Decisions: `Install-Framework` now resolves the git root of `$targetDir` and uses that as `$installDir` for `install-template.sh`; CLIs still open in the selected subfolder. If the repo root already has `.ai\.framework-version`, install is skipped. Verified with a temp project + `--dry-run` that selecting `project/src` installs into `project`.
  - `rg -n "git -C \$targetDir rev-parse --show-toplevel" Selector.ps1` → git root lookup
  - `rg -n "bashTarget = \$installDir" Selector.ps1` → line 186 passes repo root to installer

## 2026-06-21 09:10 — kimi-cli
- Action: Fixed browse-via-`b` shortcut selecting the highlighted project instead of the browsed subfolder when launching CLIs.
- Files: Selector.ps1
- Decisions: `Invoke-Browse` now resets `$script:selected` to the `[>] Browse folder...` menu item after a successful folder selection, so the post-menu switch statement uses `$script:targetDirFromBrowse` rather than the project item that happened to be highlighted when `b` was pressed. Verified with a non-interactive unit test that simulated pressing `b` on a project and selecting a subfolder.
  - `rg -n "type -eq 'browse'" Selector.ps1` → line 553 looks up the browse item inside `Invoke-Browse`
  - `rg -n "script:selected = .i" Selector.ps1` → line 554 resets `$script:selected` to the browse item index

## 2026-06-21 08:50 — kimi-cli
- Action: Fixed folder browser so repeated `Enter` navigates into subfolders instead of getting stuck on `./`, and `Enter`/`Right` on `./` selects the current folder.
- Files: Selector.ps1
- Decisions: Extracted `Get-BrowserItems` helper; cursor now lands on the first actual subfolder after navigation; `./` acts as a select-current-folder action when `Enter`/`Right` is pressed on it. Syntax-checked with PSParser and verified navigation/select behavior with a temp-folder test harness.
  - `rg -n "function Get-BrowserItems" Selector.ps1` → helper extracted
  - `rg -n "if \(\$items\[\$sel\]\.type -eq 'current'\)" Selector.ps1` → Enter/Right on `./` returns selected path
  - `rg -n "Get-FirstSubfolderIndex" Selector.ps1` → cursor positioned on first subfolder after navigation

## 2026-06-20 09:41 — kimi-cli
- Action: Fixed folder browser so `c` selects the highlighted folder instead of the directory currently being viewed.
- Files: Selector.ps1
- Decisions: Added `./` current-directory item at top of browser list; `c` now returns the selected item's path (./, ../, or any subfolder); Enter/Right still navigate into folders. Verified with PSParser.
  - `rg -n "type = 'current'" Selector.ps1` → `./` item and Green color added
  - `rg -n "return \$items\[\$sel\]\.path" Selector.ps1` → `c` returns selected path

---

## 2026-06-20 09:35 — kimi-cli
- Action: Created the Start Menu shortcut "rwn 4AI Panes" pointing to Launch4Panes.vbs with icon.ico.
- Files: —
- Decisions: Used WScript.Shell COM object; shortcut placed in `$env:APPDATA\Microsoft\Windows\Start Menu\Programs\`; left VBS path hardcoded as-is. Verified shortcut file exists.
  - `ls "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\rwn 4AI Panes.lnk"` → file created

---

## 2026-06-20 09:13 — kimi-cli
- Action: Added a console folder browser to Selector.ps1 so users can browse subfolders and select any subfolder as the project directory.
- Files: Selector.ps1
- Decisions: Implemented `Show-FolderBrowser` with Up/Down/Enter/Right/Left/Backspace/c/Esc controls; added `[>] Browse folder...` menu item and `b` shortcut; constrained browsing to `$projectsDir` and below. Syntax-checked with PSParser.
  - `rg -n "Show-FolderBrowser" Selector.ps1` → function defined at line 382
  - `rg -n "Browse folder" Selector.ps1` → menu item and footer hints added

---

