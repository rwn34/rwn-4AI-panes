# Activity Log

Newest entries at the top. Each CLI prepends an entry after completing substantive work.

**Timestamp rule:** the `HH:MM` in each entry heading is local wall-clock time at the
moment of prepending (i.e. when the work finished, not when it started). CLIs on
different local clocks may produce timestamps that don't sort monotonically;
**prepend order is the authoritative sequencing**, timestamps are annotations.

**Archive:** older entries live in `.ai/activity/archive/YYYY-MM.md` (one file per
calendar month). See `.ai/activity/archive/README.md` for the rollover protocol.

---

## 2026-06-20 09:13 — kimi-cli
- Action: Added a console folder browser to Selector.ps1 so users can browse subfolders and select any subfolder as the project directory.
- Files: Selector.ps1
- Decisions: Implemented `Show-FolderBrowser` with Up/Down/Enter/Right/Left/Backspace/c/Esc controls; added `[>] Browse folder...` menu item and `b` shortcut; constrained browsing to `$projectsDir` and below. Syntax-checked with PSParser.
  - `rg -n "Show-FolderBrowser" Selector.ps1` → function defined at line 382
  - `rg -n "Browse folder" Selector.ps1` → menu item and footer hints added

---

