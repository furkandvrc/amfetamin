# amfetamin otomatik baslatma (Task Scheduler)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'AmfetaminCore.ps1')

function Ensure-AmfetaminRunning {
    try {
        if (-not (Test-NpcapInstalled)) {
            Write-ServiceLog 'Npcap yok — amfetamin baslatilamadi'
            return
        }
        if (Test-AmfetaminRunning) {
            Write-ServiceLog 'amfetamin zaten calisiyor'
            return
        }
        Stop-LegacyEngine
        Ensure-EngineBinary
        $args = Get-EngineRunArgs
        Start-Process -FilePath $Script:EngineExe -ArgumentList $args -WorkingDirectory $Script:BinDir `
            -WindowStyle Hidden
        Start-Sleep -Seconds 3
        if (Test-AmfetaminRunning) {
            Invoke-EngineWarmup
            Write-ServiceLog 'amfetamin baslatildi (otomatik)'
        } else {
            Write-ServiceLog 'amfetamin baslatma basarisiz — amfetamin-run.log kontrol edin'
        }
    } catch {
        Write-ServiceLog "Hata: $($_.Exception.Message)"
    }
}

Ensure-AmfetaminRunning
