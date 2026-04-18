# rwn 4AI Panes

> **Goal:** One maximized Windows Terminal window with 4 vertical panes — Hermes, Claude, Kimi, Kiro — no alt-tabbing.

---

## 1. What This Does

Creates a **Start Menu shortcut** called **"rwn 4AI Panes"** that opens a Windows Terminal window in two phases:

**Phase 1 — Two panes:**
- Left (25%): **Hermes Agent** (running via WSL)
- Right (75%): **Interactive project selector** (box-drawing menu, arrow-key navigation)

**Phase 2 — After selecting a project, the right pane splits into three:**
- Claude (`claude --dangerously-skip-permissions`)
- Kimi (`kimi-cli --yolo -y`)
- Kiro (`kiro-cli chat --trust-all-tools`)

**Final layout:**

```
+----------+----------+----------+----------+
|          |          |          |          |
| Hermes   | Claude   | Kimi     | Kiro     |
| (WSL)    |          |          |          |
|          |          |          |          |
+----------+----------+----------+----------+
   25%        25%        25%        25%
```

All code CLI panes open with the selected project as working directory. Hermes runs independently (no project dir). If a CLI is not installed, that pane is skipped automatically.

---

## 2. Files

| File | Purpose |
|------|---------|
| `Launch4Panes.ps1` | Entry point. Launches wt.exe with 2 panes: Hermes + Selector. Auto-closes after launch. |
| `Selector.ps1` | Interactive box-drawing menu. Handles project selection and dynamic pane splitting. After splitting, this pane becomes Claude. |
| `Launch4Panes.vbs` | VBS wrapper. Opens the PS1 from Start Menu without leaving a lingering window. |
| `icon.ico` | Custom icon for the Start Menu shortcut (dark theme, 4 colored bars). |
| `.gitignore` | Ignores `.4pane-history` and `*.tmp`. |

---

## 3. Setup

### 3.1 Prerequisites

- **Windows 10/11**
- **Windows Terminal** (`wt.exe`) — install from Microsoft Store
- **PowerShell 5.1+**
- Optional: `claude` on PATH
- Optional: `kimi-cli` on PATH
- Optional: `kiro-cli` on PATH
- Optional: Hermes Agent (`hermes.ps1` via WSL)

### 3.2 Install

1. Clone this repo:
```
git clone https://github.com/efransiscus/rwn-4AI-panes.git C:\Users\<you>\.rwn-auto\rwn-4AI-panes
```

2. **Configure your projects folder** — edit line 5 of `Selector.ps1`:
```powershell
$projectsDir = "C:\Users\<you>\Code"
```

3. **Configure Hermes path** (if different) — edit line 7 of `Launch4Panes.ps1`:
```powershell
$hermesPs1 = "C:\Users\<you>\.local\bin\hermes.ps1"
```

4. **Create the Start Menu shortcut** — run in PowerShell:
```powershell
$shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\rwn 4AI Panes.lnk"
$target = "C:\Users\<you>\.rwn-auto\rwn-4AI-panes\Launch4Panes.vbs"
$icon = "C:\Users\<you>\.rwn-auto\rwn-4AI-panes\icon.ico"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $target
$Shortcut.WorkingDirectory = "C:\Users\<you>\.rwn-auto\rwn-4AI-panes"
$Shortcut.IconLocation = $icon
$Shortcut.Save()
Write-Host "Shortcut created at: $shortcutPath"
```

5. Press **Start**, type **"rwn 4AI Panes"**, click it.

---

## 4. How to Use

1. Start Menu → **rwn 4AI Panes**
2. A maximized Windows Terminal opens with 2 panes: Hermes (left) and the selector (right)
3. Use the selector to pick a project:
   - **Up/Down arrows** — navigate
   - **Enter** — select
   - **Number keys (1-9)** — quick jump
   - **n** — create new project
   - **w** — open without directory
   - **q** — quit
   - **PageUp/PageDown** — scroll through pages
   - **Home/End** — jump to top/bottom
   - **Escape** — quit
4. After selecting, the right pane splits into 3 (Claude, Kimi, Kiro)
5. All four panes are now running — start coding

### Menu Items

| Item | Behavior |
|------|----------|
| **Project names** | Opens all CLIs in that project folder. Shows git branch + last modified time. |
| **`[+] New project...`** | Prompts for a name, creates the folder, then launches. |
| **`[*] Open without directory`** | Launches CLIs with no working directory. |

---

## 5. How It Works Internally

### 5.1 Launch Flow

```
User clicks shortcut
  -> Launch4Panes.vbs (VBS wrapper, invisible, no lingering window)
    -> Launch4Panes.ps1 (PowerShell)
      -> wt.exe -w rwn4ai -M
          Pane 1: powershell -> hermes.ps1 -> WSL -> hermes agent
          Pane 2: split-pane -V -s 0.75 -> powershell -> Selector.ps1
      -> Stop-Process (kills the launcher PowerShell)
```

### 5.2 Pane Split Math

After the user picks a project in the selector:

```
Phase 1:  Hermes(25%) | Selector(75%)
  Split 1 (from selector pane):
    Kimi takes 66.67% of selector's 75% = 50% total
    -> Hermes(25%) | Claude(25%) | Kimi(50%)

  Split 2 (from kimi pane):
    Kiro takes 50% of Kimi's 50% = 25% total
    -> Hermes(25%) | Claude(25%) | Kimi(25%) | Kiro(25%)
```

The `-s` flag in `wt.exe split-pane` means "new pane takes this fraction of the **current** pane." By splitting the original 75% selector pane twice, we get 4 equal 25% columns.

### 5.3 Selector Pane Becomes Claude

After splitting, the selector's PowerShell pane is reused — it clears the menu and launches `claude --dangerously-skip-permissions`. No pane is wasted.

### 5.4 Window Naming

The `-w rwn4ai` flag names the Windows Terminal window "rwn4ai". The selector uses this name to target splits into the correct window (`-w rwn4ai split-pane`). This prevents splits from landing in wrong windows if you have multiple wt.exe instances open.

### 5.5 CLI Auto-Detection

At startup, the selector checks for each CLI on PATH:

```powershell
$cliClaude = [bool](Get-Command claude -ErrorAction SilentlyContinue)
$cliKimi   = [bool](Get-Command kimi-cli -ErrorAction SilentlyContinue)
$cliKiro   = [bool](Get-Command kiro-cli -ErrorAction SilentlyContinue)
```

Missing CLIs are skipped — their pane simply doesn't appear. The status bar shows which CLIs were detected: `Claude[Y] Kimi[Y] Kiro[Y]` (green if all found, yellow if some missing).

---

## 6. Key Behaviors

| Behavior | Detail |
|----------|--------|
| **4-column layout** | Equal 25% each via two sequential `split-pane` calls. |
| **Maximized** | `-M` flag passed to `wt.exe`. |
| **Auto-close launcher** | `Stop-Process -Id $PID` kills the launcher PowerShell immediately. |
| **History** | Last 5 opened projects remembered and shown at top. Stored in `.4pane-history`. |
| **Dot-folder exclusion** | Folders starting with `.` are hidden from the menu. |
| **Project info** | Shows git branch and last modified time per project. |
| **Time-ago format** | History shows relative time: "now", "5m", "2h", "1d", "3d". |
| **Pagination** | Projects paginated if list exceeds console height. Page indicator shown. |
| **Box-drawing UI** | `+----+` borders, `>` cursor, color-coded items (yellow=selected, white=project, dark cyan=action). |

---

## 7. History File Format

`.4pane-history` (JSON, stored alongside scripts):

```json
[
    {
        "project": "my-app",
        "timestamp": "2026-04-18T23:45:00"
    },
    {
        "project": "website",
        "timestamp": "2026-04-18T22:10:33"
    }
]
```

- Max 5 entries (newest first)
- Duplicates are removed (re-selected project moves to top)
- Only real project selections are saved (not "new project" or "no directory")

---

## 8. Customization

### Change the projects directory
Edit `$projectsDir` in `Selector.ps1`:
```powershell
$projectsDir = "D:\Projects"
```

### Change CLI commands
Edit the `split-pane` sections in `Selector.ps1` under the "Split Panes" comment:
```powershell
# For example, change Kimi's flags:
$splitCmd = "$dirArg powershell -NoExit -NoProfile -Command kimi-cli --safe-mode"
```

### Change pane sizes
Adjust `-s` values in `Selector.ps1`:
- First split (`-s 0.6667`): how much of the 75% selector pane Kimi takes
- Second split (`-s 0.5`): how much of Kimi's pane Kiro takes

For unequal panes, e.g. Hermes bigger:
```
Launch4Panes.ps1: -s 0.70  (Hermes gets 30%, selector gets 70%)
Selector.ps1:     adjust splits proportionally
```

### Change Hermes launcher
Edit `$hermesPs1` in `Launch4Panes.ps1`:
```powershell
$hermesPs1 = "C:\path\to\your\hermes.ps1"
```

### Remove Hermes entirely
Edit `Launch4Panes.ps1` — remove the hermes pane and make selector take 100%:
```powershell
# Single pane, no split
$wtArgs = "-w rwn4ai -M -d `"$scriptDir`" powershell -NoExit -ExecutionPolicy Bypass -File `"$selectorPs1`""
```
Then adjust selector's split math for 3 equal columns instead of 4.

---

## 9. Troubleshooting

| Problem | Fix |
|---------|-----|
| Nothing happens when clicking shortcut | The VBS file may be empty. Verify `Launch4Panes.vbs` is not 0 bytes. |
| `wt.exe` not found | Install **Windows Terminal** from the Microsoft Store. |
| Window opens but no selector | Check that `Selector.ps1` exists in the same folder as `Launch4Panes.ps1`. |
| Pane splits are wrong sizes | The `-s` values are sensitive. `0.6667` = 2/3, `0.5` = 1/2. Adjust carefully. |
| Splits go to wrong window | The `-w rwn4ai` window name targets a specific wt window. Close all wt instances and retry. |
| CLI pane is missing | That CLI isn't on PATH. Install it or check `Get-Command <cli-name>`. |
| Menu looks garbled | Box-drawing characters need a monospace font in Windows Terminal settings. |
| Double PowerShell tab | Windows Terminal may be your default terminal. The `Stop-Process` line auto-closes it. |
| `0x80070002` errors | Wrong argument quoting to `wt.exe`. The fix is `cmd.exe /c` wrapping. |
| Menu exits immediately on keypress | Running in a non-interactive context. Must run via wt.exe, not `powershell -File` directly in some shells. |

---

## 10. Dependencies

- **Windows 10/11**
- **Windows Terminal** (`wt.exe`) — from Microsoft Store
- **PowerShell 5.1+**
- **Git** (optional — for branch display in menu)
- Optional: `claude` CLI on PATH
- Optional: `kimi-cli` on PATH
- Optional: `kiro-cli` on PATH
- Optional: Hermes Agent with `hermes.ps1` launcher via WSL

---

## 11. Comparison with rwn-threecodepanes

| Feature | rwn-threecodepanes | rwn 4AI Panes |
|---------|-------------------|---------------|
| Panes | 3 (Claude, Kimi, Kiro) | 4 (Hermes, Claude, Kimi, Kiro) |
| Hermes | Not included | Left pane, runs via WSL |
| Menu style | Number input (text) | Box-drawing, arrow-key navigation |
| Launch flow | Menu -> 3 panes | Menu -> 2 panes -> dynamic split to 4 |
| Custom icon | No | Yes (`icon.ico`) |
| Pagination | Show all / compact (10) | Auto-paged by console height |

---

*End of spec. Clone, configure paths, create shortcut, done.*
