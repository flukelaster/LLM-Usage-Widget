import SwiftUI
import CoreGraphics

/// Minimal SVG path-data (`d` attribute) → SwiftUI `Path` renderer. Supports M/L/H/V/C/S/Q/T/A/Z
/// in both absolute and relative forms. Elliptical arcs are emitted as fine polylines — visually
/// exact at icon sizes and free of `addArc` orientation pitfalls. Used to draw brand logos as
/// crisp, tintable vectors without bundling image assets (which SPM-app packaging makes awkward).
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var path = Path()
        let chars = Array(d)
        var i = 0
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCubic: CGPoint?
        var lastQuad: CGPoint?

        func skipSep() {
            while i < chars.count {
                let c = chars[i]
                if c == " " || c == "," || c == "\n" || c == "\t" || c == "\r" { i += 1 } else { break }
            }
        }
        func readCommand() -> Character? {
            skipSep()
            guard i < chars.count, chars[i].isLetter else { return nil }
            let c = chars[i]; i += 1; return c
        }
        func moreParams() -> Bool {
            skipSep()
            guard i < chars.count else { return false }
            let c = chars[i]
            return c == "." || c == "+" || c == "-" || c.isNumber
        }
        func readNumber() -> CGFloat {
            skipSep()
            var s = ""
            if i < chars.count, chars[i] == "+" || chars[i] == "-" { s.append(chars[i]); i += 1 }
            var seenDot = false
            while i < chars.count {
                let c = chars[i]
                if c.isNumber { s.append(c); i += 1 }
                else if c == "." {
                    if seenDot { break }
                    seenDot = true; s.append(c); i += 1
                } else if c == "e" || c == "E" {
                    s.append(c); i += 1
                    if i < chars.count, chars[i] == "+" || chars[i] == "-" { s.append(chars[i]); i += 1 }
                } else { break }
            }
            return CGFloat(Double(s) ?? 0)
        }
        func readFlag() -> CGFloat {
            skipSep()
            guard i < chars.count else { return 0 }
            let c = chars[i]; i += 1
            return c == "1" ? 1 : 0
        }
        func readPoint(relative: Bool) -> CGPoint {
            let x = readNumber(); let y = readNumber()
            return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        }
        func reflect(_ control: CGPoint?) -> CGPoint {
            guard let control else { return current }
            return CGPoint(x: 2 * current.x - control.x, y: 2 * current.y - control.y)
        }

        while let raw = readCommand() {
            let relative = raw.isLowercase
            var op = Character(raw.uppercased())
            repeat {
                switch op {
                case "M":
                    let p = readPoint(relative: relative)
                    path.move(to: p); current = p; subpathStart = p
                    op = "L"  // additional coordinate pairs after M are implicit lineto
                    lastCubic = nil; lastQuad = nil
                case "L":
                    let p = readPoint(relative: relative)
                    path.addLine(to: p); current = p
                    lastCubic = nil; lastQuad = nil
                case "H":
                    let x = readNumber()
                    current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                    path.addLine(to: current); lastCubic = nil; lastQuad = nil
                case "V":
                    let y = readNumber()
                    current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                    path.addLine(to: current); lastCubic = nil; lastQuad = nil
                case "C":
                    let c1 = readPoint(relative: relative)
                    let c2 = readPoint(relative: relative)
                    let end = readPoint(relative: relative)
                    path.addCurve(to: end, control1: c1, control2: c2)
                    current = end; lastCubic = c2; lastQuad = nil
                case "S":
                    let c1 = reflect(lastCubic)
                    let c2 = readPoint(relative: relative)
                    let end = readPoint(relative: relative)
                    path.addCurve(to: end, control1: c1, control2: c2)
                    current = end; lastCubic = c2; lastQuad = nil
                case "Q":
                    let cq = readPoint(relative: relative)
                    let end = readPoint(relative: relative)
                    path.addQuadCurve(to: end, control: cq)
                    current = end; lastQuad = cq; lastCubic = nil
                case "T":
                    let cq = reflect(lastQuad)
                    let end = readPoint(relative: relative)
                    path.addQuadCurve(to: end, control: cq)
                    current = end; lastQuad = cq; lastCubic = nil
                case "A":
                    let rx = readNumber(); let ry = readNumber(); _ = readNumber()  // x-axis rotation (~0 in our icons)
                    let large = readFlag(); let sweep = readFlag()
                    let end = readPoint(relative: relative)
                    addArc(&path, from: current, to: end, radius: max(rx, ry), large: large, sweep: sweep)
                    current = end; lastCubic = nil; lastQuad = nil
                case "Z":
                    path.closeSubpath(); current = subpathStart
                    lastCubic = nil; lastQuad = nil
                default:
                    return path  // unsupported command — stop safely
                }
            } while op != "Z" && moreParams()
        }
        return path
    }

    /// Append a circular arc (rx == ry for our icons) as a polyline using the SVG endpoint→center
    /// parameterization. `from` is the current point; `to` is the arc endpoint.
    private static func addArc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint, radius r: CGFloat, large: CGFloat, sweep: CGFloat) {
        if r <= 0 || (p0.x == p1.x && p0.y == p1.y) { path.addLine(to: p1); return }
        let x1p = (p0.x - p1.x) / 2
        let y1p = (p0.y - p1.y) / 2
        var radius = r
        let lambda = (x1p * x1p + y1p * y1p) / (radius * radius)
        if lambda > 1 { radius *= sqrt(lambda) }
        let sign: CGFloat = (large != sweep) ? 1 : -1
        let denom = x1p * x1p + y1p * y1p
        let numerator = max(0, radius * radius - denom)
        let coef = denom > 0 ? sign * sqrt(numerator / denom) : 0
        let cxp = coef * y1p
        let cyp = -coef * x1p
        let cx = cxp + (p0.x + p1.x) / 2
        let cy = cyp + (p0.y + p1.y) / 2
        let theta1 = atan2(y1p - cyp, x1p - cxp)
        let theta2 = atan2(-y1p - cyp, -x1p - cxp)
        var delta = theta2 - theta1
        if sweep == 0 && delta > 0 { delta -= 2 * .pi }
        if sweep == 1 && delta < 0 { delta += 2 * .pi }
        let steps = max(2, Int(abs(delta) / (.pi / 24)))
        for s in 1...steps {
            let t = theta1 + delta * CGFloat(s) / CGFloat(steps)
            path.addLine(to: CGPoint(x: cx + radius * cos(t), y: cy + radius * sin(t)))
        }
    }
}
