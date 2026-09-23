using System.Drawing;
using System.Windows.Forms;

namespace Amfetamin.UI
{
    /// <summary>A scrollable page with a heading; content is stacked vertically.</summary>
    internal abstract class Page : Stack
    {
        protected readonly AppController App;
        protected readonly MainForm Host;

        protected Page(AppController app, MainForm shell, string title)
        {
            App = app;
            Host = shell;
            Padding = Dpi.P(28, 22, 28, 22);
            Dock = DockStyle.Fill;
            Visible = false;
            var heading = new TextLabel(title, Theme.Display(18f), Theme.Text) { Margin = Dpi.P(0, 0, 0, 14), Tag = "natural" };
            Controls.Add(heading);
        }

        /// <summary>Called when the page becomes visible.</summary>
        public virtual void OnShown() { }

        /// <summary>Called whenever controller state changes (UI thread).</summary>
        public virtual void Render() { }

        protected TextLabel AddSection(string text)
        {
            var l = new TextLabel(text.ToUpperInvariant(), Theme.Ui(8.5f, FontStyle.Bold), Theme.TextDim)
            {
                Margin = Dpi.P(2, 14, 0, 8),
                Tag = "natural",
            };
            Controls.Add(l);
            return l;
        }

        protected Label AddParagraph(string text, Control parent = null, Color? color = null)
        {
            var l = new Label
            {
                Text = text,
                Font = Theme.Ui(9.5f),
                ForeColor = color ?? Theme.TextMuted,
                BackColor = Color.Transparent,
                AutoSize = false,
                UseMnemonic = false,
                Margin = Dpi.P(0, 0, 0, 10),
            };
            l.Resize += (_, __) => FitHeight(l);
            l.TextChanged += (_, __) => FitHeight(l);
            (parent ?? this).Controls.Add(l);
            return l;
        }

        protected static void FitHeight(Label l)
        {
            if (l.Width <= 0) return;
            var h = TextRenderer.MeasureText(l.Text + " ", l.Font, new Size(l.Width, int.MaxValue), TextFormatFlags.WordBreak).Height;
            if (l.Height != h) l.Height = h;
        }

        /// <summary>Card whose height follows its stacked children.</summary>
        protected Card AddCard(params Control[] children)
        {
            var card = new Card { Margin = Dpi.P(0, 0, 0, 12), Padding = Dpi.P(18, 14, 18, 14) };
            var inner = new Stack { Dock = DockStyle.Fill, AutoScroll = false, BackColor = Theme.Card, Padding = Padding.Empty };
            foreach (var c in children)
            {
                if (c.Margin == new Padding(3)) c.Margin = Dpi.P(0, 4, 0, 4);
                inner.Controls.Add(c);
            }
            card.Controls.Add(inner);
            void Fit()
            {
                var h = card.Padding.Vertical;
                foreach (Control c in inner.Controls) if (c.Visible) h += c.Height + c.Margin.Vertical;
                if (card.Height != h) card.Height = h;
            }
            inner.Layout += (_, __) => Fit();
            foreach (var c in children) c.SizeChanged += (_, __) => Fit();
            Controls.Add(card);
            Fit();
            return card;
        }

        protected static ToggleRow Toggle(string text, string description = null) =>
            new ToggleRow { Text = text, Description = description ?? "" };
    }
}
