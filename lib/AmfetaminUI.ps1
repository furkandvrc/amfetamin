# amfetamin — modern UI (v2)
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
    LogTimer = $null
    TrayIcon = $null
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
    $root = Get-ProjectRoot
    foreach ($name in @('amfetamin.ico', (Join-Path 'assets' 'amfetamin.ico'))) {
        $path = Join-Path $root $name
        if (Test-Path $path) {
            $Script:AmfetaminIcon = New-Object System.Drawing.Icon($path)
            return $Script:AmfetaminIcon
        }
    }
    return $null
}

function New-AmfetaminRoundedPanel {
    param(
        [System.Drawing.Color]$BackColor,
        [int]$Radius = 12
    )
    $p = New-Object System.Windows.Forms.Panel
    $p.BackColor = $BackColor
    $p.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $rect = New-Object System.Drawing.Rectangle(0, 0, $s.Width - 1, $s.Height - 1)
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $r = 10
        $path.AddArc($rect.X, $rect.Y, $r, $r, 180, 90)
        $path.AddArc($rect.Right - $r, $rect.Y, $r, $r, 270, 90)
        $path.AddArc($rect.Right - $r, $rect.Bottom - $r, $r, $r, 0, 90)
        $path.AddArc($rect.X, $rect.Bottom - $r, $r, $r, 90, 90)
        $path.CloseFigure()
        $s.Region = New-Object System.Drawing.Region($path)
    })
    return $p
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
    $btn.Font = New-AmfetaminFont 10 'Bold'
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Add_MouseEnter({ $btn.BackColor = $HoverBg })
    $btn.Add_MouseLeave({ $btn.BackColor = $Bg })
    if ($OnClick) { $btn.Add_Click($OnClick) }
    return $btn
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
    $dot.BackColor = $t.BgCard
    $card.Controls.Add($dot)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Title
    $lbl.Font = New-AmfetaminFont 8.5
    $lbl.ForeColor = $t.TextMuted
    $lbl.BackColor = $t.BgCard
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(12, 34)
    $card.Controls.Add($lbl)

    $val = New-Object System.Windows.Forms.Label
    $val.Text = '—'
    $val.Font = New-AmfetaminFont 10 'Bold'
    $val.ForeColor = $t.Text
    $val.BackColor = $t.BgCard
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
    if (-not $Bar) { return }
    $Bar.Text = $Message
    $Bar.ForeColor = $Color
    $Bar.Visible = $true
    if ($Script:UiState.ToastTimer) {
        try { $Script:UiState.ToastTimer.Stop(); $Script:UiState.ToastTimer.Dispose() } catch {}
    }
    $Script:UiState.ToastTimer = New-Object System.Windows.Forms.Timer
    $Script:UiState.ToastTimer.Interval = 5000
    $Script:UiState.ToastTimer.Add_Tick({
        $Bar.Visible = $false
        $Script:UiState.ToastTimer.Stop()
    })
    $Script:UiState.ToastTimer.Start()
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-AmfetaminSplash {
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
    $grad.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            (New-Object System.Drawing.Point(0, 0)),
            (New-Object System.Drawing.Point($s.Width, $s.Height)),
            [System.Drawing.Color]::FromArgb(20, 0, 40),
            [System.Drawing.Color]::FromArgb(0, 30, 30))
        $g.FillRectangle($brush, $s.ClientRectangle)
        $brush.Dispose()
    })
    $splash.Controls.Add($grad)

    $accent = New-Object System.Windows.Forms.Panel
    $accent.Size = New-Object System.Drawing.Size(580, 3)
    $accent.BackColor = $t.Accent
    $accent.Dock = 'Top'
    $splash.Controls.Add($accent)
    $accent.BringToFront()

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'amfetamin'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 48, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = $t.Accent
    $title.BackColor = [System.Drawing.Color]::Transparent
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(48, 80)
    $grad.Controls.Add($title)

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = 'DPI bypass  ·  Discord  ·  Rust / EAC uyumlu'
    $sub.Font = New-AmfetaminFont 11
    $sub.ForeColor = $t.TextMuted
    $sub.BackColor = [System.Drawing.Color]::Transparent
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
    $status.Text = 'Baslatiliyor...'
    $status.Font = New-AmfetaminFont 9.5
    $status.ForeColor = $t.Text
    $status.BackColor = [System.Drawing.Color]::Transparent
    $status.AutoSize = $true
    $status.Location = New-Object System.Drawing.Point(48, 248)
    $grad.Controls.Add($status)

    $credit = New-Object System.Windows.Forms.Label
    $credit.Text = 'by furkandvrc'
    $credit.Font = New-AmfetaminFont 10 'Italic'
    $credit.ForeColor = $t.Purple
    $credit.BackColor = [System.Drawing.Color]::Transparent
    $credit.AutoSize = $true
    $credit.Location = New-Object System.Drawing.Point(48, 320)
    $grad.Controls.Add($credit)

    try { $ver = (Get-Config).version } catch { $ver = '2.0.0' }
    $version = New-Object System.Windows.Forms.Label
    $version.Text = "v$ver"
    $version.Font = New-AmfetaminFont 9
    $version.ForeColor = $t.TextMuted
    $version.BackColor = [System.Drawing.Color]::Transparent
    $version.AutoSize = $true
    $version.Location = New-Object System.Drawing.Point(480, 324)
    $grad.Controls.Add($version)

    Write-AmfetaminLog -Message 'Splash ekrani acildi' -Level DEBUG

    $steps = @(
        @{ pct = 12; msg = 'Log sistemi hazirlaniyor...' },
        @{ pct = 28; msg = 'Yetkiler dogrulaniyor...' },
        @{ pct = 45; msg = 'Npcap kontrol ediliyor...' },
        @{ pct = 62; msg = 'Durum okunuyor...' },
        @{ pct = 80; msg = 'Arayuz hazirlaniyor...' },
        @{ pct = 100; msg = 'Hazir' }
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
                    $st = Get-AmfetaminStatus
                    $status.Text = "Motor: $(if ($st.EngineRunning) {'aktif'} else {'kapali'})  ·  Npcap: $(if ($st.NpcapInstalled) {'OK'} else {'eksik'})"
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
        $splash.Close()
    })

    [void]$splash.ShowDialog()
}

function Show-AmfetaminMainForm {
    $t = $Script:AmfetaminTheme
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'amfetamin'
    $form.Size = New-Object System.Drawing.Size(720, 620)
    $form.MinimumSize = New-Object System.Drawing.Size(720, 620)
    $form.BackColor = $t.BgDeep
    $form.ForeColor = $t.Text
    $form.StartPosition = 'CenterScreen'
    $form.Font = New-AmfetaminFont 9
    $icon = Get-AmfetaminIcon
    if ($icon) { $form.Icon = $icon }

    # Header
    $header = New-Object System.Windows.Forms.Panel
    $header.Dock = 'Top'
    $header.Height = 72
    $header.BackColor = $t.BgPanel
    $header.Add_Paint({
        param($s, $e)
        $pen = New-Object System.Drawing.Pen($t.Border)
        $e.Graphics.DrawLine($pen, 0, $s.Height - 1, $s.Width, $s.Height - 1)
        $pen.Dispose()
    })
    $form.Controls.Add($header)

    $logo = New-Object System.Windows.Forms.Label
    $logo.Text = 'amfetamin'
    $logo.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
    $logo.ForeColor = $t.Accent
    $logo.BackColor = $t.BgPanel
    $logo.AutoSize = $true
    $logo.Location = New-Object System.Drawing.Point(20, 14)
    $header.Controls.Add($logo)

    $verLbl = New-Object System.Windows.Forms.Label
    try { $verLbl.Text = "v$((Get-Config).version)" } catch { $verLbl.Text = 'v2.0.0' }
    $verLbl.Font = New-AmfetaminFont 9
    $verLbl.ForeColor = $t.TextMuted
    $verLbl.BackColor = $t.BgPanel
    $verLbl.AutoSize = $true
    $verLbl.Location = New-Object System.Drawing.Point(22, 46)
    $header.Controls.Add($verLbl)

    $liveDot = New-Object System.Windows.Forms.Label
    $liveDot.Text = [char]0x25CF + '  KAPALI'
    $liveDot.Font = New-AmfetaminFont 10 'Bold'
    $liveDot.ForeColor = $t.Danger
    $liveDot.BackColor = $t.BgPanel
    $liveDot.AutoSize = $true
    $liveDot.Location = New-Object System.Drawing.Point(540, 26)
    $header.Controls.Add($liveDot)

    # Toast bar
    $toast = New-Object System.Windows.Forms.Label
    $toast.Dock = 'Bottom'
    $toast.Height = 28
    $toast.TextAlign = 'MiddleCenter'
    $toast.BackColor = $t.BgCard
    $toast.ForeColor = $t.TextMuted
    $toast.Font = New-AmfetaminFont 9
    $toast.Visible = $false
    $form.Controls.Add($toast)

    # Tabs
    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $tabs.Font = New-AmfetaminFont 10 'Bold'
    $tabs.Padding = New-Object System.Drawing.Point(16, 6)
    $form.Controls.Add($tabs)
    $tabs.BringToFront()

    function Style-TabPage($page) {
        $page.BackColor = $t.BgDeep
        $page.ForeColor = $t.Text
    }

    # === DASHBOARD ===
    $tabDash = New-Object System.Windows.Forms.TabPage
    $tabDash.Text = '  Panel  '
    Style-TabPage $tabDash
    $tabs.TabPages.Add($tabDash)

    $pillNpcap = New-StatusPill -Parent $tabDash -Title 'Npcap' -Location (New-Object System.Drawing.Point(16, 16)) -Width 155
    $pillMotor = New-StatusPill -Parent $tabDash -Title 'Motor' -Location (New-Object System.Drawing.Point(180, 16)) -Width 155
    $pillAuto = New-StatusPill -Parent $tabDash -Title 'Otomatik' -Location (New-Object System.Drawing.Point(344, 16)) -Width 155
    $pillDiscord = New-StatusPill -Parent $tabDash -Title 'Discord' -Location (New-Object System.Drawing.Point(508, 16)) -Width 155

    $warnPanel = New-AmfetaminRoundedPanel -BackColor ([System.Drawing.Color]::FromArgb(50, 35, 20))
    $warnPanel.Size = New-Object System.Drawing.Size(648, 36)
    $warnPanel.Location = New-Object System.Drawing.Point(16, 98)
    $warnPanel.Visible = $false
    $tabDash.Controls.Add($warnPanel)
    $warnLbl = New-Object System.Windows.Forms.Label
    $warnLbl.Text = '⚠ ZeroTier calisiyor — cakisma yapabilir, kapatmaniz onerilir'
    $warnLbl.ForeColor = $t.Warning
    $warnLbl.BackColor = [System.Drawing.Color]::Transparent
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
    $infoBox.Location = New-Object System.Drawing.Point(16, 142)
    $infoBox.Size = New-Object System.Drawing.Size(648, 80)
    $tabDash.Controls.Add($infoBox)

    $btnInstall = New-AmfetaminButton -Text 'CIHAZA KUR  ·  otomatik baslat' `
        -Bg $t.AccentGlow -HoverBg $t.Accent -Size (New-Object System.Drawing.Size(648, 48)) `
        -Location (New-Object System.Drawing.Point(16, 234)) -OnClick {}
    $tabDash.Controls.Add($btnInstall)

    $btnStart = New-AmfetaminButton -Text 'SIMDI BASLAT' -Bg $t.Purple -HoverBg $t.Pink `
        -Size (New-Object System.Drawing.Size(210, 42)) -Location (New-Object System.Drawing.Point(16, 292)) -OnClick {}
    $tabDash.Controls.Add($btnStart)

    $btnStop = New-AmfetaminButton -Text 'DURDUR' -Bg ([System.Drawing.Color]::FromArgb(60, 60, 85)) `
        -HoverBg ([System.Drawing.Color]::FromArgb(80, 80, 110)) `
        -Size (New-Object System.Drawing.Size(210, 42)) -Location (New-Object System.Drawing.Point(235, 292)) -OnClick {}
    $tabDash.Controls.Add($btnStop)

    $btnCleanup = New-AmfetaminButton -Text 'TEMIZLIK' -Bg ([System.Drawing.Color]::FromArgb(90, 65, 30)) `
        -HoverBg $t.Warning `
        -Size (New-Object System.Drawing.Size(210, 42)) -Location (New-Object System.Drawing.Point(454, 292)) -OnClick {}
    $tabDash.Controls.Add($btnCleanup)

    $btnTest = New-AmfetaminButton -Text 'BAGLANTI TESTI' -Bg $t.BgCard -HoverBg $t.BgCardHover `
        -Size (New-Object System.Drawing.Size(210, 38)) -Location (New-Object System.Drawing.Point(16, 344)) -OnClick {}
    $tabDash.Controls.Add($btnTest)

    $btnTtl = New-AmfetaminButton -Text 'TTL YENIDEN AYARLA' -Bg $t.BgCard -HoverBg $t.BgCardHover `
        -Size (New-Object System.Drawing.Size(210, 38)) -Location (New-Object System.Drawing.Point(235, 344)) -OnClick {}
    $tabDash.Controls.Add($btnTtl)

    $btnNpcap = New-AmfetaminButton -Text 'NPCAP KUR' -Bg $t.BgCard -HoverBg $t.BgCardHover `
        -Size (New-Object System.Drawing.Size(210, 38)) -Location (New-Object System.Drawing.Point(454, 344)) -OnClick {}
    $tabDash.Controls.Add($btnNpcap)

    # === LOGS ===
    $tabLogs = New-Object System.Windows.Forms.TabPage
    $tabLogs.Text = '  Loglar  '
    Style-TabPage $tabLogs
    $tabs.TabPages.Add($tabLogs)

    $logFilter = New-Object System.Windows.Forms.ComboBox
    $logFilter.Location = New-Object System.Drawing.Point(16, 12)
    $logFilter.Size = New-Object System.Drawing.Size(180, 28)
    $logFilter.DropDownStyle = 'DropDownList'
    $logFilter.BackColor = $t.BgCard
    $logFilter.ForeColor = $t.Text
    @('app.log', 'errors.log', 'audit.log', 'launcher.log', 'amfetamin-run.log', 'service.log') | ForEach-Object {
        [void]$logFilter.Items.Add($_)
    }
    $logFilter.SelectedIndex = 0
    $tabLogs.Controls.Add($logFilter)

    $logAuto = New-Object System.Windows.Forms.CheckBox
    $logAuto.Text = 'Canli izle'
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
    $logBox.Location = New-Object System.Drawing.Point(16, 48)
    $logBox.Size = New-Object System.Drawing.Size(648, 360)
    $tabLogs.Controls.Add($logBox)

    $btnLogRefresh = New-AmfetaminButton -Text 'Yenile' -Bg $t.BgCard -HoverBg $t.BgCardHover `
        -Size (New-Object System.Drawing.Size(100, 34)) -Location (New-Object System.Drawing.Point(16, 418)) -OnClick {}
    $tabLogs.Controls.Add($btnLogRefresh)

    $btnLogExport = New-AmfetaminButton -Text 'ZIP Disa Aktar' -Bg $t.Purple -HoverBg $t.Pink `
        -Size (New-Object System.Drawing.Size(140, 34)) -Location (New-Object System.Drawing.Point(124, 418)) -OnClick {}
    $tabLogs.Controls.Add($btnLogExport)

    $btnLogClear = New-AmfetaminButton -Text 'Temizle' -Bg ([System.Drawing.Color]::FromArgb(80, 40, 45)) `
        -HoverBg $t.Danger `
        -Size (New-Object System.Drawing.Size(100, 34)) -Location (New-Object System.Drawing.Point(272, 418)) -OnClick {}
    $tabLogs.Controls.Add($btnLogClear)

    # === SETTINGS ===
    $tabSet = New-Object System.Windows.Forms.TabPage
    $tabSet.Text = '  Ayarlar  '
    Style-TabPage $tabSet
    $tabs.TabPages.Add($tabSet)

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
    $setDoh.BackColor = $t.BgCard
    $setDoh.ForeColor = $t.Text
    @('cloudflare', 'google', 'quad9') | ForEach-Object { [void]$setDoh.Items.Add($_) }
    $tabSet.Controls.Add($setDoh)
    $y += 62

    Add-SettingLabel 'fakeTtl (TTL degeri)' ($y)
    $setTtl = New-Object System.Windows.Forms.NumericUpDown
    $setTtl.Location = New-Object System.Drawing.Point(20, ($y + 22))
    $setTtl.Size = New-Object System.Drawing.Size(120, 28)
    $setTtl.Minimum = 1; $setTtl.Maximum = 64; $setTtl.Value = 8
    $setTtl.BackColor = $t.BgCard; $setTtl.ForeColor = $t.Text
    $tabSet.Controls.Add($setTtl)
    $y += 62

    $setAutoTune = New-Object System.Windows.Forms.CheckBox
    $setAutoTune.Text = 'Ilk kurulumda otomatik TTL ayari'
    $setAutoTune.ForeColor = $t.Text; $setAutoTune.BackColor = $t.BgDeep
    $setAutoTune.Location = New-Object System.Drawing.Point(20, $y); $setAutoTune.AutoSize = $true
    $tabSet.Controls.Add($setAutoTune)
    $y += 32

    $setWarmup = New-Object System.Windows.Forms.CheckBox
    $setWarmup.Text = 'Baslangicta isinma (warmup) istekleri'
    $setWarmup.ForeColor = $t.Text; $setWarmup.BackColor = $t.BgDeep
    $setWarmup.Location = New-Object System.Drawing.Point(20, $y); $setWarmup.AutoSize = $true
    $tabSet.Controls.Add($setWarmup)
    $y += 32

    $setVerbose = New-Object System.Windows.Forms.CheckBox
    $setVerbose.Text = 'Motor verbose log'
    $setVerbose.ForeColor = $t.Text; $setVerbose.BackColor = $t.BgDeep
    $setVerbose.Location = New-Object System.Drawing.Point(20, $y); $setVerbose.AutoSize = $true
    $tabSet.Controls.Add($setVerbose)
    $y += 48

    $btnSaveSettings = New-AmfetaminButton -Text 'AYARLARI KAYDET' -Bg $t.AccentGlow -HoverBg $t.Accent `
        -Size (New-Object System.Drawing.Size(300, 42)) -Location (New-Object System.Drawing.Point(20, $y)) -OnClick {}
    $tabSet.Controls.Add($btnSaveSettings)

    # === DIAGNOSTICS ===
    $tabDiag = New-Object System.Windows.Forms.TabPage
    $tabDiag.Text = '  Teshis  '
    Style-TabPage $tabDiag
    $tabs.TabPages.Add($tabDiag)

    $diagBox = New-Object System.Windows.Forms.TextBox
    $diagBox.Multiline = $true
    $diagBox.ReadOnly = $true
    $diagBox.ScrollBars = 'Vertical'
    $diagBox.BackColor = $t.BgCard
    $diagBox.ForeColor = $t.Text
    $diagBox.Font = New-Object System.Drawing.Font('Consolas', 9)
    $diagBox.Location = New-Object System.Drawing.Point(16, 16)
    $diagBox.Size = New-Object System.Drawing.Size(648, 380)
    $tabDiag.Controls.Add($diagBox)

    $btnDiagRun = New-AmfetaminButton -Text 'TESHIS CALISTIR' -Bg $t.Purple -HoverBg $t.Pink `
        -Size (New-Object System.Drawing.Size(180, 38)) -Location (New-Object System.Drawing.Point(16, 408)) -OnClick {}
    $tabDiag.Controls.Add($btnDiagRun)

    $btnDiagSave = New-AmfetaminButton -Text 'RAPOR KAYDET' -Bg $t.BgCard -HoverBg $t.BgCardHover `
        -Size (New-Object System.Drawing.Size(180, 38)) -Location (New-Object System.Drawing.Point(210, 408)) -OnClick {}
    $tabDiag.Controls.Add($btnDiagSave)

    $btnDiagFolder = New-AmfetaminButton -Text 'LOG KLASORU AC' -Bg $t.BgCard -HoverBg $t.BgCardHover `
        -Size (New-Object System.Drawing.Size(180, 38)) -Location (New-Object System.Drawing.Point(404, 408)) -OnClick {}
    $tabDiag.Controls.Add($btnDiagFolder)

    # === ABOUT ===
    $tabAbout = New-Object System.Windows.Forms.TabPage
    $tabAbout.Text = '  Hakkinda  '
    Style-TabPage $tabAbout
    $tabs.TabPages.Add($tabAbout)

    $aboutText = @"
amfetamin — Windows DPI bypass

by furkandvrc
https://github.com/furkandvrc/amfetamin

WinDivert kullanmaz · Rust / EAC uyumlu
Npcap ile calisir · Otomatik TTL ayari

Discord web icin:
  • QUIC devre disi (chrome://flags)
  • Guvenli DNS kapali
  • ZeroTier/VPN kapali

Kurulum: %LOCALAPPDATA%\Amfetamin\
"@

    $aboutLbl = New-Object System.Windows.Forms.Label
    $aboutLbl.Text = $aboutText
    $aboutLbl.ForeColor = $t.TextMuted
    $aboutLbl.BackColor = $t.BgDeep
    $aboutLbl.Font = New-AmfetaminFont 10
    $aboutLbl.Location = New-Object System.Drawing.Point(24, 24)
    $aboutLbl.Size = New-Object System.Drawing.Size(640, 280)
    $tabAbout.Controls.Add($aboutLbl)

    $btnUpdate = New-AmfetaminButton -Text 'GUNCELLEME KONTROL' -Bg $t.AccentGlow -HoverBg $t.Accent `
        -Size (New-Object System.Drawing.Size(220, 40)) -Location (New-Object System.Drawing.Point(24, 320)) -OnClick {}
    $tabAbout.Controls.Add($btnUpdate)

    $btnUninstall = New-AmfetaminButton -Text 'CIHAZDAN KALDIR' -Bg ([System.Drawing.Color]::FromArgb(90, 35, 45)) `
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

    # --- Helpers ---
    function Update-Dashboard {
        try {
            $s = Get-AmfetaminStatus
            $ok = $t.Success; $no = $t.Danger; $mid = $t.Warning

            $pillNpcap.Dot.ForeColor = if ($s.NpcapInstalled) { $ok } else { $no }
            $pillNpcap.Value.Text = if ($s.NpcapInstalled) { 'Kurulu' } else { 'Eksik' }

            $pillMotor.Dot.ForeColor = if ($s.EngineRunning) { $ok } else { if ($s.EngineDownloaded) { $mid } else { $no } }
            $pillMotor.Value.Text = if ($s.EngineRunning) {
                if ($s.Process) { "PID $($s.Process.Pid)" } else { 'Aktif' }
            } elseif ($s.EngineDownloaded) { 'Hazir' } else { 'Yok' }

            $pillAuto.Dot.ForeColor = if ($s.AutoStartInstalled) { $ok } else { $no }
            $pillAuto.Value.Text = if ($s.AutoStartInstalled) { 'Aktif' } else { 'Yok' }

            if ($s.EngineRunning) {
                $liveDot.Text = [char]0x25CF + '  AKTIF'
                $liveDot.ForeColor = $t.Success
            } else {
                $liveDot.Text = [char]0x25CF + '  KAPALI'
                $liveDot.ForeColor = $t.Danger
            }

            $warnPanel.Visible = [bool]$s.ZeroTierRunning

            $lines = @(
                "Surum: v$($s.Version)  |  TTL: $($s.FakeTtl)  |  autoTune: $(if ($s.AutoTuneDone) {'tamam'} else {'bekliyor'})",
                "Kurulum: $($s.InstallRoot)"
            )
            if ($s.Process) {
                $lines += "Bellek: $($s.Process.MemoryMb) MB"
            }
            $infoBox.Text = ($lines -join "`r`n")
        } catch {
            Write-AmfetaminError -Message 'Dashboard guncelleme hatasi' -Exception $_.Exception
        }
    }

    function Refresh-LogView {
        $name = [string]$logFilter.SelectedItem
        if (-not $name) { return }
        $lines = Get-AmfetaminLogTail -LogName $name -Lines 300
        $logBox.Text = ($lines -join "`r`n")
        $logBox.SelectionStart = $logBox.Text.Length
        $logBox.ScrollToCaret()
    }

    function Load-Settings {
        try {
            $cfg = Get-Config
            $setDoh.SelectedItem = [string]$cfg.dohUpstream
            if (-not $setDoh.SelectedItem) { $setDoh.SelectedIndex = 0 }
            $setTtl.Value = [decimal](if ($cfg.fakeTtl) { [int]$cfg.fakeTtl } else { 8 })
            $setAutoTune.Checked = -not ($cfg.autoTuneTtl -eq $false)
            $setWarmup.Checked = -not ($cfg.warmup -eq $false)
            $setVerbose.Checked = -not ($cfg.engineVerbose -eq $false)
        } catch {}
    }

    function Invoke-UiAction {
        param(
            [scriptblock]$Action,
            [string]$SuccessMsg = $null
        )
        try {
            $result = & $Action
            Update-Dashboard
            if ($SuccessMsg) {
                Show-AmfetaminToast -Form $form -Bar $toast -Message $SuccessMsg -Color $t.Success
            } elseif ($result) {
                Show-AmfetaminToast -Form $form -Bar $toast -Message ($result.ToString().Split("`n")[0]) -Color $t.Success
            }
            Refresh-LogView
        } catch {
            Write-AmfetaminError -Message 'UI islem hatasi' -Exception $_.Exception
            Show-AmfetaminToast -Form $form -Bar $toast -Message $_.Exception.Message -Color $t.Danger
            [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'amfetamin', 'OK', 'Error')
        }
    }

    # Wire events
    $btnInstall.Add_Click({
        $wiz = New-Object System.Windows.Forms.Form
        $wiz.Text = 'amfetamin — Kurulum'
        $wiz.Size = New-Object System.Drawing.Size(520, 400)
        $wiz.StartPosition = 'CenterScreen'
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
            try {
                $result = Install-ToDevice -Progress $progressFn
                $wBar.Style = 'Continuous'; $wBar.Value = 100
                $wLog.AppendText("`r`n$result`r`n")
                Write-AmfetaminLog -Message 'Kurulum wizard tamamlandi' -Level INFO
                Start-Sleep -Milliseconds 400
                [void][System.Windows.Forms.MessageBox]::Show($result, 'amfetamin', 'OK', 'Information')
                $wiz.DialogResult = 'OK'
                $wiz.Close()
            } catch {
                $wLog.AppendText("HATA: $($_.Exception.Message)`r`n")
                Write-AmfetaminError -Message 'Kurulum hatasi' -Exception $_.Exception
                [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'amfetamin', 'OK', 'Error')
                $wiz.Close()
            }
        })
        [void]$wiz.ShowDialog()
        Update-Dashboard
        Refresh-LogView
    })

    $btnStart.Add_Click({ Invoke-UiAction { Install-And-Start } })
    $btnStop.Add_Click({ Invoke-UiAction { Stop-Amfetamin } })
    $btnNpcap.Add_Click({ Invoke-UiAction { Install-NpcapGui } })

    $btnCleanup.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show(
            "Tam temizlik:`n- Motor durur`n- Route/DNS geri alinir`n- Otomatik baslatma silinir",
            'amfetamin', 'YesNo', 'Warning')
        if ($r -eq 'Yes') { Invoke-UiAction { Invoke-AmfetaminCleanup } }
    })

    $btnTest.Add_Click({
        Invoke-UiAction {
            $results = Test-AmfetaminConnectivity
            ($results | ForEach-Object {
                $st = if ($_.Ok) { "OK $($_.StatusCode)" } else { 'FAIL' }
                "$($_.Url): $st ($($_.Ms)ms)"
            }) -join "`n"
        }
    })

    $btnTtl.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show(
            'TTL yeniden ayarlanacak (discord.com test). Devam?',
            'amfetamin', 'YesNo', 'Question')
        if ($r -eq 'Yes') {
            $wiz = New-Object System.Windows.Forms.Form
            $wiz.Text = 'TTL Ayari'; $wiz.Size = New-Object System.Drawing.Size(440, 220)
            $wiz.StartPosition = 'CenterScreen'; $wiz.BackColor = $t.BgDeep
            $wl = New-Object System.Windows.Forms.Label
            $wl.Text = 'TTL ayarlaniyor, lutfen bekleyin...'
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
                try {
                    $msg = Invoke-ManualTtlRetune -Progress { param($m) $statusL.Text = $m; [System.Windows.Forms.Application]::DoEvents() }
                    [void][System.Windows.Forms.MessageBox]::Show($msg, 'amfetamin')
                    $wiz.Close()
                } catch {
                    [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'amfetamin', 'OK', 'Error')
                    $wiz.Close()
                }
            })
            [void]$wiz.ShowDialog()
            Update-Dashboard
        }
    })

    $btnLogRefresh.Add_Click({ Refresh-LogView })
    $logFilter.Add_SelectedIndexChanged({ Refresh-LogView })
    $btnLogExport.Add_Click({
        try {
            $path = Export-AmfetaminLogs
            Show-AmfetaminToast -Form $form -Bar $toast -Message "Kaydedildi: $path" -Color $t.Success
            Start-Process explorer.exe "/select,`"$path`""
        } catch {
            Show-AmfetaminToast -Form $form -Bar $toast -Message $_.Exception.Message -Color $t.Danger
        }
    })
    $btnLogClear.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show('Tum loglar silinecek. Emin misiniz?', 'amfetamin', 'YesNo', 'Warning')
        if ($r -eq 'Yes') { Clear-AmfetaminLogs; Refresh-LogView }
    })

    $btnSaveSettings.Add_Click({
        Invoke-UiAction {
            Save-AmfetaminSettings -DohUpstream $setDoh.SelectedItem -FakeTtl ([int]$setTtl.Value) `
                -AutoTuneTtl $setAutoTune.Checked -Warmup $setWarmup.Checked -EngineVerbose $setVerbose.Checked
        }
    })

    $btnDiagRun.Add_Click({
        $diagBox.Text = 'Teshis calisiyor...'
        [System.Windows.Forms.Application]::DoEvents()
        try {
            $diagBox.Text = Get-AmfetaminDiagnosticReport -Quiet
            Write-AmfetaminLog -Message 'Teshis UI calistirildi' -Level INFO
        } catch {
            $diagBox.Text = $_.Exception.Message
        }
    })

    $btnDiagSave.Add_Click({
        try {
            $p = Save-AmfetaminDiagnosticReport
            Show-AmfetaminToast -Form $form -Bar $toast -Message "Rapor: $p" -Color $t.Success
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
        $updateLbl.Text = 'Kontrol ediliyor...'
        [System.Windows.Forms.Application]::DoEvents()
        $info = Get-AmfetaminUpdateInfo
        if (-not $info) {
            $updateLbl.Text = 'Guncelleme kontrolu basarisiz'
            return
        }
        if ($info.UpdateAvailable) {
            $updateLbl.Text = "Yeni surum: v$($info.Latest) (sizde v$($info.Current))"
            $r = [System.Windows.Forms.MessageBox]::Show(
                "v$($info.Latest) mevcut. Indirme sayfasini acayim mi?",
                'amfetamin', 'YesNo', 'Information')
            if ($r -eq 'Yes' -and $info.DownloadUrl) {
                Start-Process $info.DownloadUrl
            }
        } else {
            $updateLbl.Text = "Guncel siniz (v$($info.Current))"
        }
    })

    $btnUninstall.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show(
            'amfetamin kaldirilacak. Emin misiniz?',
            'amfetamin', 'YesNo', 'Warning')
        if ($r -eq 'Yes') { Invoke-UiAction { Uninstall-FromDevice } }
    })

    # System tray
    $trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $trayMenu.BackColor = $t.BgPanel
    $miShow = $trayMenu.Items.Add('Goster')
    $miDash = $trayMenu.Items.Add('Durum')
    $trayMenu.Items.Add('-') | Out-Null
    $miExit = $trayMenu.Items.Add('Cikis')

    $tray = New-Object System.Windows.Forms.NotifyIcon
    $tray.Text = 'amfetamin'
    if ($icon) { $tray.Icon = $icon } else { $tray.Icon = [System.Drawing.SystemIcons]::Shield }
    $tray.ContextMenuStrip = $trayMenu
    $tray.Visible = $true
    $Script:UiState.TrayIcon = $tray

    $miShow.Add_Click({ $form.Show(); $form.WindowState = 'Normal'; $form.BringToFront() })
    $miDash.Add_Click({ Update-Dashboard; $form.Show() })
    $miExit.Add_Click({
        $tray.Visible = $false
        $tray.Dispose()
        $form.Close()
    })
    $tray.Add_DoubleClick({ $form.Show(); $form.WindowState = 'Normal' })

    $form.Add_Resize({
        if ($form.WindowState -eq 'Minimized') {
            $form.Hide()
            $tray.ShowBalloonTip(2000, 'amfetamin', 'Arka planda calisiyor — tepsiden acin', 'Info')
        }
    })

    # Live timers
    $statusTimer = New-Object System.Windows.Forms.Timer
    $statusTimer.Interval = 3000
    $statusTimer.Add_Tick({ Update-Dashboard })
    $statusTimer.Start()
    $Script:UiState.StatusTimer = $statusTimer

    $logTimer = New-Object System.Windows.Forms.Timer
    $logTimer.Interval = 2000
    $logTimer.Add_Tick({
        if ($tabs.SelectedTab -eq $tabLogs -and $logAuto.Checked) { Refresh-LogView }
    })
    $logTimer.Start()
    $Script:UiState.LogTimer = $logTimer

    Register-LogSubscriber {
        param($line, $level)
        if ($tabs.SelectedTab -eq $tabLogs -and $logAuto.Checked) {
            try { Refresh-LogView } catch {}
        }
    }

    $form.Add_FormClosed({
        if ($Script:UiState.StatusTimer) { $Script:UiState.StatusTimer.Stop() }
        if ($Script:UiState.LogTimer) { $Script:UiState.LogTimer.Stop() }
        if ($Script:UiState.TrayIcon) {
            $Script:UiState.TrayIcon.Visible = $false
            $Script:UiState.TrayIcon.Dispose()
        }
        Write-AmfetaminLog -Message 'Ana pencere kapatildi' -Level INFO -Audit
    })

    Load-Settings
    Update-Dashboard
    Refresh-LogView
    Write-AmfetaminLog -Message 'Ana arayuz acildi' -Level INFO -Audit

    [void]$form.ShowDialog()
}
