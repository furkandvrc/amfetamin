using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Text;

namespace Amfetamin
{
    /// <summary>
    /// User settings persisted as config.json. Key names match the previous
    /// PowerShell launcher so existing installs keep their settings.
    /// </summary>
    [DataContract]
    internal sealed class AppConfig
    {
        [DataMember(Name = "dohUpstream", Order = 1)] public string DohUpstream { get; set; }
        [DataMember(Name = "fakeTtl", Order = 2)] public int FakeTtl { get; set; }
        [DataMember(Name = "autoTuneTtl", Order = 3)] public bool AutoTuneTtl { get; set; }
        [DataMember(Name = "autoTuneDone", Order = 4)] public bool AutoTuneDone { get; set; }
        [DataMember(Name = "autoTuneUrl", Order = 5)] public string AutoTuneUrl { get; set; }
        [DataMember(Name = "fakeTtlCandidates", Order = 6)] public int[] FakeTtlCandidates { get; set; }
        [DataMember(Name = "bypassPresets", Order = 7)] public string[] BypassPresets { get; set; }
        [DataMember(Name = "bypassPortsCustom", Order = 8)] public string[] BypassPortsCustom { get; set; }
        [DataMember(Name = "splitTunnel", Order = 9)] public bool LanExclude { get; set; }
        [DataMember(Name = "filterAaaa", Order = 10)] public bool FilterAaaa { get; set; }
        [DataMember(Name = "engineVerbose", Order = 11)] public bool EngineVerbose { get; set; }
        [DataMember(Name = "stopZeroTier", Order = 12)] public bool StopZeroTier { get; set; }
        [DataMember(Name = "minimizeToTray", Order = 13)] public bool MinimizeToTray { get; set; }
        [DataMember(Name = "autoReconnect", Order = 14)] public bool AutoReconnect { get; set; }
        [DataMember(Name = "npcapUrl", Order = 15)] public string NpcapUrl { get; set; }
        [DataMember(Name = "autoUpdate", Order = 16)] public bool AutoUpdate { get; set; }

        public AppConfig() => ApplyDefaults();

        [OnDeserializing]
        private void OnDeserializing(StreamingContext _) => ApplyDefaults();

        private void ApplyDefaults()
        {
            DohUpstream = "cloudflare,google";
            FakeTtl = 8;
            AutoTuneTtl = true;
            AutoTuneDone = false;
            AutoTuneUrl = "https://discord.com";
            FakeTtlCandidates = new[] { 6, 8, 10, 12, 14, 5, 7, 9, 11 };
            BypassPresets = new[] { "warframe" };
            BypassPortsCustom = new string[0];
            LanExclude = false;
            FilterAaaa = true;
            EngineVerbose = false;
            StopZeroTier = true;
            MinimizeToTray = true;
            AutoReconnect = true;
            NpcapUrl = "";
            AutoUpdate = true;
        }

        /// <summary>Repairs values that would make the engine refuse to start.</summary>
        public AppConfig Normalize()
        {
            if (string.IsNullOrWhiteSpace(DohUpstream)) DohUpstream = "cloudflare,google";
            if (FakeTtl < 1 || FakeTtl > 64) FakeTtl = 8;
            if (string.IsNullOrWhiteSpace(AutoTuneUrl) || !Uri.IsWellFormedUriString(AutoTuneUrl, UriKind.Absolute))
                AutoTuneUrl = "https://discord.com";
            FakeTtlCandidates = (FakeTtlCandidates ?? new int[0]).Where(t => t >= 1 && t <= 64).Distinct().ToArray();
            if (FakeTtlCandidates.Length == 0) FakeTtlCandidates = new[] { 6, 8, 10, 12, 14 };
            BypassPresets = (BypassPresets ?? new string[0])
                .Where(p => !string.IsNullOrWhiteSpace(p)).Select(p => p.Trim().ToLowerInvariant()).Distinct().ToArray();
            BypassPortsCustom = (BypassPortsCustom ?? new string[0])
                .Select(p => (p ?? "").Trim()).Where(p => p.Length > 0).Distinct().ToArray();
            if (NpcapUrl == null) NpcapUrl = "";
            return this;
        }

        public static AppConfig Load()
        {
            try
            {
                if (File.Exists(Paths.ConfigFile))
                {
                    var bytes = File.ReadAllBytes(Paths.ConfigFile);
                    // Tolerate a UTF-8 BOM written by the old PowerShell launcher.
                    var offset = bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF ? 3 : 0;
                    using (var ms = new MemoryStream(bytes, offset, bytes.Length - offset))
                    {
                        var cfg = (AppConfig)new DataContractJsonSerializer(typeof(AppConfig)).ReadObject(ms);
                        return (cfg ?? new AppConfig()).Normalize();
                    }
                }
            }
            catch (Exception ex)
            {
                Log.Error("config.json could not be read, using defaults", ex);
                try { File.Copy(Paths.ConfigFile, Paths.ConfigFile + ".broken", true); } catch { }
            }
            return new AppConfig().Normalize();
        }

        public void Save()
        {
            Normalize();
            Paths.EnsureDirs();
            var tmp = Paths.ConfigFile + ".tmp";
            using (var fs = File.Create(tmp))
            using (var writer = JsonReaderWriterFactory.CreateJsonWriter(fs, new UTF8Encoding(false), true, true, "  "))
            {
                new DataContractJsonSerializer(typeof(AppConfig)).WriteObject(writer, this);
                writer.Flush();
            }
            if (File.Exists(Paths.ConfigFile)) File.Replace(tmp, Paths.ConfigFile, null);
            else File.Move(tmp, Paths.ConfigFile);
        }

        public AppConfig Clone()
        {
            using (var ms = new MemoryStream())
            {
                var ser = new DataContractJsonSerializer(typeof(AppConfig));
                ser.WriteObject(ms, this);
                ms.Position = 0;
                return (AppConfig)ser.ReadObject(ms);
            }
        }
    }

    /// <summary>Port presets for games whose traffic should skip the tunnel.</summary>
    internal sealed class GamePreset
    {
        public string Id { get; }
        public string Name { get; }
        public string[] Rules { get; }

        private GamePreset(string id, string name, params string[] rules)
        {
            Id = id;
            Name = name;
            Rules = rules;
        }

        /// <summary>Special preset: every non-web, non-Discord UDP flow leaves the tunnel.</summary>
        public const string AutoId = "auto";
        public const string AutoRule = "udp:auto";

        public static readonly GamePreset[] All =
        {
            new GamePreset("warframe", "Warframe", "udp:4950-4955", "tcp:4950-4955", "tcp:6695-6709"),
            new GamePreset("lol", "League of Legends / Valorant", "udp:5000-5500", "udp:7000-8000", "udp:8393"),
            new GamePreset("rust", "Rust", "udp:28015-28050"),
            new GamePreset("steam", "Steam (CS2, Dota 2)", "udp:27000-27100", "tcp:27015", "tcp:27036", "udp:27031-27036"),
            new GamePreset("fortnite", "Fortnite / Epic (EAC)", "udp:9000-9100"),
            new GamePreset("apex", "Apex Legends", "udp:37000-40000"),
            new GamePreset("gta", "GTA Online / RDO", "udp:6672", "udp:61455-61458"),
        };

        public static IEnumerable<string> RulesFor(AppConfig cfg)
        {
            var rules = new List<string>();
            var selected = new HashSet<string>(cfg.BypassPresets ?? new string[0], StringComparer.OrdinalIgnoreCase);
            if (selected.Contains(AutoId)) rules.Add(AutoRule);
            foreach (var p in All)
                if (selected.Contains(p.Id)) rules.AddRange(p.Rules);
            rules.AddRange(cfg.BypassPortsCustom ?? new string[0]);
            return rules.Distinct(StringComparer.OrdinalIgnoreCase);
        }

        /// <summary>Validates a custom rule like "udp:1000-2000", "tcp:27015" or "3074".</summary>
        public static bool IsValidRule(string spec)
        {
            if (string.IsNullOrWhiteSpace(spec)) return false;
            spec = spec.Trim();
            var ports = spec;
            var colon = spec.IndexOf(':');
            if (colon >= 0)
            {
                var proto = spec.Substring(0, colon).Trim().ToLowerInvariant();
                if (proto != "udp" && proto != "tcp" && proto != "both" && proto != "any") return false;
                ports = spec.Substring(colon + 1).Trim();
                if (proto == "udp" && ports == "auto") return true;
            }
            var dash = ports.IndexOf('-');
            if (dash < 0) return IsPort(ports);
            return IsPort(ports.Substring(0, dash)) && IsPort(ports.Substring(dash + 1)) &&
                   int.Parse(ports.Substring(0, dash).Trim()) <= int.Parse(ports.Substring(dash + 1).Trim());
        }

        private static bool IsPort(string s) => int.TryParse(s.Trim(), out var n) && n >= 1 && n <= 65535;
    }
}
