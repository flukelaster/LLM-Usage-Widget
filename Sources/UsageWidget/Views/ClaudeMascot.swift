import SwiftUI

/// A tiny pixel-art Claude mascot that idles in place — hopping, blinking, glancing around, and
/// shuffling its feet — a nod to the animated companion in Claude Code Desktop's chat input.
///
/// Pure SwiftUI `Canvas` + `TimelineView(.animation)`, so it only ticks while on screen. In a
/// `MenuBarExtra` the status-bar *label* never gets a display link (so animation there is dead),
/// but the popover is a real window that does — hence this lives in the popover header. When the
/// popover closes the view is torn down and the timeline stops, so it costs nothing at rest.
///
/// Everything is drawn from a small sprite grid. The body is static; eyes and legs are painted
/// procedurally on top so they can blink / dart / march independently of the body.
struct ClaudeMascotView: View {
    /// Size of one sprite pixel, in points. The mascot spans `gridW × (gridH + 1)` of these.
    /// 1.5pt → 3 device pixels on a 2× display, keeping the art crisp (everything snaps to cells).
    var pixel: CGFloat = 1.5

    // Sprite body: ' ' transparent, 'B' body. 10 rows; legs occupy the two rows below it.
    private static let body: [String] = [
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
    ]
    private static let gridW = 16
    private static let gridH = 12   // 10 body rows + 2 leg rows

    // Palette — Claude brand terracotta over the popover's dark material.
    private static let bodyColor = Color(hex: "#D97757")
    private static let legColor  = Color(hex: "#B05A3C")
    private static let eyeWhite  = Color(hex: "#F8FAFC")
    private static let pupil     = Color(hex: "#1B1B1F")

    // Top-left cell of each 2×2 eye; 1px-wide leg columns.
    private static let eyes = [(x: 3, y: 3), (x: 6, y: 3)]
    private static let legX = [3, 6, 9, 12]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, _ in
                draw(ctx, t: timeline.date.timeIntervalSinceReferenceDate)
            }
            .frame(width: CGFloat(Self.gridW) * pixel,
                   height: CGFloat(Self.gridH + 1) * pixel)   // +1 row of headroom for the hop
        }
        .accessibilityHidden(true)
    }

    private func px(_ ctx: GraphicsContext, _ x: Int, _ y: Int, _ color: Color, _ dy: CGFloat) {
        let r = CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel + dy, width: pixel, height: pixel)
        ctx.fill(Path(r), with: .color(color))
    }

    private func draw(_ ctx: GraphicsContext, t: TimeInterval) {
        // Idle hop: rests 1px low, rises flush to the top on a ~0.6s cadence.
        let bobY: CGFloat = sin(t * 5) > 0 ? 0 : pixel

        // Static body.
        for (row, line) in Self.body.enumerated() {
            for (col, ch) in line.enumerated() where ch == "B" {
                px(ctx, col, row, Self.bodyColor, bobY)
            }
        }
        // A darker snout pixel just below the eyes.
        px(ctx, 5, 6, Self.legColor, bobY)

        // Legs: each foot plants or tucks up, alternating sets for a march-in-place shuffle.
        let step = Int(t * 2.5) % 2
        for (i, lx) in Self.legX.enumerated() {
            px(ctx, lx, Self.gridH - 2, Self.legColor, bobY)                       // upper leg, always
            if (i + step) % 2 != 0 { px(ctx, lx, Self.gridH - 1, Self.legColor, bobY) }  // foot when planted
        }

        // Eyes: a quick blink every ~3.2s; otherwise 2×2 whites with a pupil that darts the corners.
        let blink = t.truncatingRemainder(dividingBy: 3.2) < 0.14
        let (dx, dy) = [(0, 1), (1, 1), (1, 0), (0, 0)][Int(t / 1.6) % 4]
        for e in Self.eyes {
            if blink {
                px(ctx, e.x, e.y + 1, Self.legColor, bobY)            // closed lid
                px(ctx, e.x + 1, e.y + 1, Self.legColor, bobY)
            } else {
                px(ctx, e.x, e.y, Self.eyeWhite, bobY)
                px(ctx, e.x + 1, e.y, Self.eyeWhite, bobY)
                px(ctx, e.x, e.y + 1, Self.eyeWhite, bobY)
                px(ctx, e.x + 1, e.y + 1, Self.eyeWhite, bobY)
                px(ctx, e.x + dx, e.y + dy, Self.pupil, bobY)         // darting pupil
            }
        }
    }
}
