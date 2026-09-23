using System;
using System.Diagnostics;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Amfetamin
{
    internal sealed class ShellResult
    {
        public int ExitCode;
        public string Output;
        public bool TimedOut;
        public bool Ok => !TimedOut && ExitCode == 0;
    }

    /// <summary>Runs console tools without flashing windows and without blocking the UI thread.</summary>
    internal static class Shell
    {
        private static readonly Encoding OemEncoding = GetOemEncoding();

        private static Encoding GetOemEncoding()
        {
            try { return Encoding.GetEncoding(System.Globalization.CultureInfo.CurrentCulture.TextInfo.OEMCodePage); }
            catch { return Encoding.UTF8; }
        }

        public static ShellResult Run(string file, string args, int timeoutMs = 30000)
        {
            var psi = new ProcessStartInfo(file, args)
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                // Windows console tools write in the OEM code page (cp857 on
                // Turkish systems), not UTF-8.
                StandardOutputEncoding = OemEncoding,
                StandardErrorEncoding = OemEncoding,
            };
            var output = new StringBuilder();
            try
            {
                using (var p = new Process { StartInfo = psi })
                {
                    p.OutputDataReceived += (_, e) => { if (e.Data != null) lock (output) output.AppendLine(e.Data); };
                    p.ErrorDataReceived += (_, e) => { if (e.Data != null) lock (output) output.AppendLine(e.Data); };
                    p.Start();
                    p.BeginOutputReadLine();
                    p.BeginErrorReadLine();
                    if (!p.WaitForExit(timeoutMs))
                    {
                        try { p.Kill(); } catch { }
                        return new ShellResult { ExitCode = -1, TimedOut = true, Output = output.ToString() };
                    }
                    p.WaitForExit(); // flush async readers
                    return new ShellResult { ExitCode = p.ExitCode, Output = output.ToString() };
                }
            }
            catch (Exception ex)
            {
                return new ShellResult { ExitCode = -1, Output = ex.Message };
            }
        }

        public static Task<ShellResult> RunAsync(string file, string args, int timeoutMs = 30000) =>
            Task.Run(() => Run(file, args, timeoutMs));

        /// <summary>Quotes a single argument for CreateProcess command lines.</summary>
        public static string Quote(string arg)
        {
            if (string.IsNullOrEmpty(arg)) return "\"\"";
            if (arg.IndexOfAny(new[] { ' ', '\t', '"' }) < 0) return arg;
            var sb = new StringBuilder("\"");
            var backslashes = 0;
            foreach (var c in arg)
            {
                if (c == '\\') { backslashes++; continue; }
                if (c == '"') sb.Append('\\', backslashes * 2 + 1);
                else sb.Append('\\', backslashes);
                backslashes = 0;
                sb.Append(c);
            }
            sb.Append('\\', backslashes * 2);
            sb.Append('"');
            return sb.ToString();
        }

        /// <summary>Awaits process exit without blocking a thread.</summary>
        public static Task WaitForExitAsync(Process p, CancellationToken ct)
        {
            var tcs = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
            p.EnableRaisingEvents = true;
            p.Exited += (_, __) => tcs.TrySetResult(true);
            if (p.HasExited) tcs.TrySetResult(true);
            if (ct.CanBeCanceled) ct.Register(() => tcs.TrySetCanceled());
            return tcs.Task;
        }
    }
}
