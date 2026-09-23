using System;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Windows.Forms;

namespace Amfetamin.UI
{
    /// <summary>Base for owner-drawn controls: double buffered, transparent-friendly.</summary>
    internal abstract class DrawnControl : Control
    {
        protected DrawnControl()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                     ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            ForeColor = Theme.Text;
        }

        protected static float K => Dpi.Factor;

        protected static void Smooth(Graphics g)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        }
    }

    /// <summary>Rounded card background.</summary>
    internal class Card : Panel
    {
        public int Radius { get; set; } = 12;
        public Color Fill { get; set; } = Theme.Card;
        public Color Stroke { get; set; } = Color.Empty;

        public Card()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
            BackColor = Theme.Card;
            Padding = Dpi.P(16);
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            e.Graphics.Clear(Parent?.BackColor ?? Theme.Bg);
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            var r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            using (var path = Theme.Rounded(r, Radius * Dpi.Factor))
            using (var brush = new SolidBrush(Fill))
            {
                e.Graphics.FillPath(brush, path);
                if (!Stroke.IsEmpty)
                    using (var pen = new Pen(Stroke)) e.Graphics.DrawPath(pen, path);
            }
        }
    }

    internal enum ButtonKind { Primary, Secondary, Danger, Ghost }

    internal class FlatButton : DrawnControl
    {
        private bool _hover, _down;
        private ButtonKind _kind = ButtonKind.Secondary;

        public ButtonKind Kind { get => _kind; set { _kind = value; Invalidate(); } }
        public int Radius { get; set; } = 8;

        public FlatButton()
        {
            Cursor = Cursors.Hand;
            Font = Theme.Ui(9.5f, FontStyle.Bold);
            Size = Dpi.S(160, 38);
            TabStop = true;
        }

        private (Color bg, Color fg) Colors()
        {
            if (!Enabled) return (Theme.Input, Theme.TextDim);
            switch (_kind)
            {
                case ButtonKind.Primary: return (_down ? Theme.AccentDark : _hover ? Theme.AccentHover : Theme.Accent, Color.FromArgb(6, 24, 20));
                case ButtonKind.Danger: return (_down ? Theme.Blend(Theme.Bad, Color.Black, .3f) : _hover ? Theme.Blend(Theme.Bad, Color.White, .1f) : Theme.Bad, Color.White);
                case ButtonKind.Ghost: return (_hover ? Theme.CardHover : Color.Transparent, Theme.TextMuted);
                default: return (_down ? Theme.Border : _hover ? Theme.CardHover : Theme.Input, Theme.Text);
            }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Smooth(g);
            var (bg, fg) = Colors();
            using (var path = Theme.Rounded(new RectangleF(0, 0, Width - 1, Height - 1), Radius * K))
            {
                if (bg.A > 0) using (var b = new SolidBrush(bg)) g.FillPath(b, path);
                if (Focused && ShowFocusCues)
                    using (var pen = new Pen(Theme.Accent, 1.5f)) g.DrawPath(pen, path);
            }
            TextRenderer.DrawText(g, Text, Font, ClientRectangle, fg,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        }

        protected override void OnMouseEnter(EventArgs e) { _hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { _hover = _down = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { if (e.Button == MouseButtons.Left) { _down = true; Focus(); Invalidate(); } base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { _down = false; Invalidate(); base.OnMouseUp(e); }
        protected override void OnEnabledChanged(EventArgs e) { Cursor = Enabled ? Cursors.Hand : Cursors.Default; Invalidate(); base.OnEnabledChanged(e); }
        protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
        protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }
        protected override void OnTextChanged(EventArgs e) { Invalidate(); base.OnTextChanged(e); }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space) { OnClick(EventArgs.Empty); e.Handled = true; }
            base.OnKeyDown(e);
        }
    }

    /// <summary>On/off switch with a title and optional description.</summary>
    internal class ToggleRow : DrawnControl
    {
        private bool _checked;
        private bool _hover;
        private string _description = "";

        public event EventHandler CheckedChanged;

        [DefaultValue(false)]
        public bool Checked
        {
            get => _checked;
            set { if (_checked == value) return; _checked = value; Invalidate(); CheckedChanged?.Invoke(this, EventArgs.Empty); }
        }

        public string Description
        {
            get => _description;
            set { _description = value ?? ""; UpdateHeight(); Invalidate(); }
        }

        private readonly Font _descFont = Theme.Ui(8.5f);

        public ToggleRow()
        {
            Cursor = Cursors.Hand;
            Font = Theme.Ui(10f);
            TabStop = true;
            UpdateHeight();
        }

        private void UpdateHeight()
        {
            var baseH = (int)(26 * K);
            if (string.IsNullOrEmpty(_description) || Width <= 0)
            {
                Height = baseH + (int)(6 * K);
                return;
            }
            var textW = Math.Max(50, Width - (int)(64 * K));
            var h = TextRenderer.MeasureText(_description, _descFont, new Size(textW, int.MaxValue), TextFormatFlags.WordBreak).Height;
            Height = baseH + h + (int)(8 * K);
        }

        protected override void OnResize(EventArgs e) { base.OnResize(e); if (!string.IsNullOrEmpty(_description)) UpdateHeight(); }
        
        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Smooth(g);
            float sw = 40 * K, sh = 22 * K;
            var track = new RectangleF(1, 2 * K, sw, sh);
            var on = _checked && Enabled;
            var trackColor = !Enabled ? Theme.Input : on ? Theme.Accent : _hover ? Theme.Border : Theme.Input;
            using (var path = Theme.Rounded(track, sh / 2))
            using (var b = new SolidBrush(trackColor))
            {
                g.FillPath(b, path);
                if (!on) using (var pen = new Pen(Theme.Border)) g.DrawPath(pen, path);
            }
            var knob = sh - 6 * K;
            var kx = on ? track.Right - knob - 3 * K : track.X + 3 * K;
            using (var b = new SolidBrush(on ? Color.FromArgb(6, 24, 20) : Theme.TextMuted))
                g.FillEllipse(b, kx, track.Y + 3 * K, knob, knob);

            var textX = (int)(sw + 14 * K);
            var titleRect = new Rectangle(textX, 0, Width - textX, (int)(26 * K));
            TextRenderer.DrawText(g, Text, Font, titleRect, Enabled ? Theme.Text : Theme.TextDim,
                TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis);
            if (!string.IsNullOrEmpty(_description))
            {
                var descRect = new Rectangle(textX, titleRect.Bottom, Width - textX, Height - titleRect.Bottom);
                TextRenderer.DrawText(g, _description, _descFont, descRect, Theme.TextMuted, TextFormatFlags.WordBreak | TextFormatFlags.Left);
            }
            if (Focused && ShowFocusCues)
                using (var pen = new Pen(Theme.Accent)) g.DrawRectangle(pen, 0, 0, (int)sw + 2, (int)(sh + 4 * K));
        }

        protected override void OnClick(EventArgs e) { if (Enabled) Checked = !Checked; base.OnClick(e); }
        protected override void OnMouseEnter(EventArgs e) { _hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { _hover = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
        protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }
        protected override void OnTextChanged(EventArgs e) { Invalidate(); base.OnTextChanged(e); }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Space) { Checked = !Checked; e.Handled = true; }
            base.OnKeyDown(e);
        }
    }

    /// <summary>Small status tile: colored dot, caption and value.</summary>
    internal class StatusTile : Card
    {
        private string _value = "—";
        private Color _dot = Theme.Neutral;
        private readonly Font _captionFont = Theme.Ui(8.5f);
        private readonly Font _valueFont = Theme.Ui(11f, FontStyle.Bold);

        public string Caption { get; set; } = "";
        public string Value { get => _value; set { if (_value == value) return; _value = value; Invalidate(); } }
        public Color Dot { get => _dot; set { if (_dot == value) return; _dot = value; Invalidate(); } }

        public StatusTile()
        {
            Radius = 10;
            Height = Dpi.S(76);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            var s = Dpi.Factor;
            var pad = (int)(14 * s);
            using (var b = new SolidBrush(_dot)) g.FillEllipse(b, pad, pad + 3 * s, 9 * s, 9 * s);
            TextRenderer.DrawText(g, Caption, _captionFont, new Rectangle(pad + (int)(16 * s), pad - (int)(2 * s), Width - pad * 2, (int)(20 * s)),
                Theme.TextMuted, TextFormatFlags.Left | TextFormatFlags.EndEllipsis);
            TextRenderer.DrawText(g, _value, _valueFont, new Rectangle(pad, pad + (int)(22 * s), Width - pad * 2, (int)(28 * s)),
                Theme.Text, TextFormatFlags.Left | TextFormatFlags.EndEllipsis);
        }
    }

    /// <summary>Large circular connect button with an animated ring while busy.</summary>
    internal class PowerButton : DrawnControl
    {
        private Color _ring = Theme.Neutral;
        private bool _spinning;
        private bool _hover;
        private float _angle;
        private readonly Timer _timer = new Timer { Interval = 16 };

        private static readonly Font IconFont = Theme.Icon(30f);

        public Color Ring { get => _ring; set { if (_ring == value) return; _ring = value; Invalidate(); } }

        public bool Spinning
        {
            get => _spinning;
            set
            {
                if (_spinning == value) return;
                _spinning = value;
                if (value) _timer.Start(); else _timer.Stop();
                Invalidate();
            }
        }

        public PowerButton()
        {
            Cursor = Cursors.Hand;
            Size = Dpi.S(168, 168);
            TabStop = true;
            _timer.Tick += (_, __) => { _angle = (_angle + 6) % 360; Invalidate(); };
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Smooth(g);
            var size = Math.Min(Width, Height) - 8;
            var rect = new RectangleF((Width - size) / 2f, (Height - size) / 2f, size, size);
            var thick = 7 * K;

            // Soft glow
            for (var i = 3; i >= 1; i--)
            {
                var grow = i * 5 * K;
                using (var b = new SolidBrush(Color.FromArgb(_spinning ? 10 : 16, _ring)))
                    g.FillEllipse(b, RectangleF.Inflate(rect, grow - 12 * K, grow - 12 * K));
            }

            var inner = RectangleF.Inflate(rect, -thick * 1.6f, -thick * 1.6f);
            using (var b = new SolidBrush(_hover && Enabled ? Theme.CardHover : Theme.Card)) g.FillEllipse(b, inner);

            var ringRect = RectangleF.Inflate(rect, -thick / 2, -thick / 2);
            using (var track = new Pen(Theme.Border, thick)) g.DrawEllipse(track, ringRect);
            using (var pen = new Pen(_ring, thick) { StartCap = LineCap.Round, EndCap = LineCap.Round })
            {
                if (_spinning) g.DrawArc(pen, ringRect, _angle, 100);
                else g.DrawEllipse(pen, ringRect);
            }

            TextRenderer.DrawText(g, Theme.Glyph.Power, IconFont, Rectangle.Round(inner), Enabled ? _ring : Theme.TextDim,
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }

        protected override void OnMouseEnter(EventArgs e) { _hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { _hover = false; Invalidate(); base.OnMouseLeave(e); }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space) { OnClick(EventArgs.Empty); e.Handled = true; }
            base.OnKeyDown(e);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) _timer.Dispose();
            base.Dispose(disposing);
        }
    }

    internal class NavButton : DrawnControl
    {
        private bool _selected, _hover;
        private static readonly Font IconFont = Theme.Icon(12f);
        public string Glyph { get; set; }

        public bool Selected { get => _selected; set { _selected = value; Invalidate(); } }

        public NavButton()
        {
            Cursor = Cursors.Hand;
            Font = Theme.Ui(10f);
            Height = Dpi.S(42);
            TabStop = true;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Smooth(g);
            var r = new RectangleF(8 * K, 2 * K, Width - 16 * K, Height - 4 * K);
            if (_selected || _hover)
                using (var path = Theme.Rounded(r, 8 * K))
                using (var b = new SolidBrush(_selected ? Theme.Card : Theme.Blend(Theme.Sidebar, Theme.Card, .6f)))
                    g.FillPath(b, path);
            if (_selected)
                using (var b = new SolidBrush(Theme.Accent))
                using (var bar = Theme.Rounded(new RectangleF(r.X, r.Y + r.Height * .25f, 3 * K, r.Height * .5f), 1.5f * K))
                    g.FillPath(b, bar);

            var color = _selected ? Theme.Text : Theme.TextMuted;
            TextRenderer.DrawText(g, Glyph ?? "", IconFont, new Rectangle((int)(r.X + 14 * K), 0, (int)(24 * K), Height), _selected ? Theme.Accent : color,
                    TextFormatFlags.VerticalCenter | TextFormatFlags.HorizontalCenter);
            TextRenderer.DrawText(g, Text, Font, new Rectangle((int)(r.X + 46 * K), 0, Width - (int)(r.X + 50 * K), Height), color,
                TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis);
        }

        protected override void OnMouseEnter(EventArgs e) { _hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { _hover = false; Invalidate(); base.OnMouseLeave(e); }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space) { OnClick(EventArgs.Empty); e.Handled = true; }
            base.OnKeyDown(e);
        }
    }

    /// <summary>Label that paints on transparent parents without flicker.</summary>
    internal class TextLabel : Label
    {
        public TextLabel(string text, Font font, Color color)
        {
            Text = text;
            Font = font;
            ForeColor = color;
            BackColor = Color.Transparent;
            AutoSize = true;
            UseMnemonic = false;
        }
    }

    /// <summary>Vertical stack that stretches children to its width (a simple layout helper).</summary>
    internal class Stack : FlowLayoutPanel
    {
        public Stack()
        {
            FlowDirection = FlowDirection.TopDown;
            WrapContents = false;
            AutoScroll = true;
            BackColor = Theme.Bg;
            DoubleBuffered = true;
        }

        protected override void OnLayout(LayoutEventArgs e)
        {
            var w = ClientSize.Width - Padding.Horizontal;
            foreach (Control c in Controls)
            {
                if (c.Tag as string == "natural") continue;
                var target = w - c.Margin.Horizontal;
                if (target > 0 && c.Width != target) c.Width = target;
            }
            base.OnLayout(e);
        }
    }
}
