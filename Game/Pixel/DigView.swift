import SwiftUI
import UIKit

// Drawing the dig into the pixel frame, and the view that runs it: one finger is a stick (push where to go), a tap
// is Otto's bead flashing.

enum DigPainter {
    static let gold = PixelArt.hex(0xFFD36B), cream = PixelArt.hex(0xFFF1C4), amber = PixelArt.hex(0xE8A020), red = PixelArt.hex(0xFF6A5A)
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

    /// A sprite's silhouette, scaled, as a shadow on the wall.
    static func shadow(_ s: PSprite, feetX: Double, feetY: Double, scale k: Double, crown: Bool, into f: inout Frame) {
        let col = PixelArt.hex(0x0A0614)
        let w = Int(Double(s.w) * k), h = Int(Double(s.h) * k)
        let x0 = Int(feetX) - w / 2, y0 = Int(feetY) - h
        for j in 0..<h {
            for i in 0..<w {
                let sx = min(s.w - 1, Int(Double(i) / k)), sy = min(s.h - 1, Int(Double(j) / k))
                if s.px[sy * s.w + sx] >> 24 > 128 { f.blend(x0 + i, y0 + j, col, 0.6) }
            }
        }
        if crown {
            let cx = x0 + w / 2 + 2, cy = y0 + Int(2 * k)
            for i in -4...4 { f.blend(cx + i, cy, col, 0.7); f.blend(cx + i, cy - 1, col, 0.7) }
            for i in [-4, 0, 4] { for j in 2...4 { f.blend(cx + i, cy - j, col, 0.7) } }
        }
    }

    /// The wall behind a dug cell: what the cell was made of, pushed far back into the dark.
    static func backKind(_ y: Int) -> Cell {
        let d = y - DigWorld.ground
        return d < 8 ? .soil : d < 18 ? .clay : d < 38 ? .stone : .rock
    }

    static func paint(_ sim: DigSim, into f: inout Frame, cam: Double, clock: Double, stick: (CGPoint, CGPoint)?, scale: PixelScale, hud: V2 = V2(170, 40)) {
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
                    if kind.claw > sim.claw {
                        // too hard for the claw she has: pushed back into the dark, hatched
                        for j in 0..<T { for i in 0..<T { f.set(sx + i, sy + j, (i + j) % 6 == 0 ? darken(s.px[j * T + i], 0.25) : darken(s.px[j * T + i], 0.55)) } }
                    } else {
                        for j in 0..<T { for i in 0..<T { f.set(sx + i, sy + j, s.px[j * T + i]) } }
                    }
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
        if let cr = PixelArt.sprite("cracks") {
            for (key, t) in sim.damage where t > 0 {
                let cx = key % W, cy = key / W
                guard let base = sim.world.at(cx, cy).dig else { continue }
                let need = base * pow(0.75, Double(sim.claw))
                let stage = min(2, Int(t / need * 3))
                let sx = x0 + cx * T, sy = cy * T - camI
                guard sy > -T, sy < f.h else { continue }
                for j in 0..<T { for i in 0..<T where cr.px[j * cr.w + stage * T + i] >> 24 > 128 { f.set(sx + i, sy + j, ink) } }
            }
        }
        if let d = sim.digging, d.t > 0 {
            // chips fly off what she's digging now
            let sx = x0 + d.x * T, sy = d.y * T - camI
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
        // her own shadow on the wall behind her: it grows with what she carries, and past six things wears a crown
        if let ms = PixelArt.sprite("moss_idle_0") {
            let n = Double(sim.bag.count)
            let k = 1.0 + min(1.3, n * 0.13)
            shadow(ms, feetX: sim.p.x + off.x - 3 - n * 0.5, feetY: sim.p.y + off.y - 1, scale: k, crown: sim.bag.count >= 6, into: &f)
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
                case .amber, .blue, .red: if k.claw <= sim.claw { lights.append((c, 10, 0.45)) }
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
        if let h = sim.hardAt, sim.t - h.t < 0.5, Int((sim.t - h.t) * 10) % 2 == 0 {
            let sx = x0 + h.x * T, sy = h.y * T - camI
            for k in 2..<(T - 2) { f.set(sx + k, sy + k, red); f.set(sx + T - 1 - k, sy + k, red) }
        }
        // the very first night, before she's dug at all: a pulse under her says "down here"
        if !sim.started && sim.t > 1.2 {
            let c = sim.p + off + V2(0, 8)
            let r = 6 + (clock.truncatingRemainder(dividingBy: 1)) * 6
            for k in 0..<24 { let an = Double(k) / 24 * .pi * 2; f.blend(Int(c.x + cos(an) * r), Int(c.y + sin(an) * r * 0.6), cream, 0.8) }
            let bob = Int(sin(clock * 6) * 2)
            for j in 0..<5 { for i in -(4 - j)...(4 - j) { f.set(Int(c.x) + i, Int(c.y) + 12 + j + bob, gold) } }
        }
        // what she picks up flies to the bag at the top of the screen
        for pop in sim.pops {
            let a = min(1, (sim.t - pop.t0) / 0.6)
            let from = pop.p + off
            let e = a * a
            let q = V2(from.x + (hud.x - from.x) * e, from.y + (hud.y - from.y) * e - sin(a * .pi) * 16)
            if let s = PixelArt.sprite(pop.icon) { f.draw(s, feet: Int(q.x), Int(q.y)) }
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
        // where the finger is
        if let st = stick {
            let a = V2(Double(st.1.x / scale.pt), Double(st.1.y / scale.pt))
            for k in 0..<24 { let an = Double(k) / 24 * .pi * 2; f.blend(Int(a.x + cos(an) * 9), Int(a.y + sin(an) * 9), cream, 0.45) }
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
    var drawnPaused = false
    var hudTarget: V2 { V2(Double(scale.w) - 30, Double(SafeArea.top / scale.pt) + 14) }

    init(sim: DigSim, scale: PixelScale) {
        self.sim = sim; self.scale = scale
        frame_ = Frame(w: scale.w, h: scale.h)
        super.init(frame: .zero)
        layer.magnificationFilter = .nearest
        layer.contentsGravity = .resize
        layer.contentsScale = UIScreen.main.scale / CGFloat(scale.k)
        isMultipleTouchEnabled = true
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
            if c == "drop" { sim.bag = Bag() }
        }
        if demo && !paused { demoSteer() }
        link?.preferredFrameRateRange = paused ? CAFrameRateRange(minimum: 4, maximum: 10, preferred: 10) : CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
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
        // paused: one last frame, then nothing until it goes again
        if paused || sim.openMemory != nil {
            if drawnPaused { return }
            drawnPaused = true
        } else { drawnPaused = false }
        DigPainter.paint(sim, into: &frame_, cam: cam, clock: clock, stick: st, scale: scale, hud: hudTarget)
        layer.contents = frame_.cgImage()
    }

    /// CI screenshots: dig down, wander sideways now and then, flash at shadows.
    private func demoSteer() {
        let k = Int(clock / 1.6) % 5
        let s: V2 = k == 1 ? V2(1, 0) : k == 3 ? V2(-1, 0) : V2(0, 1)
        sim.push(s)
        if sim.shades.contains(where: { $0.p.dist(sim.p) < 30 }) { sim.flash() }
    }

    // Touch: the first finger presses where she should go — beside her to walk or dig that way, below to dig down,
    // above to jump (once per press) or dig up. A quick tap on Moss herself, or a second finger anywhere, flashes the bead.
    var driver: UITouch?
    var pressedOnMoss = false

    func mossOnScreen() -> V2 {
        let x0 = Double((scale.w - DigWorld.W * 16) / 2)
        return V2(x0 + sim.p.x, sim.p.y - 8 - cam)
    }

    /// The one direction a finger at this point means.
    func direction(_ p: CGPoint) -> V2 {
        let d = V2(Double(p.x / scale.pt), Double(p.y / scale.pt)) - mossOnScreen()
        if d.len < 11 { return V2(0, 0) }
        if abs(d.y) > abs(d.x) * 1.15 { return V2(0, d.y > 0 ? 1 : -1) }
        return V2(d.x > 0 ? 1 : -1, 0)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if driver == nil {
                driver = t
                let p = t.location(in: self)
                finger = p; origin = p; downAt = t.timestamp; moved = false
                let d = direction(p)
                pressedOnMoss = d.len == 0
                sim.push(d)
                if d.y < 0 { sim.jump() }
            } else {
                sim.flash()
            }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = driver, touches.contains(t) else { return }
        let p = t.location(in: self)
        if let o = origin, hypot(p.x - o.x, p.y - o.y) > 10 { moved = true }
        finger = p
        let d = direction(p)
        if d.y < 0 && sim.stick.y >= 0 { sim.jump() }
        sim.push(d)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = driver, touches.contains(t) else { return }
        if pressedOnMoss && !moved && t.timestamp - downAt < 0.35 { sim.flash() }
        driver = nil; sim.push(V2(0, 0)); origin = nil; finger = nil
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        driver = nil; sim.push(V2(0, 0)); origin = nil; finger = nil
    }
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
