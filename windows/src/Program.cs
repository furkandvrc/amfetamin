using System;
using System.Linq;
using System.Security.Principal;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Amfetamin.UI;

namespace Amfetamin
{
    internal static class Program
    {
        private const string MutexName = @"Global\Amfetamin.App";
        private const string ShowEventName = @"Global\Amfetamin.App.Show";
        private const string ExitEventName = @"Global\Amfetamin.App.Exit";

        [STAThread]
        private static int Main(string[] args)
        {
            var autostart = args.Any(a => a.Equals("--autostart", StringComparison.OrdinalIgnoreCase));
            var cleanup = args.Any(a => a.Equals("--cleanup", StringComparison.OrdinalIgnoreCase));
            var applyUpdate = args.Any(a => a.Equals("--apply-update", StringComparison.OrdinalIgnoreCase));
            var connect = args.Any(a => a.Equals("--connect", StringComparison.OrdinalIgnoreCase));

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
            Application.ThreadException += (_, e) => Crash(e.Exception);
            AppDomain.CurrentDomain.UnhandledException += (_, e) => Crash(e.ExceptionObject as Exception);
            TaskScheduler.UnobservedTaskException += (_, e) => { Log.Error("Unobserved task error", e.Exception); e.SetObserved(); };

            if (!new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator))
            {
                MessageBox.Show(S.T("err_admin"), "amfetamin", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }

            if (cleanup)
            {
                // Headless repair, usable from a shortcut or support instructions.
                EngineController.StopAsync().GetAwaiter().GetResult();
                EngineController.RunCleanupAsync().GetAwaiter().GetResult();
                return 0;
            }

            if (applyUpdate) return ApplyUpdate(connect);

            using (var mutex = new Mutex(false, MutexName, out _))
            {
                if (!Acquire(mutex, autostart)) return 0;
                try
                {
                    Log.Info($"amfetamin {AppInfo.VersionText} started{(autostart ? " (autostart)" : "")} from {Paths.CurrentExe}");
                    CloseLegacyLaunchers();
                    Run(autostart, connect);
                }
                finally
                {
                    mutex.ReleaseMutex();
                }
            }
            return 0;
        }

        /// <summary>
        /// Single instance. A second launch brings the running window forward;
        /// a launch from a different exe (an update) asks the old one to exit.
        /// </summary>
        private static bool Acquire(Mutex mutex, bool autostart)
        {
            try
            {
                if (mutex.WaitOne(0)) return true;
            }
            catch (AbandonedMutexException)
            {
                return true;
            }
            if (autostart) return false;

            if (!Paths.RunningFromInstallDir && EventWaitHandle.TryOpenExisting(ExitEventName, out var exit))
            {
                // Possibly a newer version: replace the running one.
                using (exit) exit.Set();
                try
                {
                    if (mutex.WaitOne(TimeSpan.FromSeconds(8))) return true;
                }
                catch (AbandonedMutexException)
                {
                    return true;
                }
            }
            if (EventWaitHandle.TryOpenExisting(ShowEventName, out var show))
            {
                using (show) show.Set();
            }
            return false;
        }

        /// <summary>
        /// Second half of a self-update, running from the extracted zip: take
        /// over from the old instance, install this build, start the installed copy.
        /// </summary>
        private static int ApplyUpdate(bool connect)
        {
            System.Diagnostics.ProcessStartInfo next;
            using (var mutex = new Mutex(false, MutexName, out _))
            {
                if (!Acquire(mutex, autostart: false))
                {
                    Log.Error("Update: the running instance did not exit");
                    return 1;
                }
                try
                {
                    next = Updater.Apply(connect);
                }
                catch (Exception ex)
                {
                    Log.Error("Update failed", ex);
                    MessageBox.Show(S.T("update_failed", ex.Message), "amfetamin", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return 1;
                }
                finally
                {
                    mutex.ReleaseMutex();
                }
            }
            // Started only after the mutex is free, so it becomes the instance.
            System.Diagnostics.Process.Start(next);
            return 0;
        }

        private static void Run(bool autostart, bool connect)
        {
            // The controller captures the UI context for its events; install it
            // before any control exists.
            SynchronizationContext.SetSynchronizationContext(new WindowsFormsSynchronizationContext());
            using (var app = new AppController())
            using (var form = new MainForm(app, startHidden: autostart))
            using (var showEvent = new EventWaitHandle(false, EventResetMode.AutoReset, ShowEventName))
            using (var exitEvent = new EventWaitHandle(false, EventResetMode.AutoReset, ExitEventName))
            {
                var listener = new Thread(() =>
                {
                    var handles = new WaitHandle[] { showEvent, exitEvent };
                    while (true)
                    {
                        var which = WaitHandle.WaitAny(handles);
                        if (form.IsDisposed) return;
                        try
                        {
                            if (which == 0) form.RestoreWindow();
                            else { form.ExitApp(stopEngine: false); return; }
                        }
                        catch (ObjectDisposedException) { return; }
                        catch (InvalidOperationException) { return; }
                    }
                }) { IsBackground = true, Name = "instance-listener" };
                listener.Start();

                app.Start();
                if (autostart) _ = app.AutoConnectAsync();
                else if (connect && !EngineController.IsRunning) _ = app.ConnectAsync();
                Application.Run(form);
            }
        }

        /// <summary>
        /// We own the v4 mutex, so any other Amfetamin.exe is a pre-4.0
        /// PowerShell-based launcher; it would fight us over the engine.
        /// </summary>
        private static void CloseLegacyLaunchers()
        {
            var self = System.Diagnostics.Process.GetCurrentProcess().Id;
            foreach (var p in System.Diagnostics.Process.GetProcessesByName("Amfetamin"))
            {
                try
                {
                    if (p.Id == self) continue;
                    // Process names are case-insensitive: the old engine was
                    // bin\amfetamin.exe. Leave it to setup, which restores DNS.
                    var path = p.MainModule?.FileName ?? "";
                    if (string.Equals(path, Paths.LegacyEngineExe, StringComparison.OrdinalIgnoreCase)) continue;
                    Log.Info("Closing legacy launcher PID " + p.Id);
                    p.Kill();
                    p.WaitForExit(3000);
                }
                catch { }
                finally { p.Dispose(); }
            }
        }

        private static void Crash(Exception ex)
        {
            if (ex == null) return;
            Log.Error("Unhandled error", ex);
            try
            {
                MessageBox.Show(ex.Message, "amfetamin", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            catch { }
        }
    }
}
