# amfetamin teshis araci - by furkandvrc
# CALISTIRMA: diagnose.bat dosyasina cift tikla (diagnose.ps1'e tiklama - Not Defteri acilir!)
# Cikti: Masaustunde amfetamin-diagnose.txt

$ErrorActionPreference = 'Continue'
$out = Join-Path ([Environment]::GetFolderPath('Desktop')) 'amfetamin-diagnose.txt'
$lines = [System.Collections.Generic.List[string]]::new()

function L([string]$msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    $lines.Add($line)
    Write-Host $line
}

try {
    L '=== AMFETAMIN TESHIS RAPORU ==='
    L "PC: $env:COMPUTERNAME  User: $env:USERNAME"
    L "Windows: $([Environment]::OSVersion.VersionString)"

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    L "Yonetici: $isAdmin"

    $installRoot = Join-Path $env:LOCALAPPDATA 'Amfetamin'
    $engine = Join-Path $installRoot 'bin\amfetamin.exe'
    L "Kurulum klasoru: $installRoot (var=$(Test-Path $installRoot))"
    L "Motor exe: $engine (var=$(Test-Path $engine))"

    if (Test-Path (Join-Path $installRoot 'config.json')) {
        L '--- config.json ---'
        Get-Content (Join-Path $installRoot 'config.json') | ForEach-Object { L "  $_" }
    }

    L '--- Npcap ---'
    L "  Program Files: $(Test-Path 'C:\Program Files\Npcap')"
    L "  wpcap.dll: $(Test-Path 'C:\Windows\System32\Npcap\wpcap.dll')"

    L '--- Process ---'
    $procs = Get-Process -Name amfetamin,gecit -ErrorAction SilentlyContinue
    if ($procs) { $procs | ForEach-Object { L "  $($_.Name) PID=$($_.Id)" } }
    else { L '  HATA: amfetamin process YOK' }

    L '--- Zamanlanmis gorev ---'
    $task = Get-ScheduledTask -TaskName 'Amfetamin-AutoStart' -ErrorAction SilentlyContinue
    if ($task) { L "  Gorev: $($task.State)" } else { L '  Gorev YOK' }

    L '--- DNS ayarlari ---'
    Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
        $srv = ($_.ServerAddresses -join ', ')
        if ($srv) { L "  $($_.InterfaceAlias): $srv" }
    }

    L '--- DNS cozumleme ---'
    foreach ($domain in @('discord.com', 'www.pornhub.com')) {
        L "  [$domain]"
        foreach ($server in @('127.0.0.1', '8.8.8.8')) {
            L "    nslookup @ ${server}:"
            try {
                nslookup $domain $server 2>&1 | ForEach-Object { L "      $_" }
            } catch { L "      HATA: $($_.Exception.Message)" }
        }
    }

    L '--- TCP baglanti ---'
    foreach ($target in @(
        'discord.com', 'gateway.discord.gg', 'cdn.discordapp.com',
        'www.pornhub.com', 'ei.phncdn.com',
        'www.google.com'
    )) {
        try {
            $t = Test-NetConnection $target -Port 443 -WarningAction SilentlyContinue
            L "  ${target}:443 -> $($t.TcpTestSucceeded)"
        } catch { L "  ${target}:443 -> HATA $($_.Exception.Message)" }
    }

    L '--- HTTP test (PowerShell) ---'
    foreach ($url in @(
        'https://discord.com',
        'https://discord.com/app',
        'https://www.pornhub.com',
        'https://www.google.com'
    )) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25
            $sw.Stop()
            L "  $url -> $($r.StatusCode) ($($sw.ElapsedMilliseconds)ms)"
        } catch {
            $sw.Stop()
            L "  $url -> FAIL ($($sw.ElapsedMilliseconds)ms) $($_.Exception.Message)"
        }
    }

    L '--- Antivirüs / guvenlik (WinDefender durum) ---'
    try {
        $def = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($def) { L "  Defender RealTime: $($def.RealTimeProtectionEnabled)" }
    } catch { L '  Defender bilgisi alinamadi' }

    L '--- Ag adaptorleri ---'
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | ForEach-Object {
        L "  $($_.Name) ($($_.InterfaceDescription))"
    }

    L '--- Log dosyalari ---'
    $logDir = Join-Path $installRoot 'logs'
    foreach ($name in @('launcher.log', 'amfetamin-run.log', 'amfetamin-run.err.log', 'service.log')) {
        $path = Join-Path $logDir $name
        if (Test-Path $path) {
            L "--- $name (son 15 satir) ---"
            Get-Content $path -Tail 15 -ErrorAction SilentlyContinue | ForEach-Object { L "  $_" }
        } else {
            L "--- $name: YOK ---"
        }
    }

    L '--- Tarayici kontrol listesi (elle kontrol) ---'
    L '  1) chrome://flags/#enable-quic -> Disabled mi?'
    L '  2) Chrome Ayarlar -> Guvenli DNS -> Kapali mi?'
    L '  3) VPN acik mi?'
    L '  4) Baska bypass (GoodbyeDPI vb.) calisiyor mu?'

    L '=== TESHIS BITTI ==='
    L "Rapor: $out"
} catch {
    L "KRITIK HATA: $($_.Exception.Message)"
}

$lines | Set-Content $out -Encoding UTF8
Write-Host ""
Write-Host "Rapor kaydedildi: $out" -ForegroundColor Green
Start-Process notepad.exe $out
