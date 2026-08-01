# amfetamin — gelismis log sistemi
$Script:LogLevels = @{ DEBUG = 0; INFO = 1; WARN = 2; ERROR = 3; FATAL = 4 }

function Initialize-AmfetaminLogging {
    if (-not $Script:LogDir) {
        $Script:LogDir = Join-Path (Join-Path $env:LOCALAPPDATA 'Amfetamin') 'logs'
    }
    foreach ($d in @($Script:LogDir)) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    $Script:AppLog = Join-Path $Script:LogDir 'app.log'
    $Script:ErrorLog = Join-Path $Script:LogDir 'errors.log'
    $Script:AuditLog = Join-Path $Script:LogDir 'audit.log'
    $Script:LauncherLog = Join-Path $Script:LogDir 'launcher.log'
    $Script:ServiceLog = Join-Path $Script:LogDir 'service.log'
    $Script:RunLog = Join-Path $Script:LogDir 'amfetamin-run.log'
    $Script:LogSubscribers = [System.Collections.ArrayList]::new()
}

function Register-LogSubscriber {
    param([scriptblock]$Handler)
    if (-not $Script:LogSubscribers) { $Script:LogSubscribers = [System.Collections.ArrayList]::new() }
    [void]$Script:LogSubscribers.Add($Handler)
}

function Invoke-LogSubscribers {
    param([string]$Line, [string]$Level)
    if (-not $Script:LogSubscribers) { return }
    foreach ($sub in $Script:LogSubscribers) {
        try { & $sub $Line $Level } catch {}
    }
}

function Write-AmfetaminLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('DEBUG','INFO','WARN','ERROR','FATAL')][string]$Level = 'INFO',
        [switch]$Audit,
        [switch]$NoConsole
    )
    if (-not $Script:AppLog) { Initialize-AmfetaminLogging }
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $line = "[$ts] [$Level] $Message"
    try {
        Add-Content -Path $Script:AppLog -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($Level -in @('ERROR','FATAL')) {
            Add-Content -Path $Script:ErrorLog -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        if ($Audit) {
            Add-Content -Path $Script:AuditLog -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        Invoke-LogSubscribers -Line $line -Level $Level
    } catch {}
}

function Write-LauncherLog([string]$Message) {
    Write-AmfetaminLog -Message $Message -Level INFO
    if (-not $Script:LauncherLog) { Initialize-AmfetaminLogging }
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $Script:LauncherLog -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Write-ServiceLog([string]$Message) {
    Write-AmfetaminLog -Message "[service] $Message" -Level INFO
    if (-not $Script:ServiceLog) { Initialize-AmfetaminLogging }
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $Script:ServiceLog -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Write-AmfetaminError {
    param(
        [string]$Message,
        [System.Exception]$Exception = $null,
        [string]$Context = ''
    )
    $full = if ($Context) { "[$Context] $Message" } else { $Message }
    if ($Exception) { $full += " | $($Exception.GetType().Name): $($Exception.Message)" }
    Write-AmfetaminLog -Message $full -Level ERROR
}

function Invoke-AmfetaminLogRotation {
    param([int]$MaxMb = 5)
    if (-not $Script:LogDir) { Initialize-AmfetaminLogging }
    $limit = $MaxMb * 1MB
    foreach ($path in @($Script:AppLog, $Script:ErrorLog, $Script:AuditLog, $Script:LauncherLog, $Script:ServiceLog, $Script:RunLog)) {
        if ((Test-Path $path) -and ((Get-Item $path).Length -gt $limit)) {
            $bak = "$path.old"
            if (Test-Path $bak) { Remove-Item $bak -Force -ErrorAction SilentlyContinue }
            Move-Item $path $bak -Force -ErrorAction SilentlyContinue
            Write-AmfetaminLog -Message "Log donduruldu: $(Split-Path $path -Leaf)" -Level DEBUG
        }
    }
}

function Get-AmfetaminLogTail {
    param(
        [string]$LogName = 'app.log',
        [int]$Lines = 200
    )
    if (-not $Script:LogDir) { Initialize-AmfetaminLogging }
    $path = Join-Path $Script:LogDir $LogName
    if (-not (Test-Path $path)) { return @() }
    return @(Get-Content $path -Tail $Lines -ErrorAction SilentlyContinue)
}

function Export-AmfetaminLogs {
    param([string]$DestPath)
    if (-not $Script:LogDir) { Initialize-AmfetaminLogging }
    $dest = if ($DestPath) { $DestPath } else {
        Join-Path $env:USERPROFILE "Desktop\amfetamin-logs-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
    }
    $temp = Join-Path $env:TEMP "amfetamin-log-export-$(Get-Random)"
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    try {
        Get-ChildItem $Script:LogDir -File -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $temp $_.Name) -Force
        }
        $cfg = Join-Path (Join-Path $env:LOCALAPPDATA 'Amfetamin') 'config.json'
        if (Test-Path $cfg) { Copy-Item $cfg (Join-Path $temp 'config.json') -Force }
        if (Test-Path $dest) { Remove-Item $dest -Force }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($temp, $dest)
        Write-AmfetaminLog -Message "Loglar disa aktarildi: $dest" -Level INFO -Audit
        return $dest
    } finally {
        Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Clear-AmfetaminLogs {
    if (-not $Script:LogDir) { Initialize-AmfetaminLogging }
    Get-ChildItem $Script:LogDir -File -ErrorAction SilentlyContinue | ForEach-Object {
        Clear-Content $_.FullName -ErrorAction SilentlyContinue
    }
    Write-AmfetaminLog -Message 'Loglar temizlendi' -Level WARN -Audit
}

function Install-AmfetaminGlobalErrorHandler {
    $global:ErrorActionPreference = 'Stop'
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        Write-AmfetaminLog -Message 'Uygulama kapatiliyor' -Level INFO -Audit
    } -ErrorAction SilentlyContinue | Out-Null
}

Initialize-AmfetaminLogging
Invoke-AmfetaminLogRotation
