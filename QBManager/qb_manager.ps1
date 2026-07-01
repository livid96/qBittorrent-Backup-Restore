# --------------------------- Hide Console ---------------------------
Add-Type -Name Win -Namespace Console -MemberDefinition '
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd,int nCmdShow);
'
$consolePtr = [Console.Win]::GetConsoleWindow()
[Console.Win]::ShowWindow($consolePtr,0)  # 0=Hide

# --------------------------- Admin Elevation ---------------------------
function Ensure-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = "runas"
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    }
}
Ensure-Admin

# --------------------------- Load Assemblies ---------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --------------------------- Config Initialization ---------------------------
$configFile = "$env:USERPROFILE\Documents\.QBTBackupDir.txt"
if (Test-Path $configFile) {
    (Get-Item $configFile).Attributes += 'Hidden'
}
$defaultFolder = "$env:USERPROFILE\Desktop"

if (-not (Test-Path $configFile)) {
    $defaultFolder | Set-Content $configFile
}

$global:backupDir = Get-Content $configFile


# --------------------------- Create Form ---------------------------
$form = New-Object Windows.Forms.Form
$form.font = New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)
$form.Text = "qBittorrent Manager"

# Set initial size larger than minimum
$form.Size = New-Object Drawing.Size(530, 630)   # <-- Width = 520, Height = 700 (taller)

$form.WindowState = 'Normal'
$form.FormBorderStyle = 'FixedDialog'
$form.MinimumSize = New-Object Drawing.Size(520,600)
$form.StartPosition = 'CenterScreen'
$form.BackColor = "#1e1e1e"
$font = New-Object Drawing.Font("Segoe UI",10)

# --------------------------- Folder Label ---------------------------
$folderLabel = New-Object Windows.Forms.Label
$folderLabel.Size = New-Object Drawing.Size(480,25)
$folderLabel.Location = New-Object Drawing.Point(20,10)
$folderLabel.ForeColor = "white"
$folderLabel.font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$folderLabel.Text = "Backup Folder: $global:backupDir"
$folderLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($folderLabel)


# --------------------------- Progress Bar ---------------------------
$progressX = 20
$progressY = 560

$progress = New-Object Windows.Forms.ProgressBar
$progress.Size = New-Object Drawing.Size(480,20)
$progress.Location = New-Object Drawing.Point($progressX, $progressY)
$progress.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor `
                   [System.Windows.Forms.AnchorStyles]::Left -bor `
                   [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($progress)

# Function to update progress bar position dynamically
function Set-ProgressPosition {
    param (
        [int]$X,
        [int]$Y
    )
    $progress.Location = New-Object Drawing.Point($X, $Y)
}

# Example usage: move the progress bar (can be called anywhere in your script)
# Set-ProgressPosition -X 50 -Y 400

# --------------------------- Progress Fill ---------------------------
$progressFill = New-Object Windows.Forms.Panel
$progressFill.Size = New-Object Drawing.Size(0,20)
$progressFill.Location = New-Object Drawing.Point(0,0)

# HEX Color here
$progressFill.BackColor = [Drawing.ColorTranslator]::FromHtml("#ff0000")

$progressBG.Controls.Add($progressFill)



# --------------------------- Popup Message Function ---------------------------
function Show-PopupMessage {
    param([string]$Message,[int]$DurationMs=2000)
    $popupForm = New-Object System.Windows.Forms.Form
    $popupForm.Size = New-Object System.Drawing.Size(450,80)
    $popupForm.FormBorderStyle = "None"
    $popupForm.StartPosition = "CenterScreen"
    $popupForm.TopMost = $true
    $popupForm.BackColor = "#007700"

    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize = $true
    $label.Font = New-Object System.Drawing.Font("Segoe UI",20,[System.Drawing.FontStyle]::Bold)
    $label.ForeColor = "White"
    $label.Text = $Message.ToUpper()
    $label.Location = New-Object System.Drawing.Point(20,20)
    $popupForm.Controls.Add($label)

    $popupForm.Show()
    Start-Sleep -Milliseconds $DurationMs
    $popupForm.Close()
}

# --------------------------- Font Definition ---------------------------
$font = New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)

# --------------------------- Folder Selection ---------------------------
$folderBtn = New-Object Windows.Forms.Button
$folderBtn.Text = "Select Backup Folder"
$folderBtn.Size = New-Object Drawing.Size(480,35)
$folderBtn.Location = New-Object Drawing.Point(20,40)
$folderBtn.BackColor = "#a57900"
$folderBtn.ForeColor = "white"
$folderBtn.Font = $font
$folderBtn.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($folderBtn)

$folderBtn.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if ([string]::IsNullOrEmpty($global:backupDir)) { $dialog.SelectedPath = "$env:USERPROFILE\Desktop" }
    else { $dialog.SelectedPath = $global:backupDir }

    if ($dialog.ShowDialog() -eq "OK") {
        $global:backupDir = $dialog.SelectedPath
        $folderLabel.Text = "Backup Folder: $global:backupDir"
        $global:backupDir | Set-Content $configFile
        Show-PopupMessage "FOLDER SELECTED"
        Load-RestoreList
    }
})

# --------------------------- Backup Button ---------------------------
$backupBtn = New-Object Windows.Forms.Button
$backupBtn.Text = "Backup Now"
$backupBtn.Size = New-Object Drawing.Size(480,40)
$backupBtn.Location = New-Object Drawing.Point(20,100)
$backupBtn.BackColor = "#006fb9"
$backupBtn.ForeColor = "white"
$backupBtn.Font = $font
$backupBtn.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($backupBtn)

$backupBtn.Add_Click({

    if (!(Test-Path $global:backupDir)) { New-Item $global:backupDir -ItemType Directory | Out-Null }

    $progress.Value = 10

    $local = "$env:LOCALAPPDATA\qBittorrent"
    $roaming = "$env:APPDATA\qBittorrent"

    if (!(Test-Path $global:backupDir)) { New-Item -ItemType Directory -Path $global:backupDir | Out-Null }

    # --------------------------- Torrent Count ---------------------------
    $torrentCount = 0
    $btBackup = "$local\BT_backup"

    if (Test-Path $btBackup) {
        $torrentCount = (Get-ChildItem $btBackup -Filter "*.fastresume" -ErrorAction SilentlyContinue).Count
    }

    $date = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $temp = "$env:TEMP\qb_backup"

    Remove-Item $temp -Recurse -Force -ErrorAction Ignore
    New-Item -ItemType Directory -Path $temp | Out-Null
    New-Item "$temp\Local" -ItemType Directory -Force | Out-Null
    New-Item "$temp\Roaming" -ItemType Directory -Force | Out-Null

    Copy-Item "$local\*" "$temp\Local" -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item "$roaming\*" "$temp\Roaming" -Recurse -Force -ErrorAction SilentlyContinue

    # --------------------------- Zip Name ---------------------------
    $zipFile = "$global:backupDir\qbittorrent_backup_${torrentCount}torrents_$date.zip"

    Compress-Archive -Path "$temp\*" -DestinationPath $zipFile -Force

    Remove-Item $temp -Recurse -Force

    $progress.Value = 100
    Show-PopupMessage "BACKUP SUCCESSFUL"
    $progress.Value = 0

    Load-RestoreList
})


# --------------------------- Restore List Full Script ---------------------------

# Label
$restoreLabel = New-Object Windows.Forms.Label
$restoreLabel.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$restoreLabel.Text = "Select Backup to Restore:"
$restoreLabel.ForeColor = "white"
$restoreLabel.Location = New-Object Drawing.Point(20,160)
$restoreLabel.Size = New-Object Drawing.Size(480,20)
$restoreLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($restoreLabel)

# ListBox
$restoreList = New-Object Windows.Forms.ListBox
$restoreList.Size = New-Object Drawing.Size(480,150)
$restoreList.Location = New-Object Drawing.Point(20,180)
$restoreList.BackColor = "#2e2e2e"
$restoreList.ForeColor = "white"
$restoreList.Font = New-Object System.Drawing.Font("Consolas",9,[System.Drawing.FontStyle]::Bold)
$restoreList.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$restoreList.SelectionMode = [System.Windows.Forms.SelectionMode]::MultiExtended
$restoreList.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
$restoreList.ItemHeight = 18

# Enable double buffering
$restoreList.GetType().GetProperty("DoubleBuffered", [Reflection.BindingFlags] "NonPublic, Instance").SetValue($restoreList, $true, $null)
$form.Controls.Add($restoreList)

# --------------------------- Tracking ---------------------------
$script:hoverIndex = -1
$script:mouseDown = $false

# Colors
$defaultColor       = [System.Drawing.ColorTranslator]::FromHtml("#2e2e2e")
$singleSelectColor  = [System.Drawing.ColorTranslator]::FromHtml("#006b42")
$multiSelectColor   = [System.Drawing.ColorTranslator]::FromHtml("#008c5e")
$hoverColor         = [System.Drawing.ColorTranslator]::FromHtml("#005f37")
$textBrush          = [System.Drawing.Brushes]::White

# --------------------------- Draw Items ---------------------------
$restoreList.Add_DrawItem({
    param($sender,$e)
    if ($e.Index -lt 0) { return }
    $g = $e.Graphics
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $item = $sender.Items[$e.Index]
    $isSelected = $sender.SelectedIndices.Contains($e.Index)
    $selectedCount = $sender.SelectedItems.Count
    $isHover = ($selectedCount -le 1) -and (-not $isSelected) -and ($script:hoverIndex -eq $e.Index)
    if ($isSelected -and $selectedCount -gt 1) { $bgColor = $multiSelectColor }
    elseif ($isSelected) { $bgColor = $singleSelectColor }
    elseif ($isHover) { $bgColor = $hoverColor }
    else { $bgColor = $defaultColor }
    $brush = New-Object System.Drawing.SolidBrush $bgColor
    $g.FillRectangle($brush, $e.Bounds)
    $brush.Dispose()
    $g.DrawString($item, $sender.Font, $textBrush, $e.Bounds.X + 5, $e.Bounds.Y + 1)
})

# --------------------------- Refresh ---------------------------
$restoreList.Add_SelectedIndexChanged({ $restoreList.Invalidate() })
$restoreList.Add_Resize({ $restoreList.Invalidate() })
$restoreList.Add_MouseWheel({ $restoreList.Invalidate() })

# --------------------------- Hover ---------------------------
$restoreList.Add_MouseMove({
    param($sender,$e)
    $index = $sender.IndexFromPoint($e.Location)
    if ($sender.SelectedItems.Count -le 1 -and $index -ne $script:hoverIndex) {
        if ($script:hoverIndex -ge 0) { $sender.Invalidate($sender.GetItemRectangle($script:hoverIndex)) }
        $script:hoverIndex = $index
        if ($index -ge 0) { $sender.Invalidate($sender.GetItemRectangle($index)) }
    }
    if ($script:mouseDown -and $index -ge 0 -and -not $sender.SelectedIndices.Contains($index)) {
        $sender.SetSelected($index,$true)
    }
})
$restoreList.Add_MouseLeave({
    if ($script:hoverIndex -ne -1) {
        $restoreList.Invalidate($restoreList.GetItemRectangle($script:hoverIndex))
        $script:hoverIndex = -1
    }
})

# --------------------------- Left Click & Alt+Click ---------------------------
$restoreList.Add_MouseDown({
    param($sender,$e)
    $script:mouseDown = $true
    $index = $sender.IndexFromPoint($e.Location)
    if ($index -eq -1) { return }

    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {

        # Alt+Click toggles selection without affecting others
        if ($e.Alt) {
            $sender.SetSelected($index, -not $sender.SelectedIndices.Contains($index))
            $e.Handled = $true
        }
        # Ctrl+Click and Shift+Click handled normally
        elseif (-not $e.Control -and -not $e.Shift) {
            # Single click clears others
            $sender.ClearSelected()
            $sender.SetSelected($index,$true)
        }
    }
})
$restoreList.Add_MouseUp({ $script:mouseDown = $false })

# --------------------------- Keyboard ---------------------------
$restoreList.Add_KeyDown({
    param($sender,$e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::A) {
        for ($i=0; $i -lt $sender.Items.Count; $i++) { $sender.SetSelected($i,$true) }
        $e.Handled = $true
    }
})

# --------------------------- Context Menu ---------------------------
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$contextMenu.BackColor = "#2e2e2e"
$contextMenu.ForeColor = "white"
$contextMenu.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$contextMenu.ShowImageMargin = $false
$contextMenu.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::System

$openExplorer = New-Object System.Windows.Forms.ToolStripMenuItem
$openExplorer.Text = "Open in Explorer"
$deleteItem = New-Object System.Windows.Forms.ToolStripMenuItem
$deleteItem.Text = "Delete"
$contextMenu.Items.AddRange(@($openExplorer,$deleteItem))
$restoreList.ContextMenuStrip = $contextMenu

$restoreList.Add_MouseDown({
    param($sender,$e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
        $index = $sender.IndexFromPoint($e.Location)
        if ($index -ne -1 -and -not $sender.SelectedIndices.Contains($index)) {
            $sender.ClearSelected()
            $sender.SetSelected($index,$true)
        }
        # Keep multi-selection intact
        $openExplorer.Visible = ($sender.SelectedItems.Count -eq 1)
    }
})

# --------------------------- Open/Delete ---------------------------
$openExplorer.Add_Click({
    $selected = $restoreList.SelectedItem
    if ($restoreMap.ContainsKey($selected)) {
        Start-Process explorer.exe "/select,`"$($restoreMap[$selected])`""
    }
})

Add-Type -AssemblyName Microsoft.VisualBasic
$deleteItem.Add_Click({
    $itemsToDelete = @($restoreList.SelectedItems)
    foreach ($item in $itemsToDelete) {
        if ($restoreMap.ContainsKey($item)) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $restoreMap[$item],
                'OnlyErrorDialogs',
                'SendToRecycleBin'
            )
        }
    }
    Load-RestoreList
})

# --------------------------- Restore Map ---------------------------
$restoreMap = @{}

# --------------------------- Load Backups ---------------------------
function Load-RestoreList {
    $restoreList.Items.Clear()
    $restoreMap.Clear()
    $allZips = @()

    if (Test-Path $global:backupDir) {
        $manual = Get-ChildItem $global:backupDir -Filter "*.zip" -ErrorAction SilentlyContinue
        foreach ($z in $manual) { $z | Add-Member NoteProperty Type "Manual" }
        $allZips += $manual
    }

    $autoDir = "$global:backupDir\QbitAutoBackup"
    if (Test-Path $autoDir) {
        $auto = Get-ChildItem $autoDir -Filter "*.zip" -ErrorAction SilentlyContinue
        foreach ($z in $auto) { $z | Add-Member NoteProperty Type "Auto" }
        $allZips += $auto
    }

    $allZips = $allZips | Sort-Object LastWriteTime -Descending

    foreach ($zip in $allZips) {
        $torrentCount = "?"
        if ($zip.Name -match "(\d+)torrents") { $torrentCount = $matches[1] }
        $date = $zip.LastWriteTime.ToString("dd MMM yyyy")
        $day  = $zip.LastWriteTime.ToString("ddd")
        $time = $zip.LastWriteTime.ToString("hh:mm tt")
        $typeText = if ($zip.Type -eq "Auto") { "Auto Backup" } else { "Manual Backup" }
        $display = "{0,-15} {1,-13} {2,-5} {3,-10} {4} Torrents" -f $typeText, $date, $day, $time, $torrentCount
        $restoreList.Items.Add($display)
        $restoreMap[$display] = $zip.FullName
    }
}

# --------------------------- FileSystemWatcher ---------------------------
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $global:backupDir
$watcher.Filter = "*.zip"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$watcher.NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'

$action = { Load-RestoreList }
Register-ObjectEvent $watcher Created -Action $action
Register-ObjectEvent $watcher Deleted -Action $action
Register-ObjectEvent $watcher Renamed -Action $action

# --------------------------- Load Initial List ---------------------------
Load-RestoreList



# --------------------------- Restore Button ---------------------------
$restoreBtn = New-Object Windows.Forms.Button
$restoreBtn.Text = "Restore Backup"
$restoreBtn.Size = New-Object Drawing.Size(480,40)
$restoreBtn.Location = New-Object Drawing.Point(20,340)
$restoreBtn.BackColor = "#008a39"
$restoreBtn.ForeColor = "white"
$restoreBtn.Font = $font
$restoreBtn.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor `
                      [System.Windows.Forms.AnchorStyles]::Left -bor `
                      [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($restoreBtn)

# Restore Click
$restoreBtn.Add_Click({
    if ($restoreList.SelectedItem -eq $null) {
        Show-PopupMessage "PLEASE SELECT A BACKUP"
        return
    }

    $display = $restoreList.SelectedItem
    if (-not $restoreMap.ContainsKey($display)) {
        Show-PopupMessage "BACKUP FILE NOT FOUND"
        return
    }

    $zipFile = $restoreMap[$display]

    # --------------------------- Confirmation Popup ---------------------------
    $confirmForm = New-Object Windows.Forms.Form
    $confirmForm.Size = New-Object Drawing.Size(400,180)
    $confirmForm.StartPosition = "CenterParent"
    $confirmForm.Text = "Data Restore Confirmation"
    $confirmForm.FormBorderStyle = 'FixedDialog'
    $confirmForm.MaximizeBox = $false
    $confirmForm.MinimizeBox = $false
    $confirmForm.BackColor = "#1e1e1e"

    # Label
    $label = New-Object Windows.Forms.Label
    $label.Text = "Are you sure you want to restore`n'$display'?"
    $label.AutoSize = $true
    $label.ForeColor = "white"
    $label.font = New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $label.Location = New-Object Drawing.Point(20,20)
    $confirmForm.Controls.Add($label)

    # Yes Button
    $yesBtn = New-Object Windows.Forms.Button
    $yesBtn.Text = "Yes"
    $yesBtn.Size = New-Object Drawing.Size(120,40)
    $yesBtn.Location = New-Object Drawing.Point(50,70)
    $yesBtn.BackColor = "#008a39"
    $yesBtn.ForeColor = "white"
    $yesBtn.Font = $font
    $confirmForm.Controls.Add($yesBtn)

    # Cancel Button
    $cancelBtn = New-Object Windows.Forms.Button
    $cancelBtn.Text = "Cancel"
    $cancelBtn.Size = New-Object Drawing.Size(120,40)
    $cancelBtn.Location = New-Object Drawing.Point(220,70)
    $cancelBtn.BackColor = "#b22222"
    $cancelBtn.ForeColor = "white"
    $cancelBtn.Font = $font
    $confirmForm.Controls.Add($cancelBtn)

    $yesBtn.Add_Click({
        $confirmForm.Close()

        # Close qBittorrent
        $qbProcess = Get-Process -Name "qbittorrent" -ErrorAction SilentlyContinue
        if ($qbProcess) {
            $progress.Value = 5
            foreach ($p in $qbProcess) {
                try {
                    $p.CloseMainWindow() | Out-Null
                    Start-Sleep -Milliseconds 800
                    if (!$p.HasExited) { Stop-Process -Id $p.Id -Force }
                } catch { }
            }
            Start-Sleep -Seconds 2
        }

        # Restore backup
        $progress.Value = 10
        $temp = "$env:TEMP\qb_restore"
        Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $temp | Out-Null

        $progress.Value = 30
        Expand-Archive -Path $zipFile -DestinationPath $temp -Force

        $restoreRoot = $temp
        if (!(Test-Path "$temp\Local")) {
            $folder = Get-ChildItem $temp -Directory | Select-Object -First 1
            if ($folder) { $restoreRoot = $folder.FullName }
        }

        $progress.Value = 50
        $localTarget = "$env:LOCALAPPDATA\qBittorrent"
        $roamingTarget = "$env:APPDATA\qBittorrent"
        Remove-Item $localTarget -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $roamingTarget -Recurse -Force -ErrorAction SilentlyContinue
        New-Item $localTarget -ItemType Directory -Force | Out-Null
        New-Item $roamingTarget -ItemType Directory -Force | Out-Null

        Copy-Item "$restoreRoot\Local\*" $localTarget -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item "$restoreRoot\Roaming\*" $roamingTarget -Recurse -Force -ErrorAction SilentlyContinue

        Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue

        $progress.Value = 100
        Show-PopupMessage "RESTORE SUCCESSFUL"

        # Relaunch qBittorrent
        $qbExe = "$env:ProgramFiles\qBittorrent\qbittorrent.exe"
        if (-Not (Test-Path $qbExe)) { $qbExe = "$env:ProgramFiles(x86)\qBittorrent\qbittorrent.exe" }
        if (Test-Path $qbExe) { Start-Process $qbExe }
        $progress.Value = 0
    })

    $cancelBtn.Add_Click({ $confirmForm.Close() })
    $confirmForm.TopMost = $true
    $confirmForm.ShowDialog()
})

# --------------------------- Wipe Data ---------------------------
$wipeBtn = New-Object Windows.Forms.Button
$wipeBtn.Text = "Wipe Data"
$wipeBtn.Size = New-Object Drawing.Size(480,40)
$wipeBtn.Location = New-Object Drawing.Point(20,400)
$wipeBtn.BackColor = "#b22222"
$wipeBtn.ForeColor = "white"
$wipeBtn.Font = $font
$wipeBtn.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor `
                   [System.Windows.Forms.AnchorStyles]::Left -bor `
                   [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($wipeBtn)

$wipeBtn.Add_Click({

# --------------------------- Confirmation Popup ---------------------------
$confirmForm = New-Object Windows.Forms.Form
$confirmForm.Size = New-Object Drawing.Size(400,180)
$confirmForm.StartPosition = "CenterParent"
$confirmForm.Text = "Confirm Wipe Data"
$confirmForm.FormBorderStyle = 'FixedDialog'   # Fixed size, user cannot resize
$confirmForm.MaximizeBox = $false              # No maximize
$confirmForm.MinimizeBox = $false              # No minimize
$confirmForm.BackColor = "#1e1e1e"            # Hex background color

# Label
$label = New-Object Windows.Forms.Label
$label.Text = "This will permanently delete all qBittorrent data.`nAre you sure?"
$label.AutoSize = $true
$label.ForeColor = "white"                    # Optional: make text visible on dark bg
$label.font = New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
$label.Location = New-Object Drawing.Point(20,20)
$confirmForm.Controls.Add($label)


    # Yes Button
    $yesBtn = New-Object Windows.Forms.Button
    $yesBtn.Text = "Yes"
    $yesBtn.Size = New-Object Drawing.Size(120,40)
    $yesBtn.Location = New-Object Drawing.Point(50,70)
    $yesBtn.BackColor = "#b22222"
    $yesBtn.ForeColor = "white"
    $yesBtn.Font = $font
    $confirmForm.Controls.Add($yesBtn)

    # Cancel Button
    $cancelBtn = New-Object Windows.Forms.Button
    $cancelBtn.Text = "Cancel"
    $cancelBtn.Size = New-Object Drawing.Size(120,40)
    $cancelBtn.Location = New-Object Drawing.Point(220,70)
    $cancelBtn.BackColor = "#008a39"
    $cancelBtn.ForeColor = "white"
    $cancelBtn.Font = $font
    $confirmForm.Controls.Add($cancelBtn)

    # --------------------------- Button Click Actions ---------------------------
    $yesBtn.Add_Click({
        $confirmForm.Close()

        # --------------------------- Close qBittorrent ---------------------------
        Get-Process qbittorrent -ErrorAction SilentlyContinue | Stop-Process -Force

        # --------------------------- Delete Data ---------------------------
        Remove-Item "$env:LOCALAPPDATA\qBittorrent" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:APPDATA\qBittorrent" -Recurse -Force -ErrorAction SilentlyContinue

        Show-PopupMessage "WIPE DATA SUCCESSFUL"
        Load-RestoreList

        # --------------------------- Relaunch qBittorrent ---------------------------
        $qbExe = "$env:ProgramFiles\qBittorrent\qbittorrent.exe"
        if (-Not (Test-Path $qbExe)) {
            $qbExe = "$env:ProgramFiles(x86)\qBittorrent\qbittorrent.exe"
        }
        if (Test-Path $qbExe) {
            Start-Process $qbExe
        }

        $progress.Value = 0
    })

    $cancelBtn.Add_Click({ $confirmForm.Close() })

    $confirmForm.TopMost = $true
    $confirmForm.ShowDialog()
})

# --------------------------- Auto Backup Enable/Disable ---------------------------
$enableAuto = New-Object Windows.Forms.Button
$enableAuto.Text = "Enable Auto Backup"
$enableAuto.Size = New-Object Drawing.Size(480,40)
$enableAuto.Location = New-Object Drawing.Point(20,460)
$enableAuto.BackColor = "#333333"
$enableAuto.ForeColor = "white"
$enableAuto.Font = $font
$enableAuto.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($enableAuto)

$disableAuto = New-Object Windows.Forms.Button
$disableAuto.Text = "Disable Auto Backup"
$disableAuto.Size = New-Object Drawing.Size(480,40)
$disableAuto.Location = New-Object Drawing.Point(20,510)
$disableAuto.BackColor = "#333333"
$disableAuto.ForeColor = "white"
$disableAuto.Font = $font
$disableAuto.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($disableAuto)


# Auto Backup Enable
$enableAuto.Add_Click({

    # --------------------------- Auto Backup Popup ---------------------------
    $autoForm = New-Object Windows.Forms.Form
    $autoForm.Size = New-Object Drawing.Size(520,440)
    $autoForm.StartPosition = "CenterParent"
    $autoForm.Text = "Auto Backup Settings"
    $autoForm.FormBorderStyle = 'FixedDialog'
    $autoForm.MaximizeBox = $false
    $autoForm.MinimizeBox = $false
    $autoForm.BackColor = "#1E1E1E"

    $script:selectedFrequency = $null
    $script:selectedRetention = $null

    $defaultBtnColor = "#3A3A3A"
    $selectedBtnColor = "#22AA22"
    $confirmDisabled = "#555555"
    $confirmEnabled = "#22AA22"

    $boxWidth = 200
    $boxHeight = 40
    $boxStartX = 30
    $boxStartY = 200
    $boxGapX = 230
    $boxGapY = 60

    # --------------------------- Folder Label ---------------------------
    $folderLabel = New-Object Windows.Forms.Label
    $folderLabel.Text = "Backup Folder:`n$global:backupDir\QbitAutoBackup"
    $folderLabel.Size = New-Object Drawing.Size(460,40)
    $folderLabel.ForeColor = "#FFFFFF"
    $folderLabel.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    $folderLabel.Location = New-Object Drawing.Point(20,10)
    $autoForm.Controls.Add($folderLabel)

    # --------------------------- Step 1 ---------------------------
    $labelFreq = New-Object Windows.Forms.Label
    $labelFreq.Text = "Step 1: Select backup frequency:"
    $labelFreq.AutoSize = $true
    $labelFreq.ForeColor = "#FFFFFF"
    $labelFreq.Font = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
    $labelFreq.Location = New-Object Drawing.Point(20,60)
    $autoForm.Controls.Add($labelFreq)

    $daily = New-Object Windows.Forms.RadioButton
    $daily.Text = "Daily Backup"
    $daily.Size = New-Object Drawing.Size(200,25)
    $daily.Location = New-Object Drawing.Point(40,90)
    $daily.ForeColor = "#FFFFFF"
    $daily.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    $autoForm.Controls.Add($daily)

    $weekly = New-Object Windows.Forms.RadioButton
    $weekly.Text = "Weekly Backup (Every Sunday)"
    $weekly.Size = New-Object Drawing.Size(300,25)
    $weekly.Location = New-Object Drawing.Point(40,120)
    $weekly.ForeColor = "#FFFFFF"
    $weekly.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    $autoForm.Controls.Add($weekly)

    # --------------------------- Step 2 ---------------------------
    $labelRet = New-Object Windows.Forms.Label
    $labelRet.Text = "Step 2: Choose how many days of backups to keep:"
    $labelRet.AutoSize = $true
    $labelRet.ForeColor = "#FFFFFF"
    $labelRet.Font = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
    $labelRet.Location = New-Object Drawing.Point(20,170)
    $autoForm.Controls.Add($labelRet)

    # --------------------------- Retention Buttons ---------------------------
    $retentionBtns = @()
    $days = @(7,15,30,"All")
    for ($i=0; $i -lt 4; $i++) {
        $btn = New-Object Windows.Forms.Button
        if ($days[$i] -is [int]) {
            $btn.Text = "Delete older than $($days[$i]) days"
        } else {
            $btn.Text = "Keep All Backups"
        }
        $btn.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
        $x = $boxStartX + (($i % 2) * $boxGapX)
        $y = $boxStartY + ([math]::Floor($i/2) * $boxGapY)
        $btn.Size = New-Object Drawing.Size($boxWidth,$boxHeight)
        $btn.Location = New-Object Drawing.Point($x,$y)
        $btn.BackColor = $defaultBtnColor
        $btn.ForeColor = "#FFFFFF"
        $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderSize = 1
        $retentionBtns += $btn
        $autoForm.Controls.Add($btn)

        $btn.Add_Click({
            $script:selectedRetention = $this.Text
            foreach ($b in $retentionBtns) { $b.BackColor = $defaultBtnColor }
            $this.BackColor = $selectedBtnColor
            UpdateConfirmState
        })
    }

    # --------------------------- Confirm / Cancel Buttons ---------------------------
    $yesBtn = New-Object Windows.Forms.Button
    $yesBtn.Text = "Confirm"
    $yesBtn.Size = New-Object Drawing.Size(140,40)
    $yesBtn.Location = New-Object Drawing.Point(70,340)
    $yesBtn.BackColor = $confirmDisabled
    $yesBtn.ForeColor = "#FFFFFF"
    $yesBtn.Enabled = $false
    $yesBtn.FlatStyle = "Flat"
    $yesBtn.Font = $font
    $autoForm.Controls.Add($yesBtn)

    $cancelBtn = New-Object Windows.Forms.Button
    $cancelBtn.Text = "Cancel"
    $cancelBtn.Size = New-Object Drawing.Size(140,40)
    $cancelBtn.Location = New-Object Drawing.Point(250,340)
    $cancelBtn.BackColor = "#B22222"
    $cancelBtn.ForeColor = "#FFFFFF"
    $cancelBtn.FlatStyle = "Flat"
    $cancelBtn.Add_Click({ $autoForm.Close() })
    $cancelBtn.Font = $font
    $autoForm.Controls.Add($cancelBtn)

    function UpdateConfirmState {
        if (($script:selectedFrequency) -and ($script:selectedRetention)) {
            $yesBtn.Enabled = $true
            $yesBtn.BackColor = $confirmEnabled
        } else {
            $yesBtn.Enabled = $false
            $yesBtn.BackColor = $confirmDisabled
        }
    }

    # --------------------------- Frequency Selection ---------------------------
    $daily.Add_CheckedChanged({
        if ($daily.Checked) {
            $script:selectedFrequency = "Daily"
            $daily.ForeColor = "#22AA22"
            $weekly.ForeColor = "#FFFFFF"
        }
        UpdateConfirmState
    })
    $weekly.Add_CheckedChanged({
        if ($weekly.Checked) {
            $script:selectedFrequency = "Weekly"
            $weekly.ForeColor = "#22AA22"
            $daily.ForeColor = "#FFFFFF"
        }
        UpdateConfirmState
    })

# --------------------------- Auto/Weekly Backup Script ---------------------------

# --------------------------- Daily Confirm Action ---------------------------
$yesBtn.Add_Click({

    # --------------------------- Determine Days to Keep ---------------------------
    switch ($script:selectedRetention) {
        "Delete older than 7 days" { $daysKeep = 7 }
        "Delete older than 15 days" { $daysKeep = 15 }
        "Delete older than 30 days" { $daysKeep = 30 }
        "Keep All Backups" { $daysKeep = 0 }
    }

    # --------------------------- Create backup folder ---------------------------
    $backupFolder = Join-Path $global:backupDir "QbitAutoBackup"
    if (!(Test-Path $backupFolder)) { New-Item -ItemType Directory -Path $backupFolder | Out-Null }

    # --------------------------- Generate Daily PS1 ---------------------------
$ps1Content = @'
# --------------------------- CONFIG ---------------------------
$backupFolder = "{BACKUPFOLDER}"
$local        = "$env:LOCALAPPDATA\qBittorrent"
$roaming      = "$env:APPDATA\qBittorrent"
$DaysToKeep   = {DAYSTOKEEP}

# --------------------------- CREATE BACKUP FOLDER ---------------------------
if (!(Test-Path $backupFolder)) { New-Item -ItemType Directory -Path $backupFolder | Out-Null }

# --------------------------- DELETE OLD BACKUPS ---------------------------
if ($DaysToKeep -gt 0) {
    $limit = (Get-Date).AddDays(-$DaysToKeep)
    Get-ChildItem $backupFolder -Filter "*.zip" -File | ForEach-Object {
        if ($_.LastWriteTime -lt $limit) { Remove-Item $_.FullName -Force }
    }
}

# --------------------------- SKIP IF TODAY BACKUP EXISTS ---------------------------
$today = Get-Date -Format "yyyy-MM-dd"
if (Get-ChildItem $backupFolder -Filter "qbittorrent_backup_*_$today*.zip") { exit }

# --------------------------- Torrent Count ---------------------------
$torrentCount = 0
$btBackup = "$local\BT_backup"
if (Test-Path $btBackup) { $torrentCount = (Get-ChildItem $btBackup -Filter "*.fastresume").Count }

# --------------------------- PREPARE TEMP ---------------------------
$date = Get-Date -Format "yyyy-MM-dd_HH-mm"
$temp = "$env:TEMP\qb_backup"
Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $temp | Out-Null
New-Item "$temp\Local" -ItemType Directory -Force | Out-Null
New-Item "$temp\Roaming" -ItemType Directory -Force | Out-Null

# --------------------------- COPY DATA ---------------------------
if (Test-Path $local) { Copy-Item "$local\*" "$temp\Local" -Recurse -Force }
if (Test-Path $roaming) { Copy-Item "$roaming\*" "$temp\Roaming" -Recurse -Force }

# --------------------------- CREATE ZIP ---------------------------
$zipFile = "$backupFolder\qbittorrent_backup_${torrentCount}torrents_$date.zip"
Compress-Archive -Path "$temp\*" -DestinationPath $zipFile -Force

# --------------------------- CLEAN TEMP ---------------------------
Remove-Item $temp -Recurse -Force

Write-Output "Backup created: $zipFile"
'@

# Replace placeholders
$ps1Content = $ps1Content.Replace("{BACKUPFOLDER}", $backupFolder).Replace("{DAYSTOKEEP}", $daysKeep)

# --------------------------- Save PS1 ---------------------------
$ps1Path = Join-Path $backupFolder "QbitAutoBackup.script.ps1"
Set-Content -Path $ps1Path -Value $ps1Content -Force
(Get-Item $ps1Path).Attributes += 'Hidden'

# --------------------------- Create BAT ---------------------------
$batContent = "@echo off`r`nPowerShell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ps1Path`""
$batPath = Join-Path $backupFolder "QbitAutoBackup.script.bat"
Set-Content -Path $batPath -Value $batContent -Force
(Get-Item $batPath).Attributes += 'Hidden'

# --------------------------- Scheduled Task ---------------------------
if ($script:selectedFrequency -eq "Daily") {
    $taskName = "QBT Daily Backup"
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    Show-PopupMessage "QBT DAILY BACKUP ENABLED"
} else {
    $taskName = "QBT Weekly Backup"
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    Show-PopupMessage "QBT WEEKLY BACKUP ENABLED"
}

$action = New-ScheduledTaskAction -Execute $batPath
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Force

$autoForm.Close()
})

$autoForm.ShowDialog() | Out-Null

# --------------------------- Weekly Confirm Action ---------------------------
if ($script:selectedFrequency -eq "Weekly") {

    $backupFolder = "C:\Users\user\Desktop\FG\QbitAutoBackup"
    if (!(Test-Path $backupFolder)) { New-Item -ItemType Directory -Path $backupFolder | Out-Null }

    switch ($script:selectedRetention) {
        "Delete older than 7 days" { $daysKeep = 7 }
        "Delete older than 15 days" { $daysKeep = 15 }
        "Delete older than 30 days" { $daysKeep = 30 }
        "Keep All Backups" { $daysKeep = 0 }
    }

$ps1Content = @'
# --------------------------- RUN ONLY ON SUNDAY ---------------------------
if ((Get-Date).DayOfWeek -ne "Sunday") { exit }

# --------------------------- CONFIG ---------------------------
$backupFolder = "{BACKUPFOLDER}"
$local        = "$env:LOCALAPPDATA\qBittorrent"
$roaming      = "$env:APPDATA\qBittorrent"
$DaysToKeep   = {DAYSTOKEEP}

# --------------------------- CREATE BACKUP FOLDER ---------------------------
if (!(Test-Path $backupFolder)) { New-Item -ItemType Directory -Path $backupFolder | Out-Null }

# --------------------------- DELETE OLD BACKUPS ---------------------------
if ($DaysToKeep -gt 0) {
    $limit = (Get-Date).AddDays(-$DaysToKeep)
    Get-ChildItem $backupFolder -Filter "*.zip" -File | ForEach-Object {
        if ($_.LastWriteTime -lt $limit) { Remove-Item $_.FullName -Force }
    }
}

# --------------------------- SKIP IF TODAY BACKUP EXISTS ---------------------------
$today = Get-Date -Format "yyyy-MM-dd"
if (Get-ChildItem $backupFolder -Filter "qbittorrent_backup_*_$today*.zip") { exit }

# --------------------------- Torrent Count ---------------------------
$torrentCount = 0
$btBackup = "$local\BT_backup"
if (Test-Path $btBackup) { $torrentCount = (Get-ChildItem $btBackup -Filter "*.fastresume").Count }

# --------------------------- PREPARE TEMP ---------------------------
$date = Get-Date -Format "yyyy-MM-dd_HH-mm"
$temp = "$env:TEMP\qb_backup"
Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $temp | Out-Null
New-Item "$temp\Local" -ItemType Directory -Force | Out-Null
New-Item "$temp\Roaming" -ItemType Directory -Force | Out-Null

# --------------------------- COPY DATA ---------------------------
if (Test-Path $local) { Copy-Item "$local\*" "$temp\Local" -Recurse -Force }
if (Test-Path $roaming) { Copy-Item "$roaming\*" "$temp\Roaming" -Recurse -Force }

# --------------------------- CREATE ZIP ---------------------------
$zipFile = "$backupFolder\qbittorrent_backup_${torrentCount}torrents_$date.zip"
Compress-Archive -Path "$temp\*" -DestinationPath $zipFile -Force

# --------------------------- CLEAN TEMP ---------------------------
Remove-Item $temp -Recurse -Force

Write-Output "Backup created: $zipFile"
'@

# Replace placeholders
$ps1Content = $ps1Content.Replace("{BACKUPFOLDER}", $backupFolder).Replace("{DAYSTOKEEP}", $daysKeep)

# Save PS1
$ps1Path = Join-Path $backupFolder "QbitAutoBackup.script.ps1"
Set-Content -Path $ps1Path -Value $ps1Content -Force
(Get-Item $ps1Path).Attributes += 'Hidden'

# Create BAT
$batContent = "@echo off`r`nPowerShell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ps1Path`""
$batPath = Join-Path $backupFolder "QbitAutoBackup.script.bat"
Set-Content -Path $batPath -Value $batContent -Force
(Get-Item $batPath).Attributes += 'Hidden'

# Scheduled Task
$taskName = "QBT Weekly Backup"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$action = New-ScheduledTaskAction -Execute $batPath
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Force

}

})


# --------------------------- Auto Backup Disable ---------------------------
$disableAuto.Add_Click({

    # --------------------------- Confirmation Popup ---------------------------
    $confirmForm = New-Object Windows.Forms.Form
    $confirmForm.Size = New-Object Drawing.Size(400,200)
    $confirmForm.StartPosition = "CenterParent"
    $confirmForm.Text = "Confirm Disable Auto Backup"
    $confirmForm.FormBorderStyle = 'FixedDialog'
    $confirmForm.MaximizeBox = $false
    $confirmForm.MinimizeBox = $false
    $confirmForm.BackColor = "#1e1e1e"

    # Label
    $label = New-Object Windows.Forms.Label
    $label.Text = "Do you want to disable auto backup?"
    $label.AutoSize = $true
    $label.ForeColor = "white"
    $label.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    $label.Location = New-Object Drawing.Point(20,20)
    $confirmForm.Controls.Add($label)

    # Checkbox
    $chkDeleteFolder = New-Object Windows.Forms.CheckBox
    $chkDeleteFolder.Text = "Also delete Auto Backup folder and all Backup files"
    $chkDeleteFolder.AutoSize = $true
    $chkDeleteFolder.ForeColor = "white"
    $chkDeleteFolder.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    $chkDeleteFolder.Location = New-Object Drawing.Point(20,60)
    $confirmForm.Controls.Add($chkDeleteFolder)

    # Change color when checked/unchecked
    $chkDeleteFolder.Add_CheckedChanged({
        if ($chkDeleteFolder.Checked) {
            $chkDeleteFolder.ForeColor = "#ff5858"   # red
        } else {
            $chkDeleteFolder.ForeColor = "white"
        }
    })

    # Font for buttons
    $font = New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)

    # Disable Button
    $yesBtn = New-Object Windows.Forms.Button
    $yesBtn.Text = "Disable"
    $yesBtn.Size = New-Object Drawing.Size(120,40)
    $yesBtn.Location = New-Object Drawing.Point(50,110)
    $yesBtn.BackColor = "#b22222"
    $yesBtn.ForeColor = "white"
    $yesBtn.Font = $font
    $confirmForm.Controls.Add($yesBtn)

    # Cancel Button
    $cancelBtn = New-Object Windows.Forms.Button
    $cancelBtn.Text = "Cancel"
    $cancelBtn.Size = New-Object Drawing.Size(120,40)
    $cancelBtn.Location = New-Object Drawing.Point(220,110)
    $cancelBtn.BackColor = "#008a39"
    $cancelBtn.ForeColor = "white"
    $cancelBtn.Font = $font
    $confirmForm.Controls.Add($cancelBtn)

    # --------------------------- Button Actions ---------------------------
    $yesBtn.Add_Click({
        # Remove Scheduled Tasks
        Unregister-ScheduledTask -TaskName "QBT Daily Backup" -Confirm:$false -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName "QBT Weekly Backup" -Confirm:$false -ErrorAction SilentlyContinue

        # Delete Script Files
        $backupFolder = Join-Path $global:backupDir "QbitAutoBackup"
        $ps1Path = Join-Path $backupFolder "QbitAutoBackup.script.ps1"
        $batPath = Join-Path $backupFolder "QbitAutoBackup.script.bat"

        if (Test-Path $ps1Path) { Remove-Item $ps1Path -Force -ErrorAction SilentlyContinue }
        if (Test-Path $batPath) { Remove-Item $batPath -Force -ErrorAction SilentlyContinue }

        # Delete folder if checkbox checked
        if ($chkDeleteFolder.Checked -and (Test-Path $backupFolder)) {
            Remove-Item $backupFolder -Recurse -Force -ErrorAction SilentlyContinue
        }

        Show-PopupMessage "AUTO BACKUP DISABLED"
        $confirmForm.Close()
    })

    $cancelBtn.Add_Click({
        $confirmForm.Close()
    })

    # Show Form
    $confirmForm.ShowDialog()
})


# --------------------------- Show Form ---------------------------
$form.ShowDialog()