# amfetamin - core
$ErrorActionPreference = 'Stop'

$Script:TaskName = 'Amfetamin-AutoStart'
$Script:InstallRoot = Join-Path $env:LOCALAPPDATA 'Amfetamin'
$Script:BinDir = Join-Path $Script:InstallRoot 'bin'
$Script:LogDir = Join-Path $Script:InstallRoot 'logs'
$Script:LibDir = Join-Path $Script:InstallRoot 'lib'
$Script:EngineExe = Join-Path $Script:BinDir 'amfetamin.exe'
$Script:EngineTagFile = Join-Path $Script:BinDir 'engine-tag.txt'
$Script:NpcapInstaller = Join-Path $Script:BinDir 'npcap-installer.exe'
$Script:ConfigPath = Join-Path $Script:InstallRoot 'config.json'
$Script:ServiceScript = Join-Path $Script:LibDir 'run-amfetamin-service.ps1'
if ($null -eq $Script:EmbeddedLibFiles) { $Script:EmbeddedLibFiles = @{} }

if (-not $env:AMFETAMIN_ROOT -and $PSScriptRoot) {
    if ($PSScriptRoot -match '\\lib$') {
        $env:AMFETAMIN_ROOT = Split-Path $PSScriptRoot -Parent
    } else {
        $env:AMFETAMIN_ROOT = $PSScriptRoot
    }
    $Script:AmfetaminProjectRoot = $env:AMFETAMIN_ROOT
}

if (-not (Get-Command Get-AmfetaminUtf8ScriptBlock -ErrorAction SilentlyContinue)) {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $encodingPath = Join-Path $PSScriptRoot 'AmfetaminEncoding.ps1'
        if (Test-Path -LiteralPath $encodingPath) { . $encodingPath }
    }
}

. (Get-AmfetaminUtf8ScriptBlock (Join-Path $PSScriptRoot 'AmfetaminLogger.ps1'))
. (Get-AmfetaminUtf8ScriptBlock (Join-Path $PSScriptRoot 'AmfetaminI18n.ps1'))

# Motor indirme (amfetamin engine v0.1.5)
$Script:EngineVersion = 'engine-v0.1.5'
$Script:EngineReleaseBase = 'https://github.com/furkandvrc/amfetamin/releases/download'
$Script:EngineRemoteAsset = 'amfetamin-engine.exe'
$Script:EngineChecksumFile = 'checksums.txt'

function Get-ProjectRoot {
    if ($env:AMFETAMIN_ROOT -and (Test-Path $env:AMFETAMIN_ROOT)) {
        return $env:AMFETAMIN_ROOT
    }
    if ($Script:AmfetaminProjectRoot -and (Test-Path $Script:AmfetaminProjectRoot)) {
        return $Script:AmfetaminProjectRoot
    }
    if ($PSScriptRoot -match '\\lib$') {
        return Split-Path $PSScriptRoot -Parent
    }
    if ($PSScriptRoot) { return $PSScriptRoot }
    $caller = $MyInvocation.MyCommand.Path
    if ($caller) { return Split-Path $caller -Parent }
    return $Script:InstallRoot
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
    throw (T 'err_config_not_found')
}

function Set-ConfigValues {
    param([hashtable]$Values)
    Ensure-Dirs
    $paths = @(
        (Join-Path (Get-ProjectRoot) 'config.json'),
        $Script:ConfigPath
    ) | Select-Object -Unique

    foreach ($path in $paths) {
        if (-not (Test-Path $path)) { continue }
        $json = Get-Content $path -Raw | ConvertFrom-Json
        foreach ($key in $Values.Keys) {
            if ($json.PSObject.Properties.Name -contains $key) {
                $json.$key = $Values[$key]
            } else {
                $json | Add-Member -NotePropertyName $key -NotePropertyValue $Values[$key] -Force
            }
        }
        $json | ConvertTo-Json -Depth 6 | Set-Content $path -Encoding UTF8
    }
    Write-AmfetaminLog -Message "Config guncellendi: $($Values.Keys -join ', ')" -Level INFO -Audit
}

function Test-ShouldAutoTuneFakeTtl {
    $cfg = Get-Config
    if ($cfg.PSObject.Properties.Name -contains 'autoTuneTtl' -and $cfg.autoTuneTtl -eq $false) {
        return $false
    }
    if ($cfg.PSObject.Properties.Name -contains 'autoTuneDone' -and $cfg.autoTuneDone -eq $true) {
        return $false
    }
    return $true
}

function Get-FakeTtlCandidates {
    $cfg = Get-Config
    if ($cfg.PSObject.Properties.Name -contains 'fakeTtlCandidates' -and $cfg.fakeTtlCandidates) {
        return @($cfg.fakeTtlCandidates | ForEach-Object { [int]$_ })
    }
    return @(6, 8, 10, 12, 14)
}

function Test-BypassTargetReachable {
    param(
        [string]$Url = 'https://discord.com',
        [int]$TimeoutSec = 15
    )
    foreach ($method in @('Head', 'Get')) {
        try {
            $params = @{
                Uri             = $Url
                UseBasicParsing = $true
                TimeoutSec      = $TimeoutSec
                ErrorAction     = 'Stop'
            }
            if ($method -eq 'Head') { $params.Method = 'Head' }
            $r = Invoke-WebRequest @params
            if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400) { return $true }
        } catch {}
    }
    return $false
}

function Invoke-FakeTtlAutoTune {
    param([scriptblock]$Progress = $null)

    $cfg = Get-Config
    $testUrl = 'https://discord.com'
    if ($cfg.PSObject.Properties.Name -contains 'autoTuneUrl' -and $cfg.autoTuneUrl) {
        $testUrl = [string]$cfg.autoTuneUrl
    }
    $timeout = 15
    if ($cfg.PSObject.Properties.Name -contains 'autoTuneTimeoutSec' -and $cfg.autoTuneTimeoutSec) {
        $timeout = [int]$cfg.autoTuneTimeoutSec
    }

    $candidates = Get-FakeTtlCandidates
    Write-LauncherLog ('TTL otomatik ayar basladi (' + $testUrl + '; adaylar: ' + ($candidates -join ',') + ')')

    $bestTtl = $null
    foreach ($ttl in $candidates) {
        try {
            if ($Progress) { & $Progress (T 'ttl_trying' $ttl) }
            Write-LauncherLog "TTL deneniyor: $ttl"
            Stop-Amfetamin | Out-Null
            Start-Sleep -Seconds 1
            Start-AmfetaminHidden -FakeTtlOverride $ttl -SkipWarmup | Out-Null
            if (-not (Test-AmfetaminRunning)) {
                Write-LauncherLog "TTL $ttl ile motor baslamadi"
                continue
            }
            Start-Sleep -Seconds 3
            if (Test-BypassTargetReachable -Url $testUrl -TimeoutSec $timeout) {
                $bestTtl = $ttl
                Write-LauncherLog "TTL $ttl calisti ($testUrl OK)"
                if ($Progress) { & $Progress (T 'ttl_success' $ttl) }
                break
            }
            Write-LauncherLog "TTL $ttl timeout ($testUrl)"
            if ($Progress) { & $Progress (T 'ttl_failed_next' $ttl) }
        } catch {
            Write-LauncherLog "TTL $ttl hata: $($_.Exception.Message)"
            if ($Progress) { & $Progress (T 'ttl_failed_next' $ttl) }
        }
    }

    if (-not $bestTtl) {
        $bestTtl = if ($cfg.fakeTtl) { [int]$cfg.fakeTtl } else { 8 }
        Write-LauncherLog "Uygun TTL bulunamadi, varsayilan kullaniliyor: $bestTtl"
        Stop-Amfetamin | Out-Null
        Start-Sleep -Seconds 1
        try {
            Start-AmfetaminHidden -FakeTtlOverride $bestTtl -SkipWarmup | Out-Null
        } catch {
            Write-LauncherLog "Varsayilan TTL baslatma hatasi: $($_.Exception.Message)"
            throw
        }
    }

    Set-ConfigValues @{
        fakeTtl      = $bestTtl
        autoTuneDone = $true
    }
    Sync-LauncherToDevice
    Invoke-EngineWarmup -NonBlocking

    if (Test-BypassTargetReachable -Url $testUrl -TimeoutSec $timeout) {
        return (T 'ttl_autotune_success' $bestTtl, $testUrl)
    }
    return (T 'ttl_autotune_done_no_response' $bestTtl, $testUrl)
}

function Invoke-ManualTtlRetune {
    Set-ConfigValues @{ autoTuneDone = $false }
    return Invoke-FakeTtlAutoTune
}

function Ensure-Dirs {
    foreach ($d in @($Script:InstallRoot, $Script:BinDir, $Script:LogDir, $Script:LibDir)) {
        if ([string]::IsNullOrWhiteSpace($d)) { continue }
        if (-not (Test-Path -LiteralPath $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
    }
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PowerShellPath {
    return Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
}

function Get-LauncherPath {
    $root = Get-ProjectRoot
    if (-not [string]::IsNullOrWhiteSpace($root)) {
        $exe = Join-Path $root 'Amfetamin.exe'
        if (-not [string]::IsNullOrWhiteSpace($exe) -and (Test-Path -LiteralPath $exe)) { return $exe }
        $ps1 = Join-Path $root 'Amfetamin.ps1'
        if (-not [string]::IsNullOrWhiteSpace($ps1) -and (Test-Path -LiteralPath $ps1)) { return $ps1 }
    }
    $caller = $MyInvocation.MyCommand.Path
    if (-not [string]::IsNullOrWhiteSpace($caller)) { return $caller }
    return $null
}

function Request-Admin([string[]]$ExtraArgs) {
    if (Test-IsAdmin) { return $true }
    Write-AmfetaminLog -Message 'Yonetici yetkisi isteniyor' -Level INFO -Audit
    $launcher = Get-LauncherPath
    if ([string]::IsNullOrWhiteSpace($launcher)) { throw (T 'err_launcher_not_found') }
    $root = Get-ProjectRoot
    if ($launcher -like '*.exe') {
        Start-Process -FilePath $launcher -Verb RunAs -WorkingDirectory $root
    } else {
        $argList = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-WindowStyle', 'Hidden',
            '-File', $launcher
        )
        if ($ExtraArgs) { $argList += $ExtraArgs }
        Start-Process -FilePath (Get-PowerShellPath) -Verb RunAs -WorkingDirectory $root -ArgumentList $argList
    }
    return $false
}

function Test-NpcapInstalled {
    if (Test-Path 'C:\Program Files\Npcap') { return $true }
    if (Test-Path 'C:\Windows\System32\Npcap\wpcap.dll') { return $true }
    if (Test-Path 'C:\Windows\System32\wpcap.dll') { return $true }
    return $false
}

function Stop-LegacyEngine {
    foreach ($legacyName in @('amfetamin-old')) {
        Get-Process -Name $legacyName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    foreach ($legacyFile in @('engine-old.exe')) {
        $p = Join-Path $Script:BinDir $legacyFile
        if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
    }
}

function Get-AmfetaminEngineProcesses {
    $binDir = [System.IO.Path]::GetFullPath($Script:BinDir)
    @(
        Get-Process -Name 'amfetamin' -ErrorAction SilentlyContinue | Where-Object {
            try {
                if (-not $_.Path) { return $false }
                $dir = [System.IO.Path]::GetFullPath((Split-Path $_.Path -Parent))
                return ($dir -ceq $binDir)
            } catch {
                return $false
            }
        }
    )
}

function Test-AmfetaminRunning {
    return (@(Get-AmfetaminEngineProcesses)).Count -gt 0
}

function Test-AutoStartInstalled {
    try {
        & schtasks.exe /Query /TN $Script:TaskName /FO LIST 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Get-AmfetaminProcessInfo {
    $proc = Get-AmfetaminEngineProcesses | Select-Object -First 1
    if (-not $proc) { return $null }
    return [PSCustomObject]@{
        Pid = $proc.Id
        StartTime = $proc.StartTime
        MemoryMb = [math]::Round($proc.WorkingSet64 / 1MB, 1)
    }
}

function Get-AmfetaminStatus {
    $cfg = $null
    try { $cfg = Get-Config } catch {}
    $proc = Get-AmfetaminProcessInfo
    [PSCustomObject]@{
        NpcapInstalled = Test-NpcapInstalled
        EngineDownloaded = Test-Path $Script:EngineExe
        EngineRunning = Test-AmfetaminRunning
        AutoStartInstalled = Test-AutoStartInstalled
        InstallRoot = $Script:InstallRoot
        FakeTtl = if ($cfg) { $cfg.fakeTtl } else { $null }
        AutoTuneDone = if ($cfg) { $cfg.autoTuneDone } else { $false }
        Version = if ($cfg) { $cfg.version } else { '?' }
        Process = $proc
        ZeroTierRunning = (Test-ZeroTierRunning)
    }
}

function Invoke-DownloadFile([string]$Url, [string]$Dest) {
    Write-LauncherLog "Indiriliyor: $Url"
    Write-AmfetaminLog -Message "Indiriliyor: $Url" -Level INFO
    Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
}

function Get-EngineReleaseInfo {
    $cfg = Get-Config
    $tag = $Script:EngineVersion
    if ($cfg.PSObject.Properties.Name -contains 'engineTag' -and $cfg.engineTag) {
        $tag = [string]$cfg.engineTag
    }
    $base = $Script:EngineReleaseBase
    if ($cfg.PSObject.Properties.Name -contains 'engineReleaseBase' -and $cfg.engineReleaseBase) {
        $base = [string]$cfg.engineReleaseBase
    }
    return @{
        Tag  = $tag
        Base = $base
    }
}

function Test-EngineNeedsInstall {
    $info = Get-EngineReleaseInfo
    if (-not (Test-Path $Script:EngineExe)) { return $true }
    if (-not (Test-Path $Script:EngineTagFile)) { return $true }
    $installed = (Get-Content $Script:EngineTagFile -Raw -ErrorAction SilentlyContinue).Trim()
    return $installed -ne $info.Tag
}

function Install-EngineBinary {
    Ensure-Dirs
    Stop-LegacyEngine
    if (Test-AmfetaminRunning) {
        Stop-Amfetamin | Out-Null
        Start-Sleep -Seconds 1
    }

    $info = Get-EngineReleaseInfo
    $base = "$($info.Base)/$($info.Tag)"
    Write-LauncherLog "Motor guncelleniyor: $($info.Tag)"
    Write-AmfetaminLog -Message "Motor guncelleniyor: $($info.Tag)" -Level INFO -Audit
    Invoke-DownloadFile "$base/$($Script:EngineChecksumFile)" (Join-Path $Script:BinDir 'checksums.txt')
    $tmp = Join-Path $Script:BinDir '_download.tmp'
    Invoke-DownloadFile "$base/$($Script:EngineRemoteAsset)" $tmp

    $expectedLine = Get-Content (Join-Path $Script:BinDir 'checksums.txt') | Where-Object { $_ -match [regex]::Escape($Script:EngineRemoteAsset) }
    if (-not $expectedLine) { throw (T 'err_checksum_engine_not_found') }
    $expectedHash = ($expectedLine -split '\s+')[0].ToUpperInvariant()
    $actualHash = (Get-FileHash $tmp -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($expectedHash -ne $actualHash) {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        throw (T 'err_sha256_mismatch' $expectedHash, $actualHash)
    }
    Move-Item $tmp $Script:EngineExe -Force
    Set-Content -Path $Script:EngineTagFile -Value $info.Tag -Encoding ASCII
    Write-LauncherLog 'amfetamin motor indirildi ve dogrulandi'
    Write-AmfetaminLog -Message "Motor binary dogrulandi ($($info.Tag))" -Level INFO -Audit
}

function Ensure-EngineBinary {
    if (-not (Test-EngineNeedsInstall)) { return }
    Install-EngineBinary
}

function Sync-LauncherToDevice {
    Ensure-Dirs
    $projectRoot = Get-ProjectRoot
    $libFiles = @(
        'AmfetaminEncoding.ps1', 'AmfetaminCore.ps1', 'AmfetaminLogger.ps1', 'AmfetaminI18n.ps1',
        'AmfetaminDiagnostics.ps1', 'AmfetaminUI.ps1', 'run-amfetamin-service.ps1'
    )

    $configSrc = Join-Path $projectRoot 'config.json'
    if (-not [string]::IsNullOrWhiteSpace($configSrc) -and (Test-Path -LiteralPath $configSrc)) {
        Copy-Item -LiteralPath $configSrc -Destination $Script:ConfigPath -Force
    } elseif ($Script:EmbeddedConfigJson) {
        [System.IO.File]::WriteAllText($Script:ConfigPath, $Script:EmbeddedConfigJson, (New-Object System.Text.UTF8Encoding $false))
    } else {
        throw (T 'err_config_not_found')
    }

    $copied = 0
    foreach ($libFile in $libFiles) {
        $dest = Join-Path $Script:LibDir $libFile
        $src = Join-Path $projectRoot "lib\$libFile"
        if (-not [string]::IsNullOrWhiteSpace($src) -and (Test-Path -LiteralPath $src)) {
            Copy-Item -LiteralPath $src -Destination $dest -Force
            $copied++
        } elseif ($Script:EmbeddedLibFiles -and $Script:EmbeddedLibFiles.ContainsKey($libFile)) {
            [System.IO.File]::WriteAllText($dest, $Script:EmbeddedLibFiles[$libFile], (New-Object System.Text.UTF8Encoding $false))
            $copied++
        }
    }

    if ($copied -lt $libFiles.Count) {
        throw (T 'err_lib_sync_failed' $copied, $libFiles.Count)
    }

    foreach ($icoName in @('amfetamin.ico', (Join-Path 'assets' 'amfetamin.ico'))) {
        $icoSrc = Join-Path $projectRoot $icoName
        if (-not [string]::IsNullOrWhiteSpace($icoSrc) -and (Test-Path -LiteralPath $icoSrc)) {
            Copy-Item -LiteralPath $icoSrc -Destination (Join-Path $Script:InstallRoot 'amfetamin.ico') -Force
            break
        }
    }
    Write-LauncherLog 'amfetamin dosyalari cihaza kopyalandi'
}

function Install-NpcapAuto {
    if (Test-NpcapInstalled) { return $null }
    if (-not (Test-IsAdmin)) { throw (T 'err_admin_required') }

    Ensure-Dirs
    $cfg = Get-Config
    if (-not (Test-Path $Script:NpcapInstaller)) {
        Invoke-DownloadFile $cfg.npcapUrl $Script:NpcapInstaller
    }

    Write-LauncherLog 'Npcap kurulumu baslatiliyor'
    Write-AmfetaminLog -Message 'Npcap kurulumu baslatiliyor' -Level INFO -Audit
    $installArgs = '/winpcap_mode=yes'
    Start-Process -FilePath $Script:NpcapInstaller -ArgumentList $installArgs -Verb RunAs -Wait | Out-Null
    Start-Sleep -Seconds 2

    if (-not (Test-NpcapInstalled)) {
        throw (T 'err_npcap_install_failed')
    }

    Write-LauncherLog 'Npcap kuruldu'
    return (T 'msg_npcap_installed')
}

function Install-NpcapGui {
    if (Test-NpcapInstalled) { return (T 'msg_npcap_already_installed') }
    return Install-NpcapAuto
}

function Get-EngineRunArgs {
    param(
        [switch]$VerboseLog,
        [int]$FakeTtlOverride = 0
    )
    $cfg = Get-Config
    $parts = @('run', '--doh-upstream', [string]$cfg.dohUpstream)
    $ttl = if ($FakeTtlOverride -gt 0) { $FakeTtlOverride }
           elseif ($cfg.PSObject.Properties.Name -contains 'fakeTtl' -and $cfg.fakeTtl) { [int]$cfg.fakeTtl }
           else { 0 }
    if ($ttl -gt 0) { $parts += @('--fake-ttl', [string]$ttl) }
    if ($cfg.PSObject.Properties.Name -contains 'splitTunnel' -and $cfg.splitTunnel -eq $true) {
        $parts += '--split-tunnel'
    }
    if ($VerboseLog) { $parts += '-v' }
    return $parts
}

function Get-EngineRunArgsLine {
    param([switch]$VerboseLog)
    return ((Get-EngineRunArgs -VerboseLog:$VerboseLog) -join ' ')
}

function Format-EngineArgumentLine {
    param([string[]]$EngineArgs)
    return ($EngineArgs | ForEach-Object {
        $s = [string]$_
        if ($s -match '[\s"]') { '"' + ($s -replace '"', '\"') + '"' } else { $s }
    }) -join ' '
}

function Start-EngineProcess {
    param([string[]]$EngineArgs)

    if (-not $EngineArgs -or @($EngineArgs).Count -eq 0) {
        throw (T 'err_engine_start_failed' 'empty engine args')
    }
    if (-not (Test-Path -LiteralPath $Script:EngineExe)) {
        throw (T 'err_engine_start_failed' "engine missing: $($Script:EngineExe)")
    }
    if (-not $Script:RunLog) { Initialize-AmfetaminLogging }

    $argLine = Format-EngineArgumentLine $EngineArgs
    return Start-Process -FilePath $Script:EngineExe -ArgumentList $argLine `
        -WorkingDirectory $Script:BinDir -WindowStyle Hidden -PassThru `
        -RedirectStandardError $Script:RunLog
}

function Invoke-EngineWarmup {
    param([switch]$NonBlocking)

    $cfg = Get-Config
    if ($cfg.PSObject.Properties['warmup'] -and $cfg.warmup -eq $false) { return }

    $urls = @(
        'https://www.google.com/generate_204',
        'https://discord.com',
        'https://gateway.discord.gg',
        'https://cdn.discordapp.com'
    )
    if ($cfg.PSObject.Properties['warmupUrls'] -and $cfg.warmupUrls) {
        $urls = @($cfg.warmupUrls)
    }

    $job = Start-Job -ScriptBlock {
        param($List)
        foreach ($url in $List) {
            try {
                Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 6 -Method Head -ErrorAction Stop | Out-Null
            } catch {
                try {
                    Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 6 -ErrorAction Stop | Out-Null
                } catch {}
            }
        }
    } -ArgumentList (,$urls)

    if ($NonBlocking) {
        Write-LauncherLog 'Motor isinma arka planda baslatildi'
        return
    }

    $done = Wait-Job $job -Timeout 12
    if ($done) { Receive-Job $job | Out-Null }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    Write-LauncherLog 'Motor isinma tamamlandi'
}

function Start-AmfetaminHidden {
    param(
        [int]$FakeTtlOverride = 0,
        [switch]$SkipWarmup
    )
    if (-not (Test-IsAdmin)) { throw (T 'err_admin_required') }
    if (-not (Test-NpcapInstalled)) { throw (T 'err_npcap_not_installed') }
    Stop-ZeroTierIfRunning | Out-Null
    Ensure-EngineBinary
    Stop-LegacyEngine
    if (-not $Script:RunLog) { Initialize-AmfetaminLogging }
    if (Test-AmfetaminRunning) {
        if ($FakeTtlOverride -le 0) { return (T 'msg_engine_already_running') }
        Stop-Amfetamin | Out-Null
        Start-Sleep -Seconds 1
    }

    $argParams = @{}
    if ($FakeTtlOverride -gt 0) { $argParams.FakeTtlOverride = $FakeTtlOverride }
    $engineArgs = @(Get-EngineRunArgs @argParams)
    $proc = Start-EngineProcess -EngineArgs $engineArgs
    Start-Sleep -Seconds 2
    if (-not $proc.HasExited -and (Test-AmfetaminRunning)) {
        Write-LauncherLog "amfetamin arka planda baslatildi (PID $($proc.Id))"
        Write-AmfetaminLog -Message "Motor baslatildi PID=$($proc.Id)" -Level INFO -Audit
        if (-not $SkipWarmup) { Invoke-EngineWarmup }
        return (T 'msg_engine_started_background')
    }
    if (Test-AmfetaminRunning) {
        if (-not $SkipWarmup) { Invoke-EngineWarmup }
        return (T 'msg_engine_running')
    }
    $hint = if (Test-Path $Script:RunLog) { Get-Content $Script:RunLog -Raw -ErrorAction SilentlyContinue } else { '' }
    Write-AmfetaminError -Message 'Motor baslatilamadi' -Context 'Start-AmfetaminHidden'
    throw (T 'err_engine_start_failed' $hint)
}

function Start-AmfetaminVisible {
    if (-not (Test-IsAdmin)) { throw (T 'err_admin_required') }
    if (-not (Test-NpcapInstalled)) { throw (T 'err_npcap_not_installed') }
    Ensure-EngineBinary
    Stop-LegacyEngine
    if (Test-AmfetaminRunning) { return (T 'msg_engine_already_running') }

    $cfg = Get-Config
    $verbose = $true
    if ($cfg.PSObject.Properties['engineVerbose'] -and $cfg.engineVerbose -eq $false) { $verbose = $false }
    $upstream = [string]$cfg.dohUpstream
    $batch = @"
@echo off
cd /d "$($Script:BinDir)"
title amfetamin
echo amfetamin calisiyor. Kapatmak icin Ctrl+C
"$($Script:EngineExe)" run --doh-upstream "$upstream"$(
    if ($cfg.PSObject.Properties['fakeTtl'] -and $cfg.fakeTtl) { " --fake-ttl $($cfg.fakeTtl)" } else { '' }
)$(
    if ($cfg.PSObject.Properties['splitTunnel'] -and $cfg.splitTunnel -eq $true) { ' --split-tunnel' } else { '' }
)$(
    if ($verbose) { ' -v' } else { '' }
)
pause
"@
    $batchPath = Join-Path $Script:BinDir 'start-amfetamin-visible.cmd'
    Set-Content -Path $batchPath -Value $batch -Encoding ASCII
    Start-Process cmd.exe -ArgumentList "/c `"$batchPath`"" -Verb RunAs
    Start-Sleep -Seconds 2
    Write-AmfetaminLog -Message 'Motor gorunur modda baslatildi' -Level INFO -Audit
    return (T 'msg_engine_console_opened')
}

function Stop-Amfetamin {
    $procs = @(Get-AmfetaminEngineProcesses)
    if (-not $procs) {
        Stop-LegacyEngine | Out-Null
        return (T 'msg_engine_not_running')
    }
    $procs | Stop-Process -Force
    Write-LauncherLog 'amfetamin durduruldu'
    Write-AmfetaminLog -Message 'Motor durduruldu' -Level INFO -Audit
    return (T 'msg_engine_stopped')
}

function Reset-SystemDnsIfNeeded {
    Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.ServerAddresses -contains '127.0.0.1') {
            Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
            Write-LauncherLog "DNS geri alindi: $($_.InterfaceAlias)"
        }
    }
}

function Invoke-AmfetaminCleanup {
    if (-not (Test-IsAdmin)) { throw (T 'err_admin_required') }

    $messages = @()
    Write-AmfetaminLog -Message 'Tam temizlik basladi' -Level WARN -Audit

    $messages += Stop-Amfetamin
    Stop-LegacyEngine | Out-Null

    if (Test-Path $Script:EngineExe) {
        try {
            & $Script:EngineExe cleanup 2>&1 | Out-Null
            $messages += (T 'msg_route_dns_restored')
            Write-LauncherLog 'engine cleanup calistirildi'
        } catch {
            $messages += (T 'msg_engine_cleanup_warning' $_.Exception.Message)
            Write-AmfetaminError -Message 'engine cleanup hata' -Exception $_.Exception
        }
    } else {
        $messages += (T 'msg_engine_exe_missing')
    }

    $messages += Unregister-AutoStartTask
    Reset-SystemDnsIfNeeded
    $messages += (T 'msg_dns_checked')

    $batchPath = Join-Path $Script:BinDir 'start-amfetamin-visible.cmd'
    if (Test-Path $batchPath) {
        Remove-Item $batchPath -Force -ErrorAction SilentlyContinue
        $messages += (T 'msg_temp_script_deleted')
    }

    try {
        Set-ConfigValues @{ autoTuneDone = $false }
    } catch {}

    Write-LauncherLog 'tam temizlik tamamlandi'
    return ($messages -join "`n")
}

function Get-TaskUserId {
    return [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
}

function Register-AutoStartTask {
    if (-not (Test-IsAdmin)) { throw (T 'err_admin_required') }
    Sync-LauncherToDevice
    Ensure-EngineBinary

    $existing = Get-ScheduledTask -TaskName $Script:TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $Script:TaskName -Confirm:$false
    }

    $taskUser = Get-TaskUserId
    $psExe = (Get-Command powershell.exe).Source
    $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Script:ServiceScript`""
    $action = New-ScheduledTaskAction -Execute $psExe -Argument $arg -WorkingDirectory $Script:InstallRoot
    $triggerLogon = New-ScheduledTaskTrigger -AtLogOn -User $taskUser
    $triggerLogon.Delay = 'PT45S'
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId $taskUser -RunLevel Highest -LogonType Interactive

    Register-ScheduledTask -TaskName $Script:TaskName -Action $action -Trigger $triggerLogon `
        -Settings $settings -Principal $principal -Description 'amfetamin otomatik baslatma' | Out-Null
    Enable-ScheduledTask -TaskName $Script:TaskName | Out-Null
    Write-LauncherLog "Zamanlanmis gorev olusturuldu ($taskUser, 45sn gecikme)"
    Write-AmfetaminLog -Message "Otomatik baslatma gorevi olusturuldu ($taskUser)" -Level INFO -Audit
}

function Unregister-AutoStartTask {
    if (-not (Test-IsAdmin)) { throw (T 'err_admin_required') }
    $existing = Get-ScheduledTask -TaskName $Script:TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $Script:TaskName -Confirm:$false
        Write-LauncherLog 'Zamanlanmis gorev kaldirildi'
        Write-AmfetaminLog -Message 'Otomatik baslatma kaldirildi' -Level INFO -Audit
        return (T 'msg_autostart_removed')
    }
    return (T 'msg_autostart_not_installed')
}

function Install-ToDevice {
    param([scriptblock]$Progress = $null)

    if (-not (Test-IsAdmin)) { throw (T 'err_admin_required') }

    Stop-ZeroTierIfRunning | Out-Null
    Write-AmfetaminLog -Message 'Cihaza kurulum basladi' -Level INFO -Audit
    $messages = @()
    if (-not (Test-NpcapInstalled)) {
        if ($Progress) { & $Progress (T 'progress_npcap_installing') }
        $npcapMsg = Install-NpcapAuto
        if ($npcapMsg) { $messages += $npcapMsg }
    }

    if ($Progress) { & $Progress (T 'progress_sync_files') }
    Sync-LauncherToDevice
    if ($Progress) { & $Progress (T 'progress_download_engine') }
    Ensure-EngineBinary
    Register-AutoStartTask

    if (Test-ShouldAutoTuneFakeTtl) {
        if ($Progress) { & $Progress (T 'progress_ttl_autotune') }
        $messages += Invoke-FakeTtlAutoTune -Progress $Progress
    } else {
        Start-AmfetaminHidden | Out-Null
    }

    if (-not (Test-AmfetaminRunning)) {
        throw (T 'err_install_engine_failed')
    }

    $cfg = Get-Config
    $ttlInfo = if ($cfg.fakeTtl) { "fakeTtl=$($cfg.fakeTtl)" } else { '' }

    $messages += @(
        (T 'install_complete_title'),
        (T 'install_complete_autostart'),
        (T 'install_complete_running'),
        (T 'install_complete_location' $Script:InstallRoot),
        $(if ($ttlInfo) { (T 'install_complete_ttl' $ttlInfo) }),
        '',
        (T 'install_discord_hint_header'),
        (T 'install_discord_quic'),
        (T 'install_discord_dns'),
        (T 'install_discord_vpn')
    ) | Where-Object { $_ }

    Write-AmfetaminLog -Message 'Cihaza kurulum tamamlandi' -Level INFO -Audit
    return ($messages -join "`n")
}

function Uninstall-FromDevice {
    $result = Invoke-AmfetaminCleanup
    Write-AmfetaminLog -Message 'Cihazdan kaldirildi' -Level WARN -Audit
    return "$(T 'msg_uninstalled')`n$result"
}

function Install-And-Start {
    if (-not (Test-NpcapInstalled)) {
        Install-NpcapAuto | Out-Null
    }
    Sync-LauncherToDevice
    Start-AmfetaminVisible
}

function Save-AmfetaminSettings {
    param(
        [string]$DohUpstream,
        [int]$FakeTtl,
        [bool]$AutoTuneTtl,
        [bool]$Warmup,
        [bool]$SplitTunnel,
        [bool]$EngineVerbose
    )
    $vals = @{}
    if ($DohUpstream) { $vals.dohUpstream = $DohUpstream }
    if ($FakeTtl -gt 0) { $vals.fakeTtl = $FakeTtl }
    if ($null -ne $AutoTuneTtl) { $vals.autoTuneTtl = $AutoTuneTtl }
    if ($null -ne $Warmup) { $vals.warmup = $Warmup }
    if ($null -ne $SplitTunnel) { $vals.splitTunnel = $SplitTunnel }
    if ($null -ne $EngineVerbose) { $vals.engineVerbose = $EngineVerbose }
    Set-ConfigValues $vals
    Sync-LauncherToDevice
    return (T 'msg_settings_saved')
}

if (-not (Get-Command Get-AmfetaminDiagnosticReport -ErrorAction SilentlyContinue)) {
    if (Get-Command Get-AmfetaminUtf8ScriptBlock -ErrorAction SilentlyContinue) {
        $diagPath = Join-Path $PSScriptRoot 'AmfetaminDiagnostics.ps1'
        if (-not [string]::IsNullOrWhiteSpace($diagPath) -and (Test-Path -LiteralPath $diagPath)) {
            . (Get-AmfetaminUtf8ScriptBlock $diagPath)
        }
    }
}

Write-AmfetaminLog -Message 'AmfetaminCore yuklendi' -Level DEBUG
