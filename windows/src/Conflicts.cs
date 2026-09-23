using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.ServiceProcess;

namespace Amfetamin
{
    /// <summary>Software known to fight with the tunnel, DNS or packet injection.</summary>
    internal static class Conflicts
    {
        private sealed class Known
        {
            public string Name;
            public string[] Processes;
            public string[] Services;
            public bool Stoppable;
        }

        private static readonly Known[] Catalog =
        {
            new Known { Name = "ZeroTier", Processes = new[] { "zerotier_desktop_ui", "ZeroTier One", "zerotier-one_x64", "zerotier-one_x86" }, Services = new[] { "ZeroTierOneService" }, Stoppable = true },
            new Known { Name = "GoodbyeDPI", Processes = new[] { "goodbyedpi" }, Services = new[] { "GoodbyeDPI" } },
            new Known { Name = "zapret (winws)", Processes = new[] { "winws" }, Services = new[] { "zapret", "winws1" } },
            new Known { Name = "Cloudflare WARP", Processes = new[] { "Cloudflare WARP", "warp-svc" } },
            new Known { Name = "Radmin VPN", Processes = new[] { "RvRvpnGui" } },
            new Known { Name = "Hamachi", Processes = new[] { "hamachi-2-ui" } },
            new Known { Name = "ProtonVPN", Processes = new[] { "ProtonVPN" } },
            new Known { Name = "NordVPN", Processes = new[] { "NordVPN" } },
        };

        /// <summary>Names of conflicting programs currently running.</summary>
        public static List<string> Detect()
        {
            var running = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var p in Process.GetProcesses())
            {
                try { running.Add(p.ProcessName); } catch { }
                finally { p.Dispose(); }
            }
            var found = new List<string>();
            foreach (var k in Catalog)
            {
                if (k.Processes.Any(running.Contains) || (k.Services ?? new string[0]).Any(ServiceRunning))
                    found.Add(k.Name);
            }
            return found;
        }

        public static bool CanStop(string name) => Catalog.Any(k => k.Name == name && k.Stoppable);

        public static void StopZeroTier() => Stop("ZeroTier");

        public static void Stop(string name)
        {
            var k = Catalog.FirstOrDefault(x => x.Name == name);
            if (k == null) return;
            var stopped = false;
            foreach (var procName in k.Processes)
            {
                foreach (var p in Process.GetProcessesByName(procName))
                {
                    try { p.Kill(); stopped = true; } catch { }
                    finally { p.Dispose(); }
                }
            }
            foreach (var svc in k.Services ?? new string[0])
            {
                try
                {
                    using (var sc = new ServiceController(svc))
                    {
                        if (sc.Status == ServiceControllerStatus.Running)
                        {
                            sc.Stop();
                            sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(10));
                            stopped = true;
                        }
                    }
                }
                catch { }
            }
            if (stopped) Log.Info(name + " stopped to avoid conflicts");
        }

        private static bool ServiceRunning(string name)
        {
            try
            {
                using (var sc = new ServiceController(name)) return sc.Status == ServiceControllerStatus.Running;
            }
            catch
            {
                return false;
            }
        }
    }
}
