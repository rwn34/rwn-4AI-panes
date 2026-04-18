# Selector.ps1 - Interactive project selector for rwn-4AI-panes
# Phase 1: Box-drawing menu with arrow-key navigation
# Phase 2: Splits current pane into Claude/Kimi/Kiro, runs Claude here

$ErrorActionPreference = "SilentlyContinue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectsDir = "C:\Users\rwn34\Code"
$historyFile = Join-Path $scriptDir ".4pane-history"
$wtExe = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"

# ── CLI Detection ──
$cliClaude = [bool](Get-Command claude -ErrorAction SilentlyContinue)
$cliKimi = [bool](Get-Command kimi-cli -ErrorAction SilentlyContinue)
$cliKiro = [bool](Get-Command kiro-cli -ErrorAction SilentlyContinue)

if (-not ($cliClaude -or $cliKimi -or $cliKiro)) {
    Write-Host "No code CLIs found (claude, kimi-cli, kiro-cli)." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    Stop-Process -Id $PID
}

# ── Project Functions ──
function Get-Projects {
    if (Test-Path $projectsDir) {
        Get-ChildItem -Path $projectsDir -Directory |
            Where-Object { $_.Name -notmatch '^\.' } |
            Select-Object -ExpandProperty Name | Sort-Object
    } else {
        @()
    }
}

function Get-History {
    if (Test-Path $historyFile) {
        try {
            $raw = Get-Content $historyFile -Raw | ConvertFrom-Json
            if ($raw -is [array]) { return $raw }
            if ($raw) { return @($raw) }
            return @()
        } catch { return @() }
    }
    return @()
}

function Save-History($project) {
    $history = @(Get-History)
    $entry = [PSCustomObject]@{
        project = $project
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    }
    $history = $history | Where-Object { $_.project -ne $project }
    $history = @($entry) + $history
    $history = $history | Select-Object -First 5
    ConvertTo-Json -InputObject $history | Set-Content $historyFile
}

function Format-TimeAgo($timestamp) {
    try {
        $dt = [datetime]::Parse($timestamp)
        $diff = [datetime]::Now - $dt
        if ($diff.TotalMinutes -lt 1) { return "now" }
        if ($diff.TotalMinutes -lt 60) { return "$([math]::Floor($diff.TotalMinutes))m" }
        if ($diff.TotalHours -lt 24) { return "$([math]::Floor($diff.TotalHours))h" }
        if ($diff.TotalDays -lt 2) { return "1d" }
        return "$([math]::Floor($diff.TotalDays))d"
    } catch { return "" }
}

function Get-ProjectInfo($project) {
    $dir = Join-Path $projectsDir $project
    $branch = $null
    try { $branch = & git -C $dir branch --show-current 2>$null } catch {}

    $modified = (Get-Item $dir -ErrorAction SilentlyContinue).LastWriteTime
    if ($modified) {
        $ago = [datetime]::Now - $modified
        $timeStr = if ($ago.TotalMinutes -lt 60) { "$([math]::Floor($ago.TotalMinutes))m" }
                   elseif ($ago.TotalHours -lt 24) { "$([math]::Floor($ago.TotalHours))h" }
                   else { "$([math]::Floor($ago.TotalDays))d" }
    } else { $timeStr = "" }

    $parts = @()
    if ($branch) { $parts += $branch }
    if ($timeStr) { $parts += $timeStr }
    return $parts -join " "
}

# ── Build Menu Items ──
$allProjects = Get-Projects
$history = Get-History

$ordered = [System.Collections.ArrayList]::new()
$seen = @{}
foreach ($h in $history) {
    if (($allProjects -contains $h.project) -and -not $seen.ContainsKey($h.project)) {
        [void]$ordered.Add($h.project)
        $seen[$h.project] = $true
    }
}
foreach ($p in $allProjects) {
    if (-not $seen.ContainsKey($p)) {
        [void]$ordered.Add($p)
        $seen[$p] = $true
    }
}

$menuItems = [System.Collections.ArrayList]::new()
foreach ($p in $ordered) {
    $info = Get-ProjectInfo -project $p
    $histEntry = $history | Where-Object { $_.project -eq $p } | Select-Object -First 1
    $ago = if ($histEntry) { Format-TimeAgo -timestamp $histEntry.timestamp } else { "" }
    [void]$menuItems.Add(@{ name = $p; info = $info; lastUsed = $ago; type = 'project' })
}
[void]$menuItems.Add(@{ name = '[+] New project...'; info = ''; lastUsed = ''; type = 'new' })
[void]$menuItems.Add(@{ name = '[*] Open without directory'; info = ''; lastUsed = ''; type = 'nodir' })

# ── Interactive Menu ──
$script:selected = 0
$script:pageOffset = 0
$script:pageSize = [Math]::Max(3, [Console]::WindowHeight - 13)

function Draw-Menu {
    $conW = [Console]::WindowWidth
    $boxW = [Math]::Max(40, [Math]::Min(72, $conW - 2))
    $innerW = $boxW - 2

    if ($script:selected -lt $script:pageOffset) { $script:pageOffset = $script:selected }
    if ($script:selected -ge $script:pageOffset + $script:pageSize) {
        $script:pageOffset = $script:selected - $script:pageSize + 1
    }

    $visibleCount = [Math]::Min($script:pageSize, $menuItems.Count - $script:pageOffset)

    Clear-Host

    # Top border + title
    Write-Host ("+" + "-" * $innerW + "+") -ForegroundColor Cyan
    $title = " rwn-4AI-panes"
    Write-Host ("|" + $title.PadRight($innerW) + "|") -ForegroundColor Cyan
    Write-Host ("+" + "-" * $innerW + "+") -ForegroundColor Cyan

    # CLI status
    $cl = if ($cliClaude) { "Y" } else { "N" }
    $kl = if ($cliKimi) { "Y" } else { "N" }
    $kl2 = if ($cliKiro) { "Y" } else { "N" }
    $allOK = $cliClaude -and $cliKimi -and $cliKiro
    $statusColor = if ($allOK) { "Green" } else { "Yellow" }
    $status = " Claude[$cl]  Kimi[$kl]  Kiro[$kl2]"
    Write-Host ("|" + $status.PadRight($innerW) + "|") -ForegroundColor $statusColor

    # Separator
    Write-Host ("|" + ("-" * $innerW) + "|") -ForegroundColor DarkGray

    # Items
    for ($i = 0; $i -lt $visibleCount; $i++) {
        $idx = $script:pageOffset + $i
        $item = $menuItems[$idx]
        $isSel = ($idx -eq $script:selected)

        if ($item.type -eq 'project') {
            $marker = if ($isSel) { " >" } else { "  " }
            $num = "$($idx + 1)".PadLeft(2)
            $namePart = "$marker $num $($item.name)"

            $infoParts = @()
            if ($item.info) { $infoParts += $item.info }
            if ($item.lastUsed) { $infoParts += "$($item.lastUsed) ago" }
            $infoStr = $infoParts -join " | "

            $spaceForInfo = $innerW - $namePart.Length - 1
            if ($spaceForInfo -gt 8 -and $infoStr.Length -gt 0) {
                if ($infoStr.Length -gt $spaceForInfo) {
                    $infoStr = $infoStr.Substring(0, $spaceForInfo - 2) + ".."
                }
                $line = $namePart + " " + $infoStr.PadLeft($spaceForInfo - 1)
            } else {
                $line = $namePart
            }

            if ($line.Length -gt $innerW) { $line = $line.Substring(0, $innerW) }
            $color = if ($isSel) { "Yellow" } else { "White" }
            Write-Host ("|" + $line.PadRight($innerW) + "|") -ForegroundColor $color
        } else {
            $marker = if ($isSel) { " >" } else { "  " }
            $line = "$marker $($item.name)"
            $color = if ($isSel) { "Yellow" } else { "DarkCyan" }
            Write-Host ("|" + $line.PadRight($innerW) + "|") -ForegroundColor $color
        }
    }

    # Footer
    Write-Host ("|" + ("-" * $innerW) + "|") -ForegroundColor DarkGray
    $footer = " Up/Down:navigate  Enter:select  n:new  w:no dir  q:quit"
    if ($footer.Length -gt $innerW) { $footer = $footer.Substring(0, $innerW) }
    Write-Host ("|" + $footer.PadRight($innerW) + "|") -ForegroundColor DarkGray
    Write-Host ("+" + "-" * $innerW + "+") -ForegroundColor Cyan

    if ($menuItems.Count -gt $script:pageSize) {
        $totalPages = [Math]::Ceiling($menuItems.Count / $script:pageSize)
        $currentPage = [Math]::Floor($script:pageOffset / $script:pageSize) + 1
        Write-Host " Page $currentPage/$totalPages ($($menuItems.Count) items)" -ForegroundColor DarkGray
    }
}

# ── Key Loop ──
$done = $false
while (-not $done) {
    Draw-Menu
    $key = [System.Console]::ReadKey($true)

    switch ($key.Key) {
        'UpArrow'   { $script:selected = [Math]::Max(0, $script:selected - 1) }
        'DownArrow' { $script:selected = [Math]::Min($menuItems.Count - 1, $script:selected + 1) }
        'Enter'     { $done = $true }
        'Escape'    { Stop-Process -Id $PID }
        'PageUp'    { $script:selected = [Math]::Max(0, $script:selected - $script:pageSize) }
        'PageDown'  { $script:selected = [Math]::Min($menuItems.Count - 1, $script:selected + $script:pageSize) }
        'Home'      { $script:selected = 0 }
        'End'       { $script:selected = $menuItems.Count - 1 }
        default {
            $ch = $key.KeyChar
            if ($ch -eq 'n') { $script:selected = $menuItems.Count - 2; $done = $true }
            elseif ($ch -eq 'w') { $script:selected = $menuItems.Count - 1; $done = $true }
            elseif ($ch -eq 'q') { Stop-Process -Id $PID }
            elseif ($ch -match '[0-9]') {
                $num = [int]$ch.ToString()
                if ($num -ge 1 -and $num -le $menuItems.Count) {
                    $script:selected = $num - 1
                    $done = $true
                }
            }
        }
    }
}

# ── Process Selection ──
$chosen = $menuItems[$script:selected]
$targetDir = $null

switch ($chosen.type) {
    'project' {
        $targetDir = Join-Path $projectsDir $chosen.name
        Save-History -project $chosen.name
    }
    'new' {
        Clear-Host
        Write-Host "+----------------------+" -ForegroundColor Cyan
        Write-Host "| Create New Project   |" -ForegroundColor Cyan
        Write-Host "+----------------------+" -ForegroundColor Cyan
        $name = Read-Host "Project name"
        if ([string]::IsNullOrWhiteSpace($name)) {
            Write-Host "Cancelled." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            Stop-Process -Id $PID
        }
        $targetDir = Join-Path $projectsDir $name
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir | Out-Null
            Write-Host "Created: $targetDir" -ForegroundColor Green
        }
        Save-History -project $name
        Start-Sleep -Milliseconds 500
    }
    'nodir' {
        $targetDir = $null
    }
}

# ── Split Panes ──
# Layout math:
#   Phase 1: Hermes(25%) | Selector(75%)
#   Split 1: Kimi takes 66.67% of selector -> 50% total
#     -> Hermes(25%) | Claude(25%) | Kimi(50%)
#   Split 2: Kiro takes 50% of Kimi pane -> 25% total
#     -> Hermes(25%) | Claude(25%) | Kimi(25%) | Kiro(25%)

Clear-Host
$launching = @()
if ($cliClaude) { $launching += "Claude" }
if ($cliKimi) { $launching += "Kimi" }
if ($cliKiro) { $launching += "Kiro" }
Write-Host "Launching $($launching -join ', ')..." -ForegroundColor Cyan

if ($cliKimi) {
    $dirArg = if ($targetDir) { "-d `"$targetDir`"" } else { "" }
    $splitCmd = "$dirArg powershell -NoExit -NoProfile -Command kimi-cli --yolo -y"
    $wtCmd = "-w rwn4ai split-pane -V -s 0.6667 $splitCmd"
    try {
        & cmd.exe /c "`"$wtExe`" $wtCmd"
        Start-Sleep -Milliseconds 400
    } catch {
        Write-Host "Failed to launch Kimi pane." -ForegroundColor Red
    }
}

if ($cliKiro) {
    $dirArg = if ($targetDir) { "-d `"$targetDir`"" } else { "" }
    $splitCmd = "$dirArg powershell -NoExit -NoProfile -Command kiro-cli chat --trust-all-tools"
    $wtCmd = "-w rwn4ai split-pane -V -s 0.5 $splitCmd"
    try {
        & cmd.exe /c "`"$wtExe`" $wtCmd"
        Start-Sleep -Milliseconds 400
    } catch {
        Write-Host "Failed to launch Kiro pane." -ForegroundColor Red
    }
}

# This pane -> Claude
Clear-Host
if ($cliClaude) {
    if ($targetDir) { Set-Location $targetDir }
    & claude --dangerously-skip-permissions
} else {
    Write-Host "Claude CLI not found. This pane is idle." -ForegroundColor Yellow
}
