# amfetamin - core
$ErrorActionPreference = 'Stop'

$Script:TaskName = 'Amfetamin-AutoStart'
$Script:InstallRoot = Join-Path $env:LOCALAPPDATA 'Amfetamin'
$Script:BinDir = Join-Path $InstallRoot 'bin'
$Script:LogDir = Join-Path $InstallRoot 'logs'
$Script:LibDir = Join-Path $InstallRoot 'lib'
$Script:EngineExe = Join-Path $BinDir 'amfetamin.exe'
$Script:NpcapInstaller = Join-Path $BinDir 'npcap-installer.exe'
$Script:ConfigPath = Join-Path $InstallRoot 'config.json'
$Script:ServiceScript = Join-Path $LibDir 'run-amfetamin-service.ps1'
$Script:RunLog = Join-Path $LogDir 'amfetamin-run.log'
$Script:LauncherLog = Join-Path $LogDir 'launcher.log'
$Script:ServiceLog = Join-Path $LogDir 'service.log'

# Motor indirme (v0.1.4)
$Script:EngineVersion = 'v0.1.4'
$Script:EngineReleaseBase = 'https://github.com/boratanrikulu/gecit/releases/download'
$Script:EngineRemoteAsset = 'gecit-windows-amd64.exe'
$Script:EngineChecksumFile = 'checksums.txt'

function Get-ProjectRoot {
    if ($env:AMFETAMIN_ROOT -and (Test-Path $env:AMFETAMIN_ROOT)) {
        return $env:AMFETAMIN_ROOT
    }
    if ($PSScriptRoot -match '\\lib$') {
        return Split-Path $PSScriptRoot -Parent
    }
    if ($PSScriptRoot) { return $PSScriptRoot }
    return Split-Path -Parent $MyInvocation.MyCommand.Path
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

function Get-PowerShellPath {
    return Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
}

function Get-LauncherPath {
    $root = Get-ProjectRoot
    $exe = Join-Path $root 'Amfetamin.exe'
    if (Test-Path $exe) { return $exe }
    $ps1 = Join-Path $root 'Amfetamin.ps1'
    if (Test-Path $ps1) { return $ps1 }
    return $MyInvocation.MyCommand.Path
}

function Request-Admin([string[]]$ExtraArgs) {
    if (Test-IsAdmin) { return $true }
    $launcher = Get-LauncherPath
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
    Get-Process -Name 'gecit' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $legacy = Join-Path $BinDir 'gecit.exe'
    if (Test-Path $legacy) { Remove-Item $legacy -Force -ErrorAction SilentlyContinue }
}

function Test-AmfetaminRunning {
    return $null -ne (Get-Process -Name 'amfetamin' -ErrorAction SilentlyContinue)
}

function Test-AutoStartInstalled {
    $task = Get-ScheduledTask -TaskName $Script:TaskName -ErrorAction SilentlyContinue
    return $null -ne $task
}

function Get-AmfetaminStatus {
    [PSCustomObject]@{
        NpcapInstalled = Test-NpcapInstalled
        EngineDownloaded = Test-Path $Script:EngineExe
        EngineRunning = Test-AmfetaminRunning
        AutoStartInstalled = Test-AutoStartInstalled
        InstallRoot = $Script:InstallRoot
    }
}

function Invoke-DownloadFile([string]$Url, [string]$Dest) {
    Write-LauncherLog "Indiriliyor: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
}

function Install-EngineBinary {
    Ensure-Dirs
    Stop-LegacyEngine
    $base = "$($Script:EngineReleaseBase)/$($Script:EngineVersion)"
    Invoke-DownloadFile "$base/$($Script:EngineChecksumFile)" (Join-Path $BinDir 'checksums.txt')
    $tmp = Join-Path $BinDir '_download.tmp'
    Invoke-DownloadFile "$base/$($Script:EngineRemoteAsset)" $tmp

    $expectedLine = Get-Content (Join-Path $BinDir 'checksums.txt') | Where-Object { $_ -match [regex]::Escape($Script:EngineRemoteAsset) }
    if (-not $expectedLine) { throw 'checksums.txt icinde motor dosyasi bulunamadi' }
    $expectedHash = ($expectedLine -split '\s+')[0].ToUpperInvariant()
    $actualHash = (Get-FileHash $tmp -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($expectedHash -ne $actualHash) {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        throw "SHA256 uyusmadi! Beklenen: $expectedHash Alinan: $actualHash"
    }
    Move-Item $tmp $Script:EngineExe -Force
    Write-LauncherLog 'amfetamin.exe indirildi ve dogrulandi'
}

function Ensure-EngineBinary {
    if (Test-Path $Script:EngineExe) { return }
    Install-EngineBinary
}

function Sync-LauncherToDevice {
    Ensure-Dirs
    $projectRoot = Get-ProjectRoot
    Copy-Item (Join-Path $projectRoot 'config.json') $Script:ConfigPath -Force
    Copy-Item (Join-Path $projectRoot 'lib\AmfetaminCore.ps1') (Join-Path $LibDir 'AmfetaminCore.ps1') -Force
    Copy-Item (Join-Path $projectRoot 'lib\run-amfetamin-service.ps1') $Script:ServiceScript -Force
    Copy-Item (Join-Path $projectRoot 'lib\AmfetaminUI.ps1') (Join-Path $LibDir 'AmfetaminUI.ps1') -Force -ErrorAction SilentlyContinue
    foreach ($icoName in @('amfetamin.ico', (Join-Path 'assets' 'amfetamin.ico'))) {
        $icoSrc = Join-Path $projectRoot $icoName
        if (Test-Path $icoSrc) {
            Copy-Item $icoSrc (Join-Path $InstallRoot 'amfetamin.ico') -Force
            break
        }
    }
    Write-LauncherLog 'amfetamin dosyalari cihaza kopyalandi'
}

function Install-NpcapAuto {
    if (Test-NpcapInstalled) { return $null }
    if (-not (Test-IsAdmin)) { throw 'Yonetici yetkisi gerekli' }

    Ensure-Dirs
    $cfg = Get-Config
    if (-not (Test-Path $Script:NpcapInstaller)) {
        Invoke-DownloadFile $cfg.npcapUrl $Script:NpcapInstaller
    }

    Write-LauncherLog 'Npcap kurulumu baslatiliyor'
    $installArgs = '/winpcap_mode=yes'
    Start-Process -FilePath $Script:NpcapInstaller -ArgumentList $installArgs -Verb RunAs -Wait | Out-Null
    Start-Sleep -Seconds 2

    if (-not (Test-NpcapInstalled)) {
        throw 'Npcap kurulamadi. Acilan pencerede kurulumu tamamlayip tekrar deneyin.'
    }

    Write-LauncherLog 'Npcap kuruldu'
    return 'Npcap kuruldu'
}

function Install-NpcapGui {
    if (Test-NpcapInstalled) { return 'Npcap zaten kurulu' }
    return Install-NpcapAuto
}

function Get-EngineRunArgs {
    param([switch]$VerboseLog)
    $cfg = Get-Config
    $parts = @('run', '--doh-upstream', [string]$cfg.dohUpstream)
    if ($cfg.PSObject.Properties['fakeTtl'] -and $cfg.fakeTtl) {
        $parts += @('--fake-ttl', [string]$cfg.fakeTtl)
    }
    if ($VerboseLog) { $parts += '-v' }
    return $parts
}

function Get-EngineRunArgsLine {
    param([switch]$VerboseLog)
    return ((Get-EngineRunArgs -VerboseLog:$VerboseLog) -join ' ')
}

function Invoke-EngineWarmup {
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

    $done = Wait-Job $job -Timeout 12
    if ($done) { Receive-Job $job | Out-Null }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    Write-LauncherLog 'Motor isinma tamamlandi'
}

function Start-AmfetaminHidden {
    if (-not (Test-IsAdmin)) { throw 'Yonetici yetkisi gerekli' }
    if (-not (Test-NpcapInstalled)) { throw 'Npcap kurulu degil' }
    Ensure-EngineBinary
    Stop-LegacyEngine
    if (Test-AmfetaminRunning) { return 'amfetamin zaten calisiyor' }

    $args = Get-EngineRunArgs
    $proc = Start-Process -FilePath $Script:EngineExe -ArgumentList $args -WorkingDirectory $BinDir `
        -WindowStyle Hidden -PassThru -RedirectStandardError $Script:RunLog
    Start-Sleep -Seconds 2
    if (-not $proc.HasExited -and (Test-AmfetaminRunning)) {
        Write-LauncherLog "amfetamin arka planda baslatildi (PID $($proc.Id))"
        Invoke-EngineWarmup
        return 'amfetamin arka planda baslatildi'
    }
    if (Test-AmfetaminRunning) {
        Invoke-EngineWarmup
        return 'amfetamin calisiyor'
    }
    $hint = if (Test-Path $Script:RunLog) { Get-Content $Script:RunLog -Raw -ErrorAction SilentlyContinue } else { '' }
    throw "amfetamin baslatilamadi. logs\amfetamin-run.log dosyasina bakin.`n$hint"
}

function Start-AmfetaminVisible {
    if (-not (Test-IsAdmin)) { throw 'Yonetici yetkisi gerekli' }
    if (-not (Test-NpcapInstalled)) { throw 'Npcap kurulu degil' }
    Ensure-EngineBinary
    Stop-LegacyEngine
    if (Test-AmfetaminRunning) { return 'amfetamin zaten calisiyor' }

    $cfg = Get-Config
    $verbose = $true
    if ($cfg.PSObject.Properties['engineVerbose'] -and $cfg.engineVerbose -eq $false) { $verbose = $false }
    $upstream = [string]$cfg.dohUpstream
    $argLine = Get-EngineRunArgsLine -VerboseLog:$verbose
    $batch = @"
@echo off
cd /d "$BinDir"
title amfetamin
echo amfetamin calisiyor. Kapatmak icin Ctrl+C
"$EngineExe" run --doh-upstream "$upstream"$(
    if ($cfg.PSObject.Properties['fakeTtl'] -and $cfg.fakeTtl) { " --fake-ttl $($cfg.fakeTtl)" } else { '' }
)$(
    if ($verbose) { ' -v' } else { '' }
)
pause
"@
    $batchPath = Join-Path $BinDir 'start-amfetamin-visible.cmd'
    Set-Content -Path $batchPath -Value $batch -Encoding ASCII
    Start-Process cmd.exe -ArgumentList "/c `"$batchPath`"" -Verb RunAs
    Start-Sleep -Seconds 2
    return 'amfetamin konsol penceresi acildi'
}

function Stop-Amfetamin {
    $procs = Get-Process -Name 'amfetamin' -ErrorAction SilentlyContinue
    if (-not $procs) {
        Stop-LegacyEngine | Out-Null
        return 'amfetamin zaten calismiyor'
    }
    $procs | Stop-Process -Force
    Write-LauncherLog 'amfetamin durduruldu'
    return 'amfetamin durduruldu'
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
    if (-not (Test-IsAdmin)) { throw 'Yonetici yetkisi gerekli' }
    Stop-Amfetamin | Out-Null
    if (Test-Path $Script:EngineExe) {
        & $Script:EngineExe cleanup 2>&1 | Out-Null
    }
    Reset-SystemDnsIfNeeded
    Write-LauncherLog 'cleanup tamamlandi'
    return 'DNS ve route ayarlari geri alindi'
}

function Get-TaskUserId {
    return [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
}

function Register-AutoStartTask {
    if (-not (Test-IsAdmin)) { throw 'Yonetici yetkisi gerekli' }
    Sync-LauncherToDevice
    Ensure-EngineBinary

    $existing = Get-ScheduledTask -TaskName $Script:TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $Script:TaskName -Confirm:$false
    }

    $taskUser = Get-TaskUserId
    $psExe = (Get-Command powershell.exe).Source
    $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Script:ServiceScript`""
    $action = New-ScheduledTaskAction -Execute $psExe -Argument $arg -WorkingDirectory $InstallRoot
    $triggerLogon = New-ScheduledTaskTrigger -AtLogOn -User $taskUser
    $triggerBoot = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
    $principal = New-ScheduledTaskPrincipal -UserId $taskUser -RunLevel Highest -LogonType Interactive

    Register-ScheduledTask -TaskName $Script:TaskName -Action $action -Trigger @($triggerLogon, $triggerBoot) `
        -Settings $settings -Principal $principal -Description 'amfetamin otomatik baslatma' | Out-Null
    Write-LauncherLog "Zamanlanmis gorev olusturuldu ($taskUser)"
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
    if (-not (Test-IsAdmin)) { throw 'Yonetici yetkisi gerekli' }

    $messages = @()
    if (-not (Test-NpcapInstalled)) {
        $npcapMsg = Install-NpcapAuto
        if ($npcapMsg) { $messages += $npcapMsg }
    }

    Sync-LauncherToDevice
    Ensure-EngineBinary
    Register-AutoStartTask
    Start-AmfetaminHidden | Out-Null
    if (-not (Test-AmfetaminRunning)) {
        throw 'Kurulum kaydedildi ama motor baslatilamadi. SIMDI BASLAT ile tekrar deneyin.'
    }

    $messages += @(
        'Cihaza kurulum tamamlandi!',
        '- Her acilista amfetamin otomatik baslar',
        '- Simdi arka planda calisiyor',
        "- Konum: $InstallRoot",
        '',
        'Discord web acilmiyorsa tarayicida:',
        '- Chrome/Edge: chrome://flags/#enable-quic -> Disabled',
        '- Ayarlar -> Guvenli DNS -> Kapali',
        '- Sayfayi yenile veya gizli pencere dene'
    )
    return ($messages -join "`n")
}

function Uninstall-FromDevice {
    Stop-Amfetamin | Out-Null
    Invoke-AmfetaminCleanup | Out-Null
    Unregister-AutoStartTask | Out-Null
    Reset-SystemDnsIfNeeded
    return 'Cihazdan kaldirildi. amfetamin durduruldu, otomatik baslatma silindi, DNS geri alindi.'
}

function Install-And-Start {
    if (-not (Test-NpcapInstalled)) {
        Install-NpcapAuto | Out-Null
    }
    Sync-LauncherToDevice
    Start-AmfetaminVisible
}
