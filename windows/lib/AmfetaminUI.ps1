# amfetamin — modern UI (v2)
if (-not (Get-Command T -ErrorAction SilentlyContinue)) {
    . (Get-AmfetaminUtf8ScriptBlock (Join-Path $PSScriptRoot 'AmfetaminI18n.ps1'))
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Script:AmfetaminTheme = @{
    BgDeep      = [System.Drawing.Color]::FromArgb(8, 8, 14)
    BgPanel     = [System.Drawing.Color]::FromArgb(18, 18, 28)
    BgCard      = [System.Drawing.Color]::FromArgb(26, 26, 42)
    BgCardHover = [System.Drawing.Color]::FromArgb(34, 34, 54)
    Accent      = [System.Drawing.Color]::FromArgb(0, 230, 180)
    AccentGlow  = [System.Drawing.Color]::FromArgb(0, 180, 140)
    Purple      = [System.Drawing.Color]::FromArgb(130, 80, 255)
    Pink        = [System.Drawing.Color]::FromArgb(255, 80, 140)
    Text        = [System.Drawing.Color]::FromArgb(245, 245, 255)
    TextMuted   = [System.Drawing.Color]::FromArgb(130, 130, 155)
    Danger      = [System.Drawing.Color]::FromArgb(255, 70, 90)
    Warning     = [System.Drawing.Color]::FromArgb(255, 180, 50)
    Success     = [System.Drawing.Color]::FromArgb(50, 220, 130)
    Border      = [System.Drawing.Color]::FromArgb(45, 45, 70)
}

$Script:UiState = @{
    StatusTimer = $null
    LogTimer    = $null
    ToastTimer  = $null
    InstallInProgress = $false
    ToastBar    = $null
    TrayIcon    = $null
    MainForm    = $null
    Refs        = $null
    FormReady   = $false
    NavButtons  = @()
    ActivePage  = $null
}

function Set-UiControlVisible {
    param(
        $Control,
        [bool]$Visible
    )
    if (-not $Control) { return }
    try {
        if ($Control.PSObject.Properties['Visible']) {
            $Control.Visible = $Visible
        }
    } catch {}
}

function Get-AmfetaminToastBar {
    if ($Script:UiState.ToastBar) { return $Script:UiState.ToastBar }
    if ($Script:UiState.Refs -and $Script:UiState.Refs.Toast) { return $Script:UiState.Refs.Toast }
    return $null
}

function New-AmfetaminFont($size, $style = 'Regular') {
    $fs = [System.Drawing.FontStyle]::Regular
    if ($style -eq 'Bold') { $fs = [System.Drawing.FontStyle]::Bold }
    if ($style -eq 'Italic') { $fs = [System.Drawing.FontStyle]::Italic }
    if ($style -eq 'SemiBold') { $fs = [System.Drawing.FontStyle]::Bold }
    return New-Object System.Drawing.Font('Segoe UI', $size, $fs)
}

function Get-AmfetaminIcon {
    if ($Script:AmfetaminIcon) { return $Script:AmfetaminIcon }
    $launcher = Get-LauncherPath
    if (-not [string]::IsNullOrWhiteSpace($launcher) -and $launcher -like '*.exe' -and (Test-Path -LiteralPath $launcher)) {
        try {
            $Script:AmfetaminIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($launcher)
            if ($Script:AmfetaminIcon) { return $Script:AmfetaminIcon }
        } catch {}
    }
    $root = Get-ProjectRoot
    foreach ($name in @('amfetamin.ico', (Join-Path 'assets' 'amfetamin.ico'))) {
        $path = Join-Path $root $name
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)) {
            $Script:AmfetaminIcon = New-Object System.Drawing.Icon($path)
            return $Script:AmfetaminIcon
        }
    }
    return $null
}

function New-AmfetaminRoundedPanel {
    param(
        [System.Drawing.Color]$BackColor,
        [int]$Radius = 10
    )
    $p = New-Object System.Windows.Forms.Panel
    $p.BackColor = $BackColor
    if ($Radius -gt 0) {
        $p.Add_Paint({
            if ($args.Count -lt 2) { return }
            $snd = $args[0]; $ea = $args[1]
            $w = [Math]::Max(1, [int]$snd.ClientSize.Width - 1)
            $h = [Math]::Max(1, [int]$snd.ClientSize.Height - 1)
            $r = if ($snd.Tag -and $snd.Tag.Radius) { [int]$snd.Tag.Radius } else { 10 }
            $ea.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $path.AddArc(0, 0, ($r * 2), ($r * 2), 180, 90)
            $path.AddArc(($w - $r * 2), 0, ($r * 2), ($r * 2), 270, 90)
            $path.AddArc(($w - $r * 2), ($h - $r * 2), ($r * 2), ($r * 2), 0, 90)
            $path.AddArc(0, ($h - $r * 2), ($r * 2), ($r * 2), 90, 90)
            $path.CloseFigure()
            $ea.Graphics.FillPath((New-Object System.Drawing.SolidBrush($snd.BackColor)), $path)
            $path.Dispose()
        })
        $p.Tag = @{ Radius = $Radius }
    }
    return $p
}

function Update-AmfetaminDiscordPill {
    param(
        $PillDiscord,
        [bool]$EngineRunning,
        [System.Drawing.Color]$Ok,
        [System.Drawing.Color]$No,
        [System.Drawing.Color]$Mid,
        [System.Drawing.Color]$Muted,
        [System.Windows.Forms.Panel]$DashPage = $null
    )
    if (-not $PillDiscord) { return }
    if ($Script:UiState.InstallInProgress -or $Script:InstallInProgress) {
        $PillDiscord.Dot.ForeColor = $Muted
        $PillDiscord.Value.Text = (T 'status_testing')
        return
    }

    if (-not $EngineRunning) {
        $Script:DiscordOk = $null
        $PillDiscord.Dot.ForeColor = $Muted
        $PillDiscord.Value.Text = (T 'status_off')
        return
    }

    if ($DashPage -and $Script:UiState.ActivePage -ne $DashPage) {
        if ($Script:DiscordOk -eq $true) {
            $PillDiscord.Dot.ForeColor = $Ok
            $PillDiscord.Value.Text = (T 'status_ok')
        } elseif ($Script:DiscordOk -eq $false) {
            $PillDiscord.Dot.ForeColor = $No
            $PillDiscord.Value.Text = (T 'status_timeout')
        } else {
            $PillDiscord.Dot.ForeColor = $Muted
            $PillDiscord.Value.Text = (T 'status_off')
        }
        return
    }

    $now = Get-Date
    if (-not $Script:DiscordCheckAt -or ($now - $Script:DiscordCheckAt).TotalSeconds -gt 30) {
        $Script:DiscordCheckAt = $now
        $PillDiscord.Dot.ForeColor = $Mid
        $PillDiscord.Value.Text = (T 'status_testing')
        [System.Windows.Forms.Application]::DoEvents()
        try { $Script:DiscordOk = Test-BypassTargetReachable -TimeoutSec 3 } catch { $Script:DiscordOk = $false }
    }

    if ($Script:DiscordOk -eq $true) {
        $PillDiscord.Dot.ForeColor = $Ok
        $PillDiscord.Value.Text = (T 'status_ok')
    } elseif ($Script:DiscordOk -eq $false) {
        $PillDiscord.Dot.ForeColor = $No
        $PillDiscord.Value.Text = (T 'status_timeout')
    } else {
        $PillDiscord.Dot.ForeColor = $Mid
        $PillDiscord.Value.Text = (T 'status_testing')
    }
}

function Show-AmfetaminFormForeground {
    param([System.Windows.Forms.Form]$Form)
    if (-not $Form) { return }
    try {
        $Form.ShowInTaskbar = $true
        $Form.WindowState = 'Normal'
        $Form.Activate()
        $Form.BringToFront()
        try { $Form.Focus() } catch {}
        $Form.TopMost = $true
        $Form.TopMost = $false
    } catch {}
}

function Invoke-AmfetaminUiDeferred {
    param([scriptblock]$Action)
    $form = $Script:UiState.MainForm
    if (-not $form -or -not $form.IsHandleCreated) {
        & $Action
        return
    }
    try {
        [void]$form.BeginInvoke([action]$Action)
    } catch {
        & $Action
    }
}

function Show-AmfetaminModalDialog {
    param(
        [System.Windows.Forms.Form]$Dialog,
        [System.Windows.Forms.Form]$Owner
    )
    if (-not $Dialog) { return }
    try { $Dialog.Visible = $false } catch {}
    if ($Owner) {
        $Dialog.StartPosition = 'CenterParent'
        [void]$Dialog.ShowDialog($Owner)
    } else {
        [void]$Dialog.ShowDialog()
    }
}

function Select-AmfetaminNavPage {
    param([System.Windows.Forms.Button]$NavButton)
    if (-not $NavButton) { return }
    $theme = $Script:AmfetaminTheme
    foreach ($nb in $Script:UiState.NavButtons) {
        $nb.Tag.ActiveBg = $false
        $nb.BackColor = $nb.Tag.Normal
        $nb.ForeColor = $theme.TextMuted
        if ($nb.Tag.Page) { Set-UiControlVisible $nb.Tag.Page $false }
    }
    $NavButton.Tag.ActiveBg = $true
    $NavButton.BackColor = $NavButton.Tag.Active
    $NavButton.ForeColor = $NavButton.Tag.Accent
    if ($NavButton.Tag.Page) {
        Set-UiControlVisible $NavButton.Tag.Page $true
        $NavButton.Tag.Page.BringToFront()
        $Script:UiState.ActivePage = $NavButton.Tag.Page
    }
    if ($NavButton.Tag.OnSelect) { & $NavButton.Tag.OnSelect }
}

function New-NavButton {
    param(
        [string]$Text,
        [System.Drawing.Point]$Location,
        [System.Windows.Forms.Panel]$Sidebar,
        [System.Windows.Forms.Panel]$Page,
        [scriptblock]$OnSelect = $null
    )
    $t = $Script:AmfetaminTheme
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "  $Text"
    $btn.TextAlign = 'MiddleLeft'
    $btn.Size = New-Object System.Drawing.Size(168, 40)
    $btn.Location = $Location
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = $t.BgPanel
    $btn.ForeColor = $t.TextMuted
    $btn.Font = New-AmfetaminFont 9.5
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Tag = @{ Page = $Page; Normal = $t.BgPanel; Active = $t.BgCard; Accent = $t.Accent; OnSelect = $OnSelect }
    $btn.Add_MouseEnter({
        if ($this.Tag.ActiveBg) { return }
        try { $this.BackColor = $this.Tag.Active } catch {}
    })
    $btn.Add_MouseLeave({
        if ($this.Tag.ActiveBg) { return }
        try { $this.BackColor = $this.Tag.Normal } catch {}
    })
    $btn.Add_Click({ Select-AmfetaminNavPage -NavButton $this })
    $Sidebar.Controls.Add($btn)
    $Script:UiState.NavButtons += $btn
    return $btn
}

function Set-SafeControlColor {
    param(
        $Control,
        [System.Drawing.Color]$BackColor,
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::Empty
    )
    try { $Control.BackColor = $BackColor } catch {}
    if ($ForeColor -ne [System.Drawing.Color]::Empty) {
        try { $Control.ForeColor = $ForeColor } catch {}
    }
}

function New-AmfetaminButton {
    param(
        [string]$Text,
        [System.Drawing.Color]$Bg,
        [System.Drawing.Color]$HoverBg,
        [scriptblock]$OnClick,
        [System.Drawing.Size]$Size,
        [System.Drawing.Point]$Location
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Size = $Size
    $btn.Location = $Location
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = $Bg
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.Font = New-AmfetaminFont 9.5 'Bold'
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Tag = @{ Normal = $Bg; Hover = $HoverBg }
    $btn.Add_MouseEnter({
        $colors = $this.Tag
        if ($colors -and $colors.ContainsKey('Hover')) {
            try { $this.BackColor = $colors['Hover'] } catch {}
        }
    })
    $btn.Add_MouseLeave({
        $colors = $this.Tag
        if ($colors -and $colors.ContainsKey('Normal')) {
            try { $this.BackColor = $colors['Normal'] } catch {}
        }
    })
    if ($OnClick) { $btn.Add_Click($OnClick) }
    return $btn
}

function Set-AmfetaminTaskbarIdentity {
    try {
        if (-not ([System.Management.Automation.PSTypeName]'AmfetaminAppId').Type) {
            Add-Type @'
using System.Runtime.InteropServices;
public static class AmfetaminAppId {
    [DllImport("shell32.dll")]
    public static extern int SetCurrentProcessExplicitAppUserModelID(
        [MarshalAs(System.Runtime.UnmanagedType.LPWStr)] string appId);
}
'@
        }
        [AmfetaminAppId]::SetCurrentProcessExplicitAppUserModelID('furkandvrc.amfetamin') | Out-Null
    } catch {}
}

function Install-AmfetaminUiExceptionHandler {
    [System.Windows.Forms.Application]::add_ThreadException({
        param($sender, $threadArgs)
        try {
            Write-AmfetaminError -Message 'UI thread hatasi' -Exception $threadArgs.Exception
            [void][System.Windows.Forms.MessageBox]::Show(
                $threadArgs.Exception.Message, (T 'app_name'), 'OK', 'Error')
        } catch {}
    })
}

function New-StatusPill {
    param(
        [System.Windows.Forms.Control]$Parent,
        [string]$Title,
        [System.Drawing.Point]$Location,
        [int]$Width = 130
    )
    $t = $Script:AmfetaminTheme
    $card = New-AmfetaminRoundedPanel -BackColor $t.BgCard
    $card.Size = New-Object System.Drawing.Size($Width, 72)
    $card.Location = $Location
    $Parent.Controls.Add($card)

    $dot = New-Object System.Windows.Forms.Label
    $dot.Size = New-Object System.Drawing.Size(14, 14)
    $dot.Location = New-Object System.Drawing.Point(12, 14)
    $dot.Text = [char]0x25CF
    $dot.Font = New-AmfetaminFont 10
    $dot.ForeColor = $t.TextMuted
    Set-SafeControlColor $dot $t.BgCard
    $card.Controls.Add($dot)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Title
    $lbl.Font = New-AmfetaminFont 8.5
    $lbl.ForeColor = $t.TextMuted
    Set-SafeControlColor $lbl $t.BgCard
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(12, 34)
    $card.Controls.Add($lbl)

    $val = New-Object System.Windows.Forms.Label
    $val.Text = '-'
    $val.Font = New-AmfetaminFont 10 'Bold'
    $val.ForeColor = $t.Text
    Set-SafeControlColor $val $t.BgCard
    $val.AutoSize = $true
    $val.Location = New-Object System.Drawing.Point(12, 50)
    $card.Controls.Add($val)

    return [PSCustomObject]@{ Card = $card; Dot = $dot; Value = $val }
}

function Show-AmfetaminToast {
    param(
        [System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.Label]$Bar,
        [string]$Message,
        [System.Drawing.Color]$Color
    )
    if (-not $Bar) { $Bar = Get-AmfetaminToastBar }
    if (-not $Bar) { return }
    $Script:UiState.ToastBar = $Bar
    $Bar.Text = $Message
    $Bar.ForeColor = $Color
    Set-UiControlVisible $Bar $true
    if ($Script:UiState.ToastTimer) {
        try { $Script:UiState.ToastTimer.Stop(); $Script:UiState.ToastTimer.Dispose() } catch {}
    }
    $Script:UiState.ToastTimer = New-Object System.Windows.Forms.Timer
    $Script:UiState.ToastTimer.Interval = 5000
    $Script:UiState.ToastTimer.Add_Tick({
        Set-UiControlVisible $Script:UiState.ToastBar $false
        if ($Script:UiState.ToastTimer) { $Script:UiState.ToastTimer.Stop() }
    })
    $Script:UiState.ToastTimer.Start()
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-AmfetaminSplash {
    Initialize-AmfetaminI18n
    Set-AmfetaminTaskbarIdentity
    $t = $Script:AmfetaminTheme
    $splash = New-Object System.Windows.Forms.Form
    $splash.FormBorderStyle = 'None'
    $splash.Size = New-Object System.Drawing.Size(580, 380)
    $splash.StartPosition = 'CenterScreen'
    $splash.BackColor = $t.BgDeep
    $splash.TopMost = $true
    $splash.Opacity = 0
    $icon = Get-AmfetaminIcon
    if ($icon) { $splash.Icon = $icon }

    $grad = New-Object System.Windows.Forms.Panel
    $grad.Dock = 'Fill'
    $grad.BackColor = $t.BgDeep
    $splash.Controls.Add($grad)

    $accent = New-Object System.Windows.Forms.Panel
    $accent.Size = New-Object System.Drawing.Size(580, 3)
    $accent.BackColor = $t.Accent
    $accent.Dock = 'Top'
    $splash.Controls.Add($accent)
    $accent.BringToFront()

    $title = New-Object System.Windows.Forms.Label
    $title.Text = (T 'app_name')
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 48, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = $t.Accent
    Set-SafeControlColor $title $t.BgDeep
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(48, 80)
    $grad.Controls.Add($title)

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = (T 'splash_subtitle')
    $sub.Font = New-AmfetaminFont 11
    $sub.ForeColor = $t.TextMuted
    Set-SafeControlColor $sub $t.BgDeep
    $sub.AutoSize = $true
    $sub.Location = New-Object System.Drawing.Point(52, 158)
    $grad.Controls.Add($sub)

    $progress = New-Object System.Windows.Forms.ProgressBar
    $progress.Style = 'Continuous'
    $progress.Size = New-Object System.Drawing.Size(484, 6)
    $progress.Location = New-Object System.Drawing.Point(48, 230)
    $progress.Maximum = 100
    $progress.ForeColor = $t.Accent
    $grad.Controls.Add($progress)

    $status = New-Object System.Windows.Forms.Label
    $status.Text = (T 'splash_starting')
    $status.Font = New-AmfetaminFont 9.5
    $status.ForeColor = $t.Text
    Set-SafeControlColor $status $t.BgDeep
    $status.AutoSize = $true
    $status.Location = New-Object System.Drawing.Point(48, 248)
    $grad.Controls.Add($status)

    $credit = New-Object System.Windows.Forms.Label
    $credit.Text = 'by furkandvrc'
    $credit.Font = New-AmfetaminFont 10 'Italic'
    $credit.ForeColor = $t.Purple
    Set-SafeControlColor $credit $t.BgDeep
    $credit.AutoSize = $true
    $credit.Location = New-Object System.Drawing.Point(48, 320)
    $grad.Controls.Add($credit)

    try { $ver = (Get-Config).version } catch { $ver = '2.0.0' }
    $version = New-Object System.Windows.Forms.Label
    $version.Text = "v$ver"
    $version.Font = New-AmfetaminFont 9
    $version.ForeColor = $t.TextMuted
    Set-SafeControlColor $version $t.BgDeep
    $version.AutoSize = $true
    $version.Location = New-Object System.Drawing.Point(480, 324)
    $grad.Controls.Add($version)

    Write-AmfetaminLog -Message 'Splash ekrani acildi' -Level DEBUG

    $steps = @(
        @{ pct = 12; msg = (T 'splash_step_logging') },
        @{ pct = 28; msg = (T 'splash_step_privileges') },
        @{ pct = 45; msg = (T 'splash_step_npcap') },
        @{ pct = 62; msg = (T 'splash_step_status') },
        @{ pct = 80; msg = (T 'splash_step_ui') },
        @{ pct = 100; msg = (T 'splash_ready') }
    )

    $splash.Add_Shown({
        for ($o = 0.1; $o -le 1; $o += 0.12) {
            $splash.Opacity = $o
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 18
        }
        foreach ($s in $steps) {
            $progress.Value = $s.pct
            $status.Text = $s.msg
            if ($s.pct -eq 62) {
                try {
                    $engineSt = if (Test-AmfetaminRunning) { (T 'status_engine_active') } else { (T 'status_engine_off') }
                    $npcapSt = if (Test-NpcapInstalled) { (T 'status_ok') } else { (T 'status_missing') }
                    $status.Text = (T 'splash_engine_status' $engineSt, $npcapSt)
                } catch {}
            }
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }
        for ($o = 1; $o -ge 0; $o -= 0.15) {
            $splash.Opacity = [Math]::Max(0, $o)
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 12
        }
        $splash.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $splash.Close()
    })

    $splash.Add_FormClosed({
        try { $splash.Dispose() } catch {}
    })

    try { $splash.Visible = $false } catch {}
    [void]$splash.ShowDialog()
}

function Update-AmfetaminDashboard {
    $r = $Script:UiState.Refs
    if (-not $r) { return }
    $t = $Script:AmfetaminTheme
    try {
        $s = Get-AmfetaminStatus
        $ok = $t.Success; $no = $t.Danger; $mid = $t.Warning

        $r.PillNpcap.Dot.ForeColor = if ($s.NpcapInstalled) { $ok } else { $no }
        $r.PillNpcap.Value.Text = if ($s.NpcapInstalled) { (T 'status_installed') } else { (T 'status_not_installed') }

        $r.PillMotor.Dot.ForeColor = if ($s.EngineRunning) { $ok } else { if ($s.EngineDownloaded) { $mid } else { $no } }
        $r.PillMotor.Value.Text = if ($s.EngineRunning) {
            if ($s.Process) { "PID $($s.Process.Pid)" } else { (T 'status_active') }
        } elseif ($s.EngineDownloaded) { (T 'status_ready') } else { (T 'status_none') }

        $r.PillAuto.Dot.ForeColor = if ($s.AutoStartInstalled) { $ok } else { $no }
        $r.PillAuto.Value.Text = if ($s.AutoStartInstalled) { (T 'status_active') } else { (T 'status_none') }

        if ($s.EngineRunning -and $Script:UiState.FormReady) {
            Update-AmfetaminDiscordPill -PillDiscord $r.PillDiscord -EngineRunning $true `
                -Ok $ok -No $no -Mid $mid -Muted $t.TextMuted -DashPage $r.TabDash
        } else {
            Update-AmfetaminDiscordPill -PillDiscord $r.PillDiscord -EngineRunning $false `
                -Ok $ok -No $no -Mid $mid -Muted $t.TextMuted -DashPage $r.TabDash
        }

        if ($s.ZeroTierRunning) {
            try { Stop-ZeroTierIfRunning | Out-Null } catch {}
        }
        Set-UiControlVisible $r.WarnPanel ([bool](Test-ZeroTierRunning))

        if ($s.EngineRunning) {
            $r.LiveDot.Text = [char]0x25CF + (T 'live_on')
            $r.LiveDot.ForeColor = $t.Success
        } else {
            $r.LiveDot.Text = [char]0x25CF + (T 'live_off')
            $r.LiveDot.ForeColor = $t.Danger
        }

        $lines = @(
            (T 'info_version_line' $s.Version, $s.FakeTtl, $(if ($s.AutoTuneDone) { (T 'autotune_done') } else { (T 'autotune_pending') })),
            (T 'info_install' $s.InstallRoot)
        )
        if ($s.Process) {
            $lines += (T 'info_memory' $s.Process.MemoryMb)
        }
        $r.InfoBox.Text = ($lines -join "`r`n")
    } catch {
        Write-AmfetaminError -Message 'Dashboard guncelleme hatasi' -Exception $_.Exception
    }
}

function Refresh-AmfetaminLogView {
    $r = $Script:UiState.Refs
    if (-not $r -or -not $r.LogFilter -or -not $r.LogBox) { return }
    if (-not $r.LogBox.IsHandleCreated) { return }
    $name = [string]$r.LogFilter.SelectedItem
    if (-not $name) { return }
    try {
        $lines = Get-AmfetaminLogTail -LogName $name -Lines 300
        $r.LogBox.Text = ($lines -join "`r`n")
        $r.LogBox.SelectionStart = $r.LogBox.Text.Length
        $r.LogBox.ScrollToCaret()
    } catch {}
}

function Load-AmfetaminSettings {
    $r = $Script:UiState.Refs
    if (-not $r) { return }
    try {
        $cfg = Get-Config
        $r.SetDoh.SelectedItem = [string]$cfg.dohUpstream
        if (-not $r.SetDoh.SelectedItem) { $r.SetDoh.SelectedIndex = 0 }
        $r.SetTtl.Value = [decimal](if ($cfg.fakeTtl) { [int]$cfg.fakeTtl } else { 8 })
        $r.SetAutoTune.Checked = Get-ConfigBool $cfg 'autoTuneTtl' $true
        $r.SetWarmup.Checked = Get-ConfigBool $cfg 'warmup' $true
        $r.SetSplitTunnel.Checked = Get-ConfigBool $cfg 'splitTunnel' $true
        $r.SetVerbose.Checked = Get-ConfigBool $cfg 'engineVerbose' $false
    } catch {}
}

function Invoke-AmfetaminUiAction {
    param(
        [scriptblock]$Action,
        [string]$SuccessMsg = $null
    )
    $r = $Script:UiState.Refs
    $form = $Script:UiState.MainForm
    $t = $Script:AmfetaminTheme
    $toastBar = Get-AmfetaminToastBar
    $prevCursor = $form.Cursor
    try {
        try { $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor } catch {}
        [System.Windows.Forms.Application]::DoEvents()
        $result = & $Action
        Update-AmfetaminDashboard
        if ($SuccessMsg) {
            Show-AmfetaminToast -Form $form -Bar $toastBar -Message $SuccessMsg -Color $t.Success
        } elseif ($result) {
            Show-AmfetaminToast -Form $form -Bar $toastBar -Message ($result.ToString().Split("`n")[0]) -Color $t.Success
        }
        Refresh-AmfetaminLogView
    } catch {
        Write-AmfetaminError -Message 'UI islem hatasi' -Exception $_.Exception
        Show-AmfetaminToast -Form $form -Bar $toastBar -Message $_.Exception.Message -Color $t.Danger
        [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, (T 'app_name'), 'OK', 'Error')
    } finally {
        try { $form.Cursor = $prevCursor } catch {}
    }
}

function Restore-AmfetaminMainWindow {
    $form = $Script:UiState.MainForm
    if (-not $form) { return }
    if (-not $form.Visible) {
        $form.Show()
        $form.WindowState = 'Normal'
    }
    Show-AmfetaminFormForeground -Form $form
}

function Show-AmfetaminMainForm {
    Install-AmfetaminUiExceptionHandler
    try { Sync-LauncherToDevice } catch {
        Write-AmfetaminLog -Message "Baslangic senkronizasyonu atlandi: $($_.Exception.Message)" -Level WARN
    }
    try { Stop-ZeroTierIfRunning | Out-Null } catch {}

    $t = $Script:AmfetaminTheme
    $Script:DiscordCheckAt = $null
    $Script:DiscordOk = $null
    $form = New-Object System.Windows.Forms.Form
    $form.Text = (T 'app_name')
    $form.ShowInTaskbar = $true
    $form.Size = New-Object System.Drawing.Size(860, 580)
    $form.MinimumSize = New-Object System.Drawing.Size(860, 580)
    $form.BackColor = $t.BgDeep
    $form.ForeColor = $t.Text
    $form.StartPosition = 'CenterScreen'
    $form.Font = New-AmfetaminFont 9
    $icon = Get-AmfetaminIcon
    if ($icon) { $form.Icon = $icon }
    $Script:UiState.MainForm = $form
    $Script:UiState.FormReady = $false
    $Script:UiState.NavButtons = @()

    # Toast bar
    $toast = New-Object System.Windows.Forms.Label
    $toast.Dock = 'Bottom'
    $toast.Height = 28
    $toast.TextAlign = 'MiddleCenter'
    $toast.BackColor = $t.BgCard
    $toast.ForeColor = $t.TextMuted
    $toast.Font = New-AmfetaminFont 9
    Set-UiControlVisible $toast $false
    $Script:UiState.ToastBar = $toast

    $topAccent = New-Object System.Windows.Forms.Panel
    $topAccent.Dock = 'Top'
    $topAccent.Height = 2
    $topAccent.BackColor = $t.Accent

    # Sidebar (added to form after content — dock z-order)
    $sidebar = New-Object System.Windows.Forms.Panel
    $sidebar.Dock = 'Left'
    $sidebar.Width = 180
    $sidebar.BackColor = $t.BgPanel
    $sidebar.Add_Paint({
        if ($args.Count -lt 2) { return }
        $snd = $args[0]; $ea = $args[1]
        $w = [int]$snd.ClientSize.Width
        $h = [int]$snd.ClientSize.Height
        $pen = New-Object System.Drawing.Pen($t.Border)
        $ea.Graphics.DrawLine($pen, ($w - 1), 0, ($w - 1), $h)
        $pen.Dispose()
    })

    # Content shell (must be added to form BEFORE sidebar/top/bottom)
    $content = New-Object System.Windows.Forms.Panel
    $content.Dock = 'Fill'
    $content.BackColor = $t.BgDeep
    $content.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)

    $sidebarHeader = New-Object System.Windows.Forms.Panel
    $sidebarHeader.BackColor = $t.BgPanel
    $sidebarHeader.Location = New-Object System.Drawing.Point(0, 0)
    $sidebarHeader.Size = New-Object System.Drawing.Size(180, 82)
    $sidebar.Controls.Add($sidebarHeader)

    $brand = New-Object System.Windows.Forms.Label
    $brand.Text = (T 'app_name')
    $brand.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
    $brand.ForeColor = $t.Accent
    $brand.BackColor = $t.BgPanel
    $brand.AutoSize = $true
    $brand.Location = New-Object System.Drawing.Point(18, 14)
    $sidebarHeader.Controls.Add($brand)

    $verLbl = New-Object System.Windows.Forms.Label
    try { $verLbl.Text = "v$((Get-Config).version)" } catch { $verLbl.Text = 'v2.0.0' }
    $verLbl.Font = New-AmfetaminFont 8
    $verLbl.ForeColor = $t.TextMuted
    $verLbl.BackColor = $t.BgPanel
    $verLbl.AutoSize = $true
    $verLbl.Location = New-Object System.Drawing.Point(20, 52)
    $sidebarHeader.Controls.Add($verLbl)

    $liveDot = New-Object System.Windows.Forms.Label
    $liveDot.Text = [char]0x25CF + (T 'live_off')
    $liveDot.Font = New-AmfetaminFont 9 'Bold'
    $liveDot.ForeColor = $t.Danger
    $liveDot.BackColor = $t.BgPanel
    $liveDot.AutoSize = $true
    $liveDot.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
    $liveDot.Location = New-Object System.Drawing.Point(18, 520)
    $sidebar.Controls.Add($liveDot)

    function New-ContentPage {
        $page = New-Object System.Windows.Forms.Panel
        $page.Dock = 'Fill'
        $page.BackColor = $t.BgDeep
        $page.Visible = $false
        $page.AutoScroll = $true
        $content.Controls.Add($page)
        return $page
    }

    # === DASHBOARD ===
    $tabDash = New-ContentPage

    $pillNpcap = New-StatusPill -Parent $tabDash -Title (T 'pill_npcap') -Location (New-Object System.Drawing.Point(20, 20)) -Width 150
    $pillMotor = New-StatusPill -Parent $tabDash -Title (T 'pill_engine') -Location (New-Object System.Drawing.Point(182, 20)) -Width 150
    $pillAuto = New-StatusPill -Parent $tabDash -Title (T 'pill_auto') -Location (New-Object System.Drawing.Point(344, 20)) -Width 150
    $pillDiscord = New-StatusPill -Parent $tabDash -Title (T 'pill_discord') -Location (New-Object System.Drawing.Point(506, 20)) -Width 150

    $warnPanel = New-AmfetaminRoundedPanel -BackColor ([System.Drawing.Color]::FromArgb(50, 35, 20)) -Radius 8
    $warnPanel.Size = New-Object System.Drawing.Size(636, 36)
    $warnPanel.Location = New-Object System.Drawing.Point(20, 104)
    $warnPanel.Visible = $false
    $tabDash.Controls.Add($warnPanel)
    $warnLbl = New-Object System.Windows.Forms.Label
    $warnLbl.Text = (T 'warn_zerotier')
    $warnLbl.ForeColor = $t.Warning
    Set-SafeControlColor $warnLbl ([System.Drawing.Color]::FromArgb(50, 35, 20))
    $warnLbl.Font = New-AmfetaminFont 9
    $warnLbl.AutoSize = $true
    $warnLbl.Location = New-Object System.Drawing.Point(12, 10)
    $warnPanel.Controls.Add($warnLbl)

    $infoBox = New-Object System.Windows.Forms.TextBox
    $infoBox.Multiline = $true
    $infoBox.ReadOnly = $true
    $infoBox.BorderStyle = 'None'
    $infoBox.BackColor = $t.BgCard
    $infoBox.ForeColor = $t.TextMuted
    $infoBox.Font = New-AmfetaminFont 9
    $infoBox.Location = New-Object System.Drawing.Point(20, 152)
    $infoBox.Size = New-Object System.Drawing.Size(636, 80)
    $tabDash.Controls.Add($infoBox)

    $btnInstall = New-AmfetaminButton -Text (T 'btn_install') `
        -Bg $t.AccentGlow -HoverBg $t.Accent -Size (New-Object System.Drawing.Size(636, 46)) `
        -Location (New-Object System.Drawing.Point(20, 246)) -OnClick {}
    $tabDash.Controls.Add($btnInstall)

    $btnStart = New-AmfetaminButton -Text (T 'btn_start') -Bg $t.Purple -HoverBg $t.Pink `
        -Size (New-Object System.Drawing.Size(206, 42)) -Location (New-Object System.Drawing.Point(20, 304)) -OnClick {}
    $tabDash.Controls.Add($btnStart)

    $btnStop = New-AmfetaminButton -Text (T 'btn_stop') -Bg ([System.Drawing.Color]::FromArgb(60, 60, 85)) `
        -HoverBg ([System.Drawing.Color]::FromArgb(80, 80, 110)) `
        -Size (New-Object System.Drawing.Size(206, 42)) -Location (New-Object System.Drawing.Point(234, 304)) -OnClick {}
    $tabDash.Controls.Add($btnStop)

    $btnCleanup = New-AmfetaminButton -Text (T 'btn_cleanup') -Bg ([System.Drawing.Color]::FromArgb(90, 65, 30)) `
        -HoverBg $t.Warning `
        -Size (New-Object System.Drawing.Size(206, 42)) -Location (New-Object System.Drawing.Point(448, 304)) -OnClick {}
    $tabDash.Controls.Add($btnCleanup)

    $btnTest = New-AmfetaminButton -Text (T 'btn_test') -Bg $t.BgCard -HoverBg $t.BgCardHover `
        -Size (New-Object System.Drawing.Size(206, 38)) -Location (New-Object System.Drawing.Point(20, 356)) -OnClick {}
    $tabDash.Controls.Add($btnTest)

    $btnTtl = New-AmfetaminButton -Text (T 'btn_ttl') -Bg $t.BgCard -HoverBg $t.BgCardHover `
        -Size (New-Object System.Drawing.Size(206, 38)) -Location (New-Object System.Drawing.Point(234, 356)) -OnClick {}
    $tabDash.Controls.Add($btnTtl)

    $btnNpcap = New-AmfetaminButton -Text (T 'btn_npcap') -Bg $t.BgCard -HoverBg $t.BgCardHover `
        -Size (New-Object System.Drawing.Size(206, 38)) -Location (New-Object System.Drawing.Point(448, 356)) -OnClick {}
    $tabDash.Controls.Add($btnNpcap)

    # === LOGS ===
    $tabLogs = New-ContentPage

    $logFilter = New-Object System.Windows.Forms.ComboBox
    $logFilter.Location = New-Object System.Drawing.Point(16, 12)
    $logFilter.Size = New-Object System.Drawing.Size(180, 28)
    $logFilter.DropDownStyle = 'DropDownList'
    Set-SafeControlColor $logFilter $t.BgCard $t.Text
    @('app.log', 'errors.log', 'audit.log', 'launcher.log', 'amfetamin-run.log', 'service.log') | ForEach-Object {
        [void]$logFilter.Items.Add($_)
    }
    $logFilter.SelectedIndex = 0
    $tabLogs.Controls.Add($logFilter)

    $logAuto = New-Object System.Windows.Forms.CheckBox
    $logAuto.Text = (T 'log_live')
    $logAuto.ForeColor = $t.Text
    $logAuto.BackColor = $t.BgDeep
    $logAuto.Checked = $true
    $logAuto.Location = New-Object System.Drawing.Point(210, 14)
    $logAuto.AutoSize = $true
    $tabLogs.Controls.Add($logAuto)

    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ReadOnly = $true
    $logBox.ScrollBars = 'Both'
    $logBox.WordWrap = $false
    $logBox.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 20)
    $logBox.ForeColor = $t.Accent
    $logBox.Font = New-Object System.Drawing.Font('Consolas', 9)
    $logBox.Location = New-Object System.Drawing.Point(20, 48)
    $logBox.Size = New-Object System.Drawing.Size(636, 380)
    $tabLogs.Controls.Add($logBox)

    $btnLogRefresh = New-AmfetaminButton -Text (T 'btn_refresh') -Bg $t.BgCard -HoverBg $t.BgCardHover `
        -Size (New-Object System.Drawing.Size(100, 34)) -Location (New-Object System.Drawing.Point(16, 418)) -OnClick {}
    $tabLogs.Controls.Add($btnLogRefresh)

    $btnLogExport = New-AmfetaminButton -Text (T 'btn_export_zip') -Bg $t.Purple -HoverBg $t.Pink `
        -Size (New-Object System.Drawing.Size(140, 34)) -Location (New-Object System.Drawing.Point(124, 418)) -OnClick {}
    $tabLogs.Controls.Add($btnLogExport)

    $btnLogClear = New-AmfetaminButton -Text (T 'btn_clear') -Bg ([System.Drawing.Color]::FromArgb(80, 40, 45)) `
        -HoverBg $t.Danger `
        -Size (New-Object System.Drawing.Size(100, 34)) -Location (New-Object System.Drawing.Point(272, 418)) -OnClick {}
    $tabLogs.Controls.Add($btnLogClear)

    # === SETTINGS ===
    $tabSet = New-ContentPage

    $y = 20
    function Add-SettingLabel($text, $yy) {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $text
        $l.ForeColor = $t.TextMuted
        $l.BackColor = $t.BgDeep
        $l.Font = New-AmfetaminFont 9
        $l.AutoSize = $true
        $l.Location = New-Object System.Drawing.Point(20, $yy)
        $tabSet.Controls.Add($l)
    }

    Add-SettingLabel 'DoH Upstream' $y
    $setDoh = New-Object System.Windows.Forms.ComboBox
    $setDoh.Location = New-Object System.Drawing.Point(20, ($y + 22))
    $setDoh.Size = New-Object System.Drawing.Size(300, 28)
    Set-SafeControlColor $setDoh $t.BgCard $t.Text
    @('cloudflare', 'google', 'quad9') | ForEach-Object { [void]$setDoh.Items.Add($_) }
    $tabSet.Controls.Add($setDoh)
    $y += 62

    Add-SettingLabel (T 'label_fake_ttl') ($y)
    $setTtl = New-Object System.Windows.Forms.NumericUpDown
    $setTtl.Location = New-Object System.Drawing.Point(20, ($y + 22))
    $setTtl.Size = New-Object System.Drawing.Size(120, 28)
    $setTtl.Minimum = 1; $setTtl.Maximum = 64; $setTtl.Value = 8
    try { $setTtl.ForeColor = $t.Text } catch {}
    $tabSet.Controls.Add($setTtl)
    $y += 62

    $setAutoTune = New-Object System.Windows.Forms.CheckBox
    $setAutoTune.Text = (T 'chk_auto_tune')
    $setAutoTune.ForeColor = $t.Text; $setAutoTune.BackColor = $t.BgDeep
    $setAutoTune.Location = New-Object System.Drawing.Point(20, $y); $setAutoTune.AutoSize = $true
    $tabSet.Controls.Add($setAutoTune)
    $y += 32

    $setWarmup = New-Object System.Windows.Forms.CheckBox
    $setWarmup.Text = (T 'chk_warmup')
    $setWarmup.ForeColor = $t.Text; $setWarmup.BackColor = $t.BgDeep
    $setWarmup.Location = New-Object System.Drawing.Point(20, $y); $setWarmup.AutoSize = $true
    $tabSet.Controls.Add($setWarmup)
    $y += 32

    $setSplitTunnel = New-Object System.Windows.Forms.CheckBox
    $setSplitTunnel.Text = (T 'chk_split_tunnel')
    $setSplitTunnel.ForeColor = $t.Text; $setSplitTunnel.BackColor = $t.BgDeep
    $setSplitTunnel.Checked = $true
    $setSplitTunnel.Location = New-Object System.Drawing.Point(20, $y); $setSplitTunnel.AutoSize = $true
    $tabSet.Controls.Add($setSplitTunnel)
    $y += 32

    $setVerbose = New-Object System.Windows.Forms.CheckBox
    $setVerbose.Text = (T 'chk_verbose')
    $setVerbose.ForeColor = $t.Text; $setVerbose.BackColor = $t.BgDeep
    $setVerbose.Location = New-Object System.Drawing.Point(20, $y); $setVerbose.AutoSize = $true
    $tabSet.Controls.Add($setVerbose)
    $y += 48

    $btnSaveSettings = New-AmfetaminButton -Text (T 'btn_save_settings') -Bg $t.AccentGlow -HoverBg $t.Accent `
        -Size (New-Object System.Drawing.Size(300, 42)) -Location (New-Object System.Drawing.Point(20, $y)) -OnClick {}
    $tabSet.Controls.Add($btnSaveSettings)

    # === DIAGNOSTICS ===
    $tabDiag = New-ContentPage

    $diagBox = New-Object System.Windows.Forms.TextBox
    $diagBox.Multiline = $true
    $diagBox.ReadOnly = $true
    $diagBox.ScrollBars = 'Vertical'
    $diagBox.BackColor = $t.BgCard
    $diagBox.ForeColor = $t.Text
    $diagBox.Font = New-Object System.Drawing.Font('Consolas', 9)
    $diagBox.Location = New-Object System.Drawing.Point(20, 16)
    $diagBox.Size = New-Object System.Drawing.Size(636, 400)
    $tabDiag.Controls.Add($diagBox)

    $btnDiagRun = New-AmfetaminButton -Text (T 'btn_run_diagnostics') -Bg $t.Purple -HoverBg $t.Pink `
        -Size (New-Object System.Drawing.Size(180, 38)) -Location (New-Object System.Drawing.Point(16, 408)) -OnClick {}
    $tabDiag.Controls.Add($btnDiagRun)

    $btnDiagSave = New-AmfetaminButton -Text (T 'btn_save_report') -Bg $t.BgCard -HoverBg $t.BgCardHover `
        -Size (New-Object System.Drawing.Size(180, 38)) -Location (New-Object System.Drawing.Point(210, 408)) -OnClick {}
    $tabDiag.Controls.Add($btnDiagSave)

    $btnDiagFolder = New-AmfetaminButton -Text (T 'btn_open_log_folder') -Bg $t.BgCard -HoverBg $t.BgCardHover `
        -Size (New-Object System.Drawing.Size(180, 38)) -Location (New-Object System.Drawing.Point(404, 408)) -OnClick {}
    $tabDiag.Controls.Add($btnDiagFolder)

    # === ABOUT ===
    $tabAbout = New-ContentPage

    $aboutText = (T 'about_text')

    $aboutLbl = New-Object System.Windows.Forms.Label
    $aboutLbl.Text = $aboutText
    $aboutLbl.ForeColor = $t.TextMuted
    $aboutLbl.BackColor = $t.BgDeep
    $aboutLbl.Font = New-AmfetaminFont 10
    $aboutLbl.Location = New-Object System.Drawing.Point(24, 24)
    $aboutLbl.Size = New-Object System.Drawing.Size(640, 280)
    $tabAbout.Controls.Add($aboutLbl)

    $btnUpdate = New-AmfetaminButton -Text (T 'btn_check_update') -Bg $t.AccentGlow -HoverBg $t.Accent `
        -Size (New-Object System.Drawing.Size(220, 40)) -Location (New-Object System.Drawing.Point(24, 320)) -OnClick {}
    $tabAbout.Controls.Add($btnUpdate)

    $btnUninstall = New-AmfetaminButton -Text (T 'btn_uninstall') -Bg ([System.Drawing.Color]::FromArgb(90, 35, 45)) `
        -HoverBg $t.Danger `
        -Size (New-Object System.Drawing.Size(220, 40)) -Location (New-Object System.Drawing.Point(260, 320)) -OnClick {}
    $tabAbout.Controls.Add($btnUninstall)

    $updateLbl = New-Object System.Windows.Forms.Label
    $updateLbl.Text = ''
    $updateLbl.ForeColor = $t.TextMuted
    $updateLbl.BackColor = $t.BgDeep
    $updateLbl.Font = New-AmfetaminFont 9
    $updateLbl.AutoSize = $true
    $updateLbl.Location = New-Object System.Drawing.Point(24, 372)
    $tabAbout.Controls.Add($updateLbl)

    $Script:UiState.Refs = [PSCustomObject]@{
        Toast       = $toast
        LiveDot     = $liveDot
        PillNpcap   = $pillNpcap
        PillMotor   = $pillMotor
        PillAuto    = $pillAuto
        PillDiscord = $pillDiscord
        WarnPanel   = $warnPanel
        InfoBox     = $infoBox
        LogFilter   = $logFilter
        LogBox      = $logBox
        LogAuto     = $logAuto
        TabLogs     = $tabLogs
        TabDash     = $tabDash
        SetDoh      = $setDoh
        SetTtl      = $setTtl
        SetAutoTune = $setAutoTune
        SetWarmup   = $setWarmup
        SetSplitTunnel = $setSplitTunnel
        SetVerbose  = $setVerbose
        DiagBox     = $diagBox
        UpdateLbl   = $updateLbl
    }

    $navY = 92
    $navDash = New-NavButton -Text (T 'tab_dashboard') -Location (New-Object System.Drawing.Point(6, $navY)) -Sidebar $sidebar -Page $tabDash
    $navY += 44
    $navLogs = New-NavButton -Text (T 'tab_logs') -Location (New-Object System.Drawing.Point(6, $navY)) -Sidebar $sidebar -Page $tabLogs `
        -OnSelect { Invoke-AmfetaminUiDeferred { Refresh-AmfetaminLogView } }
    $navY += 44
    $navSet = New-NavButton -Text (T 'tab_settings') -Location (New-Object System.Drawing.Point(6, $navY)) -Sidebar $sidebar -Page $tabSet
    $navY += 44
    $navDiag = New-NavButton -Text (T 'tab_diagnostics') -Location (New-Object System.Drawing.Point(6, $navY)) -Sidebar $sidebar -Page $tabDiag
    $navY += 44
    $navAbout = New-NavButton -Text (T 'tab_about') -Location (New-Object System.Drawing.Point(6, $navY)) -Sidebar $sidebar -Page $tabAbout
    Select-AmfetaminNavPage -NavButton $navDash

    # Dock order: Fill first, then edges (WinForms z-order)
    $form.Controls.Add($content)
    $form.Controls.Add($sidebar)
    $form.Controls.Add($topAccent)
    $form.Controls.Add($toast)

    # Wire events
    $btnInstall.Add_Click({
        $wiz = New-Object System.Windows.Forms.Form
        $wiz.Text = (T 'wizard_install_title')
        $wiz.Size = New-Object System.Drawing.Size(520, 400)
        $wiz.BackColor = $t.BgDeep
        $wiz.ForeColor = $t.Text
        if ($icon) { $wiz.Icon = $icon }

        $wLog = New-Object System.Windows.Forms.TextBox
        $wLog.Multiline = $true; $wLog.ReadOnly = $true; $wLog.ScrollBars = 'Vertical'
        $wLog.BackColor = $t.BgCard; $wLog.ForeColor = $t.Text
        $wLog.Font = New-AmfetaminFont 9
        $wLog.Location = New-Object System.Drawing.Point(20, 20)
        $wLog.Size = New-Object System.Drawing.Size(464, 280)
        $wiz.Controls.Add($wLog)

        $wBar = New-Object System.Windows.Forms.ProgressBar
        $wBar.Style = 'Marquee'; $wBar.MarqueeAnimationSpeed = 25
        $wBar.Location = New-Object System.Drawing.Point(20, 312)
        $wBar.Size = New-Object System.Drawing.Size(464, 8)
        $wiz.Controls.Add($wBar)

        $progressFn = {
            param($msg)
            $wLog.AppendText("> $msg`r`n")
            [System.Windows.Forms.Application]::DoEvents()
        }

        $wiz.Add_Shown({
            $statusTimerWasRunning = $false
            $logTimerWasRunning = $false
            if ($Script:UiState.StatusTimer) {
                $statusTimerWasRunning = $Script:UiState.StatusTimer.Enabled
                $Script:UiState.StatusTimer.Stop()
            }
            if ($Script:UiState.LogTimer) {
                $logTimerWasRunning = $Script:UiState.LogTimer.Enabled
                $Script:UiState.LogTimer.Stop()
            }
            $Script:UiState.InstallInProgress = $true
            try {
                $result = Install-ToDevice -Progress $progressFn
                $wBar.Style = 'Continuous'; $wBar.Value = 100
                $wLog.AppendText("`r`n$result`r`n")
                Write-AmfetaminLog -Message 'Kurulum wizard tamamlandi' -Level INFO
                Start-Sleep -Milliseconds 400
                [void][System.Windows.Forms.MessageBox]::Show($result, (T 'app_name'), 'OK', 'Information')
                $wiz.DialogResult = 'OK'
                $wiz.Close()
            } catch {
                $wLog.AppendText("$(T 'wizard_error_prefix' $_.Exception.Message)`r`n")
                Write-AmfetaminError -Message 'Kurulum hatasi' -Exception $_.Exception
                [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, (T 'app_name'), 'OK', 'Error')
                $wiz.DialogResult = 'Cancel'
                $wiz.Close()
            } finally {
                $Script:UiState.InstallInProgress = $false
                if ($Script:UiState.StatusTimer -and $statusTimerWasRunning) { $Script:UiState.StatusTimer.Start() }
                if ($Script:UiState.LogTimer -and $logTimerWasRunning) { $Script:UiState.LogTimer.Start() }
            }
        })
        Show-AmfetaminModalDialog -Dialog $wiz -Owner $form
        Load-AmfetaminSettings
        Update-AmfetaminDashboard
        Refresh-AmfetaminLogView
    })

    $btnStart.Add_Click({ Invoke-AmfetaminUiAction { Install-And-Start } })
    $btnStop.Add_Click({ Invoke-AmfetaminUiAction { Stop-Amfetamin } })
    $btnNpcap.Add_Click({ Invoke-AmfetaminUiAction { Install-NpcapGui } })

    $btnCleanup.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show(
            (T 'msg_cleanup_confirm'),
            (T 'app_name'), 'YesNo', 'Warning')
        if ($r -eq 'Yes') { Invoke-AmfetaminUiAction { Invoke-AmfetaminCleanup } }
    })

    $btnTest.Add_Click({
        Invoke-AmfetaminUiAction {
            $results = Test-AmfetaminConnectivity
            ($results | ForEach-Object {
                $st = if ($_.Ok) { "OK $($_.StatusCode)" } else { 'FAIL' }
                "$($_.Url): $st in $($_.Ms) ms"
            }) -join "`n"
        }
    })

    $btnTtl.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show(
            (T 'msg_ttl_confirm'),
            (T 'app_name'), 'YesNo', 'Question')
        if ($r -eq 'Yes') {
            $wiz = New-Object System.Windows.Forms.Form
            $wiz.Text = (T 'wizard_ttl_title'); $wiz.Size = New-Object System.Drawing.Size(440, 220)
            $wiz.BackColor = $t.BgDeep
            $wl = New-Object System.Windows.Forms.Label
            $wl.Text = (T 'wizard_ttl_waiting')
            $wl.ForeColor = $t.Accent; $wl.Font = New-AmfetaminFont 11
            $wl.AutoSize = $true; $wl.Location = New-Object System.Drawing.Point(24, 24)
            $wiz.Controls.Add($wl)
            $wBar = New-Object System.Windows.Forms.ProgressBar
            $wBar.Style = 'Marquee'; $wBar.Location = New-Object System.Drawing.Point(24, 60)
            $wBar.Size = New-Object System.Drawing.Size(380, 8)
            $wiz.Controls.Add($wBar)
            $statusL = New-Object System.Windows.Forms.Label
            $statusL.ForeColor = $t.TextMuted; $statusL.AutoSize = $true
            $statusL.Location = New-Object System.Drawing.Point(24, 80)
            $wiz.Controls.Add($statusL)
            $wiz.Add_Shown({
                $statusTimerWasRunning = $false
                $logTimerWasRunning = $false
                if ($Script:UiState.StatusTimer) {
                    $statusTimerWasRunning = $Script:UiState.StatusTimer.Enabled
                    $Script:UiState.StatusTimer.Stop()
                }
                if ($Script:UiState.LogTimer) {
                    $logTimerWasRunning = $Script:UiState.LogTimer.Enabled
                    $Script:UiState.LogTimer.Stop()
                }
                $Script:UiState.InstallInProgress = $true
                try {
                    $msg = Invoke-ManualTtlRetune -Progress {
                        param($m)
                        $statusL.Text = $m
                        [System.Windows.Forms.Application]::DoEvents()
                    }
                    [void][System.Windows.Forms.MessageBox]::Show($msg, (T 'app_name'))
                    $wiz.DialogResult = 'OK'
                    $wiz.Close()
                } catch {
                    [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, (T 'app_name'), 'OK', 'Error')
                    $wiz.DialogResult = 'Cancel'
                    $wiz.Close()
                } finally {
                    $Script:UiState.InstallInProgress = $false
                    if ($Script:UiState.StatusTimer -and $statusTimerWasRunning) { $Script:UiState.StatusTimer.Start() }
                    if ($Script:UiState.LogTimer -and $logTimerWasRunning) { $Script:UiState.LogTimer.Start() }
                }
            })
            Show-AmfetaminModalDialog -Dialog $wiz -Owner $form
            Update-AmfetaminDashboard
        }
    })

    $btnLogRefresh.Add_Click({ Refresh-AmfetaminLogView })
    $logFilter.Add_SelectedIndexChanged({ Refresh-AmfetaminLogView })
    $btnLogExport.Add_Click({
        try {
            $path = Export-AmfetaminLogs
            Show-AmfetaminToast -Form $form -Bar $toast -Message (T 'toast_saved' $path) -Color $t.Success
            Start-Process explorer.exe "/select,`"$path`""
        } catch {
            Show-AmfetaminToast -Form $form -Bar $toast -Message $_.Exception.Message -Color $t.Danger
        }
    })
    $btnLogClear.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show((T 'msg_clear_logs_confirm'), (T 'app_name'), 'YesNo', 'Warning')
        if ($r -eq 'Yes') { Clear-AmfetaminLogs; Refresh-AmfetaminLogView }
    })

    $btnSaveSettings.Add_Click({
        Invoke-AmfetaminUiAction {
            Save-AmfetaminSettings -DohUpstream $setDoh.SelectedItem -FakeTtl ([int]$setTtl.Value) `
                -AutoTuneTtl $setAutoTune.Checked -Warmup $setWarmup.Checked `
                -SplitTunnel $setSplitTunnel.Checked -EngineVerbose $setVerbose.Checked
        }
    })

    $btnDiagRun.Add_Click({
        $diagBox.Text = (T 'diag_running')
        [System.Windows.Forms.Application]::DoEvents()
        try {
            $diagBox.Text = Get-AmfetaminDiagnosticReport -Quiet
            Write-AmfetaminLog -Message 'Teshis UI calistirildi' -Level INFO
        } catch {
            $diagBox.Text = $_.Exception.Message
            Write-AmfetaminError -Message 'Teshis UI hatasi' -Exception $_.Exception
        }
    })

    $btnDiagSave.Add_Click({
        try {
            $p = Save-AmfetaminDiagnosticReport
            Show-AmfetaminToast -Form $form -Bar $toast -Message (T 'toast_report' $p) -Color $t.Success
            Start-Process notepad.exe $p
        } catch {
            Show-AmfetaminToast -Form $form -Bar $toast -Message $_.Exception.Message -Color $t.Danger
        }
    })

    $btnDiagFolder.Add_Click({
        Ensure-Dirs
        Start-Process explorer.exe $Script:LogDir
    })

    $btnUpdate.Add_Click({
        $updateLbl.Text = (T 'update_checking')
        [System.Windows.Forms.Application]::DoEvents()
        $info = Get-AmfetaminUpdateInfo
        if (-not $info) {
            $updateLbl.Text = (T 'update_check_failed')
            return
        }
        if ($info.UpdateAvailable) {
            $updateLbl.Text = (T 'update_available' $info.Latest, $info.Current)
            $r = [System.Windows.Forms.MessageBox]::Show(
                (T 'update_prompt' $info.Latest),
                (T 'app_name'), 'YesNo', 'Information')
            if ($r -eq 'Yes' -and $info.DownloadUrl) {
                Start-Process $info.DownloadUrl
            }
        } else {
            $updateLbl.Text = (T 'update_current' $info.Current)
        }
    })

    $btnUninstall.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show(
            (T 'msg_uninstall_confirm'),
            (T 'app_name'), 'YesNo', 'Warning')
        if ($r -eq 'Yes') { Invoke-AmfetaminUiAction { Uninstall-FromDevice } }
    })

    # System tray
    $trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
    try { $trayMenu.BackColor = $t.BgPanel } catch {}
    $miShow = $trayMenu.Items.Add((T 'tray_show'))
    $miDash = $trayMenu.Items.Add((T 'tray_status'))
    $trayMenu.Items.Add('-') | Out-Null
    $miExit = $trayMenu.Items.Add((T 'tray_exit'))

    $tray = New-Object System.Windows.Forms.NotifyIcon
    $tray.Text = (T 'app_name')
    if ($icon) { $tray.Icon = $icon } else { $tray.Icon = [System.Drawing.SystemIcons]::Shield }
    $tray.ContextMenuStrip = $trayMenu
    $tray.Visible = $false
    $Script:UiState.TrayIcon = $tray

    $miShow.Add_Click({ Restore-AmfetaminMainWindow })
    $miDash.Add_Click({ Update-AmfetaminDashboard; Restore-AmfetaminMainWindow })
    $miExit.Add_Click({
        $tray.Visible = $false
        $tray.Dispose()
        $form.Close()
    })
    $tray.Add_DoubleClick({ Restore-AmfetaminMainWindow })

    $form.Add_Resize({
        if (-not $Script:UiState.FormReady) { return }
        if ($form.WindowState -eq 'Minimized') {
            $form.Hide()
            $tray.ShowBalloonTip(2000, (T 'app_name'), (T 'tray_balloon'), 'Info')
        }
    })

    # Live timers (started after form is shown)
    $statusTimer = New-Object System.Windows.Forms.Timer
    $statusTimer.Interval = 3000
    $statusTimer.Add_Tick({ Update-AmfetaminDashboard })
    $Script:UiState.StatusTimer = $statusTimer

    $logTimer = New-Object System.Windows.Forms.Timer
    $logTimer.Interval = 2000
    $logTimer.Add_Tick({
        $r = $Script:UiState.Refs
        if (-not $r -or -not $r.LogAuto) { return }
        if ($Script:UiState.ActivePage -eq $r.TabLogs -and $r.LogAuto.Checked) {
            Refresh-AmfetaminLogView
        }
    })
    $Script:UiState.LogTimer = $logTimer

    Register-LogSubscriber {
        param($line, $level)
        $r = $Script:UiState.Refs
        if (-not $r -or -not $r.LogAuto) { return }
        if ($Script:UiState.ActivePage -eq $r.TabLogs -and $r.LogAuto.Checked) {
            try { Refresh-AmfetaminLogView } catch {}
        }
    }

    $form.Add_Shown({
        try {
            Select-AmfetaminNavPage -NavButton $navDash
            Update-AmfetaminDashboard
            $Script:UiState.FormReady = $true
            if ($Script:UiState.StatusTimer) { $Script:UiState.StatusTimer.Start() }
            if ($Script:UiState.LogTimer) { $Script:UiState.LogTimer.Start() }
            Show-AmfetaminFormForeground -Form $form
            if ($Script:UiState.TrayIcon) { $Script:UiState.TrayIcon.Visible = $true }

            if ($env:AMFETAMIN_UI_TEST -eq '1') {
                $result = [ordered]@{
                    activePageIsDash = ($Script:UiState.ActivePage -eq $tabDash)
                    dashVisible      = $tabDash.Visible
                    startButtonText  = $btnStart.Text
                    navDashActive    = [bool]$navDash.Tag.ActiveBg
                    passed           = $false
                }
                $result.passed = $result.activePageIsDash -and $result.dashVisible -and
                    $result.startButtonText -and $result.navDashActive
                $turkishOk = ((T 'tab_diagnostics') -eq 'Teşhis') -and ((T 'btn_start') -like '*BA*LAT*')
                $result | Add-Member -NotePropertyName turkishOk -NotePropertyValue $turkishOk -Force
                $result.passed = $result.passed -and $turkishOk
                $out = Join-Path $env:TEMP 'amfetamin-ui-test.json'
                $result | ConvertTo-Json | Set-Content -Path $out -Encoding UTF8
                $Script:UiState.TestCloseTimer = New-Object System.Windows.Forms.Timer
                $Script:UiState.TestCloseTimer.Interval = 1200
                $Script:UiState.TestCloseTimer.Add_Tick({
                    if ($Script:UiState.TestCloseTimer) {
                        $Script:UiState.TestCloseTimer.Stop()
                        $Script:UiState.TestCloseTimer.Dispose()
                        $Script:UiState.TestCloseTimer = $null
                    }
                    $f = $Script:UiState.MainForm
                    if ($f) {
                        try { $f.DialogResult = [System.Windows.Forms.DialogResult]::OK } catch {}
                        $f.Close()
                    }
                })
                $Script:UiState.TestCloseTimer.Start()
            }
        } catch {
            Write-AmfetaminError -Message 'FormShown hatasi' -Exception $_.Exception
            [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, (T 'app_name'), 'OK', 'Error')
        }
    })

    $form.Add_FormClosed({
        if ($Script:UiState.StatusTimer) { $Script:UiState.StatusTimer.Stop() }
        if ($Script:UiState.LogTimer) { $Script:UiState.LogTimer.Stop() }
        if ($Script:UiState.TrayIcon) {
            $Script:UiState.TrayIcon.Visible = $false
            $Script:UiState.TrayIcon.Dispose()
        }
        $Script:UiState.MainForm = $null
        $Script:UiState.Refs = $null
        $Script:UiState.ToastBar = $null
        $Script:UiState.FormReady = $false
        Write-AmfetaminLog -Message 'Ana pencere kapatildi' -Level INFO -Audit
    })

    Load-AmfetaminSettings
    Write-AmfetaminLog -Message 'Ana arayuz acildi' -Level INFO -Audit

    [void]$form.ShowDialog()
}
