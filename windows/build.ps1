# amfetamin.exe derleme (csc + gomulu script)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$repoRoot = Split-Path $root -Parent
$buildDir = Join-Path $root 'build'
$srcDir = Join-Path $root 'src'
$assetsDir = Join-Path $repoRoot 'assets'
$bundle = Join-Path $buildDir 'Amfetamin.bundle.ps1'
$outExe = Join-Path $root 'Amfetamin.exe'
$icoPath = Join-Path $assetsDir 'amfetamin.ico'
$rootIco = Join-Path $root 'amfetamin.ico'
$csc = Join-Path ${env:WINDIR} 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'

function Ensure-AmfetaminIco {
    Add-Type -AssemblyName System.Drawing
    $png = Join-Path $assetsDir 'amfetamin-icon.png'
    if (-not (Test-Path $png)) { return $null }

    $src = [System.Drawing.Image]::FromFile($png)
    $sizes = @(256, 48, 32, 16)
    $mem = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.BinaryWriter($mem)
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$sizes.Count)

    $offset = 6 + (16 * $sizes.Count)
    $images = @()
    foreach ($size in $sizes) {
        $bmp = New-Object System.Drawing.Bitmap($size, $size)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($src, 0, 0, $size, $size)
        $g.Dispose()
        $pngStream = New-Object System.IO.MemoryStream
        $bmp.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $images += ,@($size, $pngStream.ToArray())
        $pngStream.Dispose()
        $bmp.Dispose()
    }

    foreach ($item in $images) {
        $size = $item[0]; $data = $item[1]
        $dim = if ($size -ge 256) { 0 } else { $size }
        $writer.Write([byte]$dim)
        $writer.Write([byte]$dim)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$data.Length)
        $writer.Write([uint32]$offset)
        $offset += $data.Length
    }
    foreach ($item in $images) { $writer.Write($item[1]) }

    [System.IO.File]::WriteAllBytes($icoPath, $mem.ToArray())
    $writer.Close(); $mem.Close(); $src.Dispose()
    Copy-Item $icoPath $rootIco -Force
    return $icoPath
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null
$iconFile = Ensure-AmfetaminIco
$logger = Get-Content (Join-Path $root 'lib\AmfetaminLogger.ps1') -Raw -Encoding UTF8
$i18n = Get-Content (Join-Path $root 'lib\AmfetaminI18n.ps1') -Raw -Encoding UTF8
$diagnostics = Get-Content (Join-Path $root 'lib\AmfetaminDiagnostics.ps1') -Raw -Encoding UTF8
$core = Get-Content (Join-Path $root 'lib\AmfetaminCore.ps1') -Raw -Encoding UTF8
$ui = Get-Content (Join-Path $root 'lib\AmfetaminUI.ps1') -Raw -Encoding UTF8
# Bundle icinde dis dosya dot-source calismaz — inline yukle
$core = $core -replace "\.\s*\(Join-Path\s+\`$PSScriptRoot\s+'AmfetaminLogger\.ps1'\)\s*\r?\n", ''
$core = $core -replace "\.\s*\(Join-Path\s+\`$PSScriptRoot\s+'AmfetaminI18n\.ps1'\)\s*\r?\n", ''
$core = $core -replace "\.\s*\(Join-Path\s+\`$PSScriptRoot\s+'AmfetaminDiagnostics\.ps1'\)\s*\r?\n", ''
$ui = $ui -replace "\.\s*\(Join-Path\s+\`$PSScriptRoot\s+'AmfetaminI18n\.ps1'\)\s*\r?\n", ''
$main = @'
$ErrorActionPreference = 'Stop'
try {
    Initialize-AmfetaminI18n
    Write-AmfetaminLog -Message 'Amfetamin.exe baslatildi' -Level INFO -Audit
    if (-not (Test-IsAdmin)) {
        Request-Admin | Out-Null
        exit 0
    }
    Show-AmfetaminSplash
    Show-AmfetaminMainForm
} catch {
    Write-AmfetaminError -Message 'Kritik hata' -Exception $_.Exception
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'amfetamin', 'OK', 'Error')
    } catch {
        Write-Host $_.Exception.Message
        Read-Host (T 'prompt_press_enter')
    }
    exit 1
}
'@

$bundleText = @('# amfetamin v2 bundle - by furkandvrc', $logger, $i18n, $diagnostics, $core, $ui, $main) -join "`r`n"
[System.IO.File]::WriteAllText($bundle, $bundleText, (New-Object System.Text.UTF8Encoding $false))

$scriptText = Get-Content $bundle -Raw -Encoding UTF8
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($scriptText))

$smaDll = $null
foreach ($candidate in @(
        (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\System.Management.Automation.dll'),
        (Join-Path $env:SystemRoot 'Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\v4.0_3.0.0.0__31bf3856ad364e35\System.Management.Automation.dll')
    )) {
    if (Test-Path $candidate) { $smaDll = $candidate; break }
}
if (-not $smaDll) {
    try {
        Add-Type -AssemblyName System.Management.Automation -ErrorAction Stop
        $smaDll = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault().GetType().Assembly.Location
    } catch {}
}
if (-not $smaDll -or -not (Test-Path $smaDll)) {
    throw 'System.Management.Automation.dll bulunamadi'
}
Write-Host "SMA: $smaDll"

$launcherCs = @"
using System;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

static class AmfetaminLauncher
{
    const string ScriptB64 = @"$b64";

    [STAThread]
    static int Main()
    {
        try
        {
            string dir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            Environment.SetEnvironmentVariable("AMFETAMIN_ROOT", dir);

            string script = Encoding.UTF8.GetString(Convert.FromBase64String(ScriptB64));

            var iss = InitialSessionState.CreateDefault();
            iss.ApartmentState = ApartmentState.STA;

            using (var runspace = RunspaceFactory.CreateRunspace(iss))
            {
                runspace.Open();
                using (var ps = PowerShell.Create())
                {
                    ps.Runspace = runspace;
                    ps.AddScript(script);
                    ps.Invoke();

                    if (ps.HadErrors)
                    {
                        var sb = new StringBuilder();
                        foreach (var err in ps.Streams.Error)
                        {
                            sb.AppendLine(err.ToString());
                        }
                        MessageBox.Show(sb.ToString(), "amfetamin", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        return 1;
                    }
                }
            }
            return 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "amfetamin", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
"@

$launcherPath = Join-Path $buildDir 'AmfetaminLauncher.cs'
Set-Content $launcherPath $launcherCs -Encoding UTF8

if (-not (Test-Path $csc)) { throw "csc.exe bulunamadi: $csc" }
$buildOut = Join-Path $root 'Amfetamin.build.exe'
if (Test-Path $buildOut) { Remove-Item $buildOut -Force -ErrorAction SilentlyContinue }

Write-Host 'Amfetamin.exe derleniyor...'
$manifest = Join-Path $srcDir 'app.manifest'
$cscArgs = @('/nologo', '/target:winexe', '/platform:anycpu', "/win32manifest:$manifest", '/reference:System.Windows.Forms.dll', "/reference:$smaDll", "/out:$buildOut")
if ($iconFile -and (Test-Path $iconFile)) { $cscArgs += "/win32icon:$iconFile" }
& $csc @cscArgs $launcherPath
if (-not (Test-Path $buildOut)) { throw 'Derleme basarisiz' }
try {
    if (Test-Path $outExe) { Remove-Item $outExe -Force }
} catch {
    Write-Warning "Eski exe silinemedi ($($_.Exception.Message)) - Amfetamin.build.exe kullanin"
    Copy-Item $buildOut $outExe -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $outExe)) { Copy-Item $buildOut (Join-Path $root 'Amfetamin.new.exe') -Force; throw 'Amfetamin.exe kilitli. Amfetamin.new.exe olusturuldu.' }
}
if (Test-Path $buildOut) {
    Move-Item $buildOut $outExe -Force
}
Write-Host "Tamam: $outExe ($((Get-Item $outExe).Length) bytes)"
