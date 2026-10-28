import SwiftUI

/// The world around a room, so the game fills the whole screen without stretching the board:
/// sky and stars, a skyline or ruins on the horizon, ground that continues past the room's walls,
/// and a foreground per chapter (harbour, grass, mist, dunes). Tiles keep their size; only the world grows.
extension Painter {
    var chapterIndex: Int { max(1, min(4, Theme.chapterOf[f.room.spec.id] ?? 1)) }
    var boardRect: CGRect { CGRect(x: 0, y: 0, width: CGFloat(f.room.w) * T, height: CGFloat(f.room.h) * T) }
    /// Where the horizon sits: just above the room, so the skyline rises behind its top wall.
    var horizon: CGFloat { boardRect.minY - T * 0.15 }

    private func h(_ i: Int, _ k: Int) -> CGFloat { CGFloat(noiseHash(i, k, chapterIndex)) }

    // MARK: back

    func sceneryBack(_ ctx: inout GraphicsContext, rings withRings: Bool = true) {
        guard let E = f.extent else { return }
        let ch = chapterIndex, B = boardRect, th = Theme.of(f.room.spec.id)
        let skies: [[UInt32]] = [[0x070b1c, 0x141c3a, 0x1d2850], [0x060b09, 0x111d17, 0x1b2c22], [0x08050f, 0x150f26, 0x251a3e], [0x0b0706, 0x2a1a12, 0x4a2a17]]
        let sky = skies[ch - 1].map { Color($0) }
        ctx.fill(Path(E), with: .linearGradient(Gradient(colors: sky), startPoint: CGPoint(x: E.midX, y: E.minY), endPoint: CGPoint(x: E.midX, y: horizon + T)))

        switch ch {
        case 1: town(&ctx, E)
        case 2: ruins(&ctx, E)
        case 3: spires(&ctx, E)
        default: mesas(&ctx, E)
        }

        // ground from the horizon down, in the chapter's wall colour
        let g = CGRect(x: E.minX, y: horizon, width: E.width, height: E.maxY - horizon)
        ctx.fill(Path(g), with: .linearGradient(Gradient(colors: [th.wall, th.seam, Color(0x020306)]), startPoint: CGPoint(x: E.midX, y: g.minY), endPoint: CGPoint(x: E.midX, y: g.maxY)))

        switch ch {
        case 1: harbour(&ctx, E, B)
        case 2: meadow(&ctx, E, B)
        case 3: pools(&ctx, E, B)
        default: dunes(&ctx, E, B)
        }
        if withRings { rings(&ctx, E) }
    }

    /// The room's edge carries on for a few tiles and crumbles away, so the room sits in the world instead of floating.
    func rings(_ ctx: inout GraphicsContext, _ E: CGRect) {
        let r = f.room
        let fade: [Double] = [0.85, 0.5, 0.22]
        for y in -3..<(r.h + 3) {
            for x in -3..<(r.w + 3) {
                let dx = x < 0 ? -x : (x >= r.w ? x - r.w + 1 : 0)
                let dy = y < 0 ? -y : (y >= r.h ? y - r.h + 1 : 0)
                let d = max(dx, dy)
                guard d >= 1, d <= 3 else { continue }
                // above the room only one broken course, so the horizon shows; at the sides and below, up to three
                if y < 0 && d > 1 { continue }
                let keep: [Double] = [1, 0.72, 0.38]
                if noiseHash(x, y, 9) > (y < 0 ? 0.55 : keep[d - 1]) { continue }
                let R = rect(x, y)
                guard E.intersects(R) else { continue }
                let edge = r.tile(Pt(min(max(x, 0), r.w - 1), min(max(y, 0), r.h - 1)))
                let kind: Tile = edge == .wall ? .wall : edge == .water ? .water : .floor
                var g = ctx
                g.opacity = fade[d - 1]
                tile(&g, x, y, as: kind)
            }
        }
    }

    // MARK: horizons

    /// Chapter 1: the lighthouse town. Two rows of roofs and the old lighthouse on the right.
    func townBlocks(_ E: CGRect, near: Bool) -> [CGRect] {
        var out: [CGRect] = []
        var x = E.minX - T * 0.5, i = near ? 100 : 0
        let base = horizon + T * 0.2
        while x < E.maxX {
            let w = T * (near ? 0.9 + 0.8 * h(i, 1) : 0.7 + 0.6 * h(i, 1))
            let ht = T * (near ? 0.9 + 1.6 * h(i, 2) : 1.6 + 2.2 * h(i, 2))
            out.append(CGRect(x: x, y: base - ht, width: w, height: ht))
            x += w + T * (near ? 0.04 : 0.1)
            i += 1
        }
        return out
    }

    func town(_ ctx: inout GraphicsContext, _ E: CGRect) {
        // lighthouse first, behind everything
        let lx = E.minX + E.width * 0.8, base = horizon + T * 0.2, top = base - T * 5.2
        var tower = Path()
        tower.move(to: CGPoint(x: lx - T * 0.55, y: base))
        tower.addLine(to: CGPoint(x: lx - T * 0.3, y: top + T * 0.7))
        tower.addLine(to: CGPoint(x: lx + T * 0.3, y: top + T * 0.7))
        tower.addLine(to: CGPoint(x: lx + T * 0.55, y: base))
        tower.closeSubpath()
        ctx.fill(tower, with: .color(Color(0x1a2240)))
        for k in 0..<3 {   // bands
            let yy = top + T * (1.4 + CGFloat(k) * 1.2)
            ctx.fill(Path(CGRect(x: lx - T * 0.45, y: yy, width: T * 0.9, height: T * 0.18)), with: .color(Color(0x232c52)))
        }
        ctx.fill(Path(CGRect(x: lx - T * 0.38, y: top + T * 0.25, width: T * 0.76, height: T * 0.45)), with: .color(Color(0x2a3358)))
        var cap = Path()
        cap.move(to: CGPoint(x: lx - T * 0.42, y: top + T * 0.25))
        cap.addLine(to: CGPoint(x: lx, y: top - T * 0.1))
        cap.addLine(to: CGPoint(x: lx + T * 0.42, y: top + T * 0.25))
        cap.closeSubpath()
        ctx.fill(cap, with: .color(Color(0x141a33)))

        for (k, b) in townBlocks(E, near: false).enumerated() { roof(&ctx, b, k, Color(0x121935)) }
        for (k, b) in townBlocks(E, near: true).enumerated() { roof(&ctx, b, k + 50, Color(0x0b1026)) }
    }

    private func roof(_ ctx: inout GraphicsContext, _ b: CGRect, _ k: Int, _ c: Color) {
        ctx.fill(Path(b), with: .color(c))
        if h(k, 3) > 0.45 {
            var p = Path()
            p.move(to: CGPoint(x: b.minX - T * 0.06, y: b.minY))
            p.addLine(to: CGPoint(x: b.midX, y: b.minY - T * (0.3 + 0.3 * h(k, 4))))
            p.addLine(to: CGPoint(x: b.maxX + T * 0.06, y: b.minY))
            p.closeSubpath()
            ctx.fill(p, with: .color(c))
        } else if h(k, 5) > 0.4 {
            ctx.fill(Path(CGRect(x: b.minX + b.width * 0.65, y: b.minY - T * 0.32, width: T * 0.14, height: T * 0.34)), with: .color(c))
        }
    }

    /// Chapter 2: ruins in the green dark. Broken columns, one arch, mounds of moss.
    func ruins(_ ctx: inout GraphicsContext, _ E: CGRect) {
        let base = horizon + T * 0.2
        var x = E.minX - T * 0.4, i = 0
        while x < E.maxX {
            let r = T * (1.2 + 1.4 * h(i, 1))
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: base - r * 0.55, width: r * 2.2, height: r * 1.1)), with: .color(Color(0x0f1a14)))
            x += r * 1.6; i += 1
        }
        x = E.minX + T * 0.3; i = 0
        while x < E.maxX {
            let ht = T * (1.4 + 2.4 * h(i, 2)), w = T * 0.34
            var col = Path()
            col.addRect(CGRect(x: x, y: base - ht, width: w, height: ht))
            ctx.fill(col, with: .color(Color(0x15211a)))
            // broken top
            var brk = Path()
            brk.move(to: CGPoint(x: x, y: base - ht))
            brk.addLine(to: CGPoint(x: x + w * 0.4, y: base - ht - T * 0.22 * h(i, 3)))
            brk.addLine(to: CGPoint(x: x + w, y: base - ht + T * 0.08))
            brk.closeSubpath()
            ctx.fill(brk, with: .color(Color(0x15211a)))
            ctx.fill(Path(CGRect(x: x - T * 0.06, y: base - T * 0.18, width: w + T * 0.12, height: T * 0.18)), with: .color(Color(0x1a2a21)))
            if h(i, 4) > 0.55 {   // a lintel to the next column: the arch
                ctx.fill(Path(CGRect(x: x, y: base - ht + T * 0.1, width: T * 1.6, height: T * 0.22)), with: .color(Color(0x15211a)))
            }
            // vine
            var v = Path()
            v.move(to: CGPoint(x: x + w * 0.5, y: base - ht))
            let sway = CGFloat(sin(f.t * 0.6 + Double(i))) * T * 0.05
            v.addQuadCurve(to: CGPoint(x: x + w * 0.5 + sway, y: base - ht + T * (0.6 + 0.8 * h(i, 5))), control: CGPoint(x: x + w * 0.9 + sway, y: base - ht + T * 0.4))
            ctx.stroke(v, with: .color(Color(0x2c4a35)), lineWidth: 1.5)
            x += T * (1.6 + 1.4 * h(i, 6)); i += 1
        }
    }

    /// Chapter 3: the shadow country. Thin spires and the hive's high rim.
    func spires(_ ctx: inout GraphicsContext, _ E: CGRect) {
        let base = horizon + T * 0.2
        for layer in 0..<2 {
            var x = E.minX - T * 0.5, i = layer * 40
            let c = layer == 0 ? Color(0x1a1230) : Color(0x0f0a1d)
            while x < E.maxX {
                let ht = T * (layer == 0 ? 2.2 + 2.6 * h(i, 1) : 1 + 1.6 * h(i, 1)), w = T * (0.5 + 0.5 * h(i, 2))
                var p = Path()
                p.move(to: CGPoint(x: x, y: base))
                p.addLine(to: CGPoint(x: x + w * 0.42, y: base - ht))
                p.addLine(to: CGPoint(x: x + w * 0.5, y: base - ht - T * 0.25))
                p.addLine(to: CGPoint(x: x + w * 0.58, y: base - ht))
                p.addLine(to: CGPoint(x: x + w, y: base))
                p.closeSubpath()
                ctx.fill(p, with: .color(c))
                x += w * (layer == 0 ? 1.3 : 0.9) + T * 0.2 * h(i, 3); i += 1
            }
        }
        // floating stones
        for k in 0..<4 {
            let fx = E.minX + E.width * (0.1 + 0.25 * CGFloat(k)) + T * 0.3 * h(k, 7)
            let fy = horizon - T * (2.6 + 1.4 * h(k, 8)) + CGFloat(sin(f.t * 0.4 + Double(k))) * T * 0.08
            guard fy > E.minY else { continue }
            var p = Path()
            p.move(to: CGPoint(x: fx - T * 0.35, y: fy))
            p.addLine(to: CGPoint(x: fx + T * 0.35, y: fy))
            p.addLine(to: CGPoint(x: fx, y: fy + T * 0.45))
            p.closeSubpath()
            ctx.fill(p, with: .color(Color(0x1d1535)))
        }
    }

    /// Chapter 4: the road to the sun. Flat-topped mesas against a warm horizon.
    func mesas(_ ctx: inout GraphicsContext, _ E: CGRect) {
        let base = horizon + T * 0.2
        // the sun's nest: a low warm dome at the far end of the road
        let nest = CGPoint(x: E.midX, y: base)
        ctx.fill(Path(ellipseIn: CGRect(x: nest.x - T * 2.4, y: nest.y - T * 1.1, width: T * 4.8, height: T * 2.2)), with: .color(Color(0x2a1810)))
        for layer in 0..<2 {
            var x = E.minX - T, i = layer * 30
            let c = layer == 0 ? Color(0x26170f) : Color(0x180e09)
            while x < E.maxX {
                let w = T * (1.4 + 2.2 * h(i, 1)), ht = T * (layer == 0 ? 0.9 + 1.5 * h(i, 2) : 0.4 + 0.8 * h(i, 2))
                if abs(x + w / 2 - E.midX) < T * 2.2 && layer == 0 { x += w * 0.6; i += 1; continue }   // keep the nest clear
                var p = Path()
                p.move(to: CGPoint(x: x, y: base))
                p.addLine(to: CGPoint(x: x + w * 0.18, y: base - ht))
                p.addLine(to: CGPoint(x: x + w * 0.82, y: base - ht))
                p.addLine(to: CGPoint(x: x + w, y: base))
                p.closeSubpath()
                ctx.fill(p, with: .color(c))
                x += w * (0.8 + 0.5 * h(i, 3)); i += 1
            }
        }
    }

    // MARK: foregrounds (below and beside the room)

    func harbour(_ ctx: inout GraphicsContext, _ E: CGRect, _ B: CGRect) {
        let top = B.maxY + T * 1.2
        guard top < E.maxY else { return }
        let W = CGRect(x: E.minX, y: top, width: E.width, height: E.maxY - top)
        ctx.fill(Path(W), with: .linearGradient(Gradient(colors: [Color(0x0c1633), Color(0x050a1a)]), startPoint: CGPoint(x: W.midX, y: W.minY), endPoint: CGPoint(x: W.midX, y: W.maxY)))
        ctx.fill(Path(CGRect(x: W.minX, y: W.minY, width: W.width, height: 2)), with: .color(Color(0x9fb8ff, 0.12)))
        // quay edge and posts
        var x = E.minX + T * 0.4, i = 0
        while x < E.maxX {
            ctx.fill(Path(roundedRect: CGRect(x: x, y: top - T * 0.3, width: T * 0.16, height: T * 0.7), cornerRadius: 2), with: .color(Color(0x141a30)))
            x += T * (1.3 + 1.2 * h(i, 11)); i += 1
        }
        // two moored boats
        for k in 0..<2 {
            let bx = E.minX + E.width * (k == 0 ? 0.18 : 0.66), by = top + T * (0.9 + 0.5 * CGFloat(k)) + CGFloat(sin(f.t * 0.9 + Double(k) * 2)) * T * 0.04
            guard by + T * 0.4 < E.maxY else { continue }
            var hull = Path()
            hull.move(to: CGPoint(x: bx - T * 0.8, y: by))
            hull.addLine(to: CGPoint(x: bx + T * 0.8, y: by))
            hull.addLine(to: CGPoint(x: bx + T * 0.55, y: by + T * 0.3))
            hull.addLine(to: CGPoint(x: bx - T * 0.55, y: by + T * 0.3))
            hull.closeSubpath()
            ctx.fill(hull, with: .color(Color(0x111733)))
            ctx.fill(Path(CGRect(x: bx - T * 0.03, y: by - T * 0.9, width: T * 0.06, height: T * 0.9)), with: .color(Color(0x111733)))
        }
        // ripples
        for k in 0..<14 {
            let rx = E.minX + E.width * h(k, 12), ry = top + (W.height) * (0.1 + 0.85 * h(k, 13))
            let wv = CGFloat(sin(f.t * 0.8 + Double(k))) * T * 0.15
            var p = Path()
            p.move(to: CGPoint(x: rx - T * 0.4 + wv, y: ry))
            p.addLine(to: CGPoint(x: rx + T * 0.4 + wv, y: ry))
            ctx.stroke(p, with: .color(Color(0x8fb4ff, 0.08)), lineWidth: 1)
        }
    }

    func meadow(_ ctx: inout GraphicsContext, _ E: CGRect, _ B: CGRect) {
        let top = B.maxY + T * 0.9
        guard top < E.maxY else { return }
        // stones half-sunk in the grass
        for k in 0..<5 {
            let sx = E.minX + E.width * h(k, 21), sy = top + (E.maxY - top) * (0.15 + 0.6 * h(k, 22))
            ctx.fill(Path(ellipseIn: CGRect(x: sx, y: sy, width: T * (0.6 + 0.6 * h(k, 23)), height: T * 0.35)), with: .color(Color(0x1c2620)))
        }
        // blades: two depths, swaying
        for k in 0..<90 {
            let bx = E.minX + E.width * h(k, 24)
            let by = top + (E.maxY - top) * h(k, 25)
            let len = T * (0.25 + 0.4 * h(k, 26)) * (0.6 + 0.6 * (by - top) / max(1, E.maxY - top))
            let sway = CGFloat(sin(f.t * 1.1 + Double(k) * 0.37)) * len * 0.25
            var p = Path()
            p.move(to: CGPoint(x: bx, y: by))
            p.addQuadCurve(to: CGPoint(x: bx + sway, y: by - len), control: CGPoint(x: bx, y: by - len * 0.6))
            ctx.stroke(p, with: .color(Color(0x2f4a37, 0.55 + 0.35 * Double(h(k, 27)))), lineWidth: 1.4)
        }
    }

    func pools(_ ctx: inout GraphicsContext, _ E: CGRect, _ B: CGRect) {
        let top = B.maxY + T * 0.8
        guard top < E.maxY else { return }
        for k in 0..<6 {
            let px = E.minX + E.width * h(k, 31), py = top + (E.maxY - top) * (0.1 + 0.8 * h(k, 32))
            let w = T * (1.4 + 1.6 * h(k, 33))
            ctx.fill(Path(ellipseIn: CGRect(x: px - w / 2, y: py, width: w, height: w * 0.28)), with: .color(Color(0x05030a, 0.8)))
        }
        // thin crystal spikes poking up from the ground
        for k in 0..<12 {
            let sx = E.minX + E.width * h(k, 34), sy = top + (E.maxY - top) * h(k, 35)
            let ht = T * (0.3 + 0.5 * h(k, 36))
            var p = Path()
            p.move(to: CGPoint(x: sx - T * 0.07, y: sy))
            p.addLine(to: CGPoint(x: sx, y: sy - ht))
            p.addLine(to: CGPoint(x: sx + T * 0.07, y: sy))
            p.closeSubpath()
            ctx.fill(p, with: .color(Color(0x2a1f45)))
        }
    }

    func dunes(_ ctx: inout GraphicsContext, _ E: CGRect, _ B: CGRect) {
        let top = B.maxY + T * 0.6
        guard top < E.maxY else { return }
        for layer in 0..<3 {
            let y0 = top + (E.maxY - top) * CGFloat(layer) * 0.28
            var p = Path()
            p.move(to: CGPoint(x: E.minX, y: E.maxY))
            p.addLine(to: CGPoint(x: E.minX, y: y0))
            var x = E.minX
            var i = layer * 10
            while x < E.maxX {
                let w = T * (2 + 2 * h(i, 41))
                p.addQuadCurve(to: CGPoint(x: x + w, y: y0 + T * 0.1 * h(i, 42)), control: CGPoint(x: x + w / 2, y: y0 - T * (0.3 + 0.4 * h(i, 43))))
                x += w; i += 1
            }
            p.addLine(to: CGPoint(x: E.maxX, y: E.maxY))
            p.closeSubpath()
            let cs: [UInt32] = [0x2a1a10, 0x21140c, 0x170e08]
            ctx.fill(p, with: .color(Color(cs[layer])))
        }
        // the road, running down from the room toward the viewer
        var road = Path()
        road.move(to: CGPoint(x: B.midX - T * 0.5, y: top))
        road.addLine(to: CGPoint(x: B.midX + T * 0.5, y: top))
        road.addLine(to: CGPoint(x: B.midX + T * 2.2, y: E.maxY))
        road.addLine(to: CGPoint(x: B.midX - T * 2.2, y: E.maxY))
        road.closeSubpath()
        ctx.fill(road, with: .color(Color(0x332216, 0.8)))
        var k: CGFloat = 0
        while top + k * T * 0.8 < E.maxY {
            let y = top + k * T * 0.8, w = T * 0.04 * (1 + k * 0.3)
            ctx.fill(Path(CGRect(x: B.midX - w / 2, y: y + T * 0.1, width: w, height: T * 0.35)), with: .color(Color(0x5a4028, 0.7)))
            k += 1
        }
    }

    // MARK: front (light that shows through the night)

    func sceneryFront(_ ctx: inout GraphicsContext) {
        guard let E = f.extent else { return }
        let ch = chapterIndex, B = boardRect
        let keepOut = B.insetBy(dx: -T * 0.35, dy: -T * 0.35)
        var c = ctx
        c.blendMode = .plusLighter

        // stars above the horizon
        let starCount = ch == 4 ? 30 : 70
        let skyTop = E.minY, skyBottom = horizon - T * (ch == 1 ? 3.2 : 2.4)
        if skyBottom > skyTop {
            for k in 0..<starCount {
                let sx = E.minX + E.width * h(k, 51), sy = skyTop + (skyBottom - skyTop) * h(k, 52)
                let tw = 0.5 + 0.5 * sin(f.t * (0.8 + Double(h(k, 53)) * 1.6) + Double(k))
                let r = 0.6 + 1.1 * h(k, 54)
                c.fill(Path(ellipseIn: CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)), with: .color(Color(0xdfe6ff, 0.18 + 0.4 * tw * Double(h(k, 55)))))
            }
        }

        switch ch {
        case 1:
            // a few windows still lit in the town, and the lighthouse lamp, very low
            for (k, b) in townBlocks(E, near: true).enumerated() where h(k, 60) > 0.62 {
                let wr = CGRect(x: b.minX + b.width * 0.3, y: b.minY + b.height * 0.3, width: T * 0.14, height: T * 0.18)
                guard !keepOut.intersects(wr) else { continue }
                let fl = 0.55 + 0.45 * sin(f.t * 0.7 + Double(k) * 1.9)
                c.fill(Path(wr), with: .color(Pal.gold.opacity(0.22 * fl)))
            }
            let lx = E.minX + E.width * 0.8, ly = horizon + T * 0.2 - T * 4.75
            let pulse = 0.5 + 0.5 * sin(f.t * 0.9)
            c.fill(Path(ellipseIn: CGRect(x: lx - T, y: ly - T, width: T * 2, height: T * 2)),
                   with: .radialGradient(Gradient(colors: [Pal.gold.opacity(0.22 + 0.1 * pulse), Pal.gold.opacity(0)]), center: CGPoint(x: lx, y: ly), startRadius: 0, endRadius: T))
            // its reflection on the harbour
            let wt = B.maxY + T * 1.2
            if wt < E.maxY {
                for k in 0..<8 {
                    let ry = wt + T * (0.3 + CGFloat(k) * 0.35)
                    guard ry < E.maxY else { break }
                    let wob = CGFloat(sin(f.t * 1.4 + Double(k))) * T * 0.12
                    c.fill(Path(CGRect(x: lx - T * 0.25 + wob, y: ry, width: T * 0.5 * (1 - CGFloat(k) * 0.08), height: 1.5)), with: .color(Pal.gold.opacity(0.12 * (1 - Double(k) / 9))))
                }
            }
        case 2:
            // fireflies, outside the room only
            for k in 0..<16 {
                let ax = E.minX + E.width * h(k, 70), ay = E.minY + E.height * (0.15 + 0.85 * h(k, 71))
                let px = ax + CGFloat(sin(f.t * 0.5 + Double(k) * 1.3)) * T * 0.6
                let py = ay + CGFloat(cos(f.t * 0.37 + Double(k))) * T * 0.4
                let p = CGPoint(x: px, y: py)
                guard !keepOut.contains(p) else { continue }
                let on = max(0, sin(f.t * 1.3 + Double(k) * 2.3))
                c.fill(Path(ellipseIn: CGRect(x: px - T * 0.22, y: py - T * 0.22, width: T * 0.44, height: T * 0.44)),
                       with: .radialGradient(Gradient(colors: [Pal.mint.opacity(0.35 * on), Pal.mint.opacity(0)]), center: p, startRadius: 0, endRadius: T * 0.22))
                c.fill(Path(ellipseIn: CGRect(x: px - 1.2, y: py - 1.2, width: 2.4, height: 2.4)), with: .color(Pal.mint.opacity(0.8 * on)))
            }
        case 3:
            // pairs of eyes in the dark, blinking now and then: lost shadows that never came close
            for k in 0..<9 {
                let ex = E.minX + E.width * h(k, 80), ey = E.minY + E.height * (0.2 + 0.8 * h(k, 81))
                let p = CGPoint(x: ex, y: ey)
                guard !keepOut.insetBy(dx: -T * 0.3, dy: -T * 0.3).contains(p) else { continue }
                let cycle = (f.t * 0.35 + Double(h(k, 82)) * 5).truncatingRemainder(dividingBy: 4)
                let open: Double = cycle < 0.12 ? 0.1 : (cycle > 3 ? 0 : 1)
                let a = 0.45 * open
                for s in [-1.0, 1.0] {
                    let q = CGRect(x: ex + CGFloat(s) * T * 0.1 - T * 0.045, y: ey - T * 0.03 * CGFloat(open), width: T * 0.09, height: max(1, T * 0.07 * CGFloat(open)))
                    c.fill(Path(ellipseIn: q), with: .color(Pal.shadowEye.opacity(a)))
                }
            }
        default:
            // warm horizon behind the nest, and embers rising
            let nest = CGPoint(x: E.midX, y: horizon + T * 0.2)
            let br = 0.18 + 0.06 * sin(f.t * 0.5)
            c.fill(Path(ellipseIn: CGRect(x: nest.x - T * 4, y: nest.y - T * 2.2, width: T * 8, height: T * 4.4)),
                   with: .radialGradient(Gradient(colors: [Color(0xffb36b, br), Color(0xffb36b, 0)]), center: nest, startRadius: 0, endRadius: T * 4))
            for k in 0..<18 {
                let speed = 0.05 + 0.05 * Double(h(k, 90))
                let prog = CGFloat((f.t * speed + Double(h(k, 91))).truncatingRemainder(dividingBy: 1))
                let px = E.minX + E.width * h(k, 92) + CGFloat(sin(f.t + Double(k))) * T * 0.2
                let py = E.maxY - (E.height) * prog
                let p = CGPoint(x: px, y: py)
                guard !keepOut.contains(p) else { continue }
                c.fill(Path(ellipseIn: CGRect(x: px - 1.3, y: py - 1.3, width: 2.6, height: 2.6)), with: .color(Color(0xffc27a, 0.5 * Double(1 - prog))))
            }
        }

        // drifting mist low over the ground, normal blend
        var m = ctx
        m.opacity = ch == 3 ? 0.5 : 0.25
        for k in 0..<3 {
            let y = B.maxY + T * (0.4 + CGFloat(k) * 1.4)
            guard y < E.maxY else { break }
            let x = E.minX + ((CGFloat(f.t) * T * 0.12 * CGFloat(k + 1)).truncatingRemainder(dividingBy: E.width + T * 6)) - T * 3
            let mc = [Color(0x6c7aa8), Color(0x6c8a74), Color(0x7a64a8), Color(0xa8805c)][ch - 1]
            m.fill(Path(ellipseIn: CGRect(x: x, y: y, width: T * 6, height: T * 0.9)),
                   with: .radialGradient(Gradient(colors: [mc.opacity(0.25), mc.opacity(0)]), center: CGPoint(x: x + T * 3, y: y + T * 0.45), startRadius: 0, endRadius: T * 3))
        }

        // vignette that keeps the eye on the room
        let center = CGPoint(x: B.midX, y: B.midY)
        let dx = max(center.x - E.minX, E.maxX - center.x), dy = max(center.y - E.minY, E.maxY - center.y)
        let far = (dx * dx + dy * dy).squareRoot()
        ctx.fill(Path(E), with: .radialGradient(Gradient(stops: [.init(color: .black.opacity(0), location: 0),
                                                                  .init(color: .black.opacity(0), location: 0.5),
                                                                  .init(color: .black.opacity(0.55), location: 1)]),
                                                 center: center, startRadius: 0, endRadius: far))
    }
}
