using System;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Amfetamin.UI
{
    internal sealed class MainForm : Form
    {
        private readonly AppController _app;
        private readonly Panel _content = new Panel { Dock = DockStyle.Fill, BackColor = Theme.Bg };
        private readonly Panel _busyStrip = new Panel { Dock = DockStyle.Top, Height = Dpi.S(3), BackColor = Theme.Bg, Visible = false };
        private readonly Label _toast = new Label
        {
            Dock = DockStyle.Bottom,
            Height = Dpi.S(34),
            TextAlign = ContentAlignment.MiddleCenter,
            Font = Theme.Ui(9.5f),
            Visible = false,
            UseMnemonic = false,
            AutoEllipsis = true,
        };
        private readonly Timer _toastTimer = new Timer();
        private readonly Timer _statusTimer = new Timer { Interval = 2500 };
        private readonly Timer _discordTimer = new Timer { Interval = 60000 };
        private readonly Timer _busyAnim = new Timer { Interval = 16 };
        private float _busyPos;
        private readonly NotifyIcon _tray = new NotifyIcon();
        private readonly ToolStripMenuItem _trayToggle = new ToolStripMenuItem();
        private readonly Page[] _pages;
        private readonly NavButton[] _nav;
        private Page _current;
        private bool _exiting;
        private bool _trayHintShown;

        public static Icon AppIcon { get; } = LoadIcon();

        public MainForm(AppController app, bool startHidden)
        {
            _app = app;
            Text = "amfetamin";
            Icon = AppIcon;
            BackColor = Theme.Bg;
            ForeColor = Theme.Text;
            Font = Theme.Ui(9.5f);
            AutoScaleMode = AutoScaleMode.None;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = Dpi.S(940, 620);
            MinimumSize = Dpi.S(820, 580);
            DoubleBuffered = true;
            KeyPreview = true;

            _pages = new Page[]
            {
                new HomePage(app, this),
                new GamesPage(app, this),
                new SettingsPage(app, this),
                new LogsPage(app, this),
                new HelpPage(app, this),
            };
            var glyphs = new[] { Theme.Glyph.Home, Theme.Glyph.Game, Theme.Glyph.Settings, Theme.Glyph.Logs, Theme.Glyph.Health };
            var titles = new[] { S.T("nav_home"), S.T("nav_games"), S.T("nav_settings"), S.T("nav_logs"), S.T("nav_help") };

            // Sidebar
            var sidebar = new Panel { Dock = DockStyle.Left, Width = Dpi.S(212), BackColor = Theme.Sidebar };
            sidebar.Paint += (s, e) =>
            {
                using (var pen = new Pen(Theme.Border)) e.Graphics.DrawLine(pen, sidebar.Width - 1, 0, sidebar.Width - 1, sidebar.Height);
            };
            var logo = new PictureBox
            {
                Image = AppIcon.ToBitmap(),
                SizeMode = PictureBoxSizeMode.Zoom,
                Bounds = new Rectangle(Dpi.S(22), Dpi.S(24), Dpi.S(34), Dpi.S(34)),
                BackColor = Theme.Sidebar,
            };
            var brand = new TextLabel("amfetamin", Theme.Display(15f), Theme.Text) { Location = new Point(Dpi.S(62), Dpi.S(22)) };
            var tagline = new TextLabel(S.T("app_tagline"), Theme.Ui(7.5f), Theme.TextMuted) { Location = new Point(Dpi.S(64), Dpi.S(46)) };
            sidebar.Controls.AddRange(new Control[] { logo, brand, tagline });

            _nav = new NavButton[_pages.Length];
            for (var i = 0; i < _pages.Length; i++)
            {
                var idx = i;
                var b = new NavButton
                {
                    Text = titles[i],
                    Glyph = glyphs[i],
                    Bounds = new Rectangle(0, Dpi.S(92) + i * Dpi.S(46), Dpi.S(212), Dpi.S(42)),
                };
                b.Click += (_, __) => ShowPage(idx);
                _nav[i] = b;
                sidebar.Controls.Add(b);
            }
            var version = new TextLabel($"v{AppInfo.VersionText}  ·  {AppInfo.Author}", Theme.Ui(8f), Theme.TextDim)
            {
                Anchor = AnchorStyles.Left | AnchorStyles.Bottom,
            };
            sidebar.Controls.Add(version);
            sidebar.Resize += (_, __) => version.Location = new Point(Dpi.S(24), sidebar.Height - Dpi.S(34));

            foreach (var p in _pages) _content.Controls.Add(p);
            _busyStrip.Paint += PaintBusyStrip;
            _busyAnim.Tick += (_, __) => { _busyPos = (_busyPos + 0.012f) % 1.4f; _busyStrip.Invalidate(); };

            Controls.Add(_content);
            Controls.Add(_busyStrip);
            Controls.Add(_toast);
            Controls.Add(sidebar);

            _toastTimer.Tick += (_, __) => { _toastTimer.Stop(); _toast.Visible = false; };
            _statusTimer.Tick += (_, __) => _app.RefreshStatus();
            _discordTimer.Tick += async (_, __) => await _app.CheckDiscordAsync();

            SetupTray();
            _app.Changed += Render;
            _app.Notify += OnNotify;
            _app.ExitRequested += () => ExitApp(stopEngine: false);
            ShowPage(0);

            if (startHidden)
            {
                ShowInTaskbar = false;
                WindowState = FormWindowState.Minimized;
                Opacity = 0;
            }
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            if (Opacity == 0)
            {
                Hide();
                Opacity = 1;
                WindowState = FormWindowState.Normal;
                ShowInTaskbar = true;
            }
            _statusTimer.Start();
            _discordTimer.Start();
            _app.RefreshStatus();
            // First Discord check shortly after start.
            var once = new Timer { Interval = 4000 };
            once.Tick += async (_, __) => { once.Stop(); once.Dispose(); await _app.CheckDiscordAsync(); };
            once.Start();
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            // Dark title bar on Windows 10 20H1+ / 11.
            var on = 1;
            if (DwmSetWindowAttribute(Handle, 20, ref on, sizeof(int)) != 0)
                DwmSetWindowAttribute(Handle, 19, ref on, sizeof(int));
        }

        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

        private void ShowPage(int index)
        {
            for (var i = 0; i < _pages.Length; i++)
            {
                _nav[i].Selected = i == index;
                _pages[i].Visible = i == index;
            }
            _current = _pages[index];
            _current.OnShown();
            _current.Render();
            _current.PerformLayout();
        }

        private void Render()
        {
            foreach (var p in _pages) p.Render();
            var busy = _app.Busy;
            if (busy != _busyStrip.Visible)
            {
                _busyStrip.Visible = busy;
                if (busy) _busyAnim.Start(); else _busyAnim.Stop();
            }
            var connected = _app.State == ConnState.Connected;
            _tray.Icon = AppIcon;
            _tray.Text = "amfetamin — " + (connected ? S.T("state_connected") : busy ? S.T("busy") : S.T("state_disconnected"));
            _trayToggle.Text = connected ? S.T("tray_disconnect") : S.T("tray_connect");
            _trayToggle.Enabled = !busy;
        }

        private void PaintBusyStrip(object sender, PaintEventArgs e)
        {
            var w = _busyStrip.Width;
            var seg = w * 0.3f;
            var x = (_busyPos - 0.3f) * w;
            using (var b = new SolidBrush(Theme.Accent)) e.Graphics.FillRectangle(b, x, 0, seg, _busyStrip.Height);
        }

        private void OnNotify(string message, bool isError)
        {
            if (string.IsNullOrWhiteSpace(message)) return;
            if (!Visible)
            {
                _tray.ShowBalloonTip(5000, "amfetamin", message, isError ? ToolTipIcon.Error : ToolTipIcon.Info);
                return;
            }
            if (isError && message.Contains("\n"))
            {
                MessageBox.Show(this, message, S.T("err_title"), MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            ShowToast(message, isError);
        }

        public void ShowToast(string message, bool isError)
        {
            _toast.Text = message.Replace("\r", "").Replace("\n", "   ·   ");
            _toast.BackColor = isError ? Color.FromArgb(70, 26, 34) : Color.FromArgb(18, 52, 44);
            _toast.ForeColor = isError ? Color.FromArgb(255, 170, 178) : Color.FromArgb(150, 240, 210);
            _toast.Visible = true;
            _toastTimer.Stop();
            _toastTimer.Interval = isError ? 9000 : 5000;
            _toastTimer.Start();
        }

        // ------------------------------------------------------------------ tray

        private void SetupTray()
        {
            var menu = new ContextMenuStrip { ShowImageMargin = false };
            var open = new ToolStripMenuItem(S.T("tray_open"), null, (_, __) => RestoreWindow()) { Font = new Font(menu.Font, FontStyle.Bold) };
            _trayToggle.Click += async (_, __) => await _app.ToggleAsync();
            var exit = new ToolStripMenuItem(S.T("tray_exit"), null, (_, __) => ExitApp(stopEngine: null));
            menu.Items.AddRange(new ToolStripItem[] { open, _trayToggle, new ToolStripSeparator(), exit });
            _tray.ContextMenuStrip = menu;
            _tray.Icon = AppIcon;
            _tray.Text = "amfetamin";
            _tray.Visible = true;
            _tray.MouseClick += (_, e) => { if (e.Button == MouseButtons.Left) RestoreWindow(); };
        }

        public void RestoreWindow()
        {
            if (InvokeRequired) { BeginInvoke((Action)RestoreWindow); return; }
            Show();
            if (WindowState == FormWindowState.Minimized) WindowState = FormWindowState.Normal;
            Activate();
            BringToFront();
            _app.RefreshStatus();
        }

        /// <param name="stopEngine">null = ask the user if connected.</param>
        public void ExitApp(bool? stopEngine)
        {
            if (InvokeRequired) { BeginInvoke((Action)(() => ExitApp(stopEngine))); return; }
            if (stopEngine == null && _app.Status.EngineRunning)
            {
                if (!Visible) RestoreWindow();
                var r = MessageBox.Show(this, S.T("confirm_exit_running"), S.T("err_title"), MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question);
                if (r == DialogResult.Cancel) return;
                stopEngine = r == DialogResult.Yes;
            }
            if (stopEngine == true)
            {
                Enabled = false;
                _app.DisconnectAsync().ContinueWith(_ => BeginInvoke((Action)(() => ExitApp(false))));
                return;
            }
            _exiting = true;
            _tray.Visible = false;
            Close();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (!_exiting && e.CloseReason == CloseReason.UserClosing && _app.Config.MinimizeToTray)
            {
                e.Cancel = true;
                Hide();
                if (!_trayHintShown)
                {
                    _trayHintShown = true;
                    _tray.ShowBalloonTip(4000, "amfetamin", S.T("tray_hidden"), ToolTipIcon.Info);
                }
                return;
            }
            _tray.Visible = false;
            base.OnFormClosing(e);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.Control && e.KeyCode >= Keys.D1 && e.KeyCode <= Keys.D5)
            {
                ShowPage(e.KeyCode - Keys.D1);
                e.Handled = true;
            }
            base.OnKeyDown(e);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                _tray.Dispose();
                _toastTimer.Dispose();
                _statusTimer.Dispose();
                _discordTimer.Dispose();
                _busyAnim.Dispose();
            }
            base.Dispose(disposing);
        }

        private static Icon LoadIcon()
        {
            try
            {
                using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("Amfetamin.icon.ico"))
                    if (s != null) return new Icon(s);
            }
            catch { }
            try { return Icon.ExtractAssociatedIcon(Paths.CurrentExe); } catch { }
            return SystemIcons.Shield;
        }
    }
}
