using System;
using System.IO;
using System.Reflection;

namespace Amfetamin
{
    /// <summary>Well-known locations. Everything lives under %LOCALAPPDATA%\Amfetamin.</summary>
    internal static class Paths
    {
        public static readonly string InstallRoot =
            Environment.GetEnvironmentVariable("AMFETAMIN_INSTALL_ROOT") is string custom && custom.Length > 0
                ? custom
                : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Amfetamin");

        public static readonly string BinDir = Path.Combine(InstallRoot, "bin");
        public static readonly string LogDir = Path.Combine(InstallRoot, "logs");
        public static readonly string ConfigFile = Path.Combine(InstallRoot, "config.json");

        /// <summary>Stable copy of the app used by the scheduled task.</summary>
        public static readonly string InstalledExe = Path.Combine(InstallRoot, "Amfetamin.exe");

        public static readonly string EngineExe = Path.Combine(BinDir, AppInfo.EngineFileName);
        public static readonly string EngineTagFile = Path.Combine(BinDir, "engine-tag.txt");
        public static readonly string EngineLog = Path.Combine(LogDir, "engine.log");
        public static readonly string AppLog = Path.Combine(LogDir, "app.log");

        /// <summary>Engine binary from older releases (process name "amfetamin").</summary>
        public static readonly string LegacyEngineExe = Path.Combine(BinDir, "amfetamin.exe");

        public static string CurrentExe => Assembly.GetExecutingAssembly().Location;

        public static string CurrentDir => Path.GetDirectoryName(CurrentExe);

        /// <summary>Engine shipped next to the app in the release zip, if any.</summary>
        public static string BundledEngine
        {
            get
            {
                foreach (var candidate in new[]
                {
                    Path.Combine(CurrentDir, "engine", AppInfo.EngineFileName),
                    Path.Combine(CurrentDir, AppInfo.EngineFileName),
                })
                {
                    if (File.Exists(candidate)) return candidate;
                }
                return null;
            }
        }

        public static bool RunningFromInstallDir =>
            string.Equals(Path.GetFullPath(CurrentExe), Path.GetFullPath(InstalledExe), StringComparison.OrdinalIgnoreCase);

        public static void EnsureDirs()
        {
            Directory.CreateDirectory(InstallRoot);
            Directory.CreateDirectory(BinDir);
            Directory.CreateDirectory(LogDir);
        }
    }

    internal static class AppInfo
    {
        public const string Name = "amfetamin";
        public const string Author = "furkandvrc";
        public const string Repo = "furkandvrc/amfetamin";
        public const string ProjectUrl = "https://github.com/" + Repo;
        public const string ReleasesUrl = ProjectUrl + "/releases/latest";

        /// <summary>
        /// The engine ships in the same release (and zip) as the app, so both
        /// always carry the same version tag.
        /// </summary>
        public static string EngineTag => "v" + VersionText;
        public const string EngineFileName = "amfetamin-engine.exe";
        public const string EngineDownloadBase = ProjectUrl + "/releases/download";

        public static Version Version => Assembly.GetExecutingAssembly().GetName().Version;

        public static string VersionText
        {
            get
            {
                var v = Version;
                return $"{v.Major}.{v.Minor}.{Math.Max(0, v.Build)}";
            }
        }
    }
}
