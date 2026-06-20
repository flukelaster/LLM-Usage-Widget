using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Threading;

namespace LLMUsageWidget.App.Views;

/// <summary>A tiny pixel-art Claude mascot that idles in the popover header — hopping, blinking,
/// glancing around, and shuffling its feet. Ported from the macOS app's ClaudeMascotView (same
/// sprite grid + timings). Drawn directly to the <see cref="DrawingContext"/>; a 30 fps timer ticks
/// only while attached, so it costs nothing once the popover closes.</summary>
public sealed class ClaudeMascot : Control
{
    private const double Pixel = 1.5;   // size of one sprite cell → 16×13 cells ≈ 24×19.5 px
    private const int GridW = 16;
    private const int GridH = 12;       // 10 body rows + 2 leg rows

    // Sprite body: ' ' transparent, 'B' body. Legs occupy the two rows below it.
    private static readonly string[] Body =
    {
        "       BB       ",
        "    BBBBBBBB    ",
        "   BBBBBBBBBB   ",
        "  BBBBBBBBBBBB  ",
        " BBBBBBBBBBBBBB ",
        " BBBBBBBBBBBBBB ",
        " BBBBBBBBBBBBBB ",
        " BBBBBBBBBBBBBB ",
        "  BBBBBBBBBBBB  ",
        "   BBBBBBBBBB   ",
    };

    private static readonly IBrush BodyColor = new SolidColorBrush(Color.Parse("#D97757"));
    private static readonly IBrush LegColor = new SolidColorBrush(Color.Parse("#B05A3C"));
    private static readonly IBrush EyeWhite = new SolidColorBrush(Color.Parse("#F8FAFC"));
    private static readonly IBrush Pupil = new SolidColorBrush(Color.Parse("#1B1B1F"));

    private static readonly (int X, int Y)[] Eyes = { (3, 3), (6, 3) };
    private static readonly int[] LegX = { 3, 6, 9, 12 };
    private static readonly (int Dx, int Dy)[] Gaze = { (0, 1), (1, 1), (1, 0), (0, 0) };

    private readonly DispatcherTimer _timer;
    private double _t = 0.3;   // a calm opening frame (body up, eyes open) for the still snapshot

    public ClaudeMascot()
    {
        Width = GridW * Pixel;
        Height = (GridH + 1) * Pixel;   // +1 row of headroom for the hop
        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(1000.0 / 30) };
        _timer.Tick += (_, _) => { _t += 1.0 / 30; InvalidateVisual(); };
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);
        _timer.Start();
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnDetachedFromVisualTree(e);
        _timer.Stop();
    }

    private static void Px(DrawingContext ctx, int x, int y, IBrush color, double dy) =>
        ctx.FillRectangle(color, new Rect(x * Pixel, y * Pixel + dy, Pixel, Pixel));

    public override void Render(DrawingContext ctx)
    {
        double t = _t;
        double bob = Math.Sin(t * 5) > 0 ? 0 : Pixel;   // idle hop: rests 1px low, rises flush

        for (int row = 0; row < Body.Length; row++)
            for (int col = 0; col < Body[row].Length; col++)
                if (Body[row][col] == 'B')
                    Px(ctx, col, row, BodyColor, bob);

        Px(ctx, 5, 6, LegColor, bob);   // darker snout pixel below the eyes

        int step = (int)(t * 2.5) % 2;
        for (int i = 0; i < LegX.Length; i++)
        {
            Px(ctx, LegX[i], GridH - 2, LegColor, bob);                          // upper leg, always
            if ((i + step) % 2 != 0) Px(ctx, LegX[i], GridH - 1, LegColor, bob); // foot when planted
        }

        bool blink = t % 3.2 < 0.14;
        var (dx, dy) = Gaze[(int)(t / 1.6) % 4];
        foreach (var (ex, ey) in Eyes)
        {
            if (blink)
            {
                Px(ctx, ex, ey + 1, LegColor, bob);
                Px(ctx, ex + 1, ey + 1, LegColor, bob);
            }
            else
            {
                Px(ctx, ex, ey, EyeWhite, bob);
                Px(ctx, ex + 1, ey, EyeWhite, bob);
                Px(ctx, ex, ey + 1, EyeWhite, bob);
                Px(ctx, ex + 1, ey + 1, EyeWhite, bob);
                Px(ctx, ex + dx, ey + dy, Pupil, bob);   // darting pupil
            }
        }
    }
}
