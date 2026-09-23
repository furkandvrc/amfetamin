using System;
using System.Diagnostics;
using System.Drawing;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Amfetamin.UI
{
    internal sealed class LogsPage : Page
    {
        private readonly FlatButton _engineTab = new FlatButton { Text = S.T("logs_engine"), Size = Dpi.S(110, 34) };
        private readonly FlatButton _appTab = new FlatButton { Text = S.T("logs_app"), Size = Dpi.S(110, 34) };
        private readonly ToggleRow _follow = new ToggleRow { Text = S.T("logs_follow"), Checked = true, Width = Dpi.S(160) };
        private readonly TextBox _box = new TextBox
        {
            Multiline = true,
            ReadOnly = true,
            ScrollBars = ScrollBars.Both,
            WordWrap = false,
            BackColor = Theme.Card,
            ForeColor = Theme.Text,
            BorderStyle = BorderStyle.None,
            Font = Theme.Mono(9f),
        };
        private readonly Timer _timer = new Timer { Interval = 1500 };
        private string _file = Paths.EngineLog;
        private long _lastSize = -1;
        private bool _loading;

        public LogsPage(AppController app, MainForm shell) : base(app, shell, S.T("nav_logs"))
        {
            var bar = new FlowLayoutPanel { Height = Dpi.S(44), BackColor = Theme.Bg, WrapContents = false, Margin = Dpi.P(0, 0, 0, 8) };
            var open = new FlatButton { Text = S.T("logs_open"), Size = Dpi.S(130, 34), Kind = ButtonKind.Ghost };
            var export = new FlatButton { Text = S.T("logs_export"), Size = Dpi.S(170, 34), Kind = ButtonKind.Ghost };
            foreach (var c in new Control[] { _engineTab, _appTab, _follow, open, export }) c.Margin = Dpi.P(0, 0, 8, 0);
            _follow.Margin = Dpi.P(12, 6, 8, 0);
            bar.Controls.AddRange(new Control[] { _engineTab, _appTab, _follow, open, export });
            Controls.Add(bar);

            var card = new Card { Padding = Dpi.P(12), Margin = Padding.Empty };
            _box.Dock = DockStyle.Fill;
            card.Controls.Add(_box);
            Controls.Add(card);
            Resize += (_, __) => card.Height = Math.Max(Dpi.S(200), ClientSize.Height - card.Top - Padding.Bottom);

            _engineTab.Click += (_, __) => ShowLog(Paths.EngineLog);
            _appTab.Click += (_, __) => ShowLog(Paths.AppLog);
            open.Click += (_, __) =>
            {
                Paths.EnsureDirs();
                Process.Start("explorer.exe", Shell.Quote(Paths.LogDir));
            };
            export.Click += async (_, __) =>
            {
                try
                {
                    var zip = await Task.Run(Diagnostics.ExportLogs);
                    Host.ShowToast(S.T("logs_exported", zip), false);
                    Process.Start("explorer.exe", "/select," + Shell.Quote(zip));
                }
                catch (Exception ex)
                {
                    Host.ShowToast(ex.Message, true);
                }
            };
            _timer.Tick += async (_, __) => { if (_follow.Checked) await Reload(); };
            ShowLog(Paths.EngineLog);
        }

        private void ShowLog(string file)
        {
            _file = file;
            _engineTab.Kind = file == Paths.EngineLog ? ButtonKind.Primary : ButtonKind.Secondary;
            _appTab.Kind = file == Paths.AppLog ? ButtonKind.Primary : ButtonKind.Secondary;
            _lastSize = -1;
            _ = Reload();
        }

        private async Task Reload()
        {
            if (_loading) return;
            var size = Log.SizeOf(_file);
            if (size == _lastSize) return;
            _loading = true;
            try
            {
                var file = _file;
                var text = await Task.Run(() => Log.Tail(file, 500));
                _lastSize = size;
                _box.Text = text;
                _box.SelectionStart = _box.TextLength;
                _box.ScrollToCaret();
            }
            finally
            {
                _loading = false;
            }
        }

        public override void OnShown()
        {
            _lastSize = -1;
            _ = Reload();
            _timer.Start();
        }

        protected override void OnVisibleChanged(EventArgs e)
        {
            base.OnVisibleChanged(e);
            if (!Visible) _timer.Stop();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) _timer.Dispose();
            base.Dispose(disposing);
        }
    }
}
