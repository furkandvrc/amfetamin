using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace Amfetamin
{
    internal enum ConnState
    {
        NeedsSetup,
        Disconnected,
        Connecting,
        Connected,
        Disconnecting,
    }

    internal sealed class StatusSnapshot
    {
        public bool NpcapInstalled;
        public bool EngineInstalled;
        public bool EngineRunning;
        public int EnginePid;
        public bool AutoStart;
        public List<string> Conflicts = new List<string>();
    }

    /// <summary>
    /// Owns every long-running operation. Operations are serialized, run off
    /// the UI thread and report progress through events; the UI only renders.
    /// </summary>
    internal sealed class AppController : IDisposable
    {
        private readonly SemaphoreSlim _gate = new SemaphoreSlim(1, 1);
        private readonly SynchronizationContext _ui;
        private CancellationTokenSource _opCts;
        private System.Threading.Timer _watchdog;
        private System.Threading.Timer _updateTimer;
        private readonly List<DateTime> _restarts = new List<DateTime>();
        private volatile bool _wantConnected;
        private DateTime _autoStartCheckedAt = DateTime.MinValue;
        private bool _autoStartCached;

        public AppConfig Config { get; private set; }
        public ConnState State { get; private set; } = ConnState.Disconnected;
        public bool Busy { get; private set; }
        public string BusyText { get; private set; } = "";
        public StatusSnapshot Status { get; private set; } = new StatusSnapshot();
        public bool? DiscordReachable { get; private set; }

        public event Action Changed;
        /// <summary>Raised on the UI thread when the app must close (an update took over).</summary>
        public event Action ExitRequested;
        public UpdateInfo AvailableUpdate { get; private set; }
        /// <summary>(message, isError) — shown as toast / tray balloon.</summary>
        public event Action<string, bool> Notify;

        public AppController()
        {
            _ui = SynchronizationContext.Current ?? new SynchronizationContext();
            Config = AppConfig.Load();
        }

        public void Start()
        {
            _wantConnected = EngineController.IsRunning;
            RefreshStatus(forceAutoStart: true);
            _watchdog = new System.Threading.Timer(_ => Watchdog(), null, 5000, 5000);
            // Probing for an old install runs schtasks; keep it off the UI thread.
            Task.Run(Migration.Needed).ContinueWith(t =>
            {
                if (!t.IsFaulted && t.Result) _ = MigrateAsync();
            }, TaskScheduler.Default);
            _updateTimer = new System.Threading.Timer(_ => _ = CheckForUpdateAsync(auto: true), null,
                TimeSpan.FromSeconds(45), TimeSpan.FromHours(12));
        }

        /// <summary>
        /// Upgrades an install made by an older version in place: new engine,
        /// new logon task, old files removed. Settings (TTL included) are kept
        /// and the connection is restored if it was up.
        /// </summary>
        private Task MigrateAsync() => RunOp(async (p, ct) =>
        {
            p.Report(S.T("migrate_running"));
            var wasRunning = Migration.LegacyEngineRunning() || EngineController.IsRunning;
            var autoStart = AutoStart.LegacyEnabled() || AutoStart.IsEnabled();
            Log.Info($"Migrating previous install (running={wasRunning}, autostart={autoStart})");
            await EngineController.EnsureInstalledAsync(p, ct);
            Migration.RemoveLegacyFiles();
            if (autoStart)
            {
                AutoStart.InstallSelf();
                AutoStart.Enable();
                _autoStartCheckedAt = DateTime.MinValue;
            }
            if (wasRunning) await ConnectCoreAsync(p, ct);
            Toast(S.T("migrate_done"));
        }, ConnState.Connecting);

        /// <summary>Checks GitHub for a newer release; installs it when auto-update is on.</summary>
        public async Task CheckForUpdateAsync(bool auto)
        {
            UpdateInfo info;
            try
            {
                info = await Updater.CheckAsync(CancellationToken.None);
            }
            catch (Exception ex)
            {
                Log.Warn("Update check failed: " + ex.Message);
                if (!auto) Emit(S.T("update_failed", ex.Message), true);
                return;
            }
            AvailableUpdate = info;
            Raise();
            if (info == null)
            {
                if (!auto) Toast(S.T("update_none", AppInfo.VersionText));
                return;
            }
            Log.Info("Update available: " + info.Tag);
            if (auto && !Config.AutoUpdate)
            {
                Toast(S.T("update_available_short", info.Tag));
                return;
            }
            await InstallUpdateAsync();
        }

        public Task InstallUpdateAsync() => RunOp(async (p, ct) =>
        {
            var info = AvailableUpdate;
            if (info == null) return;
            Toast(S.T("update_installing", info.Tag));
            await Updater.LaunchAsync(info, EngineController.IsRunning, p, ct);
            _ui.Post(_ => ExitRequested?.Invoke(), null);
        });

        // ------------------------------------------------------------ public ops

        public Task ConnectAsync() => RunOp(async (p, ct) =>
        {
            if (NeedsSetup()) await SetupCoreAsync(p, ct);
            else await ConnectCoreAsync(p, ct);
            Toast(S.T("done_connected"));
        }, ConnState.Connecting);

        public Task DisconnectAsync() => RunOp(async (p, ct) =>
        {
            _wantConnected = false;
            await EngineController.StopAsync();
            Toast(S.T("done_disconnected"));
        }, ConnState.Disconnecting);

        public Task ToggleAsync() => Status.EngineRunning ? DisconnectAsync() : ConnectAsync();

        public Task RetuneAsync() => RunOp(async (p, ct) =>
        {
            await EnsureReadyAsync(p, ct);
            var ttl = await TuneTtlAsync(p, ct);
            Toast(S.T("step_ttl_ok", ttl));
        }, ConnState.Connecting);

        public Task RepairNpcapAsync() => RunOp(async (p, ct) =>
        {
            if (Npcap.IsInstalled() && Npcap.EnsureServiceRunning())
            {
                Toast(S.T("done_npcap_present"));
                return;
            }
            await Npcap.InstallAsync(Config, p, ct);
            Toast(S.T("step_npcap_done"));
        });

        public Task CleanupAsync() => RunOp(async (p, ct) =>
        {
            p.Report(S.T("step_cleanup"));
            var wasRunning = EngineController.IsRunning;
            _wantConnected = false;
            await EngineController.StopAsync();
            await EngineController.RunCleanupAsync();
            Toast(S.T("done_cleanup"));
            if (wasRunning) await ConnectCoreAsync(p, ct);
        }, ConnState.Disconnecting);

        public Task<string> TestAsync() => RunOp(async (p, ct) =>
        {
            p.Report(S.T("step_test"));
            var result = await Diagnostics.ConnectivityAsync(ct);
            Toast(result);
            return result;
        });

        public Task ApplySettingsAsync(AppConfig updated, bool? autoStart) => RunOp(async (p, ct) =>
        {
            var restart = EngineController.IsRunning &&
                          EngineController.BuildArgs(updated) != EngineController.BuildArgs(Config);
            Config = updated.Normalize();
            Config.Save();
            if (autoStart.HasValue && autoStart.Value != AutoStart.IsEnabled())
            {
                if (autoStart.Value)
                {
                    AutoStart.InstallSelf();
                    AutoStart.Enable();
                }
                else AutoStart.Disable();
                _autoStartCheckedAt = DateTime.MinValue;
            }
            if (restart)
            {
                await ConnectCoreAsync(p, ct);
                Toast(S.T("saved_restarted"));
            }
            else Toast(S.T("saved"));
        });

        public Task UninstallAsync() => RunOp(async (p, ct) =>
        {
            _wantConnected = false;
            await EngineController.StopAsync();
            await EngineController.RunCleanupAsync();
            AutoStart.Disable();
            Log.Info("Uninstalled");
            Log.Enabled = false;
            // This process (and its log file) may live inside the install
            // folder, so remove it a few seconds after we exit.
            var dir = Shell.Quote(Paths.InstallRoot);
            var cmd = $"/c for /l %i in (1,1,60) do (ping 127.0.0.1 -n 2 >nul & rmdir /s /q {dir} 2>nul & if not exist {dir} exit /b)";
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("cmd.exe", cmd)
            {
                CreateNoWindow = true,
                UseShellExecute = false,
                WorkingDirectory = Path.GetTempPath(),
            });
        }, ConnState.Disconnecting);

        public void CancelCurrent()
        {
            try { _opCts?.Cancel(); } catch { }
        }

        /// <summary>Headless start used by the logon task.</summary>
        public async Task AutoConnectAsync()
        {
            // Never pop installers at logon: setup is an interactive step.
            if (NeedsSetup())
            {
                Log.Warn("Auto-connect skipped: setup incomplete");
                Emit(S.T("err_npcap_missing"), true);
                return;
            }
            // Network may not be up right after logon; retry for a while.
            for (var attempt = 0; attempt < 6; attempt++)
            {
                if (EngineController.IsRunning) { _wantConnected = true; RefreshStatus(); return; }
                try
                {
                    await RunOp(async (p, ct) => await ConnectCoreAsync(p, ct), ConnState.Connecting, rethrow: true);
                    return;
                }
                catch (Exception ex)
                {
                    Log.Warn($"Auto-connect attempt {attempt + 1} failed: {ex.Message}");
                    await Task.Delay(TimeSpan.FromSeconds(10 + attempt * 10));
                }
            }
        }

        // ------------------------------------------------------------- internals

        private bool NeedsSetup() => !Npcap.IsInstalled() || EngineController.NeedsInstall();

        private async Task EnsureReadyAsync(IProgress<string> p, CancellationToken ct)
        {
            if (!Npcap.IsInstalled()) await Npcap.InstallAsync(Config, p, ct);
            await EngineController.EnsureInstalledAsync(p, ct);
        }

        private async Task SetupCoreAsync(IProgress<string> p, CancellationToken ct)
        {
            p.Report(S.T("step_prepare"));
            await EnsureReadyAsync(p, ct);
            p.Report(S.T("step_autostart"));
            try
            {
                AutoStart.InstallSelf();
                AutoStart.Enable();
                _autoStartCheckedAt = DateTime.MinValue;
            }
            catch (Exception ex)
            {
                Log.Error("Auto-start setup failed", ex);
            }
            await ConnectCoreAsync(p, ct);
        }

        private async Task ConnectCoreAsync(IProgress<string> p, CancellationToken ct)
        {
            await EnsureReadyAsync(p, ct);
            if (Config.AutoTuneTtl && !Config.AutoTuneDone)
            {
                await TuneTtlAsync(p, ct);
            }
            else
            {
                p.Report(S.T("step_engine_start"));
                await EngineController.StartAsync(Config, 0, ct);
            }
            // Only a successful start arms the watchdog; a failed manual
            // connect must not turn into silent retries.
            _wantConnected = true;
        }

        /// <summary>
        /// Tries TTL candidates until the test site loads through the engine.
        /// Too low a TTL doesn't reach the DPI box; too high reaches the server
        /// and corrupts the handshake — both show up as a failed probe.
        /// </summary>
        private async Task<int> TuneTtlAsync(IProgress<string> p, CancellationToken ct)
        {
            var candidates = Config.FakeTtlCandidates;
            var url = Config.AutoTuneUrl;
            for (var i = 0; i < candidates.Length; i++)
            {
                ct.ThrowIfCancellationRequested();
                var ttl = candidates[i];
                p.Report(S.T("step_ttl_try", ttl, i + 1, candidates.Length));
                try
                {
                    await EngineController.StartAsync(Config, ttl, ct);
                }
                catch (UserFacingException ex)
                {
                    // A start failure is not TTL specific; retrying other values won't help.
                    if (i == 0) throw;
                    Log.Warn($"TTL {ttl}: engine start failed: {ex.Message}");
                    continue;
                }
                await Task.Delay(1500, ct);
                var probe = await Http.ProbeAsync(url, TimeSpan.FromSeconds(8), ct);
                Log.Info($"TTL {ttl}: {(probe.Ok ? "OK" : "failed")} ({probe.Detail}, {probe.Ms} ms)");
                if (probe.Ok)
                {
                    Config.FakeTtl = ttl;
                    Config.AutoTuneDone = true;
                    Config.Save();
                    p.Report(S.T("step_ttl_ok", ttl));
                    return ttl;
                }
            }

            var fallback = Config.FakeTtl > 0 ? Config.FakeTtl : 8;
            Config.AutoTuneDone = true;
            Config.Save();
            await EngineController.StartAsync(Config, 0, ct);
            Emit(S.T("step_ttl_none", new Uri(url).Host, fallback), true);
            return fallback;
        }

        private async Task RunOp(Func<IProgress<string>, CancellationToken, Task> op, ConnState? transient = null, bool rethrow = false)
        {
            await RunOp<object>(async (p, ct) => { await op(p, ct); return null; }, transient, rethrow);
        }

        private async Task<T> RunOp<T>(Func<IProgress<string>, CancellationToken, Task<T>> op, ConnState? transient = null, bool rethrow = false)
        {
            if (!await _gate.WaitAsync(0))
            {
                Emit(S.T("busy"), false);
                return default(T);
            }
            var cts = new CancellationTokenSource();
            _opCts = cts;
            var progress = new Progress<string>(msg =>
            {
                BusyText = msg;
                Log.Info("» " + msg);
                Raise();
            });
            Busy = true;
            BusyText = S.T("busy");
            if (transient.HasValue) State = transient.Value;
            Raise();
            try
            {
                // Run on the thread pool: nothing here may touch the UI thread.
                return await Task.Run(() => op(progress, cts.Token));
            }
            catch (OperationCanceledException)
            {
                Log.Info("Operation cancelled");
                return default(T);
            }
            catch (Exception ex)
            {
                Log.Error("Operation failed", ex);
                if (rethrow) throw;
                Emit(ex is UserFacingException ? ex.Message : S.T("err_engine_start", ex.Message), true);
                return default(T);
            }
            finally
            {
                Busy = false;
                BusyText = "";
                _opCts = null;
                cts.Dispose();
                _gate.Release();
                RefreshStatus();
            }
        }

        /// <summary>Recomputes status on a worker thread and raises Changed on the UI thread.</summary>
        public void RefreshStatus(bool forceAutoStart = false)
        {
            Task.Run(() =>
            {
                var s = new StatusSnapshot
                {
                    NpcapInstalled = Npcap.IsInstalled(),
                    EngineInstalled = EngineController.BinaryInstalled,
                };
                using (var proc = EngineController.FindRunning())
                {
                    s.EngineRunning = proc != null;
                    s.EnginePid = proc?.Id ?? 0;
                }
                if (forceAutoStart || DateTime.UtcNow - _autoStartCheckedAt > TimeSpan.FromSeconds(30))
                {
                    _autoStartCached = AutoStart.IsEnabled();
                    _autoStartCheckedAt = DateTime.UtcNow;
                }
                s.AutoStart = _autoStartCached;
                s.Conflicts = Conflicts.Detect();
                return s;
            }).ContinueWith(t =>
            {
                if (t.IsFaulted) return;
                var s = t.Result;
                if (!s.EngineRunning) DiscordReachable = null;
                Status = s;
                if (!Busy)
                {
                    State = !s.NpcapInstalled || !s.EngineInstalled ? ConnState.NeedsSetup
                        : s.EngineRunning ? ConnState.Connected : ConnState.Disconnected;
                }
                Raise();
            }, TaskScheduler.Default);
        }

        public async Task CheckDiscordAsync()
        {
            if (!Status.EngineRunning || Busy) return;
            var r = await Http.ProbeAsync("https://discord.com", TimeSpan.FromSeconds(8));
            DiscordReachable = EngineController.IsRunning ? (bool?)r.Ok : null;
            Raise();
        }

        /// <summary>Restarts the engine if it died while the user wanted it on.</summary>
        private void Watchdog()
        {
            if (Busy || !_wantConnected || !Config.AutoReconnect) return;
            if (EngineController.IsRunning) return;

            _restarts.RemoveAll(t => DateTime.UtcNow - t > TimeSpan.FromMinutes(10));
            if (_restarts.Count >= 5)
            {
                _wantConnected = false;
                var tail = EngineController.Summarize(Log.Tail(Paths.EngineLog, 40));
                Log.Error("Engine keeps crashing; giving up. " + tail);
                Emit(S.T("err_engine_exited", tail), true);
                RefreshStatus();
                return;
            }
            _restarts.Add(DateTime.UtcNow);
            Log.Warn("Engine is not running; restarting (watchdog)");
            Emit(S.T("tray_engine_crashed"), false);
            _ = RunOp(async (p, ct) =>
            {
                await Task.Delay(TimeSpan.FromSeconds(2 * _restarts.Count), ct);
                await ConnectCoreAsync(p, ct);
            }, ConnState.Connecting);
        }

        private void Toast(string message) => Emit(message, false);

        private void Emit(string message, bool isError) => _ui.Post(_ => Notify?.Invoke(message, isError), null);

        private void Raise() => _ui.Post(_ => Changed?.Invoke(), null);

        public void Dispose()
        {
            _watchdog?.Dispose();
            _updateTimer?.Dispose();
            _opCts?.Cancel();
        }
    }
}
