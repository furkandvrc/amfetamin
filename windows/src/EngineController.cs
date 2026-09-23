using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.NetworkInformation;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

namespace Amfetamin
{
    /// <summary>Installs, starts and stops amfetamin-engine.exe.</summary>
    internal static class EngineController
    {
        private const string StopEventName = @"Global\AmfetaminEngineStop";
        private static readonly string ProcessName = Path.GetFileNameWithoutExtension(AppInfo.EngineFileName);

        // ---------------------------------------------------------------- status

        public static bool BinaryInstalled => File.Exists(Paths.EngineExe);

        public static Process FindRunning()
        {
            foreach (var p in Process.GetProcessesByName(ProcessName))
            {
                try
                {
                    if (!p.HasExited) return p;
                }
                catch { }
                p.Dispose();
            }
            return null;
        }

        public static bool IsRunning
        {
            get
            {
                using (var p = FindRunning()) return p != null;
            }
        }

        // --------------------------------------------------------------- install

        public static bool NeedsInstall()
        {
            if (!File.Exists(Paths.EngineExe)) return true;
            try
            {
                var tag = File.Exists(Paths.EngineTagFile) ? File.ReadAllText(Paths.EngineTagFile).Trim() : "";
                if (tag != AppInfo.EngineTag) return true;
                // A bundled engine that differs from the installed one wins
                // (e.g. a hotfix zip with the same tag).
                var bundled = Paths.BundledEngine;
                return bundled != null && !SameFile(bundled, Paths.EngineExe);
            }
            catch
            {
                return true;
            }
        }

        /// <summary>Copies the bundled engine, or downloads and verifies it from GitHub.</summary>
        public static async Task EnsureInstalledAsync(IProgress<string> progress, CancellationToken ct)
        {
            if (!NeedsInstall()) return;
            Paths.EnsureDirs();
            await StopAsync();
            RemoveLegacyEngine();

            var staged = Paths.EngineExe + ".new";
            var bundled = Paths.BundledEngine;
            if (bundled != null)
            {
                progress.Report(S.T("step_engine_copy"));
                File.Copy(bundled, staged, true);
                Log.Info("Engine installed from bundle: " + bundled);
            }
            else
            {
                var baseUrl = $"{AppInfo.EngineDownloadBase}/{AppInfo.EngineTag}";
                var sums = Path.Combine(Paths.BinDir, "checksums.txt");
                try
                {
                    progress.Report(S.T("step_engine_download", 0));
                    await Http.DownloadAsync(baseUrl + "/checksums.txt", sums, null, ct);
                    var pct = new Progress<int>(p => progress.Report(S.T("step_engine_download", p)));
                    await Http.DownloadAsync(baseUrl + "/" + AppInfo.EngineFileName, staged, pct, ct);
                }
                catch (Exception ex) when (!(ex is OperationCanceledException))
                {
                    throw new UserFacingException(S.T("err_engine_missing", ex.Message));
                }

                var expected = File.ReadAllLines(sums)
                    .Select(l => l.Trim().Split(new[] { ' ', '\t', '*' }, StringSplitOptions.RemoveEmptyEntries))
                    .Where(f => f.Length >= 2 && f[f.Length - 1].EndsWith(AppInfo.EngineFileName, StringComparison.OrdinalIgnoreCase))
                    .Select(f => f[0])
                    .FirstOrDefault();
                if (expected == null || !string.Equals(expected, Sha256(staged), StringComparison.OrdinalIgnoreCase))
                {
                    File.Delete(staged);
                    throw new UserFacingException(S.T("err_checksum"));
                }
                Log.Info("Engine downloaded and verified: " + AppInfo.EngineTag);
            }

            if (File.Exists(Paths.EngineExe)) File.Delete(Paths.EngineExe);
            File.Move(staged, Paths.EngineExe);
            File.WriteAllText(Paths.EngineTagFile, AppInfo.EngineTag);
        }

        private static void RemoveLegacyEngine()
        {
            foreach (var p in Process.GetProcessesByName("amfetamin"))
            {
                try
                {
                    if (string.Equals(p.MainModule?.FileName, Paths.LegacyEngineExe, StringComparison.OrdinalIgnoreCase))
                    {
                        p.Kill();
                        p.WaitForExit(3000);
                    }
                }
                catch { }
                finally { p.Dispose(); }
            }
            try
            {
                if (File.Exists(Paths.LegacyEngineExe))
                {
                    Shell.Run(Paths.LegacyEngineExe, "cleanup", 15000);
                    File.Delete(Paths.LegacyEngineExe);
                }
            }
            catch { }
        }

        // ----------------------------------------------------------- start/stop

        public static string BuildArgs(AppConfig cfg, int ttlOverride = 0)
        {
            var args = new List<string> { "run", "--log-file", Paths.EngineLog, "--doh-upstream", cfg.DohUpstream };
            args.Add("--fake-ttl");
            args.Add((ttlOverride > 0 ? ttlOverride : cfg.FakeTtl).ToString());
            if (!cfg.FilterAaaa) args.Add("--filter-aaaa=false");
            if (cfg.LanExclude) args.Add("--split-tunnel");
            foreach (var rule in GamePreset.RulesFor(cfg))
            {
                args.Add("--bypass-rule");
                args.Add(rule);
            }
            if (cfg.EngineVerbose) args.Add("-v");
            return string.Join(" ", args.Select(Shell.Quote));
        }

        /// <summary>
        /// Starts the engine and waits until it reports "running" (or fails).
        /// The engine is not a child of the UI: it keeps running if the window
        /// is closed.
        /// </summary>
        public static async Task StartAsync(AppConfig cfg, int ttlOverride, CancellationToken ct)
        {
            if (!File.Exists(Paths.EngineExe)) throw new UserFacingException(S.T("err_engine_missing", Paths.EngineExe));
            if (!Npcap.IsInstalled()) throw new UserFacingException(S.T("err_npcap_missing"));
            Npcap.EnsureServiceRunning();

            await StopAsync();
            if (cfg.StopZeroTier) Conflicts.StopZeroTier();

            Paths.EnsureDirs();
            var logOffset = Log.SizeOf(Paths.EngineLog);
            var args = BuildArgs(cfg, ttlOverride);
            Log.Info("Engine start: " + args);

            var psi = new ProcessStartInfo(Paths.EngineExe, args)
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden,
                WorkingDirectory = Paths.BinDir,
            };
            var proc = Process.Start(psi);
            var deadline = DateTime.UtcNow.AddSeconds(25);
            var seen = "";
            while (DateTime.UtcNow < deadline)
            {
                await Task.Delay(250, ct);
                seen = Log.ReadFrom(Paths.EngineLog, logOffset);
                if (seen.Contains("engine running")) return;
                if (seen.Contains("engine exited with error") || proc.HasExited)
                {
                    await Task.Delay(300); // let the last lines land
                    seen = Log.ReadFrom(Paths.EngineLog, logOffset);
                    throw new UserFacingException(S.T("err_engine_start", Summarize(seen, proc)));
                }
            }
            // Still alive but silent: treat as started unless it died meanwhile.
            if (proc.HasExited) throw new UserFacingException(S.T("err_engine_start", Summarize(seen, proc)));
            Log.Warn("Engine did not report readiness in time; assuming it is running");
        }

        /// <summary>Asks the engine to shut down cleanly; kills it if it doesn't.</summary>
        public static async Task StopAsync()
        {
            var procs = Process.GetProcessesByName(ProcessName);
            if (procs.Length == 0) return;
            try
            {
                if (EventWaitHandle.TryOpenExisting(StopEventName, out var ev))
                {
                    using (ev) ev.Set();
                }

                var deadline = DateTime.UtcNow.AddSeconds(10);
                while (DateTime.UtcNow < deadline && procs.Any(p => !HasExited(p))) await Task.Delay(200);

                var stuck = procs.Where(p => !HasExited(p)).ToList();
                if (stuck.Count > 0)
                {
                    Log.Warn("Engine did not stop in time; killing it and cleaning up");
                    foreach (var p in stuck)
                    {
                        try { p.Kill(); p.WaitForExit(3000); } catch { }
                    }
                    await RunCleanupAsync();
                }
                Log.Info("Engine stopped");
            }
            finally
            {
                foreach (var p in procs) p.Dispose();
            }
        }

        /// <summary>Restores DNS and removes routes left behind by a crashed engine.</summary>
        public static async Task RunCleanupAsync()
        {
            if (File.Exists(Paths.EngineExe))
            {
                var r = await Shell.RunAsync(Paths.EngineExe, "cleanup", 30000);
                Log.Info("engine cleanup: " + r.Output.Trim());
            }
            await Task.Run(ResetLoopbackDns);
        }

        /// <summary>Last resort: any adapter still pointing at 127.0.0.1 goes back to DHCP DNS.</summary>
        private static void ResetLoopbackDns()
        {
            if (IsRunning) return;
            foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
            {
                try
                {
                    var dns = nic.GetIPProperties().DnsAddresses;
                    if (dns.Any(a => a.ToString() == "127.0.0.1"))
                    {
                        Shell.Run("netsh", $"interface ipv4 set dnsservers name={Shell.Quote(nic.Name)} source=dhcp");
                        Log.Info("DNS reset to DHCP on " + nic.Name);
                    }
                }
                catch { }
            }
            Shell.Run("ipconfig", "/flushdns");
        }

        // ---------------------------------------------------------------- helpers

        private static bool HasExited(Process p)
        {
            try { return p.HasExited; } catch { return true; }
        }

        private static string Sha256(string path)
        {
            using (var sha = SHA256.Create())
            using (var fs = File.OpenRead(path))
                return BitConverter.ToString(sha.ComputeHash(fs)).Replace("-", "");
        }

        private static bool SameFile(string a, string b)
        {
            var fa = new FileInfo(a);
            var fb = new FileInfo(b);
            return fa.Length == fb.Length && Sha256(a) == Sha256(b);
        }

        private static readonly Regex MsgRe = new Regex("msg=\"((?:[^\"\\\\]|\\\\.)*)\"|msg=(\\S+)");
        private static readonly Regex ErrRe = new Regex("error=\"((?:[^\"\\\\]|\\\\.)*)\"|error=(\\S+)");

        /// <summary>Turns logrus lines into a short human-readable error.</summary>
        public static string Summarize(string log, Process proc = null)
        {
            var lines = (log ?? "").Replace("\r", "").Split('\n')
                .Where(l => l.Contains("level=error") || l.Contains("level=fatal") || l.Contains("level=warn"))
                .Select(l =>
                {
                    var m = MsgRe.Match(l);
                    var e = ErrRe.Match(l);
                    var msg = m.Success ? (m.Groups[1].Success ? m.Groups[1].Value : m.Groups[2].Value) : l;
                    if (e.Success) msg += ": " + (e.Groups[1].Success ? e.Groups[1].Value : e.Groups[2].Value);
                    return msg.Replace("\\\"", "\"");
                })
                .Distinct()
                .ToList();
            if (lines.Count == 0)
            {
                var tail = (log ?? "").Trim();
                if (tail.Length > 0) lines.Add(tail.Length > 600 ? tail.Substring(tail.Length - 600) : tail);
                else if (proc != null && HasExited(proc)) lines.Add("exit code " + SafeExitCode(proc));
                else lines.Add("?");
            }
            return string.Join("\n", lines.Skip(Math.Max(0, lines.Count - 6)));
        }

        private static int SafeExitCode(Process p)
        {
            try { return p.ExitCode; } catch { return -1; }
        }
    }
}
