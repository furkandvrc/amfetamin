# Deploy custom engine (discord-only TUN + system stack) and test both
$ErrorActionPreference = 'Stop'
$installRoot = Join-Path $env:LOCALAPPDATA 'Amfetamin'
$windowsRoot = 'c:\Users\Furkan\Desktop\amfetamin-master\windows'
$engineSrc = 'c:\Users\Furkan\Desktop\amfetamin-master\engine\bin\amfetamin-engine.exe'
$env:AMFETAMIN_ROOT = $windowsRoot

. (Join-Path $windowsRoot 'lib\AmfetaminEncoding.ps1')
. (Get-AmfetaminUtf8ScriptBlock (Join-Path $windowsRoot 'lib\AmfetaminLogger.ps1'))
. (Get-AmfetaminUtf8ScriptBlock (Join-Path $windowsRoot 'lib\AmfetaminI18n.ps1'))
. (Get-AmfetaminUtf8ScriptBlock (Join-Path $windowsRoot 'lib\AmfetaminCore.ps1'))

$log = Join-Path $installRoot 'logs\both-fix.log'
function L([string]$m) { Add-Content $log "[$(Get-Date -f 'HH:mm:ss')] $m"; Write-Host $m }

if (-not (Test-IsAdmin)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"") | Out-Null
    exit 0
}

try {
    if (-not (Test-Path $engineSrc)) { throw "Engine binary missing: $engineSrc" }
    L 'Ozel motor kuruluyor (tam TUN + Warframe route exclude)'

    # Warframe ag analizi: gelen UDP/TCP portlarina izin ver
    $wfRules = @(
        @{ Name = 'Warframe-UDP-4950-4955-In';  Proto = 'UDP'; Ports = '4950-4955' }
        @{ Name = 'Warframe-TCP-6695-6699-In';  Proto = 'TCP'; Ports = '6695-6699' }
        @{ Name = 'Warframe-UDP-4950-4955-Out'; Proto = 'UDP'; Ports = '4950-4955'; Out = $true }
        @{ Name = 'Warframe-TCP-6695-6699-Out'; Proto = 'TCP'; Ports = '6695-6699'; Out = $true }
    )
    foreach ($r in $wfRules) {
        $dir = if ($r.Out) { 'Outbound' } else { 'Inbound' }
        $existing = Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue
        if (-not $existing) {
            New-NetFirewallRule -DisplayName $r.Name -Direction $dir -Protocol $r.Proto -LocalPort $r.Ports -Action Allow -Profile Any | Out-Null
            L "Firewall kurali eklendi: $($r.Name)"
        }
    }
    $wfExe = @(
        "${env:ProgramFiles(x86)}\Steam\steamapps\common\Warframe\Warframe.x64.exe"
        "$env:ProgramFiles\Steam\steamapps\common\Warframe\Warframe.x64.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($wfExe) {
        $ruleName = 'Warframe-Exe-Allow'
        if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Program $wfExe -Action Allow -Profile Any | Out-Null
            New-NetFirewallRule -DisplayName ($ruleName + '-Out') -Direction Outbound -Program $wfExe -Action Allow -Profile Any | Out-Null
            L "Firewall: Warframe.exe izin verildi"
        }
    }

    Sync-LauncherToDevice
    Stop-Amfetamin | Out-Null
    Start-Sleep -Seconds 2

    Copy-Item $engineSrc (Join-Path $installRoot 'bin\amfetamin.exe') -Force
    Set-Content (Join-Path $installRoot 'bin\engine-tag.txt') 'engine-v0.1.16' -Encoding ASCII

    $cfgPath = Join-Path $installRoot 'config.json'
    $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
    $cfg.engineTag = 'engine-v0.1.16'
    $cfg.engineVersion = 'v0.1.16'
    $cfg | ConvertTo-Json -Depth 6 | Set-Content $cfgPath -Encoding UTF8

    Start-AmfetaminHidden | Out-Null
    Start-Sleep -Seconds 6

    $runLog = Join-Path $installRoot 'logs\amfetamin-run.log'
    Get-Content $runLog -Tail 12 | ForEach-Object { L "LOG: $_" }

    try {
        $code = (Invoke-WebRequest -Uri 'https://discord.com' -UseBasicParsing -TimeoutSec 15).StatusCode
        L "Discord HTTP: $code"
    } catch { L "Discord FAIL: $($_.Exception.Message)" }

    $defRoute = route print 0.0.0.0 | Select-String '0.0.0.0\s+0.0.0.0\s+10.0.85'
    if ($defRoute) { L 'OK: Tam TUN aktif (Discord icin)' }
    else { L 'UYARI: Tam TUN rota yok - Discord calismayabilir' }

    Get-NetUDPEndpoint -LocalPort 4950,4955 -ErrorAction SilentlyContinue | ForEach-Object {
        L "Warframe UDP port $($_.LocalPort) pid=$($_.OwningProcess)"
    }

    L 'Bitti - Warframe Ag Analizi + Discord acmayi dene'
} catch {
    L "HATA: $($_.Exception.Message)"
    exit 1
}
