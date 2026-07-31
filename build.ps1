# amfetamin.exe derleme (csc + gomulu script)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$buildDir = Join-Path $root 'build'
$srcDir = Join-Path $root 'src'
$assetsDir = Join-Path $root 'assets'
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
$core = Get-Content (Join-Path $root 'lib\AmfetaminCore.ps1') -Raw
$ui = Get-Content (Join-Path $root 'lib\AmfetaminUI.ps1') -Raw
$main = @'
$ErrorActionPreference = 'Stop'
try {
    Show-AmfetaminSplash
    Show-AmfetaminMainForm
} catch {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'amfetamin', 'OK', 'Error')
    } catch {
        Write-Host $_.Exception.Message
        Read-Host 'Enter'
    }
    exit 1
}
'@

@('# amfetamin bundle - by furkandvrc', $core, $ui, $main) -join "`r`n" | Set-Content $bundle -Encoding ASCII

$scriptText = Get-Content $bundle -Raw -Encoding UTF8
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($scriptText))

$launcherCs = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

static class AmfetaminLauncher
{
    const string ScriptB64 = @"$b64";

    [STAThread]
    static int Main()
    {
        try
        {
            string dir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            string ps = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.System),
                @"WindowsPowerShell\v1.0\powershell.exe");

            if (!File.Exists(ps))
            {
                MessageBox.Show("PowerShell bulunamadi.", "amfetamin", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }

            string scriptPath = Path.Combine(dir, ".amfetamin-run.ps1");
            File.WriteAllText(scriptPath, Encoding.UTF8.GetString(Convert.FromBase64String(ScriptB64)), new UTF8Encoding(false));

            var psi = new ProcessStartInfo
            {
                FileName = ps,
                Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File \"" + scriptPath + "\"",
                WorkingDirectory = dir,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            psi.EnvironmentVariables["AMFETAMIN_ROOT"] = dir;

            using (var proc = Process.Start(psi))
            {
                proc.WaitForExit();
                if (proc.ExitCode != 0)
                {
                    MessageBox.Show("amfetamin baslatilamadi (kod: " + proc.ExitCode + ")", "amfetamin", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
                return proc.ExitCode;
            }
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
if (Test-Path $outExe) { Remove-Item $outExe -Force }

Write-Host 'Amfetamin.exe derleniyor...'
$manifest = Join-Path $srcDir 'app.manifest'
$cscArgs = @('/nologo', '/target:winexe', '/platform:anycpu', "/win32manifest:$manifest", '/reference:System.Windows.Forms.dll', "/out:$outExe")
if ($iconFile -and (Test-Path $iconFile)) { $cscArgs += "/win32icon:$iconFile" }
& $csc @cscArgs $launcherPath
if (-not (Test-Path $outExe)) { throw 'Derleme basarisiz' }
Write-Host "Tamam: $outExe ($((Get-Item $outExe).Length) bytes)"
