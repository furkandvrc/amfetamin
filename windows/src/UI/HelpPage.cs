using System;
using System.Diagnostics;
using System.Drawing;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Amfetamin.UI
{
    internal sealed class HelpPage : Page
    {
        private readonly TextBox _report = new TextBox
        {
            Multiline = true,
            ReadOnly = true,
            ScrollBars = ScrollBars.Both,
            WordWrap = false,
            Height = Dpi.S(220),
            BackColor = Theme.Input,
            ForeColor = Theme.Text,
            BorderStyle = BorderStyle.None,
            Font = Theme.Mono(9f),
        };
        private readonly FlatButton _run = new FlatButton { Text = S.T("help_run"), Kind = ButtonKind.Primary, Size = Dpi.S(170, 38) };
        private readonly FlatButton _save = new FlatButton { Text = S.T("help_save"), Size = Dpi.S(150, 38), Enabled = false };
        private readonly FlatButton _update = new FlatButton { Text = S.T("help_update"), Size = Dpi.S(200, 38) };
        private readonly FlatButton _github = new FlatButton { Text = S.T("help_github"), Kind = ButtonKind.Ghost, Size = Dpi.S(150, 38) };
        private readonly FlatButton _uninstall = new FlatButton { Text = S.T("help_uninstall"), Kind = ButtonKind.Danger, Size = Dpi.S(170, 38) };

        public HelpPage(AppController app, MainForm shell) : base(app, shell, S.T("nav_help"))
        {
            AddSection(S.T("help_diag"));
            var desc = new Label { Text = S.T("help_diag_desc"), Font = Theme.Ui(9f), ForeColor = Theme.TextMuted, BackColor = Color.Transparent, AutoSize = false, Height = Dpi.S(36) };
            var buttons = Row(_run, _save);
            AddCard(desc, _report, buttons);

            AddSection(S.T("help_about"));
            var about = new Label
            {
                Text = $"amfetamin {AppInfo.VersionText}\nby {AppInfo.Author}  ·  {AppInfo.ProjectUrl}\n{Paths.InstallRoot}",
                Font = Theme.Ui(9.5f),
                ForeColor = Theme.TextMuted,
                BackColor = Color.Transparent,
                AutoSize = false,
                Height = Dpi.S(60),
            };
            AddCard(about, Row(_update, _github, _uninstall));

            _run.Click += async (_, __) =>
            {
                _run.Enabled = false;
                _report.Text = S.T("busy");
                try
                {
                    _report.Text = (await Task.Run(() => Diagnostics.BuildReportAsync(CancellationToken.None))).Replace("\n", "\r\n").Replace("\r\r\n", "\r\n");
                    _save.Enabled = true;
                }
                catch (Exception ex)
                {
                    _report.Text = ex.ToString();
                }
                finally
                {
                    _run.Enabled = true;
                }
            };
            _save.Click += (_, __) =>
            {
                try
                {
                    var path = Diagnostics.SaveReport(_report.Text);
                    Host.ShowToast(S.T("logs_exported", path), false);
                    Process.Start("explorer.exe", "/select," + Amfetamin.Shell.Quote(path));
                }
                catch (Exception ex)
                {
                    Host.ShowToast(ex.Message, true);
                }
            };
            _github.Click += (_, __) => OpenUrl(AppInfo.ProjectUrl);
            _update.Click += async (_, __) =>
            {
                _update.Enabled = false;
                try
                {
                    // Installs the update right away when one is found.
                    await App.CheckForUpdateAsync(auto: false);
                }
                finally
                {
                    _update.Enabled = true;
                }
            };
            _uninstall.Click += async (_, __) =>
            {
                if (MessageBox.Show(Host, S.T("confirm_uninstall"), S.T("err_title"), MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes) return;
                await App.UninstallAsync();
                MessageBox.Show(Host, S.T("uninstalled"), S.T("err_title"), MessageBoxButtons.OK, MessageBoxIcon.Information);
                Host.ExitApp(stopEngine: false);
            };
        }

        public override void Render()
        {
            _uninstall.Enabled = !App.Busy;
        }

        private static FlowLayoutPanel Row(params Control[] controls)
        {
            var row = new FlowLayoutPanel { AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, WrapContents = true, BackColor = Color.Transparent, Margin = Dpi.P(0, 8, 0, 0) };
            foreach (var c in controls) c.Margin = Dpi.P(0, 0, 10, 0);
            row.Controls.AddRange(controls);
            row.Tag = "natural";
            return row;
        }

        private static void OpenUrl(string url)
        {
            try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); } catch { }
        }
    }
}
