using System;
using System.IO;
using System.Text;

namespace Amfetamin
{
    /// <summary>Thread-safe append-only log with size-based rotation.</summary>
    internal static class Log
    {
        private const long MaxBytes = 2 * 1024 * 1024;
        private static readonly object Gate = new object();

        public static event Action<string> LineWritten;

        /// <summary>Turned off after uninstall so logging doesn't recreate the folder.</summary>
        public static volatile bool Enabled = true;

        public static void Info(string message) => Write("INFO", message);
        public static void Warn(string message) => Write("WARN", message);

        public static void Error(string message, Exception ex = null)
        {
            Write("ERROR", ex == null ? message : message + ": " + ex.Message);
            if (ex != null) Write("DEBUG", ex.ToString());
        }

        private static void Write(string level, string message)
        {
            if (!Enabled) return;
            var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} [{level}] {message}";
            lock (Gate)
            {
                try
                {
                    Directory.CreateDirectory(Paths.LogDir);
                    var fi = new FileInfo(Paths.AppLog);
                    if (fi.Exists && fi.Length > MaxBytes)
                    {
                        var old = Paths.AppLog + ".1";
                        if (File.Exists(old)) File.Delete(old);
                        File.Move(Paths.AppLog, old);
                    }
                    File.AppendAllText(Paths.AppLog, line + Environment.NewLine, new UTF8Encoding(false));
                }
                catch
                {
                    // Logging must never take the app down.
                }
            }
            try { LineWritten?.Invoke(line); } catch { }
        }

        /// <summary>Reads the last <paramref name="maxLines"/> lines without locking the writer out.</summary>
        public static string Tail(string path, int maxLines = 400)
        {
            try
            {
                if (!File.Exists(path)) return string.Empty;
                using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                {
                    const int window = 256 * 1024;
                    if (fs.Length > window) fs.Seek(-window, SeekOrigin.End);
                    using (var sr = new StreamReader(fs, Encoding.UTF8))
                    {
                        var text = sr.ReadToEnd();
                        var lines = text.Replace("\r\n", "\n").Split('\n');
                        var start = Math.Max(0, lines.Length - maxLines);
                        return string.Join(Environment.NewLine, lines, start, lines.Length - start).TrimEnd();
                    }
                }
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }

        /// <summary>Returns bytes appended to <paramref name="path"/> since <paramref name="offset"/>.</summary>
        public static string ReadFrom(string path, long offset)
        {
            try
            {
                if (!File.Exists(path)) return string.Empty;
                using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                {
                    if (offset > fs.Length) offset = 0; // rotated
                    fs.Seek(offset, SeekOrigin.Begin);
                    using (var sr = new StreamReader(fs, Encoding.UTF8)) return sr.ReadToEnd();
                }
            }
            catch
            {
                return string.Empty;
            }
        }

        public static long SizeOf(string path)
        {
            try { return File.Exists(path) ? new FileInfo(path).Length : 0; }
            catch { return 0; }
        }
    }
}
