# Gecit Launcher - core functions
$ErrorActionPreference = 'Stop'

$Script:TaskName = 'Amfetamin-AutoStart'
$Script:InstallRoot = Join-Path $env:LOCALAPPDATA 'Amfetamin'
$Script:BinDir = Join-Path $InstallRoot 'bin'
$Script:LogDir = Join-Path $InstallRoot 'logs'
$Script:LibDir = Join-Path $InstallRoot 'lib'
$Script:GecitExe = Join-Path $BinDir 'gecit.exe'
$Script:NpcapInstaller = Join-Path $BinDir 'npcap-installer.exe'
$Script:ConfigPath = Join-Path $InstallRoot 'config.json'
$Script:ServiceScript = Join-Path $LibDir 'run-gecit-service.ps1'
$Script:RunLog = Join-Path $LogDir 'gecit-run.log'
$Script:LauncherLog = Join-Path $LogDir 'launcher.log'
$Script:ServiceLog = Join-Path $LogDir 'service.log'

function Get-ProjectRoot {
    if ($PSScriptRoot -match '\\lib$') {
        return Split-Path $PSScriptRoot -Parent
    }
    return $PSScriptRoot
}

function Get-Config {
    $paths = @(
        $Script:ConfigPath,
        (Join-Path (Get-ProjectRoot) 'config.json')
    )
    foreach ($configPath in $paths) {
        if (Test-Path $configPath) {
            return Get-Content $configPath -Raw | ConvertFrom-Json
        }
    }
    throw 'config.json bulunamadi'
}

function Ensure-Dirs {
    foreach ($d in @($InstallRoot, $BinDir, $LogDir, $LibDir)) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
}

function Write-LauncherLog([string]$Message) {
    Ensure-Dirs
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $Script:LauncherLog -Value $line -Encoding UTF8
}

function Write-ServiceLog([string]$Message) {
    Ensure-Dirs
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $Script:ServiceLog -Value $line -Encoding UTF8
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-Admin([string[]]$ExtraArgs) {
    if (Test-IsAdmin) { return $true }
    $launcher = Join-Path (Get-ProjectRoot) 'Amfetamin.ps1'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$launcher`"")
    if ($ExtraArgs) { $argList += $ExtraArgs }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    return $false
}

function Test-NpcapInstalled {
    if (Test-Path 'C:\Program Files\Npcap') { return $true }
    if (Test-Path 'C:\Windows\System32\Npcap\wpcap.dll') { return $true }
    if (Test-Path 'C:\Windows\System32\wpcap.dll') { return $true }
    return $false
}

function Test-GecitRunning {
    return $null -ne (Get-Process -Name 'gecit' -ErrorAction SilentlyContinue)
}

function Test-AutoStartInstalled {
    $task = Get-ScheduledTask -TaskName $Script:TaskName -ErrorAction SilentlyContinue
    return $null -ne $task
}

function Get-GecitStatus {
    [PSCustomObject]@{
        NpcapInstalled = Test-NpcapInstalled
        GecitDownloaded = Test-Path $Script:GecitExe
        GecitRunning = Test-GecitRunning
        AutoStartInstalled = Test-AutoStartInstalled
        InstallRoot = $Script:InstallRoot
    }
}

function Invoke-DownloadFile([string]$Url, [string]$Dest) {
    Write-LauncherLog "Indiriliyor: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
}

function Install-GecitBinary {
    Ensure-Dirs
    $cfg = Get-Config
    $base = "$($cfg.gecitReleaseBase)/$($cfg.gecitVersion)"
    Invoke-DownloadFile "$base/$($cfg.gecitChecksumFile)" (Join-Path $BinDir 'checksums.txt')
    Invoke-DownloadFile "$base/$($cfg.gecitAsset)" $Script:GecitExe

    $expectedLine = Get-Content (Join-Path $BinDir 'checksums.txt') | Where-Object { $_ -match 'gecit-windows-amd64\.exe' }
    if (-not $expectedLine) { throw 'checksums.txt icinde Windows asset bulunamadi' }
    $expectedHash = ($expectedLine -split '\s+')[0].ToUpperInvariant()
    $actualHash = (Get-FileHash $Script:GecitExe -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($expectedHash -ne $actualHash) {
        Remove-Item $Script:GecitExe -Force -ErrorAction SilentlyContinue
        throw "SHA256 uyusmadi! Beklenen: $expectedHash Alinan: $actualHash"
    }
    Write-LauncherLog 'gecit.exe indirildi ve dogrulandi'
}

function Ensure-GecitBinary {
    if (Test-Path $Script:GecitExe) { return }
    Install-GecitBinary
}

function Sync-LauncherToDevice {
    Ensure-Dirs
    $projectRoot = Get-ProjectRoot
    Copy-Item (Join-Path $projectRoot 'config.json') $Script:ConfigPath -Force
    Copy-Item (Join-Path $projectRoot 'lib\GecitCore.ps1') (Join-Path $LibDir 'GecitCore.ps1') -Force
    Copy-Item (Join-Path $projectRoot 'lib\run-gecit-service.ps1') $Script:ServiceScript -Force
    Copy-Item (Join-Path $projectRoot 'lib\AmfetaminUI.ps1') (Join-Path $LibDir 'AmfetaminUI.ps1') -Force -ErrorAction SilentlyContinue
    Write-LauncherLog 'Launcher dosyalari cihaza kopyalandi'
}

function Install-NpcapGui {
    Ensure-Dirs
    $cfg = Get-Config
    if (-not (Test-Path $Script:NpcapInstaller)) {
        Invoke-DownloadFile $cfg.npcapUrl $Script:NpcapInstaller
    }
    Write-LauncherLog 'Npcap GUI kurulumu baslatiliyor'
    Start-Process -FilePath $Script:NpcapInstaller -Verb RunAs
    return 'Npcap kurulum penceresi acildi. "WinPcap API-compatible Mode" isaretli olsun.'
}

function Start-GecitHidden {
    if (-not (Test-IsAdmin)) { throw 'Yonetici yetkisi gerekli' }
    if (-not (Test-NpcapInstalled)) { throw 'Npcap kurulu degil' }
    Ensure-GecitBinary
    if (Test-GecitRunning) { return 'Gecit zaten calisiyor' }

    $cfg = Get-Config
    $args = "run --doh-upstream $($cfg.dohUpstream)"
    $proc = Start-Process -FilePath $Script:GecitExe -ArgumentList $args -WorkingDirectory $BinDir `
        -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 2
    if (-not $proc.HasExited -and (Test-GecitRunning)) {
        Write-LauncherLog "Gecit arka planda baslatildi (PID $($proc.Id))"
        return 'Gecit arka planda baslatildi'
    }
    if (Test-GecitRunning) { return 'Gecit calisiyor' }
    throw 'Gecit baslatilamadi. logs\gecit-run.log dosyasina bakin'
}

function Start-GecitVisible {
    if (-not (Test-IsAdmin)) { throw 'Yonetici yetkisi gerekli' }
    if (-not (Test-NpcapInstalled)) { throw 'Npcap kurulu degil' }
    Ensure-GecitBinary
    if (Test-GecitRunning) { return 'Gecit zaten calisiyor' }

    $cfg = Get-Config
    $arg = "run --doh-upstream $($cfg.dohUpstream) -v"
    $batch = @"
@echo off
cd /d "$BinDir"
title Gecit - DPI Bypass
echo Gecit calisiyor. Kapatmak icin Ctrl+C
"$GecitExe" $arg
pause
"@
    $batchPath = Join-Path $BinDir 'start-gecit-visible.cmd'
    Set-Content -Path $batchPath -Value $batch -Encoding ASCII
    Start-Process cmd.exe -ArgumentList "/c `"$batchPath`"" -Verb RunAs
    Start-Sleep -Seconds 2
    return 'Gecit konsol penceresi acildi'
}

function Stop-Gecit {
    $procs = Get-Process -Name 'gecit' -ErrorAction SilentlyContinue
    if (-not $procs) { return 'Gecit zaten calismiyor' }
    $procs | Stop-Process -Force
    Write-LauncherLog 'Gecit durduruldu'
    return 'Gecit durduruldu'
}

function Invoke-GecitCleanup {
    if (-not (Test-IsAdmin)) { throw 'Yonetici yetkisi gerekli' }
    Stop-Gecit | Out-Null
    if (Test-Path $Script:GecitExe) {
        & $Script:GecitExe cleanup 2>&1 | Out-Null
    }
    Write-LauncherLog 'cleanup tamamlandi'
    return 'DNS ve route ayarlari geri alindi'
}

function Register-AutoStartTask {
    if (-not (Test-IsAdmin)) { throw 'Yonetici yetkisi gerekli' }
    Sync-LauncherToDevice
    Ensure-GecitBinary

    $existing = Get-ScheduledTask -TaskName $Script:TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $Script:TaskName -Confirm:$false
    }

    $psExe = (Get-Command powershell.exe).Source
    $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Script:ServiceScript`""
    $action = New-ScheduledTaskAction -Execute $psExe -Argument $arg -WorkingDirectory $InstallRoot
    $triggerLogon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $triggerBoot = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive

    Register-ScheduledTask -TaskName $Script:TaskName -Action $action -Trigger @($triggerLogon, $triggerBoot) `
        -Settings $settings -Principal $principal -Description 'amfetamin — Gecit DPI bypass otomatik baslatma' | Out-Null
    Write-LauncherLog 'Zamanlanmis gorev olusturuldu'
}

function Unregister-AutoStartTask {
    if (-not (Test-IsAdmin)) { throw 'Yonetici yetkisi gerekli' }
    $existing = Get-ScheduledTask -TaskName $Script:TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $Script:TaskName -Confirm:$false
        Write-LauncherLog 'Zamanlanmis gorev kaldirildi'
        return 'Otomatik baslatma kaldirildi'
    }
    return 'Otomatik baslatma zaten kurulu degil'
}

function Install-ToDevice {
    if (-not (Test-NpcapInstalled)) {
        Install-NpcapGui
        return @(
            'Npcap gerekli — kurulum penceresi acildi.',
            'Npcap kurup (gerekirse yeniden baslatin), tekrar "Cihaza Kur" deyin.'
        ) -join "`n"
    }

    Sync-LauncherToDevice
    Ensure-GecitBinary
    Register-AutoStartTask
    Start-GecitHidden
    return @(
        'Cihaza kurulum tamamlandi!',
        '- Her acilista Gecit otomatik baslar',
        '- Simdi arka planda calisiyor',
        "- Konum: $InstallRoot"
    ) -join "`n"
}

function Uninstall-FromDevice {
    Stop-Gecit | Out-Null
    Invoke-GecitCleanup | Out-Null
    Unregister-AutoStartTask | Out-Null
    return 'Cihazdan kaldirildi. Gecit durduruldu, otomatik baslatma silindi.'
}

function Install-And-Start {
    if (-not (Test-NpcapInstalled)) {
        Install-NpcapGui
        return 'Npcap kurulumu gerekli — pencere acildi. Kurulumdan sonra tekrar deneyin.'
    }
    Sync-LauncherToDevice
    Start-GecitVisible
}
