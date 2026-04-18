# rwn-4AI-panes

Windows Terminal 4-column layout: **Hermes | Claude | Kimi | Kiro** — all in one maximized window, no alt-tabbing.

## How It Works

1. Launch the shortcut → Windows Terminal opens with **2 panes**: Hermes (left, 25%) and a project selector menu (right, 75%)
2. Pick a project using arrow keys + Enter
3. The selector pane splits into **3 code CLI panes** (Claude, Kimi, Kiro)
4. Final layout: **4 equal columns** (25% each)

```
+----------+----------+----------+----------+
|          |          |          |          |
| Hermes   | Claude   | Kimi     | Kiro     |
| (WSL)    |          |          |          |
|          |          |          |          |
+----------+----------+----------+----------+
```

## Selector Menu

Interactive box-drawing UI with:

- Arrow keys (Up/Down) to navigate
- Enter to select
- Number keys (1-9) for quick jump
- `n` — new project
- `w` — open without directory
- `q` — quit
- PageUp/PageDown, Home/End for large lists
- Git branch and modification time per project
- Last-used history (top 5 remembered)

## Files

| File | Purpose |
|------|---------|
| `Launch4Panes.ps1` | Entry point — launches wt.exe with Hermes + Selector |
| `Selector.ps1` | Interactive menu + dynamic pane splitting |
| `Launch4Panes.vbs` | Start Menu wrapper (no lingering window) |
| `.gitignore` | Ignores history file |

## Setup

### Prerequisites

- Windows 10/11
- Windows Terminal (`wt.exe`)
- PowerShell 5.1+
- Optional: `claude`, `kimi-cli`, `kiro-cli` on PATH
- Optional: Hermes Agent (`hermes.ps1` via WSL)

### Install

1. Clone this repo to `C:\Users\<you>\.rwn-auto\rwn-4AI-panes\`
2. Edit `$projectsDir` in `Selector.ps1` to point to your code folder
3. Edit `$hermesPs1` in `Launch4Panes.ps1` if Hermes is elsewhere
4. Create the Start Menu shortcut:

```powershell
$shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\rwn-4AI-panes.lnk"
$target = "C:\Users\<you>\.rwn-auto\rwn-4AI-panes\Launch4Panes.vbs"
$icon = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $target
$Shortcut.WorkingDirectory = "C:\Users\<you>\.rwn-auto\rwn-4AI-panes"
$Shortcut.IconLocation = $icon
$Shortcut.Save()
```

5. Press Start, type "rwn-4AI-panes", click it.

### Use

Just run the shortcut. Pick a project. Done.

## Pane Split Math

```
Phase 1:  Hermes(25%) | Selector(75%)
  Split 1: Selector splits -> Kimi takes 66.67% of 75% = 50% total
  Split 2: Kimi splits    -> Kiro takes 50% of 50% = 25% total
Result:   Hermes(25%) | Claude(25%) | Kimi(25%) | Kiro(25%)
```

## Customization

- **Change projects folder**: edit `$projectsDir` in `Selector.ps1`
- **Change CLI commands**: edit the `split-pane` commands in Selector.ps1's "Split Panes" section
- **Change pane sizes**: adjust `-s 0.6667` and `-s 0.5` values
- **Change Hermes launcher**: edit `$hermesPs1` in `Launch4Panes.ps1`

## License

MIT
