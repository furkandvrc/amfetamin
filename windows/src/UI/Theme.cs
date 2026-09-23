using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Linq;

namespace Amfetamin.UI
{
    /// <summary>Scales 96-DPI layout values to the system DPI.</summary>
    internal static class Dpi
    {
        public static readonly float Factor = GetFactor();

        private static float GetFactor()
        {
            using (var g = Graphics.FromHwnd(System.IntPtr.Zero)) return g.DpiX / 96f;
        }

        public static int S(int px) => (int)System.Math.Round(px * Factor);
        public static System.Drawing.Size S(int w, int h) => new System.Drawing.Size(S(w), S(h));
        public static System.Windows.Forms.Padding P(int all) => new System.Windows.Forms.Padding(S(all));
        public static System.Windows.Forms.Padding P(int l, int t, int r, int b) => new System.Windows.Forms.Padding(S(l), S(t), S(r), S(b));
    }

    internal static class Theme
    {
        public static readonly Color Bg = Color.FromArgb(13, 14, 20);
        public static readonly Color Sidebar = Color.FromArgb(18, 19, 27);
        public static readonly Color Card = Color.FromArgb(24, 26, 36);
        public static readonly Color CardHover = Color.FromArgb(32, 35, 48);
        public static readonly Color Border = Color.FromArgb(40, 43, 58);
        public static readonly Color Input = Color.FromArgb(30, 32, 44);

        public static readonly Color Text = Color.FromArgb(236, 238, 245);
        public static readonly Color TextMuted = Color.FromArgb(142, 147, 168);
        public static readonly Color TextDim = Color.FromArgb(96, 100, 120);

        public static readonly Color Accent = Color.FromArgb(0, 214, 170);
        public static readonly Color AccentHover = Color.FromArgb(40, 232, 192);
        public static readonly Color AccentDark = Color.FromArgb(0, 120, 96);
        public static readonly Color Purple = Color.FromArgb(124, 92, 255);
        public static readonly Color Good = Color.FromArgb(52, 211, 128);
        public static readonly Color Warn = Color.FromArgb(250, 176, 60);
        public static readonly Color Bad = Color.FromArgb(244, 84, 100);
        public static readonly Color Neutral = Color.FromArgb(92, 97, 120);

        private static readonly string UiFamily = Pick("Segoe UI Variable Text", "Segoe UI");
        private static readonly string DisplayFamily = Pick("Segoe UI Variable Display", "Segoe UI Semibold", "Segoe UI");
        public static readonly string IconFamily = Pick("Segoe Fluent Icons", "Segoe MDL2 Assets");

        public static Font Ui(float size, FontStyle style = FontStyle.Regular) => new Font(UiFamily, size, style);
        public static Font Display(float size, FontStyle style = FontStyle.Bold) => new Font(DisplayFamily, size, style);
        public static Font Icon(float size) => new Font(IconFamily, size);
        public static Font Mono(float size) => new Font(Pick("Cascadia Mono", "Consolas"), size);

        private static string Pick(params string[] families)
        {
            using (var installed = new InstalledFontCollection())
            {
                var names = installed.Families.Select(f => f.Name).ToList();
                return families.FirstOrDefault(f => names.Contains(f)) ?? "Segoe UI";
            }
        }

        public static GraphicsPath Rounded(RectangleF r, float radius)
        {
            var path = new GraphicsPath();
            var d = radius * 2;
            if (d <= 0 || r.Width < d || r.Height < d)
            {
                path.AddRectangle(r);
                return path;
            }
            path.AddArc(r.X, r.Y, d, d, 180, 90);
            path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }

        public static Color Blend(Color a, Color b, float t) => Color.FromArgb(
            (int)(a.A + (b.A - a.A) * t), (int)(a.R + (b.R - a.R) * t),
            (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t));

        public static class Glyph
        {
            public const string Home = "";
            public const string Game = "";
            public const string Settings = "";
            public const string Logs = "";
            public const string Health = "";
            public const string Power = "";
            public const string Warning = "";
            public const string Check = "";
        }
    }
}
