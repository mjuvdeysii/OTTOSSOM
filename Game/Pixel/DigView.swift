import SwiftUI
import UIKit

// Drawing the dig into the pixel frame, and the view that runs it: one finger is a stick (push where to go), a tap
// is Otto's bead flashing.

enum DigPainter {
    static let gold = PixelArt.hex(0xFFD36B), cream = PixelArt.hex(0xFFF1C4), amber = PixelArt.hex(0xE8A020)
    static let ink = PixelArt.hex(0x0B0A18)
    static var tileCache: [Int: PSprite] = [:]

    /// One 16 × 16 cell of the tile sheet (row = tile kind, column = variant).
    static func tile(_ kind: Cell, _ variant: Int) -> PSprite? {
        let key = Int(kind.rawValue) * 8 + variant
        if let s = tileCache[key] { return s }
        guard let sheet = PixelArt.sprite("tiles") else { return nil }
        let T = 16
        var px = [UInt32](repeating: 0, count: T * T)
        for y in 0..<T { for x in 0..<T { px[y * T + x] = sheet.px[(Int(kind.rawValue) * T + y) * sheet.w + variant * T + x] | 0xFF000000 } }
        let s = PSprite(w: T, h: T, px: px)
        tileCache[key] = s
        return s
    }

    static func darken(_ c: UInt32, _ k: Double) -> UInt32 {
        let r = UInt32(Double(c & 0xff) * k), g = UInt32(Double((c >> 8) & 0xff) * k), b = UInt32(Double((c >> 16) & 0xff) * k)
        return 0xFF000000 | b << 16 | g << 8 | r
    }

    /// The wall behind a dug cell: what the cell was made of, pushed far back into the dark.
    static func backKind(_ y: Int) -> Cell {
        let d = y - DigWorld.ground
        return d < 8 ? .soil : d < 18 ? .clay : d < 38 ? .stone : .rock
    }

    static func paint(_ sim: DigSim, into f: inout Frame, cam: Double, clock: Double, stick: (CGPoint, CGPoint)?, scale: PixelScale) {
        let T = 16, W = DigWorld.W, G = DigWorld.ground
        let x0 = (f.w - W * T) / 2
        let camI = Int(cam.rounded())
        f.ox = 0; f.oy = 0
        f.clear(PixelArt.hex(0x070910))
        // the sky and what's above ground
        let groundY = G * T - camI
        if groundY > 0 {
            for y in 0..<min(f.h, groundY) {
                let k = max(0, min(1, Double(y + camI) / Double(G * T)))
                let c = PixelArt.rgb(Int(7 + 20 * k), Int(10 + 24 * k), Int(24 + 40 * k))
                for x in 0..<f.w { f.set(x, y, c) }
            }
            if let s = PixelArt.sprite("dig_surface") { f.draw(s, feet: f.w / 2, groundY - 1) }
        }
        // the ground, row by row
        let r0 = max(0, camI / T), r1 = min(DigWorld.H - 1, (camI + f.h) / T + 1)
        for ty in r0...r1 {
            for tx in 0..<W {
                let kind = sim.world.at(tx, ty)
                let sx = x0 + tx * T, sy = ty * T - camI
                let v = (tx * 7 + ty * 13) & 3
                if kind == .air {
                    guard ty > G else { continue }
                    if let s = tile(backKind(ty), v) {
                        for j in 0..<T { for i in 0..<T { f.set(sx + i, sy + j, darken(s.px[j * T + i], 0.32)) } }
                    }
                    continue
                }
                if let s = tile(kind, v) {
                    for j in 0..<T { for i in 0..<T { f.set(sx + i, sy + j, s.px[j * T + i]) } }
                }
                // edges against the dug-out dark: a lit lip on top, ink on the other sides
                if ty > G {
                    if !sim.world.at(tx, ty - 1).solid { for i in 0..<T { f.set(sx + i, sy, ink); f.blend(sx + i, sy + 1, cream, 0.18) } }
                    if !sim.world.at(tx, ty + 1).solid { for i in 0..<T { f.set(sx + i, sy + T - 1, ink) } }
                    if tx > 0 && !sim.world.at(tx - 1, ty).solid { for j in 0..<T { f.set(sx, sy + j, ink) } }
                    if tx < W - 1 && !sim.world.at(tx + 1, ty).solid { for j in 0..<T { f.set(sx + T - 1, sy + j, ink) } }
                }
            }
        }
        // the crack in what she's digging
        if let d = sim.digging, d.t > 0, let base = sim.world.at(d.x, d.y).dig, let cr = PixelArt.sprite("cracks") {
            let need = base * pow(0.75, Double(sim.claw))
            let stage = min(2, Int(d.t / need * 3))
            let sx = x0 + d.x * T, sy = d.y * T - camI
            for j in 0..<T { for i in 0..<T where cr.px[j * cr.w + stage * T + i] >> 24 > 128 { f.set(sx + i, sy + j, ink) } }
            // chips fly
            let ph = Int(clock * 20) % 4
            f.set(sx + 4 + ph * 2, sy - 1 - ph, cream)
        }

        let off = V2(Double(x0), -cam)
        // Otto at the top, holding the thread
        if groundY > -40, let o = PixelArt.sprite(sim.light < sim.lightMax * 0.25 ? "otto_dim" : "otto_idle_\(Int(clock * 3) % 4)") {
            f.draw(o, feet: Int(sim.otto.x + off.x), Int(sim.otto.y + off.y) - 1)
        }
        // Mosto in his nest at the bottom, with the stolen light
        if !sim.nestDone {
            let nx = Double(x0 + DigWorld.nestX * T), ny = Double((DigWorld.nestY + 1) * T - camI)
            if ny > -40 && ny < Double(f.h) + 40, let mo = PixelArt.sprite("mosto_carry_\(Int(clock * 4) % 2)") {
                f.draw(mo, feet: Int(nx) + 8, Int(ny) - 2 + Int(sin(clock * 2) * 2), flip: true)
            }
        }
        // Moss
        let moving = abs(sim.v.x) > 5 || sim.digging != nil
        let mName = sim.digging != nil ? "moss_run_\(Int(clock * 16) % 4)" : moving ? "moss_run_\(Int(clock * 10) % 4)" : (clock.truncatingRemainder(dividingBy: 3.7) < 0.15 ? "moss_blink" : "moss_idle_\(Int(clock * 2) % 2)")
        if let m = PixelArt.sprite(mName) {
            let blink = sim.hurtCD > 0 && Int(clock * 16) % 2 == 0
            if !blink { f.draw(m, feet: Int(sim.p.x + off.x), Int(sim.p.y + off.y) + 1, flip: sim.face < 0) }
        }

        // the dark, with light where there is light
        var lights: [(V2, Double, Double)] = []
        let frac = max(0, sim.light / sim.lightMax)
        lights.append((sim.p + off + V2(0, -10), 48 + 58 * frac, 1.0))
        lights.append((sim.otto + off + V2(-6, -25), 70, 0.9))
        if sim.t - sim.flashAt < 0.25 { lights.append((sim.p + off + V2(0, -8), 60, 1.0)) }
        for ty in r0...r1 {
            for tx in 0..<W {
                let k = sim.world.at(tx, ty)
                let c = V2(Double(x0 + tx * T + 8), Double(ty * T - camI + 9))
                switch k {
                case .amber, .blue, .red: lights.append((c, 10, 0.45))
                case .memory: lights.append((c, 22 + 3 * sin(clock * 3), 0.75))
                case .mote: lights.append((c, 9, 0.5))
                default: break
                }
            }
        }
        if !sim.nestDone { lights.append((V2(Double(x0 + DigWorld.nestX * T + 8), Double((DigWorld.nestY + 1) * T - camI - 14)), 46, 0.95)) }
        // above ground it's night, not the dark
        if groundY > 0 { lights.append((V2(Double(f.w) / 2, Double(groundY) - 60), 140, 0.6)) }
        f.night(base: 0.3, lights: lights)

        // the thread back up to Otto, over the dark: it is light
        let th = sim.thread
        if th.count > 1 {
            var prev = th[0] + off
            for k in 1..<th.count {
                let q = th[k] + off
                f.line(prev, q, gold, glow: amber)
                prev = q
            }
            f.line(prev, sim.p + off + V2(0, -8), gold, glow: amber)
        }
        // the shadows, over the dark so their eyes read
        for s in sim.shades {
            let name = s.moth ? "moth_\(Int(clock * 10) % 2)" : "shade_\(Int(clock * 6) % 2)"
            if let sp = PixelArt.sprite(name) { f.draw(sp, feet: Int(s.p.x + off.x), Int(s.p.y + off.y) + 1, flip: s.dir < 0) }
        }
        for b in sim.bits { f.set(Int(b.p.x + off.x), Int(b.p.y + off.y), b.color) }
        for pop in sim.pops {
            let a = sim.t - pop.t0
            if let s = PixelArt.sprite(pop.icon) { f.draw(s, feet: Int(pop.p.x + off.x), Int(pop.p.y + off.y - a * 26), alpha: a < 0.6 ? 1 : max(0, 1 - (a - 0.6) / 0.3)) }
        }
        // the flash
        if sim.t - sim.flashAt < 0.2 {
            let r = 10 + (sim.t - sim.flashAt) * 170
            let c = sim.p + off + V2(0, -8)
            for k in 0..<40 { let a = Double(k) / 40 * .pi * 2; f.set(Int(c.x + cos(a) * r), Int(c.y + sin(a) * r), cream) }
        }
        // a gold arrow at the edge toward the next memory stone, when it's off screen
        let nextMemory = sim.world.memories.sorted(by: { $0.key < $1.key }).first(where: { Cell(rawValue: sim.world.cells[$0.value]) == .memory })?.value
        let goalCell: Int? = nextMemory ?? (sim.nestDone ? nil : DigWorld.nestY * W + DigWorld.nestX)
        if let m = goalCell {
            let mx = m % W, my = m / W
            let c = V2(Double(x0 + mx * T + 8), Double(my * T - camI + 8))
            if c.y > Double(f.h) - 20 || c.y < 40 {
                let down = c.y > Double(f.h) - 20
                let ay = down ? f.h - 46 : 70
                let ax = Int(max(12, min(Double(f.w - 12), c.x)))
                let bob = Int(sin(clock * 5) * 2)
                for j in 0..<6 {
                    for i in -j...j {
                        f.set(ax + i, ay + (down ? j : -j) + bob, j == 5 || abs(i) == j ? ink : gold)
                    }
                }
            }
        }
        // a depth ruler down the left edge
        let firstMark = max(0, (camI / T - G) / 5 * 5)
        var dm = firstMark
        while true {
            let y = (G + dm) * T - camI
            if y > f.h { break }
            if y >= 0 && dm > 0 {
                for i in 0..<4 { f.blend(i, y, cream, 0.35) }
            }
            dm += 5
        }
        // the stick, where the finger is
        if let st = stick {
            let o = st.0, n = st.1
            let a = V2(Double(o.x / scale.pt), Double(o.y / scale.pt)), b = V2(Double(n.x / scale.pt), Double(n.y / scale.pt))
            for k in 0..<28 { let an = Double(k) / 28 * .pi * 2; f.blend(Int(a.x + cos(an) * 14), Int(a.y + sin(an) * 14), cream, 0.5) }
            var d = b - a; if d.len > 14 { d = d.norm * 14 }
            let kx = Int(a.x + d.x), ky = Int(a.y + d.y)
            for j in -2...2 { for i in -2...2 where i * i + j * j <= 5 { f.blend(kx + i, ky + j, cream, 0.75) } }
        }
    }
}

final class DigCanvas: UIView {
    var sim: DigSim
    let scale: PixelScale
    var frame_: Frame
    var link: CADisplayLink?
    var last: CFTimeInterval = 0
    var clock = 0.0
    var cam = 0.0
    var onEvents: (([DigEvent]) -> Void)?
    var onTick: ((DigSim) -> Void)?
    var paused = false
    var demo = false
    var origin: CGPoint?
    var finger: CGPoint?
    var downAt: CFTimeInterval = 0
    var moved = false
    var command: String?            // set from SwiftUI: "reel", "closeMemory"
    var shake = 0.0

    init(sim: DigSim, scale: PixelScale) {
        self.sim = sim; self.scale = scale
        frame_ = Frame(w: scale.w, h: scale.h)
        super.init(frame: .zero)
        layer.magnificationFilter = .nearest
        layer.contentsGravity = .resize
        layer.contentsScale = UIScreen.main.scale / CGFloat(scale.k)
        isMultipleTouchEnabled = false
        backgroundColor = .black
        cam = targetCam()
    }
    required init?(coder: NSCoder) { fatalError() }

    func targetCam() -> Double {
        let h = Double(scale.h)
        let minCam = Double(DigWorld.ground * 16) - h * 0.42
        let maxCam = Double(DigWorld.H * 16) - h
        return max(minCam, min(maxCam, sim.p.y - h * 0.45))
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, link == nil {
            let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
            l.add(to: .main, forMode: .common); link = l
        } else if window == nil { link?.invalidate(); link = nil }
    }

    @objc func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        let dt = last == 0 ? 1.0 / 60 : min(1.0 / 20, now - last)
        last = now
        clock += dt
        if let c = command {
            command = nil
            if c == "reel" { sim.reelIn() }
            if c == "closeMemory" { sim.openMemory = nil }
        }
        if demo && !paused { demoSteer() }
        if !paused && sim.openMemory == nil {
            sim.step(dt)
        }
        if !sim.events.isEmpty {
            for e in sim.events {
                switch e {
                case .land: shake = max(shake, 0.12)
                case .gem, .hurt, .nest: shake = max(shake, 0.18)
                default: break
                }
            }
            onEvents?(sim.events); sim.events = []
        }
        if shake > 0 {
            shake -= dt
            let a = CGFloat(scale.pt) * (shake > 0 ? 1 : 0)
            transform = CGAffineTransform(translationX: Int(clock * 60) % 2 == 0 ? a : -a, y: Int(clock * 47) % 2 == 0 ? a : 0)
        } else if transform != .identity { transform = .identity }
        onTick?(sim)
        cam += (targetCam() - cam) * min(1, dt * 6)
        let st: (CGPoint, CGPoint)? = origin.flatMap { o in finger.map { (o, $0) } }
        DigPainter.paint(sim, into: &frame_, cam: cam, clock: clock, stick: st, scale: scale)
        layer.contents = frame_.cgImage()
    }

    /// CI screenshots: dig down, wander sideways now and then, flash at shadows.
    private func demoSteer() {
        let k = Int(clock / 1.6) % 5
        let s: V2 = k == 1 ? V2(1, 0) : k == 3 ? V2(-1, 0) : V2(0, 1)
        sim.push(s)
        if sim.shades.contains(where: { $0.p.dist(sim.p) < 30 }) { sim.flash() }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        origin = t.location(in: self); finger = origin; downAt = t.timestamp; moved = false
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let o = origin else { return }
        let p = t.location(in: self)
        finger = p
        let d = V2(Double(p.x - o.x), Double(p.y - o.y))
        if d.len > 10 { moved = true }
        // 28 points of push is full stick; past that the ring follows the finger
        let full = 28.0
        var s = d * (1 / full)
        if s.len > 1 { s = s.norm }
        if d.len > full * 1.6 {
            let back = d.norm * (full * 1.6)
            origin = CGPoint(x: p.x - back.x, y: p.y - back.y)
        }
        sim.push(d.len > 6 ? s : V2(0, 0))
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        if !moved && t.timestamp - downAt < 0.3 { sim.flash() }
        sim.push(V2(0, 0)); origin = nil; finger = nil
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { sim.push(V2(0, 0)); origin = nil; finger = nil }
}

struct DigCanvasView: UIViewRepresentable {
    let sim: DigSim
    let scale: PixelScale
    var paused: Bool
    var demo = false
    @Binding var command: String?
    var onEvents: ([DigEvent]) -> Void
    var onTick: (DigSim) -> Void

    func makeUIView(context: Context) -> DigCanvas {
        let v = DigCanvas(sim: sim, scale: scale)
        v.onEvents = onEvents; v.onTick = onTick; v.demo = demo
        return v
    }
    func updateUIView(_ v: DigCanvas, context: Context) {
        v.paused = paused
        if let c = command { v.command = c; DispatchQueue.main.async { command = nil } }
    }
}
