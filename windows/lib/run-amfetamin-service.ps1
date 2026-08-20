# amfetamin otomatik baslatma (Task Scheduler)
$ErrorActionPreference = 'Stop'
$LibDir = $PSScriptRoot
$BootLog = Join-Path (Join-Path $env:LOCALAPPDATA 'Amfetamin\logs') 'service-boot.log'

function Write-BootLog([string]$Message) {
    try {
        $dir = Split-Path $BootLog -Parent
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $BootLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" -Encoding UTF8
    } catch {}
}

try {
    Write-BootLog 'Gorev basladi'
    . (Join-Path $LibDir 'AmfetaminEncoding.ps1')
    . (Join-Path $LibDir 'AmfetaminCore.ps1')
    if (Get-Command Initialize-AmfetaminI18n -ErrorAction SilentlyContinue) {
        Initialize-AmfetaminI18n
    }
    if (Get-Command Initialize-AmfetaminLogging -ErrorAction SilentlyContinue) {
        Initialize-AmfetaminLogging
    }
} catch {
    Write-BootLog "Bootstrap hatasi: $($_.Exception.Message)"
    exit 1
}

function Ensure-AmfetaminRunning {
    try {
        Write-ServiceLog 'Otomatik baslatma tetiklendi'
        if (-not (Test-NpcapInstalled)) {
            Write-ServiceLog 'Npcap yok — amfetamin baslatilamadi'
            Write-AmfetaminLog -Message 'Npcap eksik — otomatik baslatma atlandi' -Level WARN
            return
        }
        if (Test-AmfetaminRunning) {
            Write-ServiceLog 'amfetamin zaten calisiyor'
            return
        }
        Stop-LegacyEngine
        Ensure-EngineBinary
        if (-not $Script:RunLog) { Initialize-AmfetaminLogging }
        $engineArgs = @(Get-EngineRunArgs)
        if ($engineArgs.Count -eq 0) {
            Write-ServiceLog 'Motor argumanlari bos — baslatma atlandi'
            return
        }
        Start-Process -FilePath $Script:EngineExe -ArgumentList $engineArgs -WorkingDirectory $Script:BinDir `
            -WindowStyle Hidden -RedirectStandardError $Script:RunLog
        Start-Sleep -Seconds 3
        if (Test-AmfetaminRunning) {
            Invoke-EngineWarmup -NonBlocking
            Write-ServiceLog 'amfetamin baslatildi (otomatik)'
            Write-AmfetaminLog -Message 'Otomatik baslatma basarili' -Level INFO -Audit
        } else {
            Write-ServiceLog 'amfetamin baslatma basarisiz'
            Write-AmfetaminLog -Message 'Otomatik baslatma basarisiz' -Level ERROR
        }
    } catch {
        Write-ServiceLog "Hata: $($_.Exception.Message)"
        Write-AmfetaminError -Message 'Otomatik baslatma hatasi' -Exception $_.Exception
        Write-BootLog "Calistirma hatasi: $($_.Exception.Message)"
    }
}

Ensure-AmfetaminRunning
