# Gecit otomatik baslatma servisi (Task Scheduler tarafindan calistirilir)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'GecitCore.ps1')

function Ensure-GecitRunning {
    try {
        if (-not (Test-NpcapInstalled)) {
            Write-ServiceLog 'Npcap yok — Gecit baslatilamadi'
            return
        }
        if (Test-GecitRunning) {
            Write-ServiceLog 'Gecit zaten calisiyor'
            return
        }
        Ensure-GecitBinary
        $cfg = Get-Config
        $args = "run --doh-upstream $($cfg.dohUpstream)"
        Start-Process -FilePath $Script:GecitExe -ArgumentList $args -WorkingDirectory $Script:BinDir `
            -WindowStyle Hidden
        Start-Sleep -Seconds 3
        if (Test-GecitRunning) {
            Write-ServiceLog 'Gecit baslatildi (otomatik)'
        } else {
            Write-ServiceLog 'Gecit baslatma basarisiz — gecit-run.log kontrol edin'
        }
    } catch {
        Write-ServiceLog "Hata: $($_.Exception.Message)"
    }
}

Ensure-GecitRunning
