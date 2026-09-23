using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace Amfetamin.UI
{
    internal sealed class GamesPage : Page
    {
        private readonly ToggleRow _auto;
        private readonly Dictionary<string, ToggleRow> _presets = new Dictionary<string, ToggleRow>();
        private readonly TextBox _custom;
        private readonly Label _error;
        private readonly FlatButton _save = new FlatButton { Kind = ButtonKind.Primary, Text = S.T("btn_save"), Size = Dpi.S(140, 40), Tag = "natural", Margin = Dpi.P(0, 6, 0, 0) };

        public GamesPage(AppController app, MainForm shell) : base(app, shell, S.T("nav_games"))
        {
            AddParagraph(S.T("games_desc"));

            _auto = Toggle(S.T("games_auto"), S.T("games_auto_desc"));
            AddCard(_auto);

            AddSection(S.T("games_presets"));
            var rows = GamePreset.All.Select(p =>
            {
                var row = Toggle(p.Name, string.Join("  ·  ", p.Rules));
                _presets[p.Id] = row;
                return (Control)row;
            }).ToArray();
            AddCard(rows);

            AddSection(S.T("games_custom"));
            _custom = new TextBox
            {
                Multiline = true,
                ScrollBars = ScrollBars.Vertical,
                Height = Dpi.S(88),
                BackColor = Theme.Input,
                ForeColor = Theme.Text,
                BorderStyle = BorderStyle.FixedSingle,
                Font = Theme.Mono(10f),
                AcceptsReturn = true,
            };
            var hint = new Label { Text = S.T("games_custom_desc"), Font = Theme.Ui(8.5f), ForeColor = Theme.TextMuted, BackColor = Color.Transparent, AutoSize = true };
            _error = new Label { Font = Theme.Ui(9f), ForeColor = Theme.Bad, BackColor = Color.Transparent, AutoSize = true, Visible = false };
            AddCard(hint, _custom, _error);

            _save.Click += async (_, __) =>
            {
                var cfg = Collect(out var bad);
                _error.Visible = bad != null;
                if (bad != null)
                {
                    _error.Text = S.T("games_invalid", bad);
                    return;
                }
                await App.ApplySettingsAsync(cfg, null);
            };
            Controls.Add(_save);
        }

        public override void OnShown()
        {
            var cfg = App.Config;
            var selected = new HashSet<string>(cfg.BypassPresets, StringComparer.OrdinalIgnoreCase);
            _auto.Checked = selected.Contains(GamePreset.AutoId);
            foreach (var kv in _presets) kv.Value.Checked = selected.Contains(kv.Key);
            _custom.Text = string.Join(Environment.NewLine, cfg.BypassPortsCustom);
            _error.Visible = false;
        }

        public override void Render() => _save.Enabled = !App.Busy;

        private AppConfig Collect(out string invalid)
        {
            invalid = null;
            var cfg = App.Config.Clone();
            var presets = _presets.Where(kv => kv.Value.Checked).Select(kv => kv.Key).ToList();
            if (_auto.Checked) presets.Insert(0, GamePreset.AutoId);
            cfg.BypassPresets = presets.ToArray();

            var rules = _custom.Text
                .Split(new[] { '\r', '\n', ',', ';' }, StringSplitOptions.RemoveEmptyEntries)
                .Select(r => r.Trim())
                .Where(r => r.Length > 0)
                .ToList();
            invalid = rules.FirstOrDefault(r => !GamePreset.IsValidRule(r));
            cfg.BypassPortsCustom = rules.ToArray();
            return cfg;
        }
    }
}
