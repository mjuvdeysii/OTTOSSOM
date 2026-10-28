import SwiftUI

/// Everything the board needs for one frame, copied out of the model.
struct BoardFrame {
    let room: Room
    let state: GameState
    let prev: GameState?
    let e: Double              // 0…1 progress of the last move's animation
    let t: Double              // seconds, for idle motion
    let active: Int
    let face: [Int]
    let actors: [String: Figure]
    let mainDim: Bool
    let dark: Double
    let hideHeroes: Bool
    let bulbR: Double
    let doudou: Bool
}

private extension Color {
    init(_ hex: UInt32, _ a: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: a)
    }
}

enum Pal {
    static let floorA = Color(0x1b2136), floorB = Color(0x1e2540), wall = Color(0x0b0e19), wallTop = Color(0x2a3152)
    static let water = Color(0x0c1530), gold = Color(0xf2c062), shadow = Color(0x05060c), shadowEye = Color(0xcfd6ff)
    static let ottoBlue = Color(0x2f5aa8), ottoLid = Color(0x244a92), mossGreen = Color(0x6f8f58), mint = Color(0x9fd2a8)
    static let mostoViolet = Color(0x7b4bb3), mostoWing = Color(0x4b2a73), cream = Color(0xefe3c8), night = Color(0x05060c)
}

/// Draws one frame of a room. T = tile size in points.
struct Painter {
    let f: BoardFrame
    let T: CGFloat

    func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * f.e }
    func pos(_ i: Int) -> CGPoint {
        let p = f.state.c[i]
        guard let q = f.prev, i < q.c.count else { return CGPoint(x: p.x, y: p.y) }
        return CGPoint(x: lerp(Double(q.c[i].x), Double(p.x)), y: lerp(Double(q.c[i].y), Double(p.y)))
    }
    func shadowPos(_ i: Int) -> CGPoint {
        let p = f.state.shadows[i]
        guard let q = f.prev, i < q.shadows.count else { return CGPoint(x: p.x, y: p.y) }
        return CGPoint(x: lerp(Double(q.shadows[i].x), Double(p.x)), y: lerp(Double(q.shadows[i].y), Double(p.y)))
    }
    func boulderPos(_ i: Int) -> CGPoint {
        let p = f.state.boulders[i]
        guard let q = f.prev, i < q.boulders.count else { return CGPoint(x: p.x, y: p.y) }
        return CGPoint(x: lerp(Double(q.boulders[i].x), Double(p.x)), y: lerp(Double(q.boulders[i].y), Double(p.y)))
    }

    func draw(_ ctx: inout GraphicsContext) {
        let r = f.room
        for y in 0..<r.h { for x in 0..<r.w { tile(&ctx, x, y) } }
        // y-sorted figures
        var items: [(Double, (inout GraphicsContext) -> Void)] = []
        for (i, p) in r.lampPos.enumerated() { items.append((Double(p.y), { c in self.lamp(&c, i) })) }
        for (p, ch) in r.npcs { items.append((Double(p.y), { c in self.npc(&c, p, ch) })) }
        for (p, _) in r.tablets.map({ ($0, 0) }) { items.append((Double(p.y), { c in self.tablet(&c, p) })) }
        for i in f.state.boulders.indices { let p = boulderPos(i); items.append((Double(p.y), { c in self.boulder(&c, p) })) }
        for i in f.state.shadows.indices {
            let p = shadowPos(i)
            let crowd = r.lampPos.contains { $0.dist(f.state.shadows[i]) == 1 }
            items.append((Double(p.y), { c in self.shadow(&c, p, i, crowd) }))
        }
        if !f.hideHeroes {
            for (i, h) in r.heroes.enumerated() {
                let p = pos(i)
                items.append((Double(p.y) + 0.01, { c in
                    if r.heroes.count > 1 && i == self.f.active { self.marker(&c, p) }
                    switch h {
                    case .otto: self.otto(&c, p, bulb: self.f.state.bulb, face: self.f.face[i])
                    case .moss: self.moss(&c, p, alpha: 1)
                    case .mosto: self.mosto(&c, p, alpha: 1, carry: self.f.state.carry)
                    }
                }))
            }
        }
        for (_, a) in f.actors {
            let p = CGPoint(x: a.x, y: a.y)
            items.append((a.y, { c in
                if a.kind == "moss" { self.moss(&c, p, alpha: a.alpha) } else { self.mosto(&c, p, alpha: a.alpha, carry: a.carry) }
            }))
        }
        for it in items.sorted(by: { $0.0 < $1.0 }) { it.1(&ctx) }
        darkness(&ctx)
        glow(&ctx)
    }

    // MARK: tiles
    func rect(_ x: Int, _ y: Int) -> CGRect { CGRect(x: CGFloat(x) * T, y: CGFloat(y) * T, width: T, height: T) }

    func tile(_ ctx: inout GraphicsContext, _ x: Int, _ y: Int) {
        let r = f.room, t = r.tile(Pt(x, y)), R = rect(x, y)
        switch t {
        case .wall:
            ctx.fill(Path(R), with: .color(Pal.wall))
            ctx.fill(Path(CGRect(x: R.minX, y: R.minY, width: T, height: T * 0.22)), with: .color(Pal.wallTop))
        case .water:
            ctx.fill(Path(R), with: .color(Pal.water))
            var p = Path()
            let o = CGFloat(sin(f.t * 1.1 + Double(x + y))) * T * 0.08
            p.move(to: CGPoint(x: R.minX + T * 0.15, y: R.minY + T * 0.45 + o))
            p.addQuadCurve(to: CGPoint(x: R.minX + T * 0.85, y: R.minY + T * 0.45 + o), control: CGPoint(x: R.midX, y: R.minY + T * 0.35 + o))
            ctx.stroke(p, with: .color(Color(0x78a0ff, 0.14)), lineWidth: 1)
        default:
            ctx.fill(Path(R), with: .color((x + y) % 2 == 0 ? Pal.floorB : Pal.floorA))
            let n = CGFloat(((x * 73856093) ^ (y * 19349663)) & 7)
            ctx.fill(Path(CGRect(x: R.minX + T * (0.15 + n * 0.06), y: R.minY + T * 0.22, width: T * 0.3, height: 1.5)), with: .color(.white.opacity(0.03)))
            if t == .plate {
                let pressed = f.state.boulders.contains(Pt(x, y)) || f.state.c.contains(Pt(x, y))
                let pr = R.insetBy(dx: T * 0.16, dy: T * 0.16)
                ctx.fill(Path(roundedRect: pr, cornerRadius: T * 0.08), with: .color(pressed ? Pal.gold.opacity(0.35) : Color(0x3a4266)))
                ctx.stroke(Path(roundedRect: pr, cornerRadius: T * 0.08), with: .color(pressed ? Pal.gold : Color(0x59628f)), lineWidth: 1.5)
            }
            if t == .door {
                let open = r.platesDown(f.state)
                if !open {
                    for k in 0..<4 {
                        let bx = R.minX + T * (0.14 + CGFloat(k) * 0.2)
                        ctx.fill(Path(CGRect(x: bx, y: R.minY + T * 0.08, width: T * 0.1, height: T * 0.84)), with: .color(Color(0x6b6f86)))
                    }
                } else {
                    ctx.stroke(Path(CGRect(x: R.minX + 2, y: R.minY + 2, width: T - 4, height: T - 4)), with: .color(Pal.gold.opacity(0.35)), lineWidth: 1)
                }
            }
            if t == .exit {
                let open = r.exitOpen(f.state)
                let ar = CGRect(x: R.minX + T * 0.18, y: R.minY + T * 0.12, width: T * 0.64, height: T * 0.76)
                ctx.fill(Path(roundedRect: ar, cornerRadius: T * 0.3), with: .color(open ? Pal.gold.opacity(0.22) : .white.opacity(0.05)))
                ctx.stroke(Path(roundedRect: ar, cornerRadius: T * 0.3), with: .color(open ? Pal.gold : Color(0x4a5174)), lineWidth: 2)
                for i in 0..<3 {
                    ctx.fill(Path(CGRect(x: R.minX + T * 0.3, y: R.minY + T * (0.5 + CGFloat(i) * 0.12), width: T * 0.4, height: 2)), with: .color(open ? Pal.gold.opacity(0.5) : .white.opacity(0.12)))
                }
            }
        }
    }

    func lamp(_ ctx: inout GraphicsContext, _ i: Int) {
        let p = f.room.lampPos[i], R = rect(p.x, p.y), lit = f.state.lit[i]
        if f.room.spec.sun == true && !f.room.nest[i] { sun(&ctx, R, lit: lit); return }
        if f.room.nest[i] {
            var bowl = Path()
            bowl.addArc(center: CGPoint(x: R.midX, y: R.minY + T * 0.5), radius: T * 0.32, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            bowl.closeSubpath()
            ctx.fill(bowl, with: .color(Color(0x5a4630)))
            for k in 0..<5 {
                var tw = Path()
                tw.move(to: CGPoint(x: R.minX + T * (0.2 + CGFloat(k) * 0.14), y: R.minY + T * 0.5))
                tw.addLine(to: CGPoint(x: R.minX + T * (0.28 + CGFloat(k) * 0.12), y: R.minY + T * 0.74))
                ctx.stroke(tw, with: .color(Color(0x8a6a44)), lineWidth: 1.4)
            }
            if lit { ctx.fill(Path(ellipseIn: CGRect(x: R.midX - T * 0.13, y: R.minY + T * 0.32, width: T * 0.26, height: T * 0.26)), with: .color(Color(0xffd77a))) }
            return
        }
        let main = f.room.spec.id == "top" || f.room.spec.id == "lamp"
        ctx.fill(Path(CGRect(x: R.minX + T * 0.45, y: R.minY + T * 0.38, width: T * 0.1, height: T * 0.5)), with: .color(Color(0x3a4060)))
        ctx.fill(Path(CGRect(x: R.minX + T * 0.32, y: R.minY + T * 0.84, width: T * 0.36, height: T * 0.08)), with: .color(Color(0x3a4060)))
        let head = CGRect(x: R.minX + T * 0.28, y: R.minY + T * 0.1, width: T * 0.44, height: T * 0.34)
        let g = main && f.mainDim ? 0.55 : 1.0
        ctx.fill(Path(roundedRect: head, cornerRadius: T * 0.1), with: .color(lit ? Pal.gold.opacity(0.35 + 0.65 * g) : Color(0x4b5170)))
        ctx.stroke(Path(roundedRect: head, cornerRadius: T * 0.1), with: .color(Color(0x1a1f33)), lineWidth: 1.5)
    }

    func sun(_ ctx: inout GraphicsContext, _ R: CGRect, lit: Bool) {
        let c = CGPoint(x: R.midX, y: R.midY), rad = T * 0.62
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - rad * 1.8, y: c.y - rad * 1.8, width: rad * 3.6, height: rad * 3.6)),
                 with: .radialGradient(Gradient(colors: [Pal.gold.opacity(lit ? 0.45 : 0.15), Pal.gold.opacity(0)]), center: c, startRadius: 0, endRadius: rad * 1.8))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)), with: .color(lit ? Color(0xf6c35c) : Color(0x8a6a34)))
        // the sun's tired eye and eye bags — like Otto's
        let er = rad * 0.38
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - er, y: c.y - er * 0.7, width: er * 2, height: er * 1.4)), with: .color(Color(0xfff4d8)))
        var lid = Path(); lid.addRect(CGRect(x: c.x - er * 1.05, y: c.y - er * 0.8, width: er * 2.1, height: er * (lit ? 0.85 : 1.5)))
        ctx.fill(lid, with: .color(lit ? Color(0xe0a840) : Color(0x7a5a2c)))
        var bag = Path(); bag.addArc(center: CGPoint(x: c.x, y: c.y + er * 0.6), radius: er * 0.8, startAngle: .degrees(30), endAngle: .degrees(150), clockwise: false)
        ctx.stroke(bag, with: .color(Color(0x9a6a20)), lineWidth: 1.5)
    }

    func tablet(_ ctx: inout GraphicsContext, _ p: Pt) {
        let R = rect(p.x, p.y)
        let s = CGRect(x: R.minX + T * 0.22, y: R.minY + T * 0.12, width: T * 0.56, height: T * 0.8)
        var path = Path()
        path.move(to: CGPoint(x: s.minX, y: s.maxY)); path.addLine(to: CGPoint(x: s.minX, y: s.minY + T * 0.18))
        path.addQuadCurve(to: CGPoint(x: s.maxX, y: s.minY + T * 0.18), control: CGPoint(x: s.midX, y: s.minY - T * 0.1))
        path.addLine(to: CGPoint(x: s.maxX, y: s.maxY)); path.closeSubpath()
        ctx.fill(path, with: .color(Color(0x5e6478)))
        for k in 0..<3 { ctx.fill(Path(CGRect(x: s.minX + T * 0.1, y: s.minY + T * (0.28 + CGFloat(k) * 0.14), width: T * 0.36, height: 1.5)), with: .color(Color(0x9da3b8))) }
    }

    func boulder(_ ctx: inout GraphicsContext, _ p: CGPoint) {
        let X = p.x * T + T / 2, Y = p.y * T + T * 0.56
        ctx.fill(Path(ellipseIn: CGRect(x: X - T * 0.34, y: Y + T * 0.18, width: T * 0.68, height: T * 0.14)), with: .color(.black.opacity(0.35)))
        var b = Path()
        b.move(to: CGPoint(x: X - T * 0.36, y: Y + T * 0.24))
        b.addCurve(to: CGPoint(x: X + T * 0.36, y: Y + T * 0.24), control1: CGPoint(x: X - T * 0.44, y: Y - T * 0.46), control2: CGPoint(x: X + T * 0.44, y: Y - T * 0.46))
        b.closeSubpath()
        ctx.fill(b, with: .color(Color(0x6c6a72)))
        ctx.fill(Path(ellipseIn: CGRect(x: X - T * 0.2, y: Y - T * 0.18, width: T * 0.16, height: T * 0.1)), with: .color(.white.opacity(0.12)))
    }

    func shadow(_ ctx: inout GraphicsContext, _ p: CGPoint, _ i: Int, _ crowd: Bool) {
        let X = p.x * T + T / 2, Y = p.y * T + T * 0.58, s = T * 0.36
        let sh = CGFloat(sin(f.t * 8 + Double(i) * 1.7)) * T * 0.025
        ctx.fill(Path(ellipseIn: CGRect(x: X - s * 0.9, y: Y + s * 0.5, width: s * 1.8, height: s * 0.5)), with: .color(.black.opacity(0.35)))
        var b = Path()
        b.move(to: CGPoint(x: X - s + sh, y: Y + s * 0.6))
        b.addCurve(to: CGPoint(x: X + s + sh, y: Y + s * 0.6), control1: CGPoint(x: X - s * 1.05 + sh, y: Y - s * 0.9), control2: CGPoint(x: X + s * 1.05 + sh, y: Y - s * 0.9))
        for k in 0..<4 {
            let xx = X + s - (CGFloat(k) + 0.5) * s * 0.5 + sh
            b.addQuadCurve(to: CGPoint(x: xx - s * 0.12, y: Y + s * 0.6), control: CGPoint(x: xx + s * 0.12, y: Y + s * (0.82 + CGFloat(k % 2) * 0.08)))
        }
        b.closeSubpath()
        ctx.fill(b, with: .color(Pal.shadow))
        ctx.stroke(b, with: .color(Color(0xa0afe6, 0.2)), lineWidth: 1)
        let blink = Int(f.t / 2.6 + Double(i)) % 5 == 0 && f.t.truncatingRemainder(dividingBy: 2.6) < 0.14
        if blink {
            ctx.fill(Path(CGRect(x: X - s * 0.38 + sh, y: Y - s * 0.1, width: s * 0.24, height: 1.5)), with: .color(Pal.shadowEye))
            ctx.fill(Path(CGRect(x: X + s * 0.14 + sh, y: Y - s * 0.1, width: s * 0.24, height: 1.5)), with: .color(Pal.shadowEye))
        } else {
            ctx.fill(Path(ellipseIn: CGRect(x: X - s * 0.36 + sh, y: Y - s * 0.24, width: s * 0.2, height: s * 0.28)), with: .color(Pal.shadowEye))
            ctx.fill(Path(ellipseIn: CGRect(x: X + s * 0.16 + sh, y: Y - s * 0.24, width: s * 0.2, height: s * 0.28)), with: .color(Pal.shadowEye))
        }
        if crowd {
            var m = Path()
            m.move(to: CGPoint(x: X - s * 0.5 + sh, y: Y - s * 0.55)); m.addLine(to: CGPoint(x: X - s * 0.3 + sh, y: Y - s * 0.7))
            m.move(to: CGPoint(x: X + s * 0.5 + sh, y: Y - s * 0.55)); m.addLine(to: CGPoint(x: X + s * 0.3 + sh, y: Y - s * 0.7))
            ctx.stroke(m, with: .color(Pal.shadowEye.opacity(0.4)), lineWidth: 1)
        }
    }

    func marker(_ ctx: inout GraphicsContext, _ p: CGPoint) {
        let X = p.x * T + T / 2, Y = p.y * T + T * 0.92
        ctx.stroke(Path(ellipseIn: CGRect(x: X - T * 0.36, y: Y - T * 0.09, width: T * 0.72, height: T * 0.18)), with: .color(Pal.gold.opacity(0.8)), lineWidth: 1.5)
    }

    // MARK: characters (per the character bible)
    /// Otto: deep-blue tall dome, one big eye with a heavy lid and eye bags, a thin stem curving forward to a gold
    /// bulb, short ink legs.
    func otto(_ ctx: inout GraphicsContext, _ p: CGPoint, bulb: Bool, face: Int) {
        let X = p.x * T + T / 2, B = p.y * T + T * 0.92, w = T * 0.62, h = T * 0.78
        let bob = CGFloat(sin(f.t * 2.4)) * T * 0.015
        ctx.fill(Path(ellipseIn: CGRect(x: X - w * 0.48, y: B - T * 0.07, width: w * 0.96, height: T * 0.14)), with: .color(.black.opacity(0.35)))
        var legs = Path()
        legs.move(to: CGPoint(x: X - w * 0.18, y: B - T * 0.12)); legs.addLine(to: CGPoint(x: X - w * 0.18, y: B))
        legs.move(to: CGPoint(x: X + w * 0.18, y: B - T * 0.12)); legs.addLine(to: CGPoint(x: X + w * 0.18, y: B))
        ctx.stroke(legs, with: .color(Color(0x0b0e19)), style: StrokeStyle(lineWidth: T * 0.06, lineCap: .round))
        let top = B - h + bob
        var body = Path()
        body.move(to: CGPoint(x: X - w / 2, y: B - T * 0.1))
        body.addLine(to: CGPoint(x: X - w / 2, y: top + w * 0.5))
        body.addArc(center: CGPoint(x: X, y: top + w * 0.5), radius: w / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        body.addLine(to: CGPoint(x: X + w / 2, y: B - T * 0.1))
        body.addQuadCurve(to: CGPoint(x: X - w / 2, y: B - T * 0.1), control: CGPoint(x: X, y: B - T * 0.02))
        ctx.fill(body, with: .color(Pal.ottoBlue))
        ctx.fill(Path(ellipseIn: CGRect(x: X - w * 0.3, y: top + w * 0.23, width: w * 0.16, height: w * 0.44)), with: .color(.white.opacity(0.08)))
        let lean = CGFloat(face) * T * 0.22, bx = X + lean, by = top - T * 0.2
        var stem = Path()
        stem.move(to: CGPoint(x: X, y: top + T * 0.02))
        stem.addQuadCurve(to: CGPoint(x: bx, y: by), control: CGPoint(x: X, y: top - T * 0.18))
        ctx.stroke(stem, with: .color(Color(0x22283f)), lineWidth: T * 0.035)
        if bulb {
            ctx.fill(Path(ellipseIn: CGRect(x: bx - T * 0.5, y: by - T * 0.5, width: T, height: T)),
                     with: .radialGradient(Gradient(colors: [Pal.gold.opacity(0.55), Pal.gold.opacity(0)]), center: CGPoint(x: bx, y: by), startRadius: 0, endRadius: T * 0.5))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: bx - T * 0.085, y: by - T * 0.085, width: T * 0.17, height: T * 0.17)), with: .color(bulb ? Color(0xffd77a) : Color(0x6b6040)))
        let ey = top + w * 0.62, er = w * 0.27
        ctx.fill(Path(ellipseIn: CGRect(x: X - er, y: ey - er * 0.86, width: er * 2, height: er * 1.72)), with: .color(Color(0xf4f1e8)))
        let look = CGFloat(face) * er * 0.18
        ctx.fill(Path(ellipseIn: CGRect(x: X + look - er * 0.42, y: ey + er * 0.12 - er * 0.42, width: er * 0.84, height: er * 0.84)), with: .color(Color(0x14182a)))
        ctx.fill(Path(ellipseIn: CGRect(x: X + look - er * 0.24, y: ey - er * 0.16, width: er * 0.2, height: er * 0.2)), with: .color(.white))
        let day = Double(f.room.spec.day)
        let blink = f.t.truncatingRemainder(dividingBy: 4.2) < 0.15
        let tired = blink ? 1.0 : min(0.62, 0.36 + day / 100 * 0.26)
        var lid = Path()
        lid.addArc(center: CGPoint(x: X, y: ey), radius: er * 1.02, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        lid.addLine(to: CGPoint(x: X + er * 1.02, y: ey - er * 0.9 + er * 1.8 * CGFloat(tired)))
        lid.addLine(to: CGPoint(x: X - er * 1.02, y: ey - er * 0.9 + er * 1.8 * CGFloat(tired)))
        lid.closeSubpath()
        ctx.fill(lid, with: .color(Pal.ottoLid))
        var bags = Path()
        bags.addArc(center: CGPoint(x: X, y: ey + er * 0.95), radius: er * 0.7, startAngle: .degrees(45), endAngle: .degrees(135), clockwise: false)
        bags.move(to: CGPoint(x: X + er * 0.55 * cos(.pi * 0.3), y: ey + er * 1.12 + er * 0.55 * sin(.pi * 0.3)))
        bags.addArc(center: CGPoint(x: X, y: ey + er * 1.12), radius: er * 0.55, startAngle: .degrees(54), endAngle: .degrees(126), clockwise: false)
        ctx.stroke(bags, with: .color(Color(0x1b3570)), lineWidth: 1.4)
    }

    /// Moss: flat moss-green stone, two oval eyes, a stem with two pairs of mint leaves, short legs, small round hands.
    func moss(_ ctx: inout GraphicsContext, _ p: CGPoint, alpha: Double) {
        var c = ctx; c.opacity = alpha
        let X = p.x * T + T / 2, B = p.y * T + T * 0.9, w = T * 0.62, h = T * 0.36
        let bob = CGFloat(abs(sin(f.t * 5.5))) * T * 0.03
        c.fill(Path(ellipseIn: CGRect(x: X - w * 0.45, y: B - T * 0.06, width: w * 0.9, height: T * 0.12)), with: .color(.black.opacity(0.35)))
        var legs = Path()
        legs.move(to: CGPoint(x: X - w * 0.18, y: B - T * 0.1)); legs.addLine(to: CGPoint(x: X - w * 0.18, y: B))
        legs.move(to: CGPoint(x: X + w * 0.18, y: B - T * 0.1)); legs.addLine(to: CGPoint(x: X + w * 0.18, y: B))
        c.stroke(legs, with: .color(Color(0x2a2f22)), style: StrokeStyle(lineWidth: T * 0.05, lineCap: .round))
        let cy = B - T * 0.1 - h / 2 - bob
        c.fill(Path(ellipseIn: CGRect(x: X - w / 2, y: cy - h / 2, width: w, height: h)), with: .color(Pal.mossGreen))
        c.fill(Path(ellipseIn: CGRect(x: X - w * 0.33, y: cy - h * 0.3, width: w * 0.36, height: h * 0.24)), with: .color(.white.opacity(0.08)))
        c.fill(Path(ellipseIn: CGRect(x: X - w * 0.57, y: cy + h * 0.1 - T * 0.05, width: T * 0.1, height: T * 0.1)), with: .color(Pal.mossGreen))
        c.fill(Path(ellipseIn: CGRect(x: X + w * 0.47, y: cy + h * 0.1 - T * 0.05, width: T * 0.1, height: T * 0.1)), with: .color(Pal.mossGreen))
        c.fill(Path(ellipseIn: CGRect(x: X - w * 0.15 - T * 0.045, y: cy - T * 0.07, width: T * 0.09, height: T * 0.14)), with: .color(Color(0x1d2318)))
        c.fill(Path(ellipseIn: CGRect(x: X + w * 0.15 - T * 0.045, y: cy - T * 0.07, width: T * 0.09, height: T * 0.14)), with: .color(Color(0x1d2318)))
        var stem = Path(); stem.move(to: CGPoint(x: X, y: cy - h / 2)); stem.addLine(to: CGPoint(x: X, y: cy - h / 2 - T * 0.2))
        c.stroke(stem, with: .color(Color(0x4c6a3e)), lineWidth: T * 0.03)
        for (s, k) in [(-1.0, 0.08), (1.0, 0.08), (-1.0, 0.17), (1.0, 0.17)] {
            let cx = X + CGFloat(s) * T * 0.07, ly = cy - h / 2 - T * CGFloat(k)
            var leaf = Path(ellipseIn: CGRect(x: -T * 0.07, y: -T * 0.035, width: T * 0.14, height: T * 0.07))
            leaf = leaf.applying(CGAffineTransform(rotationAngle: CGFloat(s) * 0.5)).applying(CGAffineTransform(translationX: cx, y: ly))
            c.fill(leaf, with: .color(Pal.mint))
        }
    }

    /// Mosto: violet gummy body, tilted gold crown, cream curled horns, bat wings, heart tail, inward brows, a fang.
    func mosto(_ ctx: inout GraphicsContext, _ p: CGPoint, alpha: Double, carry: Bool) {
        var c = ctx; c.opacity = alpha
        let X = p.x * T + T / 2, B = p.y * T + T * 0.88, r = T * 0.26
        let bob = CGFloat(sin(f.t * 6.2)) * T * 0.03, cy = B - r - bob
        c.fill(Path(ellipseIn: CGRect(x: X - r, y: B - T * 0.03, width: r * 2, height: T * 0.1)), with: .color(.black.opacity(0.3)))
        let flap = CGFloat(sin(f.t * 11)) * 0.35
        for s: CGFloat in [-1, 1] {
            var wing = Path()
            wing.move(to: CGPoint(x: X + s * r * 0.6, y: cy - r * 0.2))
            wing.addLine(to: CGPoint(x: X + s * r * 1.9, y: cy - r * (1 + flap)))
            wing.addLine(to: CGPoint(x: X + s * r * 1.6, y: cy - r * 0.2))
            wing.addLine(to: CGPoint(x: X + s * r * 1.9, y: cy + r * 0.3))
            wing.closeSubpath()
            c.fill(wing, with: .color(Pal.mostoWing))
        }
        var tail = Path()
        tail.move(to: CGPoint(x: X + r * 0.8, y: cy + r * 0.6))
        tail.addQuadCurve(to: CGPoint(x: X + r * 1.5, y: cy + r * 0.2), control: CGPoint(x: X + r * 1.6, y: cy + r * 0.9))
        c.stroke(tail, with: .color(Pal.mostoViolet), lineWidth: T * 0.035)
        c.fill(Path(ellipseIn: CGRect(x: X + r * 1.45 - T * 0.035, y: cy + r * 0.15 - T * 0.035, width: T * 0.07, height: T * 0.07)), with: .color(Color(0xcfe8ff)))
        c.fill(Path(ellipseIn: CGRect(x: X - r, y: cy - r * 0.95, width: r * 2, height: r * 1.9)), with: .color(Pal.mostoViolet))
        c.fill(Path(ellipseIn: CGRect(x: X - r * 0.57, y: cy - r * 0.49, width: r * 0.44, height: r * 0.28)), with: .color(.white.opacity(0.18)))
        var horns = Path()
        horns.addArc(center: CGPoint(x: X - r * 0.75, y: cy - r * 0.75), radius: r * 0.28, startAngle: .radians(.pi * 0.2), endAngle: .radians(.pi * 1.4), clockwise: false)
        horns.move(to: CGPoint(x: X + r * 0.75 + r * 0.28 * cos(-.pi * 0.4), y: cy - r * 0.75 + r * 0.28 * sin(-.pi * 0.4)))
        horns.addArc(center: CGPoint(x: X + r * 0.75, y: cy - r * 0.75), radius: r * 0.28, startAngle: .radians(-.pi * 0.4), endAngle: .radians(.pi * 0.8), clockwise: false)
        c.stroke(horns, with: .color(Pal.cream), lineWidth: T * 0.045)
        var crown = Path()
        crown.move(to: CGPoint(x: -r * 0.4, y: 0)); crown.addLine(to: CGPoint(x: -r * 0.4, y: -r * 0.35)); crown.addLine(to: CGPoint(x: -r * 0.2, y: -r * 0.15))
        crown.addLine(to: CGPoint(x: 0, y: -r * 0.42)); crown.addLine(to: CGPoint(x: r * 0.2, y: -r * 0.15)); crown.addLine(to: CGPoint(x: r * 0.4, y: -r * 0.35))
        crown.addLine(to: CGPoint(x: r * 0.4, y: 0)); crown.closeSubpath()
        crown = crown.applying(CGAffineTransform(rotationAngle: 0.3)).applying(CGAffineTransform(translationX: X + r * 0.15, y: cy - r * 0.95))
        c.fill(crown, with: .color(Pal.gold))
        var brows = Path()
        brows.move(to: CGPoint(x: X - r * 0.5, y: cy - r * 0.32)); brows.addLine(to: CGPoint(x: X - r * 0.18, y: cy - r * 0.2))
        brows.move(to: CGPoint(x: X + r * 0.5, y: cy - r * 0.32)); brows.addLine(to: CGPoint(x: X + r * 0.18, y: cy - r * 0.2))
        c.stroke(brows, with: .color(Color(0x2a1640)), lineWidth: 1.6)
        c.fill(Path(ellipseIn: CGRect(x: X - r * 0.3 - T * 0.035, y: cy - T * 0.035, width: T * 0.07, height: T * 0.07)), with: .color(Color(0x160b26)))
        c.fill(Path(ellipseIn: CGRect(x: X + r * 0.3 - T * 0.035, y: cy - T * 0.035, width: T * 0.07, height: T * 0.07)), with: .color(Color(0x160b26)))
        var fang = Path()
        fang.move(to: CGPoint(x: X + r * 0.05, y: cy + r * 0.35)); fang.addLine(to: CGPoint(x: X + r * 0.15, y: cy + r * 0.55)); fang.addLine(to: CGPoint(x: X + r * 0.25, y: cy + r * 0.35)); fang.closeSubpath()
        c.fill(fang, with: .color(.white))
        if carry {
            let g = CGPoint(x: X, y: cy + r * 0.5)
            c.fill(Path(ellipseIn: CGRect(x: g.x - T * 0.4, y: g.y - T * 0.4, width: T * 0.8, height: T * 0.8)),
                   with: .radialGradient(Gradient(colors: [Pal.gold.opacity(0.9), Pal.gold.opacity(0)]), center: g, startRadius: 0, endRadius: T * 0.4))
        }
    }

    func npc(_ ctx: inout GraphicsContext, _ p: Pt, _ ch: Character) {
        let X = CGFloat(p.x) * T + T / 2, B = CGFloat(p.y) * T + T * 0.92
        if ch == "o" { fallenOtto(&ctx, p); return }
        if ch == "m" { moss(&ctx, CGPoint(x: p.x, y: p.y), alpha: 1); return }
        let spec: (CGFloat, Color, Color) = ch == "h" ? (0.82, Color(0x6b4f3a), Color(0xd8b894)) : ch == "d" ? (0.56, Color(0xa8443a), Color(0xe2c4a0)) : (0.7, Color(0x4f6b5c), Color(0xd4b08c))
        ctx.fill(Path(ellipseIn: CGRect(x: X - T * 0.22, y: B - T * 0.06, width: T * 0.44, height: T * 0.12)), with: .color(.black.opacity(0.35)))
        let top = B - T * spec.0
        var body = Path()
        body.move(to: CGPoint(x: X - T * 0.2, y: B)); body.addLine(to: CGPoint(x: X - T * 0.14, y: top + T * 0.2))
        body.addLine(to: CGPoint(x: X + T * 0.14, y: top + T * 0.2)); body.addLine(to: CGPoint(x: X + T * 0.2, y: B)); body.closeSubpath()
        ctx.fill(body, with: .color(spec.1))
        ctx.fill(Path(ellipseIn: CGRect(x: X - T * 0.11, y: top - T * 0.01, width: T * 0.22, height: T * 0.22)), with: .color(spec.2))
        if ch == "n" {
            var scarf = Path(); scarf.addArc(center: CGPoint(x: X, y: top + T * 0.07), radius: T * 0.12, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            ctx.fill(scarf, with: .color(Color(0x3b5245)))
            ctx.fill(Path(CGRect(x: X + T * 0.16, y: B - T * 0.26, width: T * 0.14, height: T * 0.18)), with: .color(Color(0x2c2f45)))
        }
        if ch == "h" { ctx.fill(Path(ellipseIn: CGRect(x: X + T * 0.08, y: top + T * 0.41, width: T * 0.08, height: T * 0.08)), with: .color(Color(0xd9c27a))) }
        if ch == "d" {
            let lx = X + T * 0.24, ly = top + T * 0.32
            if f.doudou {
                ctx.fill(Path(ellipseIn: CGRect(x: lx - T * 0.35, y: ly - T * 0.35, width: T * 0.7, height: T * 0.7)),
                         with: .radialGradient(Gradient(colors: [Color(0xffbe78, 0.6), Color(0xffbe78, 0)]), center: CGPoint(x: lx, y: ly), startRadius: 0, endRadius: T * 0.35))
            }
            ctx.fill(Path(roundedRect: CGRect(x: lx - T * 0.07, y: ly - T * 0.08, width: T * 0.14, height: T * 0.16), cornerRadius: T * 0.05), with: .color(f.doudou ? Color(0xffcf8a) : Color(0xc9b9a0)))
        }
    }

    func fallenOtto(_ ctx: inout GraphicsContext, _ p: Pt) {
        let X = CGFloat(p.x) * T + T / 2, Y = CGFloat(p.y) * T + T * 0.7
        var body = Path()
        body.addRoundedRect(in: CGRect(x: X - T * 0.42, y: Y - T * 0.2, width: T * 0.84, height: T * 0.34), cornerSize: CGSize(width: T * 0.17, height: T * 0.17))
        ctx.fill(body, with: .color(Pal.ottoBlue))
        ctx.fill(Path(ellipseIn: CGRect(x: X - T * 0.05, y: Y - T * 0.12, width: T * 0.2, height: T * 0.05)), with: .color(Pal.ottoLid))
        ctx.fill(Path(ellipseIn: CGRect(x: X + T * 0.42, y: Y - T * 0.06, width: T * 0.13, height: T * 0.13)), with: .color(Color(0x6b6040)))
    }

    // MARK: light
    func lightMap() -> [[Double]] {
        let r = f.room
        var M = Array(repeating: Array(repeating: 0.0, count: r.w), count: r.h)
        func add(_ p: CGPoint, _ rad: Double, _ k: Double) {
            guard rad >= 0 else { return }
            for y in 0..<r.h { for x in 0..<r.w {
                let px = Double(p.x).rounded(), py = Double(p.y).rounded()
                let d: Double = abs(Double(x) - px) + abs(Double(y) - py)
                if d <= rad { M[y][x] = max(M[y][x], k * (1 - d / (rad + 1.2))) }
            } }
        }
        let main = r.spec.id == "top" || r.spec.id == "lamp"
        for (i, p) in r.lampPos.enumerated() where f.state.lit[i] {
            let rad = r.spec.sun == true ? 3.0 : Double(main ? 2 : r.rLamp)
            add(CGPoint(x: p.x, y: p.y), rad, main && f.mainDim ? 0.6 : 1)
        }
        if let oi = r.index(of: .otto), f.state.bulb, !f.hideHeroes { add(pos(oi), f.bulbR.rounded(), 1) }
        if let xi = r.index(of: .mosto), f.state.carry, !f.hideHeroes { add(pos(xi), Double(r.rCarry), 0.9) }
        for (_, a) in f.actors where a.carry { add(CGPoint(x: a.x, y: a.y), 1, 0.8) }
        return M
    }

    func darkness(_ ctx: inout GraphicsContext) {
        let r = f.room, M = lightMap(), base = 0.5 + f.dark * 0.4
        for y in 0..<r.h { for x in 0..<r.w {
            let a = max(0, base * (1 - M[y][x] * 1.05))
            if a > 0.01 { ctx.fill(Path(rect(x, y)), with: .color(Color(0x03040a, a))) }
        } }
        // the bulb's reach, outlined — it's exactly where shadows get pulled from
        if let oi = r.index(of: .otto), f.state.bulb, !f.hideHeroes, f.bulbR > 0 {
            let o = f.state.c[oi], rad = Int(f.bulbR.rounded())
            var p = Path()
            for y in 0..<r.h { for x in 0..<r.w where abs(x - o.x) + abs(y - o.y) == rad { p.addRect(rect(x, y).insetBy(dx: 3, dy: 3)) } }
            ctx.stroke(p, with: .color(Pal.gold.opacity(0.28)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        }
    }

    func glow(_ ctx: inout GraphicsContext) {
        var c = ctx
        c.blendMode = .plusLighter
        let main = f.room.spec.id == "top" || f.room.spec.id == "lamp"
        for (i, p) in f.room.lampPos.enumerated() where f.state.lit[i] {
            let X = CGFloat(p.x) * T + T / 2, Y = CGFloat(p.y) * T + T * 0.27, R = T * 1.4
            let k = 0.28 * (main && f.mainDim ? 0.5 : 1)
            c.fill(Path(ellipseIn: CGRect(x: X - R, y: Y - R, width: R * 2, height: R * 2)),
                   with: .radialGradient(Gradient(colors: [Pal.gold.opacity(k), Pal.gold.opacity(0)]), center: CGPoint(x: X, y: Y), startRadius: 0, endRadius: R))
        }
    }
}
