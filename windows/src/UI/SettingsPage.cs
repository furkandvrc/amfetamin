using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace Amfetamin.UI
{
    internal sealed class SettingsPage : Page
    {
        private sealed class DnsChoice
        {
            public string Value;
            public string Label;
            public override string ToString() => Label;
        }

        private static readonly DnsChoice[] DnsChoices =
        {
            new DnsChoice { Value = "cloudflare,google", Label = S.T("dns_auto") },
            new DnsChoice { Value = "cloudflare", Label = "Cloudflare (1.1.1.1)" },
            new DnsChoice { Value = "google", Label = "Google (8.8.8.8)" },
            new DnsChoice { Value = "quad9", Label = "Quad9 (9.9.9.9)" },
            new DnsChoice { Value = "adguard", Label = "AdGuard" },
            new DnsChoice { Value = "nextdns", Label = "NextDNS" },
        };

        private readonly ToggleRow _autoStart = Toggle(S.T("set_autostart"));
        private readonly ToggleRow _tray = Toggle(S.T("set_tray"));
        private readonly ToggleRow _reconnect = Toggle(S.T("set_reconnect"));
        private readonly ToggleRow _zerotier = Toggle(S.T("set_zerotier"));
        private readonly ToggleRow _autoUpdate = Toggle(S.T("set_autoupdate"));
        private readonly ComboBox _dns = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, FlatStyle = FlatStyle.Flat, BackColor = Theme.Input, ForeColor = Theme.Text, Width = Dpi.S(280) };
        private readonly NumericUpDown _ttl = new NumericUpDown { Minimum = 1, Maximum = 64, Width = Dpi.S(90), BackColor = Theme.Input, ForeColor = Theme.Text, BorderStyle = BorderStyle.FixedSingle };
        private readonly ToggleRow _autoTune = Toggle(S.T("set_autotune"));
        private readonly ToggleRow _filterAaaa = Toggle(S.T("set_ipv4"));
        private readonly ToggleRow _lan = Toggle(S.T("set_lan"));
        private readonly ToggleRow _verbose = Toggle(S.T("set_verbose"));
        private readonly FlatButton _save = new FlatButton { Kind = ButtonKind.Primary, Text = S.T("btn_save"), Size = Dpi.S(140, 40), Tag = "natural", Margin = Dpi.P(0, 6, 0, 0) };

        public SettingsPage(AppController app, MainForm shell) : base(app, shell, S.T("nav_settings"))
        {
            AddSection(S.T("set_general"));
            AddCard(_autoStart, _tray, _reconnect, _zerotier, _autoUpdate);

            AddSection(S.T("set_network"));
            _dns.Items.AddRange(DnsChoices);
            _dns.Font = Theme.Ui(10f);
            _ttl.Font = Theme.Ui(10f);
            var dnsLabel = new Label { Text = S.T("set_dns"), Font = Theme.Ui(10f), ForeColor = Theme.Text, BackColor = Color.Transparent, AutoSize = true, Margin = Dpi.P(0, 4, 0, 2) };
            var ttlLabel = new Label { Text = S.T("set_ttl"), Font = Theme.Ui(10f), ForeColor = Theme.Text, BackColor = Color.Transparent, AutoSize = true, Margin = Dpi.P(0, 12, 0, 2) };
            var ttlHint = new Label { Text = S.T("set_ttl_desc"), Font = Theme.Ui(8.5f), ForeColor = Theme.TextMuted, BackColor = Color.Transparent, AutoSize = true, Margin = Dpi.P(0, 0, 0, 4) };
            foreach (var c in new Control[] { dnsLabel, ttlLabel, ttlHint, _dns, _ttl }) c.Tag = "natural";
            _dns.Margin = Dpi.P(0, 2, 0, 4);
            _ttl.Margin = Dpi.P(0, 2, 0, 8);
            AddCard(dnsLabel, _dns, ttlLabel, ttlHint, _ttl, _autoTune, _filterAaaa, _lan, _verbose);

            _save.Click += async (_, __) =>
            {
                var cfg = App.Config.Clone();
                cfg.MinimizeToTray = _tray.Checked;
                cfg.AutoReconnect = _reconnect.Checked;
                cfg.StopZeroTier = _zerotier.Checked;
                cfg.AutoUpdate = _autoUpdate.Checked;
                cfg.DohUpstream = (_dns.SelectedItem as DnsChoice)?.Value ?? cfg.DohUpstream;
                if ((int)_ttl.Value != cfg.FakeTtl)
                {
                    cfg.FakeTtl = (int)_ttl.Value;
                    cfg.AutoTuneDone = true; // a manual value wins over auto tuning
                }
                cfg.AutoTuneTtl = _autoTune.Checked;
                cfg.FilterAaaa = _filterAaaa.Checked;
                cfg.LanExclude = _lan.Checked;
                cfg.EngineVerbose = _verbose.Checked;
                await App.ApplySettingsAsync(cfg, _autoStart.Checked);
            };
            Controls.Add(_save);
        }

        public override void OnShown()
        {
            var cfg = App.Config;
            _autoStart.Checked = App.Status.AutoStart;
            _tray.Checked = cfg.MinimizeToTray;
            _reconnect.Checked = cfg.AutoReconnect;
            _zerotier.Checked = cfg.StopZeroTier;
            _autoUpdate.Checked = cfg.AutoUpdate;
            var choice = DnsChoices.FirstOrDefault(d => string.Equals(d.Value, cfg.DohUpstream, StringComparison.OrdinalIgnoreCase));
            if (choice == null)
            {
                choice = new DnsChoice { Value = cfg.DohUpstream, Label = cfg.DohUpstream };
                _dns.Items.Add(choice);
            }
            _dns.SelectedItem = choice;
            _ttl.Value = Math.Max(_ttl.Minimum, Math.Min(_ttl.Maximum, cfg.FakeTtl));
            _autoTune.Checked = cfg.AutoTuneTtl;
            _filterAaaa.Checked = cfg.FilterAaaa;
            _lan.Checked = cfg.LanExclude;
            _verbose.Checked = cfg.EngineVerbose;
        }

        public override void Render() => _save.Enabled = !App.Busy;
    }
}
