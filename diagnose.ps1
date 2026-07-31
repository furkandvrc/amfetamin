# amfetamin teshis - by furkandvrc
# Calistir: diagnose.bat  VEYA  powershell -ExecutionPolicy Bypass -File .\diagnose.ps1
# Cikti: bu klasorde amfetamin-diagnose.txt

$ErrorActionPreference = 'Continue'

function Write-DiagLine {
    param([string]$Message, [System.Collections.ArrayList]$Buffer)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    [void]$Buffer.Add($line)
    Write-Host $line
}

function Get-DiagReportPath {
    if ($PSScriptRoot) {
        return Join-Path $PSScriptRoot 'amfetamin-diagnose.txt'
    }
    return Join-Path (Get-Location).Path 'amfetamin-diagnose.txt'
}

$lines = New-Object System.Collections.ArrayList

try {
    Write-DiagLine '=== AMFETAMIN TESHIS RAPORU ===' $lines
    Write-DiagLine "PC: $env:COMPUTERNAME  User: $env:USERNAME" $lines
    Write-DiagLine "Klasor: $(Get-Location)" $lines
    Write-DiagLine "Windows: $([Environment]::OSVersion.VersionString)" $lines

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-DiagLine "Yonetici: $isAdmin" $lines

    $installRoot = Join-Path $env:LOCALAPPDATA 'Amfetamin'
    $engine = Join-Path $installRoot 'bin\amfetamin.exe'
    Write-DiagLine "Kurulum klasoru: $installRoot (var=$(Test-Path $installRoot))" $lines
    Write-DiagLine "Motor exe: $engine (var=$(Test-Path $engine))" $lines

    $configPath = Join-Path $installRoot 'config.json'
    if (Test-Path $configPath) {
        Write-DiagLine '--- config.json ---' $lines
        Get-Content $configPath -ErrorAction SilentlyContinue | ForEach-Object {
            Write-DiagLine "  $_" $lines
        }
    }

    Write-DiagLine '--- Npcap ---' $lines
    Write-DiagLine "  Program Files: $(Test-Path 'C:\Program Files\Npcap')" $lines
    Write-DiagLine "  wpcap.dll: $(Test-Path 'C:\Windows\System32\Npcap\wpcap.dll')" $lines

    Write-DiagLine '--- Process ---' $lines
    $procs = Get-Process -Name amfetamin, gecit -ErrorAction SilentlyContinue
    if ($procs) {
        foreach ($proc in $procs) {
            Write-DiagLine "  $($proc.Name) PID=$($proc.Id)" $lines
        }
    } else {
        Write-DiagLine '  HATA: amfetamin process YOK' $lines
    }

    Write-DiagLine '--- Zamanlanmis gorev ---' $lines
    $task = Get-ScheduledTask -TaskName 'Amfetamin-AutoStart' -ErrorAction SilentlyContinue
    if ($task) { Write-DiagLine "  Gorev: $($task.State)" $lines }
    else { Write-DiagLine '  Gorev YOK' $lines }

    Write-DiagLine '--- DNS ayarlari ---' $lines
    Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
        $srv = ($_.ServerAddresses -join ', ')
        if ($srv) { Write-DiagLine "  $($_.InterfaceAlias): $srv" $lines }
    }

    Write-DiagLine '--- DNS cozumleme ---' $lines
    foreach ($domain in @('discord.com', 'www.pornhub.com')) {
        Write-DiagLine "  [$domain]" $lines
        foreach ($server in @('127.0.0.1', '8.8.8.8')) {
            Write-DiagLine "    nslookup @ ${server}:" $lines
            cmd /c "nslookup $domain $server 2>&1" | ForEach-Object {
                Write-DiagLine "      $_" $lines
            }
        }
    }

    Write-DiagLine '--- TCP baglanti ---' $lines
    foreach ($target in @(
            'discord.com', 'gateway.discord.gg', 'cdn.discordapp.com',
            'www.pornhub.com', 'ei.phncdn.com', 'www.google.com'
        )) {
        try {
            $t = Test-NetConnection $target -Port 443 -WarningAction SilentlyContinue
            Write-DiagLine "  ${target}:443 -> $($t.TcpTestSucceeded)" $lines
        } catch {
            Write-DiagLine "  ${target}:443 -> HATA $($_.Exception.Message)" $lines
        }
    }

    Write-DiagLine '--- HTTP test ---' $lines
    foreach ($url in @(
            'https://discord.com', 'https://discord.com/app',
            'https://www.pornhub.com', 'https://www.google.com'
        )) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25
            $sw.Stop()
            Write-DiagLine "  $url -> $($r.StatusCode) ($($sw.ElapsedMilliseconds)ms)" $lines
        } catch {
            $sw.Stop()
            Write-DiagLine "  $url -> FAIL ($($sw.ElapsedMilliseconds)ms) $($_.Exception.Message)" $lines
        }
    }

    Write-DiagLine '--- Log dosyalari ---' $lines
    $logDir = Join-Path $installRoot 'logs'
    foreach ($logName in @('launcher.log', 'amfetamin-run.log', 'service.log')) {
        $path = Join-Path $logDir $logName
        if (Test-Path $path) {
            Write-DiagLine "--- ${logName} (son 10 satir) ---" $lines
            Get-Content $path -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object {
                Write-DiagLine "  $_" $lines
            }
        } else {
            Write-DiagLine "--- ${logName} YOK ---" $lines
        }
    }

    Write-DiagLine '=== TESHIS BITTI ===' $lines
} catch {
    Write-DiagLine "KRITIK HATA: $($_.Exception.Message)" $lines
}

$reportPath = Get-DiagReportPath
$backupPath = Join-Path $env:TEMP 'amfetamin-diagnose.txt'
$text = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
$savedPath = $null

foreach ($targetPath in @($reportPath, $backupPath)) {
    try {
        [System.IO.File]::WriteAllText($targetPath, $text, [System.Text.UTF8Encoding]::new($false))
        $savedPath = $targetPath
        Write-DiagLine "Kaydedildi: $targetPath" $lines
        break
    } catch {
        Write-Host "Kayit hatasi ($targetPath): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ''
if ($savedPath) {
    Write-Host "Rapor: $savedPath" -ForegroundColor Green
    try { Start-Process notepad.exe $savedPath } catch {}
} else {
    Write-Host 'Dosya kaydedilemedi. Cikti:' -ForegroundColor Red
    Write-Host $text
}

exit 0
