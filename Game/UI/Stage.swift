import SwiftUI
import UIKit

/// The art made in Blender (Tools/art): one pre-rendered background per room and a sprite for everything that moves.
/// Both share one orthographic camera looking down `tilt` degrees, `pc` pixels to a cell, so the game only has to
/// scale them by T / pc and stand each sprite's feet on its cell. Nothing is ever stretched.
enum Art {
    struct SpriteMeta { var feet: CGPoint; var bead: CGPoint?; var hold: CGPoint?; var tail: CGPoint? }
    struct RoomBG { var image: UIImage; var origin: CGPoint; var pc: CGFloat }

    static let tilt = 48.0
    static let k = CGFloat(sin(tilt * .pi / 180))    // a cell's depth on screen, as a share of its width
    static let lift = CGFloat(cos(tilt * .pi / 180)) // a world height on screen, as a share of the cell width per S
    static let pc: CGFloat = 110
    static let zs = lift / 1.5                       // screen cell-widths per world unit of height (a cell is 1.5 units)

    private static var images: [String: UIImage] = [:]
    private static var resolved: [String: Image] = [:]
    static let meta: [String: SpriteMeta] = {
        guard let url = Bundle.main.url(forResource: "sprites", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        func pt(_ a: Any?) -> CGPoint? { (a as? [Double]).flatMap { $0.count == 2 ? CGPoint(x: $0[0], y: $0[1]) : nil } }
        var out: [String: SpriteMeta] = [:]
        for (k, v) in obj {
            guard let d = v as? [String: Any], let f = pt(d["feet"]) else { continue }
            out[k] = SpriteMeta(feet: f, bead: pt(d["bead"]), hold: pt(d["hold"]), tail: pt(d["tail"]))
        }
        return out
    }()

    static func uiImage(_ name: String, ext: String = "png") -> UIImage? {
        if let i = images[name] { return i }
        guard let url = Bundle.main.url(forResource: name, withExtension: ext), let i = UIImage(contentsOfFile: url.path) else { return nil }
        images[name] = i
        return i
    }
    static func image(_ name: String) -> Image? {
        if let i = resolved[name] { return i }
        guard let u = uiImage(name) else { return nil }
        let i = Image(uiImage: u)
        resolved[name] = i
        return i
    }

    private static var bgs: [String: RoomBG] = [:]
    static func background(_ room: String) -> RoomBG? {
        if let b = bgs[room] { return b }
        guard let img = uiImage("bg_\(room)", ext: "jpg"),
              let url = Bundle.main.url(forResource: "bg_\(room)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let o = d["origin"] as? [Double], o.count == 2 else { return nil }
        let b = RoomBG(image: img, origin: CGPoint(x: o[0], y: o[1]), pc: CGFloat(d["pc"] as? Double ?? 110))
        bgs[room] = b
        return b
    }
}

/// Draws one frame of a room with the Blender art. Coordinates: the room's top-left ground corner is (0, 0); a cell
/// is T wide and T·k deep on screen.
struct Stage {
    let f: BoardFrame
    let T: CGFloat
    var K: CGFloat { Art.k }
    var s: CGFloat { T / Art.pc }      // points per art pixel

    /// Ground position of a (possibly fractional) cell centre.
    func ground(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x + 0.5) * T, y: (p.y + 0.5) * T * K) }

    func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * f.e }
    func pos(_ i: Int) -> CGPoint {
        let p = f.state.c[i]
        guard let q = f.prev, i < q.c.count else { return CGPoint(x: p.x, y: p.y) }
        return CGPoint(x: lerp(Double(q.c[i].x), Double(p.x)), y: lerp(Double(q.c[i].y), Double(p.y)))
    }
    func moved(_ a: [Pt], _ b: [Pt]?, _ i: Int) -> CGPoint {
        let p = a[i]
        guard let q = b, i < q.count else { return CGPoint(x: p.x, y: p.y) }
        return CGPoint(x: lerp(Double(q[i].x), Double(p.x)), y: lerp(Double(q[i].y), Double(p.y)))
    }

    // MARK: frame

    func draw(_ ctx: inout GraphicsContext) {
        let r = f.room
        background(&ctx)
        plates(&ctx)
        guides(&ctx)
        affordances(&ctx)
        forecast(&ctx)
        var items: [(Double, (inout GraphicsContext) -> Void)] = []
        for (i, p) in r.lampPos.enumerated() where !r.nest[i] {
            items.append((Double(p.y), { c in self.lamp(&c, i) }))
        }
        for (p, ch) in r.npcs { items.append((Double(p.y), { c in self.npc(&c, p, ch) })) }
        if !r.platesDown(f.state) {
            for y in 0..<r.h { for x in 0..<r.w where r.tile(Pt(x, y)) == .door {
                items.append((Double(y) - 0.01, { c in self.sprite(&c, "bars", at: CGPoint(x: x, y: y), warm: false) }))
            } }
        }
        for i in f.state.boulders.indices {
            let p = moved(f.state.boulders, f.prev?.boulders, i)
            items.append((Double(p.y), { c in self.sprite(&c, "boulder", at: p) }))
        }
        for i in f.state.shadows.indices {
            let p = moved(f.state.shadows, f.prev?.shadows, i)
            let sp = f.state.shadows[i]
            var lean = CGPoint.zero
            if let l = r.lampPos.enumerated().first(where: { f.state.lit[$0.offset] && $0.element.dist(sp) == 1 })?.element {
                lean = CGPoint(x: CGFloat(l.x - sp.x) * 0.12, y: CGFloat(l.y - sp.y) * 0.12)
            }
            let blink = (f.t + Double(i) * 1.3).truncatingRemainder(dividingBy: 3.1) < 0.14
            let wob = CGFloat(sin(f.t * 3 + Double(i) * 1.7)) * 0.025
            items.append((Double(p.y), { c in self.sprite(&c, blink ? "shadow_blink" : "shadow", at: CGPoint(x: p.x + lean.x + wob, y: p.y + lean.y), warm: false) }))
        }
        if let t = f.state.thief {
            var p = CGPoint(x: t.x, y: t.y)
            if let q = f.prev?.thief { p = CGPoint(x: lerp(Double(q.x), Double(t.x)), y: lerp(Double(q.y), Double(t.y))) }
            let caught = r.trapped(f.state)
            let dx = (f.prev?.thief).map { t.x - $0.x } ?? 0
            let pz = f.poses["x"]
            let st = pz?.state ?? (caught ? "caught" : blinking(2.1, 4.4) ? "blink" : dx < 0 ? "left" : dx > 0 ? "right" : "glee")
            items.append((Double(p.y) + 0.005, { c in
                self.figure(&c, "mosto", st, at: p, pose: pz)
                if !caught && st != "caught" && st != "sleep" { self.spark(&c, "mosto_\(st)", at: p) }
            }))
        }
        if !f.hideHeroes {
            for (i, h) in r.heroes.enumerated() {
                let p = pos(i)
                let moving = f.e < 1 && (f.prev.map { i < $0.c.count && $0.c[i] != f.state.c[i] } ?? false)
                let hop = moving ? CGFloat(sin(f.e * .pi)) * 0.16 : 0
                items.append((Double(p.y) + 0.01, { c in
                    if r.heroes.count > 1 && i == self.f.active { self.marker(&c, p) }
                    self.hero(&c, h, i, p, hop: hop)
                }))
            }
        }
        for (key, a) in f.actors {
            let p = CGPoint(x: a.x, y: a.y)
            let pz = f.poses[key]
            items.append((a.y, { c in
                var g = c; g.opacity = a.alpha
                switch a.kind {
                case "moss": self.figure(&g, "moss", pz?.state ?? self.mossState(face: 1), at: p, pose: pz)
                case "otto":
                    let st = pz?.state.map { $0.contains("_") ? $0 : "\($0)_S" } ?? (self.blinking(0.4, 4.2) ? "blink_S" : "idle_S")
                    self.figure(&g, "otto", st, at: p, pose: pz)
                    if a.carry { self.bulb(&g, "otto_\(st)", at: p, lift: 0) }
                case "hank": self.sprite(&g, "npc_h", at: p, pose: pz)
                case "dora": self.sprite(&g, pz?.state == "lit" || (pz == nil && a.carry) ? "npc_dl" : "npc_d", at: p, pose: pz)
                case "lynn": self.sprite(&g, "npc_n", at: p, pose: pz)
                default:
                    let st = pz?.state ?? self.mostoState(face: -1)
                    self.figure(&g, "mosto", st, at: p, pose: pz); if a.carry { self.spark(&g, "mosto_idle", at: p) }
                }
            }))
        }
        for it in items.sorted(by: { $0.0 < $1.0 }) { it.1(&ctx) }
        night(&ctx)
        glows(&ctx)
        motes(&ctx)
        flights(&ctx)
        hintMarks(&ctx)
        bubbles(&ctx)
    }

    // MARK: reading the room

    /// What happens next if nothing else changes: a pale arrow under each shadow that will drift, a red ring on a lamp
    /// two shadows are about to crowd out, and Mosto's next step in violet with the lamp he is about to rob.
    func forecast(_ ctx: inout GraphicsContext) {
        let r = f.room
        guard !f.hideHeroes, f.e >= 0.999, !r.heroes.isEmpty, f.state.c.count == r.heroes.count else { return }
        var s = f.state, ev: [Event] = []
        r.drift(&s, &ev)
        let pulse = 0.55 + 0.45 * sin(f.t * 5)
        for i in s.shadows.indices where i < f.state.shadows.count && s.shadows[i] != f.state.shadows[i] {
            arrow(&ctx, f.state.shadows[i], s.shadows[i], Color(0xcfd6ff, 0.75))
        }
        for i in r.lampPos.indices where f.state.lit[i] && !s.lit[i] { ring(&ctx, r.lampPos[i], Color(0xe8503a, pulse), 0.46) }
        guard let a = f.state.thief, !r.trapped(f.state) else { return }
        var s2 = s
        r.thiefMove(&s2, &ev)
        let violet = Color(0xb07af0)
        if let b = s2.thief, b != a { arrow(&ctx, a, b, violet.opacity(0.95)) }
        // the lamp he's after: robbed next step (ring pulses), or the nearest lit one he's heading for (faint)
        if let i = r.lampPos.indices.first(where: { s.lit[$0] && !s2.lit[$0] }) {
            ring(&ctx, r.lampPos[i], violet.opacity(pulse), 0.48)
        } else if let i = r.lampPos.indices.filter({ s.lit[$0] && !r.nest[$0] }).min(by: { r.lampPos[$0].dist(a) < r.lampPos[$1].dist(a) }) {
            ring(&ctx, r.lampPos[i], violet.opacity(0.35), 0.48)
        }
    }

    func arrow(_ ctx: inout GraphicsContext, _ a: Pt, _ b: Pt, _ col: Color) {
        let p = ground(CGPoint(x: a.x, y: a.y)), q = ground(CGPoint(x: b.x, y: b.y))
        let dx = q.x - p.x, dy = q.y - p.y, len = max(1, hypot(dx, dy))
        let ux = dx / len, uy = dy / len
        let tip = CGPoint(x: p.x + dx * 0.78, y: p.y + dy * 0.78)
        let base = CGPoint(x: p.x + dx * 0.36, y: p.y + dy * 0.36)
        var line = Path(); line.move(to: base); line.addLine(to: tip)
        ctx.stroke(line, with: .color(col), style: StrokeStyle(lineWidth: max(2, T * 0.06), lineCap: .round))
        let w = T * 0.13
        var head = Path()
        head.move(to: CGPoint(x: tip.x - ux * w * 1.4 - uy * w, y: tip.y - uy * w * 1.4 + ux * w))
        head.addLine(to: tip)
        head.addLine(to: CGPoint(x: tip.x - ux * w * 1.4 + uy * w, y: tip.y - uy * w * 1.4 - ux * w))
        ctx.stroke(head, with: .color(col), style: StrokeStyle(lineWidth: max(2, T * 0.06), lineCap: .round, lineJoin: .round))
    }

    func ring(_ ctx: inout GraphicsContext, _ p: Pt, _ col: Color, _ r: CGFloat) {
        let c = ground(CGPoint(x: p.x, y: p.y))
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - T * r, y: c.y - T * r * K, width: T * r * 2, height: T * r * 2 * K)), with: .color(col), lineWidth: 2.5)
    }

    /// What the one you're playing can use from where they stand: a gold ring under it, or red where it won't work
    /// (a dark lamp with a shadow beside it).
    func affordances(_ ctx: inout GraphicsContext) {
        let r = f.room
        guard !f.hideHeroes, f.active >= 0, f.active < f.state.c.count, f.active < r.heroes.count else { return }
        let me = f.state.c[f.active], who = r.heroes[f.active], st = f.state
        let pulse = 0.5 + 0.5 * sin(f.t * 4)
        for (i, lp) in r.lampPos.enumerated() where lp.dist(me) == 1 {
            let crowded = st.shadows.contains { $0.dist(lp) == 1 }
            var use: Bool? = nil
            switch who {
            case .otto: if !st.lit[i] && !r.nest[i] { use = !crowded }
            case .mosto: if st.carry && !st.lit[i] { use = !crowded } else if !st.carry && st.lit[i] { use = true }
            case .moss: break
            }
            if let ok = use { ring(&ctx, lp, ok ? Color(0xf2c062, 0.5 + 0.45 * pulse) : Color(0xe8503a, 0.8), 0.44) }
        }
        if who == .moss { for t in r.tablets where t.dist(me) == 1 { ring(&ctx, t, Color(0xf2c062, 0.5 + 0.45 * pulse), 0.44) } }
        for (p, _) in r.npcs where p.dist(me) == 1 { ring(&ctx, p, Color(0xf2c062, 0.35 + 0.3 * pulse), 0.4) }
    }

    // MARK: feelings

    /// Where someone's head is, for a speech-free bubble: heroes by their letter, story actors by name, townsfolk by theirs.
    func head(_ who: String) -> CGPoint? {
        let tall: [String: CGFloat] = ["o": 2.2, "m": 1.45, "x": 1.7, "moss": 1.45, "mosto": 1.7, "otto": 2.2, "h": 1.35, "n": 1.35, "d": 1.05, "hank": 1.35, "lynn": 1.35, "dora": 1.05]
        let heroKey: [String: Hero] = ["o": .otto, "m": .moss, "x": .mosto]
        var at: CGPoint? = nil
        if who == "x", let t = f.state.thief { at = CGPoint(x: t.x, y: t.y) }
        else if let h = heroKey[who], let i = f.room.index(of: h), !f.hideHeroes { at = pos(i) }
        else if let a = f.actors[who] { at = CGPoint(x: a.x, y: a.y) }
        else if let c = who.first, who.count == 1, let p = f.room.npcs.first(where: { $0.value == c })?.key { at = CGPoint(x: p.x, y: p.y) }
        if at == nil, who == "m", let p = f.room.npcs.first(where: { $0.value == "m" })?.key { at = CGPoint(x: p.x, y: p.y) }
        if at == nil, who == "o", let p = f.room.npcs.first(where: { $0.value == "o" })?.key { at = CGPoint(x: p.x, y: p.y) }
        guard let p = at else { return nil }
        let g = ground(p)
        return CGPoint(x: g.x, y: g.y - (tall[who] ?? 1.2) * T * 0.78)
    }

    func bubbles(_ ctx: inout GraphicsContext) {
        let symbols: [String: String] = ["!": "exclamationmark", "?": "questionmark", "...": "ellipsis", "note": "music.note",
                                         "anger": "bolt.fill", "zzz": "zzz", "heart": "heart.fill", "sweat": "drop.fill",
                                         "spark": "sparkles", "grin": "theatermasks.fill"]
        let tints: [String: Color] = ["anger": Color(0xe8503a), "heart": Color(0xe86a8a), "sweat": Color(0x5a9ae8), "spark": Color(0xe8a030), "grin": Color(0x7b4bb3)]
        for (who, e) in f.emotes {
            guard let h = head(who) else { continue }
            let age = Date().timeIntervalSince(e.at)
            let pop = min(1, age / 0.18)
            let k = CGFloat(0.6 + 0.4 * pop + 0.08 * sin(min(1, age / 0.3) * .pi))
            let w = T * 0.62 * k, hh = T * 0.5 * k
            let r = CGRect(x: h.x - w / 2, y: h.y - hh - T * 0.12, width: w, height: hh)
            var b = Path(roundedRect: r, cornerRadius: hh * 0.45)
            b.move(to: CGPoint(x: h.x - T * 0.06, y: r.maxY - 1)); b.addLine(to: CGPoint(x: h.x, y: r.maxY + T * 0.12)); b.addLine(to: CGPoint(x: h.x + T * 0.08, y: r.maxY - 1))
            ctx.fill(b, with: .color(Color(0xfbf7ee, 0.96 * pop)))
            ctx.stroke(b, with: .color(.black.opacity(0.25 * pop)), lineWidth: 1)
            var img = ctx.resolve(Image(systemName: symbols[e.icon] ?? "ellipsis"))
            img.shading = .color(tints[e.icon] ?? Color(0x1a1e2e))
            let isz = hh * 0.62
            ctx.draw(img, in: CGRect(x: r.midX - isz / 2, y: r.midY - isz / 2, width: isz, height: isz))
        }
    }

    // MARK: layers

    func background(_ ctx: inout GraphicsContext) {
        if let bg = Art.background(f.room.spec.id) {
            let k = T / bg.pc
            let rect = CGRect(x: -bg.origin.x * k, y: -bg.origin.y * k, width: bg.image.size.width * k, height: bg.image.size.height * k)
            ctx.draw(Image(uiImage: bg.image), in: rect)
        } else {
            // no render yet for this room: a plain floor, so the game still plays
            if let e = f.extent { ctx.fill(Path(e), with: .color(Color(0x141a30))) }
            for y in 0..<f.room.h { for x in 0..<f.room.w {
                let t = f.room.tile(Pt(x, y))
                let R = CGRect(x: CGFloat(x) * T, y: CGFloat(y) * T * K, width: T, height: T * K).insetBy(dx: 1, dy: 1)
                ctx.fill(Path(roundedRect: R, cornerRadius: 4), with: .color(t == .wall ? Color(0x2a3152) : t == .water ? Color(0x0c1530) : Color(0x3a4266)))
            } }
        }
    }

    /// A sprite standing on a cell: its feet on the cell centre, scaled T / pc. "_w" is laid over "_n" where it is lit.
    /// The figures are drawn a little larger than the world, so faces read on a phone; props keep the world's scale.
    func scaleOf(_ name: String) -> CGFloat {
        name.hasPrefix("otto") || name.hasPrefix("moss") || name.hasPrefix("mosto") || name.hasPrefix("npc") ? s * 1.3 : s
    }
    func sprite(_ ctx: inout GraphicsContext, _ name: String, at p: CGPoint, lift: CGFloat = 0, warm: Bool = true, flip: Bool = false, pose: Pose? = nil) {
        let s = scaleOf(name)
        guard let m = Art.meta[name] else { return }
        let g = ground(p)
        let n = Art.image(name + "_n") ?? Art.image(name)
        guard let img = n, let ui = Art.uiImage(name + "_n") ?? Art.uiImage(name) else { return }
        let w = ui.size.width * s, h = ui.size.height * s
        var c = ctx
        let act = acting(pose)
        let rect = CGRect(x: g.x - m.feet.x * s, y: g.y - m.feet.y * s - (lift + act.lift) * T, width: w, height: h)
        if act != .still {
            c.translateBy(x: g.x, y: g.y)
            c.rotate(by: .radians(act.rot))
            c.scaleBy(x: act.sx, y: act.sy)
            c.translateBy(x: -g.x, y: -g.y)
            c.opacity *= act.alpha
        }
        if flip { c.translateBy(x: g.x * 2, y: 0); c.scaleBy(x: -1, y: 1) }
        c.draw(img, in: rect)
        if warm, let wimg = Art.image(name + "_w") {
            let l = lightAt(p)
            if l > 0.02 { var cw = c; cw.opacity = min(1, l); cw.draw(wimg, in: rect) }
        }
    }

    func figure(_ ctx: inout GraphicsContext, _ who: String, _ state: String, at p: CGPoint, lift: CGFloat = 0, pose: Pose? = nil) {
        sprite(&ctx, "\(who)_\(state)", at: p, lift: lift, pose: pose)
    }

    /// A little acting, about the feet: squash, stretch, a wag, a stomp, a paper spin, shrinking into the ground.
    struct Acting: Equatable { var sx: CGFloat = 1, sy: CGFloat = 1, rot: Double = 0, lift: CGFloat = 0, alpha: Double = 1
        static let still = Acting() }
    func acting(_ p: Pose?) -> Acting {
        guard let p, let fx = p.fx else { return .still }
        let age = Date().timeIntervalSince(p.at)
        let k = CGFloat(min(1, age / 0.18))                     // ease into the pose
        let u = min(1, age / max(0.1, p.dur))                    // 0…1 over the whole beat
        var a = Acting()
        switch fx {
        case "flat": a.sx = 1 + 0.2 * k; a.sy = 1 - 0.3 * k                       // Moss, thwarted: flattened to the ground
        case "tall": a.sx = 1 - 0.07 * k; a.sy = 1 + 0.14 * k                      // Moss's "mine!": stands up tall
            a.lift = CGFloat(max(0, sin(min(1, age / 0.3) * .pi))) * 0.12
        case "wag": a.rot = sin(age * 13) * 0.09 * Double(k)                       // Mosto's gleeful sway
        case "stomp": let b = abs(sin(age * 15)); a.lift = CGFloat(b) * 0.07       // Hank stamping
            a.sy = 1 - CGFloat(1 - b) * 0.08; a.sx = 1 + CGFloat(1 - b) * 0.05
        case "shake": a.rot = sin(age * 18) * 0.08 * (1 - u)                      // Lynn shaking her head
        case "spin": a.sx = CGFloat(cos(age * 9)); a.lift = CGFloat(abs(sin(age * 9))) * 0.06   // Dora twirling
        case "nod": a.sy = 1 - CGFloat(max(0, sin(age * 8))) * 0.07
        case "slump": a.rot = -0.12 * Double(k) * min(1, age / 0.6); a.sy = 1 - 0.08 * CGFloat(min(1, age / 0.6))  // Otto giving way
        case "shrink": let q = CGFloat(1 - u); a.sx = q; a.sy = q * q; a.alpha = Double(q)   // Mosto drawn into Moss's shadow
        case "hop": a.lift = CGFloat(abs(sin(age * 10))) * 0.14 * CGFloat(1 - u)
        default: break
        }
        return a
    }

    func blinking(_ seed: Double, _ every: Double) -> Bool { (f.t + seed).truncatingRemainder(dividingBy: every) < 0.13 }
    func mossState(face: Int) -> String { blinking(1.3, 3.7) ? "blink" : face < 0 ? "left" : "right" }
    func mostoState(face: Int) -> String { blinking(2.1, 4.4) ? "blink" : face < 0 ? "left" : "right" }

    func hero(_ ctx: inout GraphicsContext, _ h: Hero, _ i: Int, _ p: CGPoint, hop: CGFloat) {
        let face = i < f.face.count ? f.face[i] : 1
        switch h {
        case .otto:
            let pz = f.poses["o"]
            let dir = face < 0 ? "W" : "E"
            let name = pz?.state.map { "otto_" + ($0.contains("_") ? $0 : "\($0)_S") } ?? (blinking(0.4, 4.2) ? "otto_blink_\(dir)" : "otto_idle_\(dir)")
            sprite(&ctx, name, at: p, lift: hop, pose: pz)
            if f.state.bulb { bulb(&ctx, name, at: p, lift: hop) }
        case .moss:
            let pz = f.poses["m"]
            figure(&ctx, "moss", pz?.state ?? mossState(face: face), at: p, lift: hop, pose: pz)
        case .mosto:
            let pz = f.poses["x"]
            let st = pz?.state ?? mostoState(face: face)
            figure(&ctx, "mosto", st, at: p, lift: hop, pose: pz)
            if f.state.carry { spark(&ctx, "mosto_\(st)", at: p, lift: hop) }
        }
    }

    /// Otto's bead, lit: a warm halo at the bead's place in his sprite.
    func bulb(_ ctx: inout GraphicsContext, _ sprite: String, at p: CGPoint, lift: CGFloat) {
        guard let m = Art.meta[sprite], let b = m.bead else { return }
        let g = ground(p)
        let s = scaleOf(sprite)
        let c = CGPoint(x: g.x + (b.x - m.feet.x) * s, y: g.y + (b.y - m.feet.y) * s - lift * T)
        var a = ctx; a.blendMode = .plusLighter
        let R = T * 0.55
        a.fill(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2)),
               with: .radialGradient(Gradient(colors: [Color(0xffd77a, 0.9), Color(0xffb04a, 0.25), Color(0xffb04a, 0)]), center: c, startRadius: 0, endRadius: R))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - T * 0.06, y: c.y - T * 0.06, width: T * 0.12, height: T * 0.12)), with: .color(Color(0xfff2c4)))
    }

    /// The sun's fire in Mosto's hands: six frames of flicker, a warm halo round it.
    func spark(_ ctx: inout GraphicsContext, _ holder: String, at p: CGPoint, lift: CGFloat = 0) {
        guard let m = Art.meta[holder], let hold = m.hold else { return }
        let g = ground(p)
        let s = scaleOf(holder)
        let c = CGPoint(x: g.x + (hold.x - m.feet.x) * s, y: g.y + (hold.y - m.feet.y) * s - lift * T)
        var a = ctx; a.blendMode = .plusLighter
        let R = T * 0.42
        a.fill(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R * 0.9, width: R * 2, height: R * 1.8)),
               with: .radialGradient(Gradient(colors: [Color(0xff9a3a, 0.32), Color(0xff6a20, 0)]), center: c, startRadius: 0, endRadius: R))
        let frame = Int(f.t * 10) % 6
        guard let fm = Art.meta["spark_\(frame)"], let img = Art.image("spark_\(frame)"), let ui = Art.uiImage("spark_\(frame)") else { return }
        let sc = s * 0.4
        ctx.draw(img, in: CGRect(x: c.x - fm.feet.x * sc, y: c.y - fm.feet.y * sc, width: ui.size.width * sc, height: ui.size.height * sc))
    }

    func lamp(_ ctx: inout GraphicsContext, _ i: Int) {
        let p = f.room.lampPos[i]
        sprite(&ctx, f.state.lit[i] ? "lantern_on" : "lantern_off", at: CGPoint(x: p.x, y: p.y), warm: false)
    }

    func npc(_ ctx: inout GraphicsContext, _ p: Pt, _ ch: Character) {
        let at = CGPoint(x: p.x, y: p.y)
        switch ch {
        case "o":
            let pz = f.poses["o"]
            sprite(&ctx, "otto_" + (pz?.state.map { $0.contains("_") ? $0 : "\($0)_S" } ?? "sleep_S"), at: at, pose: pz)
        case "m": let pz = f.poses["m"]; figure(&ctx, "moss", pz?.state ?? mossState(face: 1), at: at, pose: pz)
        case "d": sprite(&ctx, f.doraLit || f.poses["d"]?.state == "lit" ? "npc_dl" : "npc_d", at: at, pose: f.poses["d"])
        case "h", "n": sprite(&ctx, "npc_\(ch)", at: at, pose: f.poses[String(ch)])
        default: break
        }
    }

    func plates(_ ctx: inout GraphicsContext) {
        let r = f.room
        for y in 0..<r.h { for x in 0..<r.w where r.tile(Pt(x, y)) == .plate {
            let pressed = f.state.boulders.contains(Pt(x, y)) || f.state.c.contains(Pt(x, y))
            guard pressed else { continue }
            let c = ground(CGPoint(x: x, y: y))
            var a = ctx; a.blendMode = .plusLighter
            a.fill(Path(ellipseIn: CGRect(x: c.x - T * 0.36, y: c.y - T * 0.36 * K, width: T * 0.72, height: T * 0.72 * K)), with: .color(Color(0xf2c062, 0.35)))
        } }
        // an open exit glows
        for y in 0..<r.h { for x in 0..<r.w where r.tile(Pt(x, y)) == .exit && r.exitOpen(f.state) {
            let c = ground(CGPoint(x: x, y: y))
            let br = 0.35 + 0.2 * (0.5 + 0.5 * sin(f.t * 2.2))
            var a = ctx; a.blendMode = .plusLighter
            a.fill(Path(ellipseIn: CGRect(x: c.x - T * 0.5, y: c.y - T * 0.5 * K, width: T, height: T * K)),
                   with: .radialGradient(Gradient(colors: [Color(0xffd27a, br), Color(0xffd27a, 0)]), center: c, startRadius: 0, endRadius: T * 0.5))
        } }
    }

    func marker(_ ctx: inout GraphicsContext, _ p: CGPoint) {
        let c = ground(p)
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - T * 0.38, y: c.y - T * 0.38 * K * 0.6, width: T * 0.76, height: T * 0.76 * K * 0.6)), with: .color(Color(0xf2c062, 0.85)), lineWidth: 2)
    }

    func guides(_ ctx: inout GraphicsContext) {
        for (k, p) in f.dots.enumerated() {
            let c = ground(CGPoint(x: p.x, y: p.y))
            let r = T * (k == f.dots.count - 1 ? 0.1 : 0.06)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * K, width: r * 2, height: r * 2 * K)), with: .color(Color(0xf2c062, 0.8)))
        }
        if let tp = f.tap, tp.1 < 0.45 {
            let c = ground(CGPoint(x: tp.0.x, y: tp.0.y)), k = tp.1 / 0.45
            let r = T * (0.2 + 0.35 * CGFloat(k))
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * K, width: r * 2, height: r * 2 * K)), with: .color(Color.white.opacity(0.5 * (1 - k))), lineWidth: 2)
        }
    }

    func hintMarks(_ ctx: inout GraphicsContext) {
        guard let h = f.hint, h.hero < f.state.c.count else { return }
        let pulse = 0.55 + 0.45 * sin(f.t * 6)
        for p in [f.state.c[h.hero]] + (h.target.map { [$0] } ?? []) {
            let c = ground(CGPoint(x: p.x, y: p.y))
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - T * 0.42, y: c.y - T * 0.42 * K, width: T * 0.84, height: T * 0.84 * K)), with: .color(Color(0xf2c062, pulse)), lineWidth: 2.5)
        }
    }

    // MARK: light

    /// Light sources in cell units: centre, reach (cells), strength, warm (false for the cold sun-nest glow).
    func lights() -> [(CGPoint, Double, Double)] {
        let r = f.room
        var out: [(CGPoint, Double, Double)] = []
        let main = r.spec.id == "top" || r.spec.id == "lamp"
        for (i, p) in r.lampPos.enumerated() where f.state.lit[i] {
            let rad = r.spec.sun == true ? 3.0 : Double(main ? 2 : r.rLamp)
            let flick = 0.94 + 0.06 * sin(f.t * 7.3 + Double(i) * 2.1)
            out.append((CGPoint(x: p.x, y: p.y), rad, (main && f.mainDim ? 0.6 : 1) * flick))
        }
        if let oi = r.index(of: .otto), f.state.bulb, !f.hideHeroes { out.append((pos(oi), f.bulbR, 1)) }
        if let xi = r.index(of: .mosto), f.state.carry, !f.hideHeroes { out.append((pos(xi), Double(r.rCarry), 0.9)) }
        if let t = f.state.thief, !r.trapped(f.state) { out.append((CGPoint(x: t.x, y: t.y), 1.2, 0.8)) }
        for (_, a) in f.actors where a.carry { out.append((CGPoint(x: a.x, y: a.y), 1, 0.8)) }
        for fl in f.flies { out.append((flyAt(fl).0, 1.2, 0.9)) }
        if let d = f.room.npcs.first(where: { $0.value == "d" })?.key, f.doraLit || f.poses["d"]?.state == "lit" {
            out.append((CGPoint(x: d.x, y: d.y), 1.0, 0.7))
        }
        return out
    }

    /// Where a flying mote is now (cells) and how high above the ground (cells of lift).
    func flyAt(_ fl: Fly) -> (CGPoint, CGFloat) {
        let u = CGFloat(min(1, max(0, Date().timeIntervalSince(fl.at) / fl.dur)))
        let e = u * u * (3 - 2 * u)
        let p = CGPoint(x: fl.from.x + (fl.to.x - fl.from.x) * e, y: fl.from.y + (fl.to.y - fl.from.y) * e)
        return (p, 0.9 + sin(u * .pi) * 1.1)
    }

    /// The fire in flight: a mote with a short tail, arcing from one holder to the next.
    func flights(_ ctx: inout GraphicsContext) {
        var c = ctx; c.blendMode = .plusLighter
        for fl in f.flies {
            for k in 0..<6 {
                let back = Fly(from: fl.from, to: fl.to, at: fl.at.addingTimeInterval(Double(k) * 0.035), dur: fl.dur)
                let (p, lift) = flyAt(back)
                let g = ground(p)
                let cy = g.y - lift * T * Art.zs
                let R = T * (0.26 - 0.035 * CGFloat(k))
                let a = 0.9 - 0.14 * Double(k)
                c.fill(Path(ellipseIn: CGRect(x: g.x - R, y: cy - R, width: R * 2, height: R * 2)),
                       with: .radialGradient(Gradient(colors: [Color(0xfff2c4, a), Color(0xffa040, a * 0.5), Color(0xff6a20, 0)]), center: CGPoint(x: g.x, y: cy), startRadius: 0, endRadius: R))
            }
        }
    }

    /// How lit a cell is, 0…1, for laying the warm sprite over the cold one.
    func lightAt(_ p: CGPoint) -> Double {
        var best = 0.0
        for (c, rad, k) in lights() {
            let d = hypot(Double(p.x - c.x), Double(p.y - c.y))
            best = max(best, k * max(0, 1 - d / (rad + 0.8)))
        }
        return min(1, best * 1.3)
    }

    /// The night over everything, thinner where light reaches; the bulb's exact reach outlined.
    func night(_ ctx: inout GraphicsContext) {
        let r = f.room
        let full = f.extent ?? CGRect(x: 0, y: 0, width: CGFloat(r.w) * T, height: CGFloat(r.h) * T * K)
        let base = min(0.82, 0.3 + f.dark * 0.5)
        let ls = lights()
        ctx.drawLayer { layer in
            layer.fill(Path(full), with: .color(Color(0x03040a, base)))
            layer.blendMode = .destinationOut
            for (c, rad, k) in ls where rad > 0 {
                let g = ground(c), R = CGFloat(rad + 0.9) * T
                layer.fill(Path(ellipseIn: CGRect(x: g.x - R, y: g.y - R * K, width: R * 2, height: R * 2 * K)),
                           with: .radialGradient(Gradient(stops: [.init(color: .white.opacity(0.95 * k), location: 0),
                                                                  .init(color: .white.opacity(0.7 * k), location: 0.45),
                                                                  .init(color: .white.opacity(0), location: 1)]),
                                                 center: g, startRadius: 0, endRadius: R))
            }
        }
        if let oi = r.index(of: .otto), f.state.bulb, !f.hideHeroes, f.bulbR > 0 {
            let o = f.state.c[oi], rad = Int(f.bulbR.rounded())
            var p = Path()
            for y in 0..<r.h { for x in 0..<r.w where abs(x - o.x) + abs(y - o.y) == rad {
                p.addRect(CGRect(x: CGFloat(x) * T + 4, y: CGFloat(y) * T * K + 3, width: T - 8, height: T * K - 6))
            } }
            ctx.stroke(p, with: .color(Color(0xf2c062, 0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        }
    }

    /// Warm pools of light on the ground under every lit source.
    func glows(_ ctx: inout GraphicsContext) {
        var c = ctx; c.blendMode = .plusLighter
        for (p, rad, k) in lights() {
            let g = ground(p), R = CGFloat(min(rad, 2.5) + 0.6) * T
            c.fill(Path(ellipseIn: CGRect(x: g.x - R, y: g.y - R * K, width: R * 2, height: R * 2 * K)),
                   with: .radialGradient(Gradient(colors: [Color(0xffb45a, 0.22 * k), Color(0xffb45a, 0)]), center: g, startRadius: 0, endRadius: R))
        }
        // lit lanterns burn a little brighter than their sprite
        for (i, p) in f.room.lampPos.enumerated() where f.state.lit[i] && !f.room.nest[i] {
            let g = ground(CGPoint(x: p.x, y: p.y))
            let hc = CGPoint(x: g.x, y: g.y - 1.28 * Art.zs * T)
            let R = T * 0.6
            c.fill(Path(ellipseIn: CGRect(x: hc.x - R, y: hc.y - R, width: R * 2, height: R * 2)),
                   with: .radialGradient(Gradient(colors: [Color(0xffd27a, 0.45), Color(0xffd27a, 0)]), center: hc, startRadius: 0, endRadius: R))
        }
        for (i, p) in f.room.lampPos.enumerated() where f.state.lit[i] && f.room.nest[i] {
            let g = ground(CGPoint(x: p.x, y: p.y))
            c.fill(Path(ellipseIn: CGRect(x: g.x - T * 0.3, y: g.y - T * 0.3 * K - T * 0.1, width: T * 0.6, height: T * 0.6 * K)), with: .color(Color(0xffd77a, 0.8)))
        }
    }

    func motes(_ ctx: inout GraphicsContext) {
        var c = ctx; c.blendMode = .plusLighter
        for (li, l) in lights().enumerated() {
            for k in 0..<6 {
                let seed = Double(li * 31 + k * 7)
                let ang = f.t * (0.25 + 0.05 * Double(k)) + seed
                let rr = (0.4 + 0.5 * (0.5 + 0.5 * sin(seed * 3.1))) * min(l.1, 2)
                let g = ground(CGPoint(x: l.0.x + CGFloat(cos(ang) * rr), y: l.0.y + CGFloat(sin(ang * 0.8) * rr * 0.7)))
                let py = g.y - CGFloat((f.t * 0.12 + seed).truncatingRemainder(dividingBy: 1.0)) * T * 0.8 - T * 0.3
                let a = 0.3 * l.2 * (0.5 + 0.5 * sin(f.t * 2 + seed))
                c.fill(Path(ellipseIn: CGRect(x: g.x - 1.3, y: py - 1.3, width: 2.6, height: 2.6)), with: .color(Color(0xf2c062, a)))
            }
        }
    }
}
