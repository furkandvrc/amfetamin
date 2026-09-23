using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;
using System.ServiceProcess;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;

namespace Amfetamin
{
    /// <summary>
    /// Npcap is needed to send the fake packets and read TCP sequence numbers.
    /// The free edition has no silent install, so its installer UI is shown
    /// and awaited asynchronously.
    /// </summary>
    internal static class Npcap
    {
        private const string FallbackUrl = "https://npcap.com/dist/npcap-1.83.exe";
        private const string DownloadPage = "https://npcap.com/";

        private static string DllPath =>
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "Npcap", "wpcap.dll");

        public static bool IsInstalled()
        {
            try
            {
                using (var key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\npcap"))
                {
                    if (key == null) return false;
                }
                return File.Exists(DllPath);
            }
            catch
            {
                return false;
            }
        }

        public static string Version()
        {
            foreach (var path in new[]
            {
                @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\NpcapInst",
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\NpcapInst",
            })
            {
                try
                {
                    using (var key = Registry.LocalMachine.OpenSubKey(path))
                    {
                        if (key?.GetValue("DisplayVersion") is string v && v.Length > 0) return v;
                    }
                }
                catch { }
            }
            return null;
        }

        /// <summary>Starts the driver service if it is installed but stopped.</summary>
        public static bool EnsureServiceRunning()
        {
            try
            {
                using (var sc = new ServiceController("npcap"))
                {
                    if (sc.Status == ServiceControllerStatus.Running) return true;
                    sc.Start();
                    sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(10));
                    return sc.Status == ServiceControllerStatus.Running;
                }
            }
            catch (Exception ex)
            {
                Log.Warn("npcap service: " + ex.Message);
                return false;
            }
        }

        public static async Task InstallAsync(AppConfig cfg, IProgress<string> progress, CancellationToken ct)
        {
            progress.Report(S.T("step_npcap_download"));
            var url = !string.IsNullOrWhiteSpace(cfg.NpcapUrl) ? cfg.NpcapUrl : await LatestUrlAsync(ct);
            var file = Path.Combine(Path.GetTempPath(), "amfetamin-" + Path.GetFileName(new Uri(url).LocalPath));
            Log.Info("Npcap download: " + url);
            try
            {
                await Http.DownloadAsync(url, file, null, ct);
            }
            catch (Exception ex) when (!(ex is OperationCanceledException) && url != FallbackUrl)
            {
                Log.Warn($"Npcap download from {url} failed ({ex.Message}), trying {FallbackUrl}");
                url = FallbackUrl;
                file = Path.Combine(Path.GetTempPath(), "amfetamin-" + Path.GetFileName(new Uri(url).LocalPath));
                await Http.DownloadAsync(url, file, null, ct);
            }

            if (!IsTrustedInstaller(file))
            {
                TryDelete(file);
                throw new UserFacingException(S.T("err_npcap_signature"));
            }

            progress.Report(S.T("step_npcap_install"));
            Log.Info("Npcap installer started");
            using (var p = Process.Start(new ProcessStartInfo(file) { UseShellExecute = true }))
            {
                await Shell.WaitForExitAsync(p, ct);
                Log.Info("Npcap installer exited with code " + p.ExitCode);
            }
            TryDelete(file);

            // The service key appears a moment after the installer closes.
            for (var i = 0; i < 20 && !IsInstalled(); i++) await Task.Delay(250, ct);
            if (!IsInstalled()) throw new UserFacingException(S.T("err_npcap_cancelled"));
            EnsureServiceRunning();
            progress.Report(S.T("step_npcap_done"));
        }

        /// <summary>Finds the newest installer linked from npcap.com.</summary>
        private static async Task<string> LatestUrlAsync(CancellationToken ct)
        {
            try
            {
                var html = await Http.GetStringAsync(DownloadPage, TimeSpan.FromSeconds(15), ct);
                var best = Regex.Matches(html, @"dist/npcap-(\d+)\.(\d+)\.exe")
                    .Cast<Match>()
                    .Select(m => new { Url = "https://npcap.com/" + m.Value, Ver = new Version(int.Parse(m.Groups[1].Value), int.Parse(m.Groups[2].Value)) })
                    .OrderByDescending(x => x.Ver)
                    .FirstOrDefault();
                if (best != null) return best.Url;
            }
            catch (Exception ex) when (!(ex is OperationCanceledException))
            {
                Log.Warn("Npcap version lookup failed: " + ex.Message);
            }
            return FallbackUrl;
        }

        /// <summary>Requires a valid Authenticode signature from the Npcap publisher.</summary>
        private static bool IsTrustedInstaller(string file)
        {
            try
            {
                if (!WinTrust.Verify(file))
                {
                    Log.Warn("Npcap installer signature is not valid");
                    return false;
                }
                var cert = X509Certificate.CreateFromSignedFile(file);
                var subject = cert.Subject ?? "";
                var ok = subject.IndexOf("Insecure.Com", StringComparison.OrdinalIgnoreCase) >= 0 ||
                         subject.IndexOf("Nmap Software", StringComparison.OrdinalIgnoreCase) >= 0;
                if (!ok) Log.Warn("Unexpected Npcap signer: " + subject);
                return ok;
            }
            catch (Exception ex)
            {
                Log.Error("Npcap signature check failed", ex);
                return false;
            }
        }

        private static void TryDelete(string path)
        {
            try { if (File.Exists(path)) File.Delete(path); } catch { }
        }
    }

    /// <summary>Minimal WinVerifyTrust wrapper (Authenticode, whole chain, no UI).</summary>
    internal static class WinTrust
    {
        private static readonly Guid ActionGenericVerifyV2 = new Guid("00AAC56B-CD44-11d0-8CC2-00C04FC295EE");

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct WINTRUST_FILE_INFO
        {
            public uint cbStruct;
            public string pcwszFilePath;
            public IntPtr hFile;
            public IntPtr pgKnownSubject;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct WINTRUST_DATA
        {
            public uint cbStruct;
            public IntPtr pPolicyCallbackData;
            public IntPtr pSIPClientData;
            public uint dwUIChoice;
            public uint fdwRevocationChecks;
            public uint dwUnionChoice;
            public IntPtr pFile;
            public uint dwStateAction;
            public IntPtr hWVTStateData;
            public IntPtr pwszURLReference;
            public uint dwProvFlags;
            public uint dwUIContext;
            public IntPtr pSignatureSettings;
        }

        [DllImport("wintrust.dll", CharSet = CharSet.Unicode)]
        private static extern int WinVerifyTrust(IntPtr hwnd, [MarshalAs(UnmanagedType.LPStruct)] Guid action, ref WINTRUST_DATA data);

        public static bool Verify(string file)
        {
            var fileInfo = new WINTRUST_FILE_INFO
            {
                cbStruct = (uint)Marshal.SizeOf(typeof(WINTRUST_FILE_INFO)),
                pcwszFilePath = file,
            };
            var pFile = Marshal.AllocHGlobal(Marshal.SizeOf(fileInfo));
            try
            {
                Marshal.StructureToPtr(fileInfo, pFile, false);
                var data = new WINTRUST_DATA
                {
                    cbStruct = (uint)Marshal.SizeOf(typeof(WINTRUST_DATA)),
                    dwUIChoice = 2,            // WTD_UI_NONE
                    fdwRevocationChecks = 0,   // WTD_REVOKE_NONE (offline friendly)
                    dwUnionChoice = 1,         // WTD_CHOICE_FILE
                    pFile = pFile,
                    dwStateAction = 0,
                    dwProvFlags = 0x00000080,  // WTD_REVOCATION_CHECK_NONE
                };
                return WinVerifyTrust(IntPtr.Zero, ActionGenericVerifyV2, ref data) == 0;
            }
            finally
            {
                Marshal.DestroyStructure(pFile, typeof(WINTRUST_FILE_INFO));
                Marshal.FreeHGlobal(pFile);
            }
        }
    }

    /// <summary>An error whose message is already written for the user.</summary>
    internal sealed class UserFacingException : Exception
    {
        public UserFacingException(string message) : base(message) { }
    }
}
