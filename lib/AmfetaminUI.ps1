# amfetamin — UI (splash + ana pencere)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Script:AmfetaminTheme = @{
    BgDeep     = [System.Drawing.Color]::FromArgb(10, 10, 16)
    BgPanel    = [System.Drawing.Color]::FromArgb(22, 22, 34)
    BgCard     = [System.Drawing.Color]::FromArgb(30, 30, 48)
    Accent     = [System.Drawing.Color]::FromArgb(0, 255, 200)
    AccentDim  = [System.Drawing.Color]::FromArgb(0, 180, 140)
    Purple     = [System.Drawing.Color]::FromArgb(140, 90, 255)
    Text       = [System.Drawing.Color]::FromArgb(240, 240, 250)
    TextMuted  = [System.Drawing.Color]::FromArgb(150, 150, 170)
    Danger     = [System.Drawing.Color]::FromArgb(220, 70, 90)
    Warning    = [System.Drawing.Color]::FromArgb(255, 170, 50)
    Success    = [System.Drawing.Color]::FromArgb(60, 210, 130)
}

function New-AmfetaminFont($size, $style = 'Regular') {
    $fs = [System.Drawing.FontStyle]::Regular
    if ($style -eq 'Bold') { $fs = [System.Drawing.FontStyle]::Bold }
    if ($style -eq 'Italic') { $fs = [System.Drawing.FontStyle]::Italic }
    return New-Object System.Drawing.Font('Segoe UI', $size, $fs)
}

function Set-AmfetaminFormStyle($form, $title) {
    $form.Text = $title
    $form.BackColor = $Script:AmfetaminTheme.BgDeep
    $form.ForeColor = $Script:AmfetaminTheme.Text
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
}

function Show-AmfetaminSplash {
    $splash = New-Object System.Windows.Forms.Form
    $splash.FormBorderStyle = 'None'
    $splash.Size = New-Object System.Drawing.Size(520, 340)
    $splash.StartPosition = 'CenterScreen'
    $splash.BackColor = $Script:AmfetaminTheme.BgDeep
    $splash.TopMost = $true
    $splash.Opacity = 0
    $splash.ShowInTaskbar = $false

    $topBar = New-Object System.Windows.Forms.Panel
    $topBar.Size = New-Object System.Drawing.Size(520, 4)
    $topBar.Location = New-Object System.Drawing.Point(0, 0)
    $topBar.BackColor = $Script:AmfetaminTheme.Accent
    $splash.Controls.Add($topBar)

    $accentLine = New-Object System.Windows.Forms.Panel
    $accentLine.Size = New-Object System.Drawing.Size(4, 200)
    $accentLine.Location = New-Object System.Drawing.Point(0, 40)
    $accentLine.BackColor = $Script:AmfetaminTheme.Purple
    $splash.Controls.Add($accentLine)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'amfetamin'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 42, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = $Script:AmfetaminTheme.Accent
    $title.BackColor = $Script:AmfetaminTheme.BgDeep
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(48, 72)
    $splash.Controls.Add($title)

    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Text = 'DPI bypass  ·  Discord  ·  EAC uyumlu'
    $subtitle.Font = New-AmfetaminFont 11
    $subtitle.ForeColor = $Script:AmfetaminTheme.TextMuted
    $subtitle.BackColor = $Script:AmfetaminTheme.BgDeep
    $subtitle.AutoSize = $true
    $subtitle.Location = New-Object System.Drawing.Point(52, 138)
    $splash.Controls.Add($subtitle)

    $progress = New-Object System.Windows.Forms.ProgressBar
    $progress.Style = 'Continuous'
    $progress.Size = New-Object System.Drawing.Size(424, 8)
    $progress.Location = New-Object System.Drawing.Point(48, 210)
    $progress.Maximum = 100
    $splash.Controls.Add($progress)

    $status = New-Object System.Windows.Forms.Label
    $status.Text = 'Baslatiliyor...'
    $status.Font = New-AmfetaminFont 9.5
    $status.ForeColor = $Script:AmfetaminTheme.Text
    $status.BackColor = $Script:AmfetaminTheme.BgDeep
    $status.AutoSize = $true
    $status.Location = New-Object System.Drawing.Point(48, 228)
    $splash.Controls.Add($status)

    $credit = New-Object System.Windows.Forms.Label
    $credit.Text = 'by furkandvrc'
    $credit.Font = New-AmfetaminFont 10 'Italic'
    $credit.ForeColor = $Script:AmfetaminTheme.Purple
    $credit.BackColor = $Script:AmfetaminTheme.BgDeep
    $credit.AutoSize = $true
    $credit.Location = New-Object System.Drawing.Point(48, 288)
    $splash.Controls.Add($credit)

    $version = New-Object System.Windows.Forms.Label
    $version.Text = 'v1.1.2'
    $version.Font = New-AmfetaminFont 8
    $version.ForeColor = $Script:AmfetaminTheme.TextMuted
    $version.BackColor = $Script:AmfetaminTheme.BgDeep
    $version.AutoSize = $true
    $version.Location = New-Object System.Drawing.Point(400, 292)
    $splash.Controls.Add($version)

    $steps = @(
        @{ pct = 15; msg = 'Yetkiler dogrulaniyor...' },
        @{ pct = 35; msg = 'Npcap kontrol ediliyor...' },
        @{ pct = 55; msg = 'Durum okunuyor...' },
        @{ pct = 75; msg = 'Arayuz hazirlaniyor...' },
        @{ pct = 100; msg = 'Hazir' }
    )

    $splash.Add_Shown({
        for ($o = 0.15; $o -le 1; $o += 0.15) {
            $splash.Opacity = $o
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 15
        }
        foreach ($s in $steps) {
            $progress.Value = $s.pct
            $status.Text = $s.msg
            if ($s.pct -eq 55) {
                try {
                    $st = Get-AmfetaminStatus
                    $status.Text = "amfetamin: $(if ($st.EngineRunning) {'aktif'} else {'kapali'})  ·  Npcap: $(if ($st.NpcapInstalled) {'tamam'} else {'eksik'})"
                } catch {}
            }
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 120
        }
        for ($o = 1; $o -ge 0; $o -= 0.2) {
            $splash.Opacity = [Math]::Max(0, $o)
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 15
        }
        $splash.Close()
    })

    [void]$splash.ShowDialog()
}

function Show-AmfetaminInstallWizard {
    param([scriptblock]$InstallAction)

    $wiz = New-Object System.Windows.Forms.Form
    Set-AmfetaminFormStyle $wiz 'amfetamin - Kurulum'
    $wiz.Size = New-Object System.Drawing.Size(480, 320)

    $hdr = New-Object System.Windows.Forms.Label
    $hdr.Text = 'Cihaza kuruluyor'
    $hdr.Font = New-AmfetaminFont 16 'Bold'
    $hdr.ForeColor = $Script:AmfetaminTheme.Accent
    $hdr.Location = New-Object System.Drawing.Point(24, 20)
    $hdr.AutoSize = $true
    $wiz.Controls.Add($hdr)

    $log = New-Object System.Windows.Forms.TextBox
    $log.Multiline = $true
    $log.ReadOnly = $true
    $log.ScrollBars = 'Vertical'
    $log.BorderStyle = 'None'
    $log.BackColor = $Script:AmfetaminTheme.BgCard
    $log.ForeColor = $Script:AmfetaminTheme.Text
    $log.Font = New-AmfetaminFont 9
    $log.Location = New-Object System.Drawing.Point(24, 58)
    $log.Size = New-Object System.Drawing.Size(416, 160)
    $wiz.Controls.Add($log)

    $bar = New-Object System.Windows.Forms.ProgressBar
    $bar.Style = 'Marquee'
    $bar.MarqueeAnimationSpeed = 30
    $bar.Location = New-Object System.Drawing.Point(24, 230)
    $bar.Size = New-Object System.Drawing.Size(416, 10)
    $wiz.Controls.Add($bar)

    $wiz.Add_Shown({
        $log.AppendText("> Dosyalar hazirlaniyor...`r`n")
        [System.Windows.Forms.Application]::DoEvents()
        $log.AppendText("> Npcap kontrol ediliyor...`r`n")
        [System.Windows.Forms.Application]::DoEvents()
        try {
            $log.AppendText("> Eksik bilesenler kuruluyor...`r`n")
            [System.Windows.Forms.Application]::DoEvents()
            $log.AppendText("> amfetamin indiriliyor / dogrulaniyor...`r`n")
            [System.Windows.Forms.Application]::DoEvents()
            $result = & $InstallAction
            $bar.Style = 'Continuous'
            $bar.Value = 100
            $log.AppendText("> Tamamlandi!`r`n`r`n")
            foreach ($line in ($result -split "`n")) {
                if ($line.Trim()) { $log.AppendText("$line`r`n") }
            }
            Start-Sleep -Milliseconds 600
            [void][System.Windows.Forms.MessageBox]::Show($result, 'amfetamin', 'OK', 'Information')
            $wiz.DialogResult = 'OK'
            $wiz.Close()
        } catch {
            $log.AppendText("> HATA: $($_.Exception.Message)`r`n")
            [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'amfetamin', 'OK', 'Error')
            $wiz.DialogResult = 'Cancel'
            $wiz.Close()
        }
    })

    [void]$wiz.ShowDialog()
}

function Show-AmfetaminMainForm {
    $form = New-Object System.Windows.Forms.Form
    Set-AmfetaminFormStyle $form 'amfetamin'
    $form.Size = New-Object System.Drawing.Size(460, 520)

    $header = New-Object System.Windows.Forms.Panel
    $header.Size = New-Object System.Drawing.Size(444, 88)
    $header.Location = New-Object System.Drawing.Point(8, 8)
    $header.BackColor = $Script:AmfetaminTheme.BgPanel
    $form.Controls.Add($header)

    $logo = New-Object System.Windows.Forms.Label
    $logo.Text = 'amfetamin'
    $logo.Font = New-Object System.Drawing.Font('Segoe UI', 26, [System.Drawing.FontStyle]::Bold)
    $logo.ForeColor = $Script:AmfetaminTheme.Accent
    $logo.BackColor = $Script:AmfetaminTheme.BgPanel
    $logo.AutoSize = $true
    $logo.Location = New-Object System.Drawing.Point(16, 12)
    $header.Controls.Add($logo)

    $tagline = New-Object System.Windows.Forms.Label
    $tagline.Text = 'tek tik  ·  otomatik  ·  WinDivert yok'
    $tagline.Font = New-AmfetaminFont 9
    $tagline.ForeColor = $Script:AmfetaminTheme.TextMuted
    $tagline.BackColor = $Script:AmfetaminTheme.BgPanel
    $tagline.AutoSize = $true
    $tagline.Location = New-Object System.Drawing.Point(18, 52)
    $header.Controls.Add($tagline)

    $card = New-Object System.Windows.Forms.Panel
    $card.Size = New-Object System.Drawing.Size(444, 108)
    $card.Location = New-Object System.Drawing.Point(8, 104)
    $card.BackColor = $Script:AmfetaminTheme.BgCard
    $form.Controls.Add($card)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(16, 12)
    $statusLabel.Size = New-Object System.Drawing.Size(412, 88)
    $statusLabel.Font = New-AmfetaminFont 9.5
    $statusLabel.ForeColor = $Script:AmfetaminTheme.Text
    $statusLabel.BackColor = $Script:AmfetaminTheme.BgCard
    $card.Controls.Add($statusLabel)

    function Update-Status {
        $s = Get-AmfetaminStatus
        $dot = { param($ok) if ($ok) { [char]0x25CF } else { [char]0x25CB } }
        $statusLabel.Text = @(
            "$(& $dot $s.NpcapInstalled)  Npcap        $(if ($s.NpcapInstalled) {'kurulu'} else {'eksik'})",
            "$(& $dot $s.EngineDownloaded)  Motor        $(if ($s.EngineDownloaded) {'hazir'} else {'indirilecek'})",
            "$(& $dot $s.EngineRunning)  Durum        $(if ($s.EngineRunning) {'calisiyor'} else {'kapali'})",
            "$(& $dot $s.AutoStartInstalled)  Otomatik     $(if ($s.AutoStartInstalled) {'her acilista'} else {'kurulmadi'})"
        ) -join "`n"
    }
    Update-Status

    function Show-Result($msg) {
        [void][System.Windows.Forms.MessageBox]::Show($msg, 'amfetamin', 'OK', 'Information')
        Update-Status
    }

    function Add-Btn($text, $y, $bg, $handler, $h = 44) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $text
        $btn.Location = New-Object System.Drawing.Point(8, $y)
        $btn.Size = New-Object System.Drawing.Size(444, $h)
        $btn.Font = New-AmfetaminFont 10 'Bold'
        $btn.BackColor = $bg
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.FlatStyle = 'Flat'
        $btn.FlatAppearance.BorderSize = 0
        $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btn.Add_Click($handler)
        $form.Controls.Add($btn)
    }

    $t = $Script:AmfetaminTheme
    Add-Btn 'CIHAZA KUR  ·  her acilista otomatik' 224 $t.AccentDim {
        Show-AmfetaminInstallWizard { Install-ToDevice }
        Update-Status
    }
    Add-Btn 'SIMDI BASLAT' 276 $t.Purple {
        try { Show-Result (Install-And-Start) } catch { Show-Result $_.Exception.Message }
    }
    Add-Btn 'DURDUR' 328 ([System.Drawing.Color]::FromArgb(55, 55, 75)) {
        try { Show-Result (Stop-Amfetamin) } catch { Show-Result $_.Exception.Message }
    }
    Add-Btn 'NPCAP KUR' 380 ([System.Drawing.Color]::FromArgb(70, 70, 95)) {
        try { Show-Result (Install-NpcapGui) } catch { Show-Result $_.Exception.Message }
    }
    Add-Btn 'TEMIZLIK' 432 $t.Warning {
        try { Show-Result (Invoke-AmfetaminCleanup) } catch { Show-Result $_.Exception.Message }
    } 38

    $footer = New-Object System.Windows.Forms.Label
    $footer.Text = 'by furkandvrc'
    $footer.Font = New-AmfetaminFont 9.5 'Italic'
    $footer.ForeColor = $t.Purple
    $footer.AutoSize = $true
    $footer.Location = New-Object System.Drawing.Point(8, 478)
    $form.Controls.Add($footer)

    $uninstall = New-Object System.Windows.Forms.LinkLabel
    $uninstall.Text = 'cihazdan kaldir'
    $uninstall.LinkColor = $t.Danger
    $uninstall.ActiveLinkColor = $t.Text
    $uninstall.AutoSize = $true
    $uninstall.Location = New-Object System.Drawing.Point(340, 480)
    $uninstall.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show(
            'amfetamin kaldirilacak: servis durur, otomatik baslatma silinir.',
            'amfetamin', 'YesNo', 'Warning')
        if ($r -eq 'Yes') {
            try { Show-Result (Uninstall-FromDevice) } catch { Show-Result $_.Exception.Message }
        }
    })
    $form.Controls.Add($uninstall)

    [void]$form.ShowDialog()
}
