using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

namespace Amfetamin
{
    internal sealed class UpdateInfo
    {
        public string Tag;
        public string ZipUrl;
        public string ChecksumsUrl;
    }

    /// <summary>
    /// Self-update: download the release zip, verify it, extract it and hand
    /// over to the new exe (--apply-update), which replaces the installed copy.
    /// </summary>
    internal static class Updater
    {
        private const string ZipName = "amfetamin-windows.zip";

        /// <summary>Returns the latest release if it is newer than this build, else null.</summary>
        public static async Task<UpdateInfo> CheckAsync(CancellationToken ct)
        {
            var json = await Http.GetStringAsync($"https://api.github.com/repos/{AppInfo.Repo}/releases/latest", TimeSpan.FromSeconds(15), ct);
            var tag = Regex.Match(json, "\"tag_name\"\\s*:\\s*\"([^\"]+)\"").Groups[1].Value;
            if (!IsNewer(tag)) return null;
            string Asset(string name) => Regex.Match(json, "\"browser_download_url\"\\s*:\\s*\"([^\"]*/" + Regex.Escape(name) + ")\"").Groups[1].Value;
            var info = new UpdateInfo { Tag = tag, ZipUrl = Asset(ZipName), ChecksumsUrl = Asset("checksums.txt") };
            return info.ZipUrl.Length > 0 ? info : null;
        }

        public static bool IsNewer(string tag)
        {
            var core = Regex.Match(tag ?? "", @"\d+(\.\d+){1,3}").Value;
            if (!Version.TryParse(core, out var latest)) return false;
            var cur = AppInfo.Version;
            return new Version(latest.Major, latest.Minor, Math.Max(0, latest.Build)) >
                   new Version(cur.Major, cur.Minor, Math.Max(0, cur.Build));
        }

        /// <summary>Downloads and verifies the update, then starts the new exe. The caller must exit.</summary>
        public static async Task LaunchAsync(UpdateInfo info, bool reconnect, IProgress<string> progress, CancellationToken ct)
        {
            var dir = Path.Combine(Path.GetTempPath(), "amfetamin-update-" + info.Tag);
            var zip = dir + ".zip";
            if (Directory.Exists(dir)) Directory.Delete(dir, true);

            var pct = new Progress<int>(p => progress.Report(S.T("update_downloading", p)));
            await Http.DownloadAsync(info.ZipUrl, zip, pct, ct);
            if (info.ChecksumsUrl.Length > 0)
            {
                var sums = await Http.GetStringAsync(info.ChecksumsUrl, TimeSpan.FromSeconds(30), ct);
                var expected = sums.Split('\n')
                    .Select(l => l.Trim().Split(new[] { ' ', '\t', '*' }, StringSplitOptions.RemoveEmptyEntries))
                    .Where(f => f.Length >= 2 && f[f.Length - 1] == ZipName)
                    .Select(f => f[0]).FirstOrDefault();
                if (expected == null || !string.Equals(expected, Sha256(zip), StringComparison.OrdinalIgnoreCase))
                {
                    File.Delete(zip);
                    throw new UserFacingException(S.T("err_checksum"));
                }
            }
            ZipFile.ExtractToDirectory(zip, dir);
            File.Delete(zip);

            var exe = Path.Combine(dir, "Amfetamin.exe");
            if (!File.Exists(exe)) throw new UserFacingException(S.T("update_failed", "Amfetamin.exe"));
            Log.Info($"Update {info.Tag} downloaded; handing over to {exe}");
            Process.Start(new ProcessStartInfo(exe, "--apply-update" + (reconnect ? " --connect" : ""))
            {
                UseShellExecute = true,
                WorkingDirectory = dir,
            });
        }

        /// <summary>
        /// Runs in the freshly extracted exe once the old instance has exited:
        /// installs this build, then starts the installed copy.
        /// </summary>
        public static ProcessStartInfo Apply(bool reconnect)
        {
            Log.Info($"Applying update {AppInfo.VersionText} from {Paths.CurrentDir}");
            EngineController.EnsureInstalledAsync(new Progress<string>(), CancellationToken.None).GetAwaiter().GetResult();
            AutoStart.InstallSelf();
            if (AutoStart.IsEnabled()) AutoStart.Enable(); // refresh the task definition
            Migration.RemoveLegacyFiles();
            return new ProcessStartInfo(Paths.InstalledExe, reconnect ? "--connect" : "")
            {
                UseShellExecute = true,
                WorkingDirectory = Paths.InstallRoot,
            };
        }

        private static string Sha256(string path)
        {
            using (var sha = SHA256.Create())
            using (var fs = File.OpenRead(path))
                return BitConverter.ToString(sha.ComputeHash(fs)).Replace("-", "");
        }
    }

    /// <summary>
    /// Brings installs made by the pre-4.0 PowerShell launcher up to date
    /// without user interaction: settings and TTL are kept, Npcap is reused.
    /// </summary>
    internal static class Migration
    {
        private static string LegacyLibDir => Path.Combine(Paths.InstallRoot, "lib");

        /// <summary>True when an earlier install exists and only needs the new engine/task.</summary>
        public static bool Needed()
        {
            if (!Npcap.IsInstalled()) return false; // first-time setup, handled interactively
            var previousInstall = File.Exists(Paths.ConfigFile) || File.Exists(Paths.LegacyEngineExe) || File.Exists(Paths.EngineExe);
            return previousInstall && (EngineController.NeedsInstall() || Directory.Exists(LegacyLibDir) || AutoStart.LegacyEnabled());
        }

        public static bool LegacyEngineRunning()
        {
            foreach (var p in Process.GetProcessesByName("amfetamin"))
            {
                try
                {
                    if (string.Equals(p.MainModule?.FileName, Paths.LegacyEngineExe, StringComparison.OrdinalIgnoreCase)) return true;
                }
                catch { }
                finally { p.Dispose(); }
            }
            return false;
        }

        public static void RemoveLegacyFiles()
        {
            try { if (Directory.Exists(LegacyLibDir)) Directory.Delete(LegacyLibDir, true); } catch { }
            foreach (var f in new[] { "start-amfetamin-visible.cmd", "npcap-installer.exe", "_download.tmp" })
                try { File.Delete(Path.Combine(Paths.BinDir, f)); } catch { }
            try { File.Delete(Path.Combine(Paths.InstallRoot, "amfetamin.ico")); } catch { }
        }
    }
}
