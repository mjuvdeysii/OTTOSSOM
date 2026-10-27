import UIKit

// MARK: 平面 — the companions drawn flat (the hidden 2D world)
//
// Moss and Otto are drawn from the same path data as the app's flat companions (摸索台灯 IP/Shapes.swift, build 196):
// flat colour, no outline, ink only for pupils, legs and expression lines, paper white only for the whites of the eyes.
// Mosto is drawn in the same language for the first time here. Every image is laid out on the 3D sprites' frame
// (Art.frame): the same size, the feet on the same pixel, so the game swaps one set for the other without moving
// anything.

enum FlatArt {
    struct Pal {
        static let ink = UIColor(hex: 0x1C1D19), paper = UIColor(hex: 0xFBF9F3)
        static let moss = UIColor(hex: 0x55704A), mossDeep = UIColor(hex: 0x3D5434)
        static let mint = UIColor(hex: 0x4FAE7F), mintLight = UIColor(hex: 0x7FCBA0), mintPale = UIColor(hex: 0xA9E0C0)
        static let rod = UIColor(hex: 0x2D4A8C), rodDeep = UIColor(hex: 0x1F3566)
        static let bead = UIColor(hex: 0xD4A21C), beadLight = UIColor(hex: 0xEDCB6A)
        static let pink = UIColor(hex: 0xF2A9B6)
        static let mosto = UIColor(hex: 0x633EBF), mostoDeep = UIColor(hex: 0x2B1961), mostoFeet = UIColor(hex: 0x221650)
        static let horn = UIColor(hex: 0xFFE4A8), crown = UIColor(hex: 0xE3B24A), iris = UIColor(hex: 0xD69A34), blush = UIColor(hex: 0xF2A9D2)
        static let glow = UIColor(hex: 0xFFC45A)
    }

    enum Face { case open, happy, shut, sleep, squint }

    static func image(_ name: String, size: CGFloat) -> UIImage {
        let r = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return r.image { c in
            let g = c.cgContext
            // the 100-unit drawing box: (50, 90) — between the feet — lands on Art.frame.feet
            let k = size / 512 * 3.57
            g.translateBy(x: size * Art.frame.feetX - 50 * k, y: size * Art.frame.feetY - 90 * k)
            g.scaleBy(x: k, y: k)
            let parts = name.split(separator: "_").map(String.init)
            switch parts.first {
            case "moss": drawMoss(g, state: parts.count > 1 ? parts[1] : "idle")
            case "otto": drawOtto(g, state: parts.count > 1 ? parts[1] : "idle", facing: parts.count > 2 ? parts[2] : "S")
            case "mosto": drawMosto(g, state: parts.count > 1 ? parts[1] : "idle")
            default: break
            }
        }
    }

    // MARK: shared pieces

    private static func fill(_ g: CGContext, _ p: CGPath, _ c: UIColor) { g.addPath(p); g.setFillColor(c.cgColor); g.fillPath() }
    private static func stroke(_ g: CGContext, _ p: CGPath, _ c: UIColor, _ w: CGFloat) {
        g.addPath(p); g.setStrokeColor(c.cgColor); g.setLineWidth(w); g.setLineCap(.round); g.setLineJoin(.round); g.strokePath()
    }
    private static func ellipse(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2), transform: nil)
    }
    private static func shadow(_ g: CGContext, _ rx: CGFloat) {
        g.saveGState()
        g.translateBy(x: 50, y: 90.5); g.scaleBy(x: 1, y: 0.2)
        let cs = CGColorSpaceCreateDeviceRGB()
        let grad = CGGradient(colorsSpace: cs, colors: [Pal.ink.withAlphaComponent(0.22).cgColor, Pal.ink.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
        g.drawRadialGradient(grad, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: rx * 1.1, options: [])
        g.restoreGState()
    }
    private static func leg(_ g: CGContext, _ x: CGFloat, _ c: UIColor = Pal.ink) {
        fill(g, CGPath(roundedRect: CGRect(x: x, y: 80, width: 6.5, height: 10), cornerWidth: 3.2, cornerHeight: 3.2, transform: nil), c)
    }
    /// The flat body with the app's matte volume: a soft light side, a shade side, the deeper underside, bounce light.
    private static func body(_ g: CGContext, _ p: CGPath, _ c: UIColor, under: CGPath, _ deep: UIColor) {
        let b = p.boundingBox
        let cs = CGColorSpaceCreateDeviceRGB()
        g.saveGState(); g.addPath(p); g.clip()
        let grad = CGGradient(colorsSpace: cs, colors: [c.mix(.white, 0.2).cgColor, c.cgColor, c.mix(deep, 0.45).cgColor] as CFArray, locations: [0, 0.45, 1])!
        g.drawLinearGradient(grad, start: CGPoint(x: b.minX + b.width * 0.15, y: b.minY), end: CGPoint(x: b.maxX, y: b.maxY), options: [])
        fill(g, under, deep.withAlphaComponent(0.5))
        let hl = CGGradient(colorsSpace: cs, colors: [UIColor.white.withAlphaComponent(0.16).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
        let hc = CGPoint(x: b.minX + b.width * 0.32, y: b.minY + b.height * 0.25)
        g.drawRadialGradient(hl, startCenter: hc, startRadius: 0, endCenter: hc, endRadius: b.width * 0.32, options: [])
        let warm = UIColor(hex: 0xFFE7B8)
        let bl = CGGradient(colorsSpace: cs, colors: [warm.withAlphaComponent(0).cgColor, warm.withAlphaComponent(0.14).cgColor] as CFArray, locations: [0, 1])!
        g.drawLinearGradient(bl, start: CGPoint(x: 0, y: b.maxY - b.height * 0.14), end: CGPoint(x: 0, y: b.maxY), options: [])
        g.restoreGState()
    }
    private static func eye(_ g: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, look: CGPoint, lid: CGFloat,
                            skin: UIColor, face: Face, iris: UIColor? = nil) {
        switch face {
        case .shut, .sleep, .happy:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: cx - rx * 0.9, y: cy))
            let cyc: CGFloat = face == .happy ? cy - ry * 0.9 : face == .sleep ? cy + ry * 0.9 : cy + ry * 0.25
            p.addQuadCurve(to: CGPoint(x: cx + rx * 0.9, y: cy), control: CGPoint(x: cx, y: cyc))
            stroke(g, p, Pal.ink, max(1.8, ry * 0.34))
            return
        case .squint:
            // screwed shut against the light: two short strokes meeting at the outer corner
            let p = CGMutablePath()
            p.move(to: CGPoint(x: cx - rx * 0.85, y: cy - ry * 0.35)); p.addLine(to: CGPoint(x: cx + rx * 0.7, y: cy))
            p.addLine(to: CGPoint(x: cx - rx * 0.85, y: cy + ry * 0.35))
            stroke(g, p, Pal.ink, max(1.8, ry * 0.3))
            return
        case .open: break
        }
        let r = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
        g.saveGState(); g.addEllipse(in: r); g.clip()
        fill(g, CGPath(rect: r, transform: nil), Pal.paper)
        let pr = min(rx, ry) * (iris == nil ? 0.62 : 0.72)
        let px = cx + max(-1, min(1, look.x)) * (rx - pr - 0.3), py = cy + max(-1, min(1, look.y)) * (ry - pr - 0.3)
        if let iris { fill(g, ellipse(px, py, pr, pr), iris) }
        let pp = iris == nil ? pr : pr * 0.62
        fill(g, ellipse(px, py, pp, pp), Pal.ink)
        fill(g, ellipse(px - pp * 0.35, py - pp * 0.4, pp * 0.22, pp * 0.22), UIColor.white.withAlphaComponent(0.9))
        if lid > 0 { fill(g, CGPath(rect: CGRect(x: cx - rx - 0.6, y: cy - ry - 0.6, width: rx * 2 + 1.2, height: (ry * 2 + 1.2) * lid), transform: nil), skin) }
        g.restoreGState()
        if lid > 0 { g.addEllipse(in: r.insetBy(dx: -0.4, dy: -0.4)); g.setStrokeColor(skin.cgColor); g.setLineWidth(1.2); g.strokePath() }
    }

    private static func look(_ s: String) -> CGPoint {
        switch s {
        case "left": return CGPoint(x: -0.95, y: 0.1)
        case "right": return CGPoint(x: 0.95, y: 0.1)
        case "up": return CGPoint(x: 0.05, y: -0.9)
        case "down": return CGPoint(x: 0, y: 0.8)
        default: return CGPoint(x: 0.1, y: 0.25)
        }
    }

    // MARK: Moss

    private static func drawMoss(_ g: CGContext, state: String) {
        let face: Face = (["blink": .shut, "glee": .happy, "sleep": .sleep] as [String: Face])[state] ?? .open
        let lid: CGFloat = state == "down" ? 0.15 : 0
        g.saveGState()
        if state == "left" || state == "right" { g.translateBy(x: 50, y: 88); g.rotate(by: (state == "left" ? -8 : 8) * .pi / 180); g.translateBy(x: -50, y: -88) }
        if state == "hop" { g.translateBy(x: 0, y: -6) }
        shadow(g, 31)
        stroke(g, FlatShapes.mossStem, Pal.mossDeep, 2.2)
        g.saveGState()
        let perk: CGFloat = state == "sleep" ? 6 : state == "hop" || state == "wide" || state == "up" ? -10 : 0
        g.translateBy(x: 49.6, y: 25); g.rotate(by: perk * .pi / 180); g.translateBy(x: -49.6, y: -25)
        fill(g, FlatShapes.mintB, Pal.mintLight); fill(g, FlatShapes.mintA, Pal.mint)
        fill(g, FlatShapes.mintD, Pal.mintPale); fill(g, FlatShapes.mintC, Pal.mintPale)
        g.restoreGState()
        leg(g, 33); leg(g, 59)
        body(g, FlatShapes.mossBody, Pal.moss, under: FlatShapes.mossUnder, Pal.mossDeep)
        if face == .happy || state == "wide" {
            fill(g, ellipse(35, 64, 4, 2.4), Pal.pink.withAlphaComponent(0.75)); fill(g, ellipse(66, 64, 4, 2.4), Pal.pink.withAlphaComponent(0.75))
        }
        let er: CGFloat = state == "wide" ? 1.12 : 1
        eye(g, 43, 55, 6.4 * er, 7.4 * er, look: look(state), lid: lid, skin: Pal.moss, face: face)
        eye(g, 58, 55, 6.4 * er, 7.4 * er, look: look(state), lid: lid, skin: Pal.moss, face: face)
        g.restoreGState()
    }

    // MARK: Otto

    private static func drawOtto(_ g: CGContext, state: String, facing: String) {
        let face: Face = (["blink": .shut, "yawn": .shut, "sleep": .sleep] as [String: Face])[state] ?? .open
        let lid: CGFloat = state == "wide" ? 0.2 : state == "glee" ? 0.45 : 0.42
        g.saveGState()
        // the flat Otto's rod reaches to the left; facing east he is mirrored
        if facing == "E" { g.translateBy(x: 100, y: 0); g.scaleBy(x: -1, y: 1) }
        shadow(g, 23)
        g.saveGState()
        let droop: CGFloat = state == "sleep" ? 10 : state == "yawn" ? 6 : facing == "N" ? -6 : 0
        g.translateBy(x: 50, y: 16.5); g.rotate(by: droop * .pi / 180); g.translateBy(x: -50, y: -16.5)
        stroke(g, FlatShapes.ottoRod, Pal.rodDeep, 2.4)
        fill(g, ellipse(20, 11.5, 5, 5), Pal.bead)
        fill(g, ellipse(18.6, 9.9, 1.6, 1.6), Pal.beadLight)
        g.restoreGState()
        leg(g, 38); leg(g, 56)
        body(g, FlatShapes.ottoBody, Pal.rod, under: FlatShapes.ottoDip, Pal.rodDeep)
        if facing != "N" {
            let lk: CGPoint = facing == "W" ? CGPoint(x: -0.8, y: 0.2) : facing == "E" ? CGPoint(x: -0.8, y: 0.2) : CGPoint(x: 0, y: 0.3)
            eye(g, 51, 44, 12.5, 11.5, look: lk, lid: lid, skin: Pal.rod, face: face)
            if state == "yawn" { fill(g, ellipse(51, 65, 3.2, 4.2), Pal.ink) }
            if state == "glee" {
                let p = CGMutablePath(); p.move(to: CGPoint(x: 47, y: 64)); p.addQuadCurve(to: CGPoint(x: 56, y: 61.5), control: CGPoint(x: 52, y: 66))
                stroke(g, p, Pal.ink, 1.8)
            }
        }
        g.restoreGState()
    }

    // MARK: Mosto

    private static func drawMosto(_ g: CGContext, state: String) {
        let face: Face = (["blink": .shut, "seen": .squint] as [String: Face])[state] ?? .open
        let evil = state != "seen" && state != "found" && state != "day"
        g.saveGState()
        if state == "left" || state == "right" { g.translateBy(x: 50, y: 88); g.rotate(by: (state == "left" ? -6 : 6) * .pi / 180); g.translateBy(x: -50, y: -88) }
        shadow(g, 30)
        // tail: from behind the right flank, up in an S, a cream spade at its tip (gold at night)
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: 78, y: 78)); tail.addCurve(to: CGPoint(x: 92, y: 50), control1: CGPoint(x: 92, y: 80), control2: CGPoint(x: 98, y: 64))
        stroke(g, tail, Pal.mosto.mix(.white, 0.12), 3.2)
        let spade = CGMutablePath()
        spade.move(to: CGPoint(x: 91, y: 40)); spade.addCurve(to: CGPoint(x: 86, y: 51), control1: CGPoint(x: 88, y: 44), control2: CGPoint(x: 83, y: 48))
        spade.addCurve(to: CGPoint(x: 92, y: 51), control1: CGPoint(x: 88, y: 54), control2: CGPoint(x: 91, y: 53))
        spade.addCurve(to: CGPoint(x: 97, y: 50), control1: CGPoint(x: 93, y: 53), control2: CGPoint(x: 97, y: 54))
        spade.addCurve(to: CGPoint(x: 91, y: 40), control1: CGPoint(x: 99, y: 47), control2: CGPoint(x: 94, y: 44))
        if evil { fill(g, ellipse(91.5, 47, 9, 9), Pal.glow.withAlphaComponent(0.28)) }
        fill(g, spade, evil ? Pal.glow : Pal.horn)
        // wings behind the shoulders: small scalloped bat wings
        for s in [-1.0, 1.0] as [CGFloat] {
            let w = CGMutablePath()
            let x0: CGFloat = 50 + s * 26
            w.move(to: CGPoint(x: x0, y: 50))
            w.addCurve(to: CGPoint(x: 50 + s * 47, y: 30), control1: CGPoint(x: 50 + s * 34, y: 40), control2: CGPoint(x: 50 + s * 42, y: 30))
            w.addQuadCurve(to: CGPoint(x: 50 + s * 42, y: 42), control: CGPoint(x: 50 + s * 47, y: 38))
            w.addQuadCurve(to: CGPoint(x: 50 + s * 36, y: 47), control: CGPoint(x: 50 + s * 41, y: 47))
            w.addQuadCurve(to: CGPoint(x: x0, y: 56), control: CGPoint(x: 50 + s * 34, y: 54))
            w.closeSubpath()
            fill(g, w, Pal.mostoDeep)
        }
        leg(g, 34, Pal.mostoFeet); leg(g, 59, Pal.mostoFeet)
        // body: a gumdrop, plumper at the bottom
        let b = CGMutablePath()
        b.move(to: CGPoint(x: 22, y: 84))
        b.addCurve(to: CGPoint(x: 17, y: 58), control1: CGPoint(x: 15, y: 78), control2: CGPoint(x: 14, y: 67))
        b.addCurve(to: CGPoint(x: 50, y: 30), control1: CGPoint(x: 21, y: 42), control2: CGPoint(x: 34, y: 30))
        b.addCurve(to: CGPoint(x: 83, y: 58), control1: CGPoint(x: 66, y: 30), control2: CGPoint(x: 79, y: 42))
        b.addCurve(to: CGPoint(x: 78, y: 84), control1: CGPoint(x: 86, y: 67), control2: CGPoint(x: 85, y: 78))
        b.addCurve(to: CGPoint(x: 22, y: 84), control1: CGPoint(x: 64, y: 89), control2: CGPoint(x: 36, y: 89))
        b.closeSubpath()
        let under = CGMutablePath()
        under.move(to: CGPoint(x: 14, y: 70)); under.addCurve(to: CGPoint(x: 86, y: 70), control1: CGPoint(x: 32, y: 78), control2: CGPoint(x: 68, y: 78))
        under.addLine(to: CGPoint(x: 86, y: 92)); under.addLine(to: CGPoint(x: 14, y: 92)); under.closeSubpath()
        body(g, b, Pal.mosto, under: under, Pal.mostoDeep)
        // horns: out, then up and in
        let droop: CGFloat = state == "seen" ? 5 : 0
        for s in [-1.0, 1.0] as [CGFloat] {
            let h = CGMutablePath()
            h.move(to: CGPoint(x: 50 + s * 18, y: 36))
            h.addCurve(to: CGPoint(x: 50 + s * 33, y: 12 + droop), control1: CGPoint(x: 50 + s * 31, y: 32), control2: CGPoint(x: 50 + s * 36, y: 22))
            h.addCurve(to: CGPoint(x: 50 + s * 25, y: 36), control1: CGPoint(x: 50 + s * 31, y: 22 + droop), control2: CGPoint(x: 50 + s * 28, y: 30))
            h.closeSubpath()
            fill(g, h, Pal.horn)
        }
        // the crown, worn at a rakish angle: three points
        g.saveGState()
        g.translateBy(x: 54, y: 29); g.rotate(by: (state == "seen" ? 22 : 12) * .pi / 180)
        let c = CGMutablePath()
        c.move(to: CGPoint(x: -9, y: 3)); c.addLine(to: CGPoint(x: -10, y: -7)); c.addLine(to: CGPoint(x: -4.5, y: -2))
        c.addLine(to: CGPoint(x: 0, y: -9)); c.addLine(to: CGPoint(x: 4.5, y: -2)); c.addLine(to: CGPoint(x: 10, y: -7))
        c.addLine(to: CGPoint(x: 9, y: 3)); c.closeSubpath()
        fill(g, c, Pal.crown)
        g.restoreGState()
        // blush, brows, eyes, the cat grin with one fang
        fill(g, ellipse(29, 66, 4.4, 2.6), Pal.blush.withAlphaComponent(0.8)); fill(g, ellipse(71, 66, 4.4, 2.6), Pal.blush.withAlphaComponent(0.8))
        if face == .open && state != "found" {
            for s in [-1.0, 1.0] as [CGFloat] {
                let br = CGMutablePath()
                br.move(to: CGPoint(x: 50 + s * 22, y: 42)); br.addLine(to: CGPoint(x: 50 + s * 8, y: 47.5))
                stroke(g, br, Pal.mostoDeep, 2.6)
            }
        }
        let lk = look(state == "found" ? "idle" : state)
        let lid: CGFloat = state == "found" ? 0 : evil ? 0.3 : 0.12
        eye(g, 40, 55, 7, 7.6, look: lk, lid: lid, skin: Pal.mosto, face: face, iris: Pal.iris)
        eye(g, 60, 55, 7, 7.6, look: lk, lid: lid + (evil ? 0.08 : 0), skin: Pal.mosto, face: face, iris: Pal.iris)
        let m = CGMutablePath()
        m.move(to: CGPoint(x: 43, y: 67)); m.addQuadCurve(to: CGPoint(x: 50, y: 68), control: CGPoint(x: 46.5, y: 71))
        m.addQuadCurve(to: CGPoint(x: 57, y: 67), control: CGPoint(x: 53.5, y: 71))
        stroke(g, m, Pal.ink, 1.7)
        let fang = CGMutablePath(); fang.move(to: CGPoint(x: 51.5, y: 68.6)); fang.addLine(to: CGPoint(x: 54.5, y: 68.4)); fang.addLine(to: CGPoint(x: 53, y: 72)); fang.closeSubpath()
        fill(g, fang, Pal.paper)
        g.restoreGState()
    }
}

/// The app's flat geometry in a 100 × 100 box (摸索台灯 IP/Shapes.swift).
enum FlatShapes {
    static let mossStem = SVG.path("M49 36 C48 30 49.2 23 50 17.6")
    static let mintA = SVG.path("M49.80 24.00 Q52.61 27.00 54.92 26.72 L59.05 26.80 Q59.05 25.74 59.20 25.58 L62.47 24.24 Q62.40 23.06 62.52 22.84 L65.12 20.40 Q65.11 19.32 65.21 19.07 L67.19 15.60 Q67.33 14.76 67.42 14.51 Q67.86 13.39 68.00 13.00 Q67.59 12.94 66.40 12.81 Q66.13 12.78 65.32 12.51 L61.33 12.65 Q61.06 12.62 60.11 12.11 L56.74 13.28 Q56.49 13.28 55.48 12.67 L52.77 14.94 Q52.56 15.00 51.62 14.51 L49.78 18.20 Q48.45 20.12 49.80 24.00Z")
    static let mintB = SVG.path("M48.80 26.00 Q49.48 22.34 48.07 20.84 L45.98 17.84 Q45.22 18.42 45.03 18.40 L42.38 16.79 Q41.57 17.49 41.36 17.53 L38.27 17.00 Q37.50 17.60 37.27 17.66 L33.77 18.16 Q33.10 18.52 32.87 18.59 Q31.85 18.89 31.50 19.00 Q31.67 19.32 32.20 20.25 Q32.32 20.46 32.55 21.19 L34.72 23.98 Q34.84 24.18 34.97 25.14 L37.56 26.91 Q37.69 27.09 37.78 28.15 L40.80 28.84 Q40.96 28.96 41.10 29.90 L44.69 29.20 Q46.74 29.10 48.80 26.00Z")
    static let mintC = SVG.path("M50.40 17.80 Q52.30 18.17 53.12 17.39 L55.35 14.61 Q55.06 13.89 55.07 13.67 L55.09 9.92 Q54.83 9.22 54.77 8.96 Q54.65 8.39 54.60 8.20 Q54.42 8.29 53.92 8.59 Q53.70 8.72 53.00 9.01 L50.27 11.57 Q50.11 11.72 49.38 12.00 L48.85 15.52 Q48.84 16.66 50.40 17.80Z")
    static let mintD = SVG.path("M49.60 18.00 Q50.87 16.72 50.70 15.69 L49.72 12.60 Q49.01 12.46 48.84 12.35 L45.98 10.48 Q45.30 10.33 45.07 10.24 Q44.57 10.06 44.40 10.00 Q44.38 10.18 44.35 10.72 Q44.33 10.95 44.20 11.63 L44.74 15.01 Q44.78 15.22 44.61 15.92 L47.05 18.07 Q47.92 18.64 49.60 18.00Z")
    static let mossBody = SVG.path("M22 82 C15 77 13 66 16 56 C19 45 28 36 41 34 C53 32 63 33 72 38 C82 44 88 55 87 67 C86 77 80 84 70 86 C56 88 33 89 22 82Z")
    static let mossUnder = SVG.path("M14 68 C30 76 70 76 88 66 C88 76 80 84 70 86 C56 88 33 89 22 82 C17 78 14 74 14 68Z")
    static let ottoRod = SVG.path("M50 16.5 C45 4 30 1 21 8 L20 11.5")
    static let ottoBody = SVG.path("M30 84 C25 74 24 58 26 44 C28 28 38 16 52 16 C65 17 74 28 75 44 C76 60 74 75 70 84 C60 88 40 88 30 84Z")
    static let ottoDip = SVG.path("M25.2 64 C35 68 64 68 75.4 63 C75 71 73 78 70 84 C60 88 40 88 30 84 C27.6 78 26 71 25.2 64Z")
}

/// A small reader for SVG path data (M L H V C Q Z, absolute and relative), as in the app.
enum SVG {
    static func path(_ d: String) -> CGPath {
        var tokens: [String] = []
        var cur = ""
        func flush() { if !cur.isEmpty { tokens.append(cur); cur = "" } }
        for ch in d {
            if ch.isLetter && ch != "e" { flush(); tokens.append(String(ch)) }
            else if ch == " " || ch == "," { flush() }
            else if ch == "-" { if let l = cur.last, l != "e" { flush() }; cur.append(ch) }
            else if ch == "." && cur.contains(".") { flush(); cur.append(ch) }
            else { cur.append(ch) }
        }
        flush()
        let p = CGMutablePath()
        var i = 0, cmd = "M"
        var pt = CGPoint.zero, start = CGPoint.zero
        func num() -> CGFloat { defer { i += 1 }; return i < tokens.count ? CGFloat(Double(tokens[i]) ?? 0) : 0 }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter {
                cmd = tokens[i]; i += 1
                if cmd == "Z" || cmd == "z" { p.closeSubpath(); pt = start; continue }
            }
            let rel = cmd == cmd.lowercased()
            func abs(_ x: CGFloat, _ y: CGFloat) -> CGPoint { rel ? CGPoint(x: pt.x + x, y: pt.y + y) : CGPoint(x: x, y: y) }
            switch cmd.uppercased() {
            case "M": pt = abs(num(), num()); start = pt; p.move(to: pt); cmd = rel ? "l" : "L"
            case "L": pt = abs(num(), num()); p.addLine(to: pt)
            case "H": let x = num(); pt = CGPoint(x: rel ? pt.x + x : x, y: pt.y); p.addLine(to: pt)
            case "V": let y = num(); pt = CGPoint(x: pt.x, y: rel ? pt.y + y : y); p.addLine(to: pt)
            case "C": let a = abs(num(), num()), b = abs(num(), num()), e = abs(num(), num()); p.addCurve(to: e, control1: a, control2: b); pt = e
            case "Q": let a = abs(num(), num()), e = abs(num(), num()); p.addQuadCurve(to: e, control: a); pt = e
            default: i += 1
            }
        }
        return p
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
    func mix(_ o: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0, r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1); o.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }
}
