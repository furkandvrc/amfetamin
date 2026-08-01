# amfetamin otomatik baslatma (Task Scheduler)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'AmfetaminCore.ps1')

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
        $args = Get-EngineRunArgs
        Start-Process -FilePath $Script:EngineExe -ArgumentList $args -WorkingDirectory $Script:BinDir `
            -WindowStyle Hidden -RedirectStandardError $Script:RunLog
        Start-Sleep -Seconds 3
        if (Test-AmfetaminRunning) {
            Invoke-EngineWarmup
            Write-ServiceLog 'amfetamin baslatildi (otomatik)'
            Write-AmfetaminLog -Message 'Otomatik baslatma basarili' -Level INFO -Audit
        } else {
            Write-ServiceLog 'amfetamin baslatma basarisiz'
            Write-AmfetaminLog -Message 'Otomatik baslatma basarisiz' -Level ERROR
        }
    } catch {
        Write-ServiceLog "Hata: $($_.Exception.Message)"
        Write-AmfetaminError -Message 'Otomatik baslatma hatasi' -Exception $_.Exception
    }
}

Ensure-AmfetaminRunning
