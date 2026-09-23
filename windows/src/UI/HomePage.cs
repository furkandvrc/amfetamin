using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace Amfetamin.UI
{
    internal sealed class HomePage : Page
    {
        private readonly PowerButton _power = new PowerButton();
        private readonly TextLabel _state = new TextLabel("", Theme.Display(22f), Theme.Text);
        private readonly Label _hint = new Label { AutoSize = false, Font = Theme.Ui(10f), ForeColor = Theme.TextMuted, BackColor = Color.Transparent, UseMnemonic = false };
        private readonly FlatButton _action = new FlatButton { Kind = ButtonKind.Primary, Size = Dpi.S(220, 44), Font = Theme.Ui(10.5f, FontStyle.Bold) };
        private readonly FlatButton _cancel = new FlatButton { Kind = ButtonKind.Ghost, Size = Dpi.S(100, 44), Visible = false };

        private readonly Card _conflict = new Card { Fill = Color.FromArgb(52, 38, 18), BackColor = Color.FromArgb(52, 38, 18), Visible = false };
        private readonly Label _conflictText = new Label { AutoSize = false, Font = Theme.Ui(9.5f), ForeColor = Theme.Warn, BackColor = Color.Transparent, UseMnemonic = false };
        private readonly FlatButton _conflictClose = new FlatButton { Size = Dpi.S(100, 32), Text = S.T("warn_conflict_close") };
        private string _conflictName;

        private readonly StatusTile _tEngine = new StatusTile { Caption = S.T("card_engine") };
        private readonly StatusTile _tNpcap = new StatusTile { Caption = S.T("card_npcap") };
        private readonly StatusTile _tAuto = new StatusTile { Caption = S.T("card_autostart") };
        private readonly StatusTile _tDiscord = new StatusTile { Caption = S.T("card_discord") };

        private readonly FlatButton[] _quick;

        public HomePage(AppController app, MainForm shell) : base(app, shell, S.T("nav_home"))
        {
            // Hero
            var hero = new Card { Height = Dpi.S(224), Margin = Dpi.P(0, 0, 0, 12) };
            hero.Controls.AddRange(new Control[] { _power, _state, _hint, _action, _cancel });
            hero.Resize += (_, __) => LayoutHero(hero);
            Controls.Add(hero);

            _power.Click += (_, __) => Primary();
            _action.Click += (_, __) => Primary();
            _cancel.Text = S.T("btn_cancel");
            _cancel.Click += (_, __) => App.CancelCurrent();

            // Conflict banner
            _conflict.Height = Dpi.S(56);
            _conflict.Margin = Dpi.P(0, 0, 0, 12);
            _conflict.Controls.AddRange(new Control[] { _conflictText, _conflictClose });
            _conflict.Resize += (_, __) =>
            {
                var pad = Dpi.S(14);
                _conflictClose.Location = new Point(_conflict.Width - _conflictClose.Width - pad, (_conflict.Height - _conflictClose.Height) / 2);
                _conflictText.Bounds = new Rectangle(pad + Dpi.S(4), 0, _conflictClose.Left - pad * 2, _conflict.Height);
                _conflictText.TextAlign = ContentAlignment.MiddleLeft;
            };
            _conflictClose.Click += (_, __) =>
            {
                if (_conflictName == null) return;
                var name = _conflictName;
                System.Threading.Tasks.Task.Run(() => Conflicts.Stop(name)).ContinueWith(_ => App.RefreshStatus());
            };
            Controls.Add(_conflict);

            // Tiles
            var tiles = new TableLayoutPanel { ColumnCount = 4, RowCount = 1, Height = Dpi.S(80), Margin = Dpi.P(0, 0, 0, 4), BackColor = Theme.Bg };
            for (var i = 0; i < 4; i++) tiles.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 25));
            foreach (var t in new[] { _tEngine, _tNpcap, _tAuto, _tDiscord })
            {
                t.Dock = DockStyle.Fill;
                t.Margin = Dpi.P(0, 0, 10, 0);
                tiles.Controls.Add(t);
            }
            _tDiscord.Margin = Padding.Empty;
            Controls.Add(tiles);

            // Quick actions
            AddSection(S.T("nav_help"));
            var quick = new FlowLayoutPanel { BackColor = Theme.Bg, WrapContents = true, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Tag = "natural", Margin = Padding.Empty };
            _quick = new[]
            {
                QuickButton(S.T("quick_test"), async () => await App.TestAsync()),
                QuickButton(S.T("quick_retune"), async () => await App.RetuneAsync()),
                QuickButton(S.T("quick_npcap"), async () => await App.RepairNpcapAsync()),
                QuickButton(S.T("quick_cleanup"), async () => await App.CleanupAsync()),
            };
            quick.Controls.AddRange(_quick);
            Controls.Add(quick);
        }

        private FlatButton QuickButton(string text, Func<System.Threading.Tasks.Task> action)
        {
            var b = new FlatButton { Text = text, Size = Dpi.S(188, 40), Margin = Dpi.P(0, 0, 10, 10) };
            b.Click += async (_, __) => await action();
            return b;
        }

        private void Primary()
        {
            if (App.Busy) return;
            _ = App.State == ConnState.Connected ? App.DisconnectAsync() : App.ConnectAsync();
        }

        private void LayoutHero(Card hero)
        {
            var pad = Dpi.S(28);
            var size = Math.Min(hero.Height - Dpi.S(36), Dpi.S(176));
            _power.Bounds = new Rectangle(pad, (hero.Height - size) / 2, size, size);
            var x = _power.Right + Dpi.S(32);
            var w = Math.Max(Dpi.S(160), hero.Width - x - pad);
            _state.Location = new Point(x, Dpi.S(40));
            _hint.Bounds = new Rectangle(x, _state.Bottom + Dpi.S(6), w, Dpi.S(44));
            _action.Location = new Point(x, _hint.Bottom + Dpi.S(12));
            _cancel.Location = new Point(_action.Right + Dpi.S(10), _action.Top);
        }

        public override void Render()
        {
            var st = App.Status;
            var busy = App.Busy;
            switch (App.State)
            {
                case ConnState.Connected:
                    _state.Text = S.T("state_connected");
                    _hint.Text = S.T("state_hint_connected");
                    _power.Ring = Theme.Good;
                    _action.Text = S.T("btn_disconnect");
                    _action.Kind = ButtonKind.Secondary;
                    break;
                case ConnState.Connecting:
                    _state.Text = S.T("state_starting");
                    _power.Ring = Theme.Warn;
                    break;
                case ConnState.Disconnecting:
                    _state.Text = S.T("state_stopping");
                    _power.Ring = Theme.Warn;
                    break;
                case ConnState.NeedsSetup:
                    _state.Text = S.T("state_setup");
                    _hint.Text = S.T("state_hint_setup");
                    _power.Ring = Theme.Purple;
                    _action.Text = S.T("btn_setup");
                    _action.Kind = ButtonKind.Primary;
                    break;
                default:
                    _state.Text = S.T("state_disconnected");
                    _hint.Text = S.T("state_hint_disconnected");
                    _power.Ring = Theme.Neutral;
                    _action.Text = S.T("btn_connect");
                    _action.Kind = ButtonKind.Primary;
                    break;
            }
            if (busy) _hint.Text = App.BusyText;
            _power.Spinning = busy;
            _action.Enabled = !busy;
            _power.Enabled = !busy;
            _cancel.Visible = busy;
            foreach (var b in _quick) b.Enabled = !busy;

            _tEngine.Value = st.EngineRunning ? S.T("val_running") : S.T("val_stopped");
            _tEngine.Dot = st.EngineRunning ? Theme.Good : st.EngineInstalled ? Theme.Neutral : Theme.Bad;
            _tNpcap.Value = st.NpcapInstalled ? S.T("val_installed") : S.T("val_missing");
            _tNpcap.Dot = st.NpcapInstalled ? Theme.Good : Theme.Bad;
            _tAuto.Value = st.AutoStart ? S.T("val_on") : S.T("val_off");
            _tAuto.Dot = st.AutoStart ? Theme.Good : Theme.Neutral;
            var d = App.DiscordReachable;
            _tDiscord.Value = !st.EngineRunning ? S.T("val_unknown") : d == null ? S.T("val_checking") : d.Value ? S.T("val_ok") : S.T("val_fail");
            _tDiscord.Dot = !st.EngineRunning || d == null ? Theme.Neutral : d.Value ? Theme.Good : Theme.Bad;

            var conflict = st.Conflicts.FirstOrDefault();
            _conflictName = conflict;
            _conflict.Visible = conflict != null;
            if (conflict != null)
            {
                _conflictText.Text = S.T("warn_conflict", string.Join(", ", st.Conflicts));
                _conflictClose.Visible = Conflicts.CanStop(conflict);
            }
            LayoutHero((Card)_power.Parent);
        }
    }
}
