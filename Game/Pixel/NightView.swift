import SwiftUI
import UIKit

/// The pixel font (Fusion Pixel, OFL): crisp only at whole multiples of its 12-pixel grid.
enum PixelFont {
    static let name = "Fusion-Pixel-12px-Prop-zh_hans-Regular"
    /// Size in points so each font pixel is `px` game pixels of `k` device pixels.
    static func font(_ step: Int = 1, k: Int) -> Font {
        let s = UIScreen.main.scale
        return .custom(name, fixedSize: CGFloat(12 * step * k) / s)
    }
}

/// How big a game pixel is on this screen: a whole number of device pixels, so the art never shimmers.
struct PixelScale {
    let k: Int            // device pixels per game pixel
    let w: Int, h: Int    // the game's size in game pixels
    init(size: CGSize) {
        let s = UIScreen.main.scale
        let wp = Int(size.width * s), hp = Int(size.height * s)
        k = max(2, Int((Double(wp) / 192).rounded()))
        w = wp / k; h = hp / k
    }
    var pt: CGFloat { CGFloat(k) / UIScreen.main.scale }     // points per game pixel
}

// MARK: drawing a night

enum NightPainter {
    static let gold = PixelArt.hex(0xFFD36B), cream = PixelArt.hex(0xFFF1C4), amber = PixelArt.hex(0xE8A020)
    static let violet = PixelArt.hex(0xA68CF2), red = PixelArt.hex(0xE8503A)
    static let ottoBead = V2(-6, -25), mossHand = V2(0, -6)

    static func paint(_ sim: NightSim, into f: inout Frame, clock: Double) {
        if let bg = PixelArt.sprite("place_\(sim.spec.place)") { f.ox = 0; f.oy = 0; f.back(bg) } else { f.clear(PixelArt.hex(0x141a33)) }
        let sh = sim.shake
        f.ox = sh > 0 ? Int((sin(clock * 70) * 2 * sh).rounded()) : 0
        f.oy = sh > 0 ? Int((cos(clock * 53) * 2 * sh).rounded()) : 0

        // Moss's trail on the ground: bright where it's new, broken where it's fading
        let tr = sim.trail
        if tr.count > 1 {
            for i in 1..<tr.count {
                let age = (sim.t - tr[i].1) / sim.trailLife
                let c = age < 0.35 ? cream : age < 0.7 ? gold : amber
                if age > 0.7 && i % 2 == 0 { continue }
                f.line(tr[i - 1].0, tr[i].0, c)
            }
        }
        // a caught loop flashes
        if sim.t - sim.lastLoopAt < 0.25, !sim.lastLoop.isEmpty {
            let k = 1 - (sim.t - sim.lastLoopAt) / 0.25
            let xs = sim.lastLoop.map { $0.x }, ys = sim.lastLoop.map { $0.y }
            for y in Int(ys.min()!)...Int(ys.max()!) { for x in Int(xs.min()!)...Int(xs.max()!) where (x + y) % 2 == 0 {
                if Geo.inside(V2(Double(x), Double(y)), sim.lastLoop) { f.add(x, y, gold, 0.3 * k) }
            } }
        }

        // everyone, back to front
        var items: [(Double, (inout Frame) -> Void)] = []
        let fr = Int(clock * 6)
        if let m = sim.maw, m.hp > 0 {
            items.append((m.p.y, { f in
                if let s = PixelArt.sprite("maw_\(fr % 2)_\(min(3, m.belly + (m.belly > 0 ? 1 : 0)))") {
                    f.draw(s, feet: Int(m.p.x), Int(m.p.y) + 20, tint: m.hurt > 0.3 ? cream : nil)
                }
            }))
        }
        let ottoName = sim.light < 15 ? "otto_dim" : (clock.truncatingRemainder(dividingBy: 4.3) < 0.15 ? "otto_blink" : "otto_idle_\(Int(clock * 3) % 4)")
        items.append((sim.otto.y, { f in if let s = PixelArt.sprite(ottoName) { f.draw(s, feet: Int(sim.otto.x), Int(sim.otto.y)) } }))
        let moving = sim.mossV.len > 20
        let mossName = moving ? "moss_run_\(Int(clock * 12) % 4)" : (clock.truncatingRemainder(dividingBy: 3.7) < 0.15 ? "moss_blink" : "moss_idle_\(Int(clock * 2) % 2)")
        items.append((sim.moss.y, { f in if let s = PixelArt.sprite(mossName) { f.draw(s, feet: Int(sim.moss.x), Int(sim.moss.y) + 4, flip: sim.mossV.x < -5) } }))
        if let th = sim.thief, th.state < 3 {
            let n = th.state == 2 ? "mosto_caught" : th.sack > 0 ? "mosto_carry_\(Int(clock * 8) % 2)" : "mosto_fly_\(Int(clock * 8) % 2)"
            items.append((th.p.y, { f in if let s = PixelArt.sprite(n) { f.draw(s, feet: Int(th.p.x), Int(th.p.y) + 10, flip: th.state == 1 && th.exit.x < th.p.x) } }))
        }
        for it in items.sorted(by: { $0.0 < $1.0 }) { it.1(&f) }

        // the night, with light where there is light
        var lights: [(V2, Double, Double)] = [(sim.otto + ottoBead, sim.threadLen * 1.15 + 10, 1.0)]
        for m in sim.motes { lights.append((m.p, 7, 0.7)) }
        if let th = sim.thief, th.sack > 0, th.state == 1 { lights.append((th.p, 16, 0.8)) }
        if let m = sim.maw, m.belly > 0 { lights.append((m.p + V2(0, 8), 12 + Double(m.belly) * 6, 0.7)) }
        let fx = f.ox, fy = f.oy
        f.ox = 0; f.oy = 0
        f.night(base: 0.42, lights: lights.map { (V2($0.0.x + Double(fx), $0.0.y + Double(fy)), $0.1, $0.2) })
        f.ox = fx; f.oy = fy

        // the shadows come after the night: they are the night, and their eyes have to read in it
        var shadows: [(Double, (inout Frame) -> Void)] = []
        for fo in sim.foes {
            let name: String
            switch fo.type {
            case .shade: name = "shade_\(fr % 2)"
            case .shell: name = "shell_\(fr % 2)"
            case .moth: name = "moth_\(Int(clock * 10) % 2)"
            case .fang: name = "fang_\(fr % 2)"
            }
            shadows.append((fo.p.y, { f in
                if let s = PixelArt.sprite(name) { f.draw(s, feet: Int(fo.p.x), Int(fo.p.y) + 4, flip: fo.v.x < 0, tint: fo.hitCD > 0.1 ? cream : nil) }
                if fo.type == .fang && fo.state == 1 && Int(clock * 8) % 2 == 0 {
                    f.rect(Int(fo.p.x), Int(fo.p.y) - 18, 1, 4, red); f.set(Int(fo.p.x), Int(fo.p.y) - 12, red)
                }
            }))
        }
        for it in shadows.sorted(by: { $0.0 < $1.0 }) { it.1(&f) }

        // the thread, over the dark: it is light
        let a = sim.otto + ottoBead, b = sim.moss + mossHand
        let taut = sim.moss.dist(sim.otto) >= sim.threadLen - 1
        f.line(a, b, taut ? cream : gold, glow: amber)
        // Otto's bead burns
        f.add(Int(a.x), Int(a.y), cream, 1)
        for m in sim.motes {
            let tw = Int(clock * 8 + Double(m.id)) % 4
            if let s = PixelArt.sprite("mote_\(tw)") { f.draw(s, feet: Int(m.p.x), Int(m.p.y) + 2) }
        }
        for s in sim.sparks { f.set(Int(s.p.x), Int(s.p.y), s.color) }
        f.ox = 0; f.oy = 0

        // light and dawn, as two pixel bars at the top
        let bw = f.w - 40, lx = 20, ly = 31
        f.rect(lx - 1, ly - 1, bw + 2, 6, PixelArt.hex(0x0b0a18))
        let filled = Int(Double(bw) * max(0, min(1, sim.hud.light)))
        for x in 0..<bw { f.rect(lx + x, ly, 1, 4, x < filled ? (x % 4 == 3 ? amber : gold) : PixelArt.hex(0x241c34)) }
        if sim.light < sim.lightMax * 0.25 && Int(clock * 4) % 2 == 0 { f.rect(lx, ly, filled, 4, red) }
        let dw = Int(Double(bw) * sim.hud.dawn)
        f.rect(lx - 1, ly + 6, bw + 2, 3, PixelArt.hex(0x0b0a18))
        f.rect(lx, ly + 7, dw, 1, PixelArt.hex(0xF0A0B8))
        // the wake: a ring round Otto when he can be woken and the light is low
        if sim.wakeCD <= 0 && sim.light < sim.lightMax * 0.45 && Int(clock * 3) % 2 == 0 {
            let c = sim.otto + V2(0, -12)
            for k in 0..<24 { let an = Double(k) / 24 * .pi * 2; f.set(Int(c.x + cos(an) * 15), Int(c.y + sin(an) * 17), cream) }
        }
    }
}

// MARK: the view

final class NightCanvas: UIView {
    var sim: NightSim
    var scale: PixelScale
    var frame_: Frame
    var link: CADisplayLink?
    var last: CFTimeInterval = 0
    var clock = 0.0
    var onEvents: (([NightEvent]) -> Void)?
    var onTick: ((NightSim) -> Void)?
    var downAt: (CGPoint, CFTimeInterval)?
    var paused = false
    var demo = false        // CI screenshots: the bot plays
    var bot = NightBot()

    init(sim: NightSim, scale: PixelScale) {
        self.sim = sim; self.scale = scale
        frame_ = Frame(w: scale.w, h: scale.h)
        super.init(frame: .zero)
        layer.magnificationFilter = .nearest
        layer.contentsGravity = .topLeft
        layer.contentsScale = UIScreen.main.scale / CGFloat(scale.k)
        isMultipleTouchEnabled = false
        backgroundColor = .black
    }
    required init?(coder: NSCoder) { fatalError() }

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
        if demo && !paused { bot.steer(&sim, dt) }
        if !paused {
            sim.step(dt)
            if !sim.events.isEmpty { onEvents?(sim.events); sim.events = [] }
            onTick?(sim)
        } else { sim.step(0) }
        NightPainter.paint(sim, into: &frame_, clock: clock)
        layer.contents = frame_.cgImage()
    }

    func game(_ p: CGPoint) -> V2 { V2(Double(p.x / scale.pt), Double(p.y / scale.pt)) }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        downAt = (p, t.timestamp)
        sim.touch(game(p))
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        sim.touch(game(t.location(in: self)))
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        // a quick tap on Otto wakes him
        if let (p0, t0) = downAt, t.timestamp - t0 < 0.25, hypot(p.x - p0.x, p.y - p0.y) < 12 {
            let g = game(p)
            if g.dist(sim.otto + V2(0, -12)) < 18, sim.wake() { onEvents?([.wake]) }
        }
        sim.touch(nil); downAt = nil
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { sim.touch(nil); downAt = nil }
}

struct NightCanvasView: UIViewRepresentable {
    let spec: NightSpec
    let scale: PixelScale
    let seed: UInt64
    let upgrades: [String: Int]
    var paused: Bool
    var demo = false
    var onEvents: ([NightEvent]) -> Void
    var onTick: (NightSim) -> Void

    func makeUIView(context: Context) -> NightCanvas {
        let v = NightCanvas(sim: NightSim(spec: spec, w: Double(scale.w), h: Double(scale.h), seed: seed, upgrades: upgrades), scale: scale)
        v.onEvents = onEvents; v.onTick = onTick; v.demo = demo
        return v
    }
    func updateUIView(_ v: NightCanvas, context: Context) { v.paused = paused }
}
