using System;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;

namespace Amfetamin
{
    internal static class Diagnostics
    {
        public static readonly string[] ProbeUrls =
        {
            "https://discord.com",
            "https://gateway.discord.gg",
            "https://www.google.com/generate_204",
        };

        public static async Task<string> ConnectivityAsync(CancellationToken ct)
        {
            var tasks = ProbeUrls.Select(u => Http.ProbeAsync(u, TimeSpan.FromSeconds(10), ct)).ToArray();
            var results = await Task.WhenAll(tasks);
            var sb = new StringBuilder();
            for (var i = 0; i < ProbeUrls.Length; i++)
            {
                var r = results[i];
                var host = new Uri(ProbeUrls[i]).Host;
                sb.AppendLine(S.T("test_result", host, r.Ok ? S.T("test_ok", r.Ms) : S.T("test_fail", r.Detail)));
            }
            return sb.ToString().TrimEnd();
        }

        public static async Task<string> BuildReportAsync(CancellationToken ct)
        {
            var sb = new StringBuilder();
            void Line(string s = "") => sb.AppendLine(s);
            void Section(string s) { Line(); Line("== " + s + " =="); }

            Line($"amfetamin {AppInfo.VersionText}  ·  engine {AppInfo.EngineTag}  ·  {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
            Line($"Windows: {WindowsVersion()}  ·  64-bit: {Environment.Is64BitOperatingSystem}  ·  .NET: {Environment.Version}");

            Section("Status");
            Line($"Npcap: {(Npcap.IsInstalled() ? "installed " + (Npcap.Version() ?? "") : "MISSING")}");
            Line($"Engine binary: {(EngineController.BinaryInstalled ? Paths.EngineExe : "MISSING")}");
            Line($"Engine running: {EngineController.IsRunning}");
            Line($"Auto-start: {AutoStart.IsEnabled()}");
            var cfg = AppConfig.Load();
            Line($"Engine args: {EngineController.BuildArgs(cfg)}");
            var conflicts = Conflicts.Detect();
            Line($"Conflicting software: {(conflicts.Count == 0 ? "none" : string.Join(", ", conflicts))}");

            Section("Network adapters");
            foreach (var nic in NetworkInterface.GetAllNetworkInterfaces().Where(n => n.OperationalStatus == OperationalStatus.Up))
            {
                var props = nic.GetIPProperties();
                var v4 = props.UnicastAddresses.Where(a => a.Address.AddressFamily == AddressFamily.InterNetwork).Select(a => a.Address.ToString());
                var v6 = props.UnicastAddresses.Any(a => a.Address.AddressFamily == AddressFamily.InterNetworkV6 && !a.Address.IsIPv6LinkLocal);
                var gw = props.GatewayAddresses.Select(g => g.Address.ToString());
                var dns = props.DnsAddresses.Select(d => d.ToString());
                Line($"- {nic.Name} [{nic.NetworkInterfaceType}] {nic.Description}");
                Line($"    IPv4: {string.Join(", ", v4)}  IPv6 global: {v6}");
                Line($"    Gateway: {string.Join(", ", gw)}");
                Line($"    DNS: {string.Join(", ", dns)}");
            }

            Section("Default routes");
            Line(Shell.Run("route", "print -4 0.0.0.0").Output.Trim());

            Section("Connectivity");
            Line(await ConnectivityAsync(ct));

            Section("Engine log (last 60 lines)");
            Line(Log.Tail(Paths.EngineLog, 60));

            Section("App log (last 40 lines)");
            Line(Log.Tail(Paths.AppLog, 40));
            return sb.ToString();
        }

        public static string SaveReport(string report)
        {
            Paths.EnsureDirs();
            var path = Path.Combine(Paths.LogDir, $"amfetamin-diagnose-{DateTime.Now:yyyyMMdd-HHmmss}.txt");
            File.WriteAllText(path, report, new UTF8Encoding(true));
            return path;
        }

        public static string ExportLogs()
        {
            Paths.EnsureDirs();
            var desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            var zip = Path.Combine(desktop, $"amfetamin-logs-{DateTime.Now:yyyyMMdd-HHmmss}.zip");
            using (var archive = ZipFile.Open(zip, ZipArchiveMode.Create))
            {
                foreach (var file in Directory.GetFiles(Paths.LogDir))
                {
                    try
                    {
                        using (var src = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                        using (var dst = archive.CreateEntry(Path.GetFileName(file)).Open())
                            src.CopyTo(dst);
                    }
                    catch { }
                }
                if (File.Exists(Paths.ConfigFile)) archive.CreateEntryFromFile(Paths.ConfigFile, "config.json");
            }
            return zip;
        }

        private static string WindowsVersion()
        {
            try
            {
                using (var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion"))
                {
                    var product = key?.GetValue("ProductName") as string;
                    var build = key?.GetValue("CurrentBuild") as string;
                    var display = key?.GetValue("DisplayVersion") as string;
                    // Windows 11 still reports "Windows 10" in ProductName.
                    if (product != null && int.TryParse(build, out var b) && b >= 22000) product = product.Replace("Windows 10", "Windows 11");
                    return $"{product} {display} (build {build})";
                }
            }
            catch
            {
                return Environment.OSVersion.ToString();
            }
        }
    }
}
