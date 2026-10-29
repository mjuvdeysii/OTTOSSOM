import Foundation
import CoreGraphics

// 《灯台索魔》 — one night. Otto keeps the lamp; Moss runs where your finger is; a thread of light joins them.
// Shadows the thread sweeps through break into motes of light; a loop Moss's glowing trail closes catches everything
// inside it. The thread is as long as Otto's light is bright; shadows that reach Otto drink it. Last till dawn.
// Pure and deterministic: the view drives it, the tests play it with a bot.

struct V2: Equatable {
    var x: Double, y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    static func + (a: V2, b: V2) -> V2 { V2(a.x + b.x, a.y + b.y) }
    static func - (a: V2, b: V2) -> V2 { V2(a.x - b.x, a.y - b.y) }
    static func * (a: V2, k: Double) -> V2 { V2(a.x * k, a.y * k) }
    var len: Double { (x * x + y * y).squareRoot() }
    var norm: V2 { let l = len; return l > 1e-9 ? V2(x / l, y / l) : V2(0, 0) }
    func dist(_ o: V2) -> Double { (self - o).len }
}

enum Geo {
    /// Distance from p to the segment ab.
    static func segDist(_ p: V2, _ a: V2, _ b: V2) -> Double {
        let ab = b - a, ap = p - a
        let l2 = ab.x * ab.x + ab.y * ab.y
        let t = l2 > 0 ? max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / l2)) : 0
        return p.dist(a + ab * t)
    }
    /// Where segments ab and cd cross, if they do.
    static func cross(_ a: V2, _ b: V2, _ c: V2, _ d: V2) -> V2? {
        let r = b - a, s = d - c
        let den = r.x * s.y - r.y * s.x
        if abs(den) < 1e-9 { return nil }
        let t = ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / den
        let u = ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / den
        return (t > 0 && t < 1 && u > 0 && u < 1) ? a + r * t : nil
    }
    static func inside(_ p: V2, _ poly: [V2]) -> Bool {
        var c = false
        var j = poly.count - 1
        for i in 0..<poly.count {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { c.toggle() }
            j = i
        }
        return c
    }
    static func area(_ poly: [V2]) -> Double {
        var s = 0.0
        for i in 0..<poly.count { let a = poly[i], b = poly[(i + 1) % poly.count]; s += a.x * b.y - b.x * a.y }
        return abs(s) / 2
    }
}

enum FoeType: String, Codable { case shade, shell, moth, fang }

struct Foe {
    var id: Int
    var type: FoeType
    var p: V2
    var v = V2(0, 0)
    var hp: Int
    var state = 0          // fang: 0 approach, 1 wind-up, 2 charge, 3 recover
    var timer = 0.0
    var hitCD = 0.0
    var dir = V2(0, 0)
    var seed: Double
    var radius: Double { type == .shell ? 7 : type == .moth ? 6 : 6 }
}

struct Mote { var id: Int; var p: V2; var v: V2; var age = 0.0 }

struct Spark { var p: V2; var v: V2; var life: Double; var color: UInt32 }

struct Thief {
    var p: V2
    var state = 0          // 0 flying in, 1 fleeing with the light, 2 caught (dizzy, then gone), 3 gone
    var sack = 0.0
    var stun = 0.0
    var timer = 0.0
    var exit = V2(0, 0)
}

struct Maw {
    var p: V2
    static let maxHP = 10
    var hp = Maw.maxHP
    var belly = 0          // motes swallowed: its belly glows from 2
    var spit = 4.0
    var drift = 0.0
    var hurt = 0.0
}

struct Wave: Codable { var t: Double; var type: FoeType; var n: Int }

struct NightSpec: Codable {
    var id: Int
    var name: String
    var place: String          // background
    var dawn: Double           // seconds to dawn (0: until the boss falls)
    var drain: Double          // light lost per second
    var waves: [Wave]
    var thiefAt: Double?       // Mosto comes to steal
    var boss: Bool?
    var teach: String?
}

enum NightEvent: Equatable {
    case pop(FoeType), loop(Int), mote, drink, wake, steal, caught, escaped, mawHit, mawDown, bounce, dawn, dark
}

struct NightSim {
    // the world
    let W: Double, H: Double
    let spec: NightSpec
    var t = 0.0
    var otto: V2
    var moss: V2
    var mossV = V2(0, 0)
    var target: V2?
    var light = 70.0
    var lightMax = 100.0
    var wakeCD = 0.0
    var trail: [(V2, Double)] = []      // Moss's glowing trail: point and the time it was made
    var foes: [Foe] = []
    var motes: [Mote] = []
    var sparks: [Spark] = []
    var thief: Thief?
    var maw: Maw?
    var rng: Rng
    var nextID = 1
    var waveAt = 0
    var collected = 0
    var bestLoop = 0
    var events: [NightEvent] = []
    var lastLoop: [V2] = []
    var lastLoopAt = -9.0
    var outcome = 0                      // 0 playing, 1 dawn, -1 the light went out
    var shake = 0.0

    // upgrades
    var trailLife = 1.1
    var mossSpeed = 175.0
    var guardK = 1.0                     // how much a touch on Otto drinks
    var wakeTime = 12.0

    var threadLen: Double { 30 + light * 0.55 }
    var hud: (light: Double, dawn: Double) { (light / lightMax, spec.dawn > 0 ? min(1, t / spec.dawn) : maw.map { 1 - Double($0.hp) / Double(Maw.maxHP) } ?? 0) }

    init(spec: NightSpec, w: Double, h: Double, seed: UInt64, upgrades: [String: Int] = [:]) {
        self.spec = spec; W = w; H = h
        otto = V2(w / 2, h * 0.56)
        moss = V2(w / 2, h * 0.56 + 22)
        rng = Rng(seed)
        let u = upgrades
        lightMax = 100 + Double(u["wick"] ?? 0) * 20
        light = lightMax * 0.7
        guardK = 1 - Double(u["shade"] ?? 0) * 0.15
        mossSpeed = 175 + Double(u["leaf"] ?? 0) * 20
        trailLife = 1.1 + Double(u["glow"] ?? 0) * 0.25
        wakeTime = 12 - Double(u["snore"] ?? 0) * 2.5
        if spec.boss == true { maw = Maw(p: V2(w / 2, h * 0.24)) }
    }

    var threadLenFor: Double { threadLen }

    // MARK: input

    mutating func touch(_ p: V2?) { target = p }

    /// A tap on Otto wakes him: a burst of light, then a wait.
    mutating func wake() -> Bool {
        guard wakeCD <= 0, outcome == 0 else { return false }
        light = min(lightMax, light + 14)
        wakeCD = wakeTime
        events.append(.wake)
        burst(otto + V2(0, -18), 10, 0xFF6BD3FF)
        return true
    }

    // MARK: the step

    mutating func step(_ dt: Double) {
        guard outcome == 0 else { decay(dt); return }
        t += dt
        wakeCD = max(0, wakeCD - dt)
        shake = max(0, shake - dt * 3)
        light -= spec.drain * dt
        spawn()
        moveMoss(dt)
        threadHits()
        loops()
        moveFoes(dt)
        moveMotes(dt)
        moveThief(dt)
        moveMaw(dt)
        decay(dt)
        if light <= 0 { light = 0; outcome = -1; events.append(.dark) }
        else if spec.dawn > 0 && t >= spec.dawn && thief.map({ $0.state >= 2 }) ?? true { outcome = 1; events.append(.dawn) }
        else if spec.boss == true, let m = maw, m.hp <= 0 { outcome = 1; events.append(.dawn) }
    }

    private mutating func spawn() {
        while waveAt < spec.waves.count && spec.waves[waveAt].t <= t {
            let w = spec.waves[waveAt]; waveAt += 1
            for _ in 0..<w.n { foes.append(makeFoe(w.type, at: edgePoint())) }
        }
        if let at = spec.thiefAt, thief == nil, t >= at {
            thief = Thief(p: V2(rng.unit() < 0.5 ? -10 : W + 10, H * 0.15))
        }
    }

    private mutating func edgePoint() -> V2 {
        let side = Int(rng.next() % 4)
        let r = rng.unit()
        switch side {
        case 0: return V2(r * W, -8)
        case 1: return V2(W + 8, 20 + r * (H - 60))
        case 2: return V2(r * W, H + 8)
        default: return V2(-8, 20 + r * (H - 60))
        }
    }

    mutating func makeFoe(_ type: FoeType, at p: V2) -> Foe {
        defer { nextID += 1 }
        return Foe(id: nextID, type: type, p: p, hp: type == .shell ? 99 : 1, seed: rng.unit() * 10)
    }

    private mutating func moveMoss(_ dt: Double) {
        if let tg = target {
            let d = tg - moss
            let want = d.len > 1 ? d.norm * min(mossSpeed, d.len * 14) : V2(0, 0)
            mossV = mossV + (want - mossV) * min(1, dt * 18)
        } else {
            mossV = mossV * max(0, 1 - dt * 10)
        }
        moss = moss + mossV * dt
        moss = V2(max(4, min(W - 4, moss.x)), max(14, min(H - 4, moss.y)))
        // the thread: at full stretch Moss tugs Otto along, slowly; she can't get farther than it reaches
        let L = threadLen
        let d = moss.dist(otto)
        if d > L {
            let pull = (moss - otto).norm
            otto = otto + pull * min(d - L, 30 * dt)
            let d2 = moss.dist(otto)
            if d2 > L { moss = otto + (moss - otto).norm * L }
        }
        otto = V2(max(8, min(W - 8, otto.x)), max(24, min(H - 8, otto.y)))
        if let last = trail.last?.0, last.dist(moss) < 1.5 { } else { trail.append((moss, t)) }
        trail.removeAll { t - $0.1 > trailLife }
    }

    private mutating func threadHits() {
        let a = otto + V2(-6, -25), b = moss + V2(0, -6)
        for i in foes.indices {
            guard foes[i].hitCD <= 0, Geo.segDist(foes[i].p, a, b) < foes[i].radius + 1 else { continue }
            if foes[i].type == .shell {
                // the thread only clinks off the shell: it has to be looped
                foes[i].v = (foes[i].p - otto).norm * 25; foes[i].hitCD = 0.5
                events.append(.bounce)
                sparks.append(Spark(p: foes[i].p + V2(0, -6), v: V2(0, -14), life: 0.25, color: 0xFFC4C0D0))
            } else {
                foes[i].hp -= 1; foes[i].hitCD = 0.2
            }
        }
        if var th = thief, th.state <= 1, Geo.segDist(th.p, a, b) < 8, th.stun <= 0 { th.stun = 0.7; thief = th; events.append(.bounce) }
        reap()
    }

    /// Moss's trail crossing itself closes a loop: everything inside is caught.
    private mutating func loops() {
        guard trail.count >= 6 else { return }
        let n = trail.count
        let a = trail[n - 2].0, b = trail[n - 1].0
        for i in 0..<(n - 4) {
            guard let x = Geo.cross(a, b, trail[i].0, trail[i + 1].0) else { continue }
            var poly = [x]
            for k in (i + 1)...(n - 2) { poly.append(trail[k].0) }
            guard Geo.area(poly) > 70 else { continue }
            catchInside(poly)
            trail.removeFirst(n - 1)
            return
        }
    }

    private mutating func catchInside(_ poly: [V2]) {
        var caught = 0
        for i in foes.indices where Geo.inside(foes[i].p, poly) { foes[i].hp = -99; caught += 1 }
        for m in motes where Geo.inside(m.p, poly) { take(m) }
        if var th = thief, th.state <= 1, Geo.inside(th.p, poly) {
            th.state = 2; th.timer = 1.2
            let back = th.sack + 10
            light = min(lightMax, light + back)
            for _ in 0..<8 { motes.append(Mote(id: nextID, p: th.p, v: V2(rng.unit() * 60 - 30, rng.unit() * 60 - 30))); nextID += 1 }
            th.sack = 0
            thief = th
            events.append(.caught); caught += 3; shake = 1
        }
        if var m = maw, Geo.inside(m.p, poly) {
            m.hp -= m.belly >= 2 ? 3 : 1
            m.belly = 0; m.hurt = 0.5
            maw = m
            events.append(m.hp <= 0 ? .mawDown : .mawHit); caught += 2; shake = 1
            burst(m.p, 24, 0xFF50B0FF)
        }
        if caught > 0 {
            bestLoop = max(bestLoop, caught)
            events.append(.loop(caught))
            if caught >= 3 { shake = max(shake, 0.6) }
        }
        lastLoop = poly; lastLoopAt = t
        reap()
    }

    private mutating func reap() {
        var keep: [Foe] = []
        for f in foes {
            if f.hp <= 0 {
                events.append(.pop(f.type))
                burst(f.p, 8, 0xFF2A2630)
                let drops = f.type == .shell ? 3 : f.type == .fang ? 2 : 1
                for _ in 0..<drops { motes.append(Mote(id: nextID, p: f.p, v: V2(rng.unit() * 50 - 25, rng.unit() * 50 - 25))); nextID += 1 }
            } else { keep.append(f) }
        }
        foes = keep
    }

    private mutating func moveFoes(_ dt: Double) {
        for i in foes.indices {
            foes[i].hitCD -= dt
            var f = foes[i]
            let toOtto = otto - f.p
            switch f.type {
            case .shade, .shell:
                let sp = f.type == .shade ? 13.0 : 9.0
                f.v = f.v * max(0, 1 - dt * 3) + toOtto.norm * sp * min(1, dt * 3) * 1.0
                if f.v.len > sp * 1.5 && f.hitCD <= 0 { f.v = f.v.norm * sp }
                if f.v.len < sp { f.v = toOtto.norm * sp }
            case .moth:
                // after the motes on the ground first, Otto second; never straight
                let goal = motes.min(by: { $0.p.dist(f.p) < $1.p.dist(f.p) })?.p ?? otto
                let wob = V2(cos(t * 5 + f.seed) * 22, sin(t * 4 + f.seed) * 22)
                f.v = (goal - f.p).norm * 26 + wob
            case .fang:
                f.timer -= dt
                switch f.state {
                case 0:
                    f.v = toOtto.norm * 16
                    if toOtto.len < 58 { f.state = 1; f.timer = 0.9; f.v = V2(0, 0); f.dir = toOtto.norm }
                case 1:
                    f.v = V2(0, 0)
                    if f.timer <= 0 { f.state = 2; f.timer = 0.75; f.v = f.dir * 110 }
                case 2:
                    if f.timer <= 0 { f.state = 3; f.timer = 0.8; f.v = V2(0, 0) }
                default:
                    if f.timer <= 0 { f.state = 0 }
                }
            }
            f.p = f.p + f.v * dt
            foes[i] = f
        }
        // the ones that reach Otto drink his light and are gone
        var keep: [Foe] = []
        for f in foes {
            if f.p.dist(otto + V2(0, -6)) < 8 {
                let k = f.type == .fang && f.state == 2 ? 24.0 : f.type == .shell ? 15 : 11
                light -= k * guardK
                events.append(.drink); shake = max(shake, 0.5)
                burst(otto, 6, 0xFF3A2010)
            } else if f.type == .moth, let mi = motes.firstIndex(where: { $0.p.dist(f.p) < 5 }) {
                motes.remove(at: mi); keep.append(f)
            } else { keep.append(f) }
        }
        foes = keep
    }

    private mutating func moveMotes(_ dt: Double) {
        var keep: [Mote] = []
        for var m in motes {
            m.age += dt
            m.v = m.v * max(0, 1 - dt * 4)
            // close to Moss they leap to her
            let d = moss - m.p
            if d.len < 16 { m.v = m.v + d.norm * 260 * dt }
            m.p = m.p + m.v * dt
            if m.p.dist(moss) < 6 { take(m); continue }
            if m.age < 14 { keep.append(m) }
        }
        motes = keep
    }

    private mutating func take(_ m: Mote) {
        motes.removeAll { $0.id == m.id }
        collected += 1
        light = min(lightMax, light + 3)
        events.append(.mote)
        sparks.append(Spark(p: m.p, v: V2(0, -20), life: 0.3, color: 0xFF6BD3FF))
    }

    private mutating func moveThief(_ dt: Double) {
        guard var th = thief else { return }
        th.stun = max(0, th.stun - dt)
        let sp = th.stun > 0 ? 12.0 : 1.0
        switch th.state {
        case 0:
            let to = (otto + V2(-6, -25)) - th.p
            th.p = th.p + to.norm * min(to.len, 64 * dt * (sp > 1 ? 0.2 : 1))
            if to.len < 4 {
                let take = min(28.0, max(0, light - 6))
                light -= take; th.sack = take; th.state = 1
                events.append(.steal); shake = 0.8
                th.exit = V2(th.p.x < W / 2 ? -14 : W + 14, th.p.y < H / 2 ? -14 : H * 0.35)
            }
        case 1:
            let to = th.exit - th.p
            let s = th.stun > 0 ? 14.0 : 50.0
            th.p = th.p + to.norm * s * dt + V2(0, sin(t * 6) * 10 * dt)
            if to.len < 4 { th.state = 3; events.append(.escaped) }
        case 2:
            th.timer -= dt
            th.p = th.p + V2(0, -30 * dt)
            if th.timer <= 0 { th.state = 3 }
        default: break
        }
        thief = th
    }

    private mutating func moveMaw(_ dt: Double) {
        guard var m = maw, m.hp > 0 else { return }
        m.drift += dt
        m.hurt = max(0, m.hurt - dt)
        m.p = V2(W / 2 + sin(m.drift * 0.5) * W * 0.28, H * 0.24 + sin(m.drift * 0.8) * 10)
        m.spit -= dt
        if m.spit <= 0 {
            m.spit = 5.5
            for k in 0..<3 { foes.append(makeFoe(k == 2 && m.hp < 5 ? .fang : .shade, at: m.p + V2(Double(k - 1) * 12, 14))) }
        }
        // it swallows the motes near it: the belly glows
        for mo in motes where mo.p.dist(m.p) < 34 {
            motes.removeAll { $0.id == mo.id }
            m.belly = min(3, m.belly + 1)
        }
        // touching Otto is a big drink
        if m.p.dist(otto) < 22 { light -= 20 * dt }
        maw = m
    }

    private mutating func burst(_ p: V2, _ n: Int, _ color: UInt32) {
        for _ in 0..<n {
            let a = rng.unit() * .pi * 2, s = 20 + rng.unit() * 50
            sparks.append(Spark(p: p, v: V2(cos(a) * s, sin(a) * s), life: 0.3 + rng.unit() * 0.4, color: color))
        }
    }

    private mutating func decay(_ dt: Double) {
        for i in sparks.indices { sparks[i].p = sparks[i].p + sparks[i].v * dt; sparks[i].v = sparks[i].v * 0.92; sparks[i].life -= dt }
        sparks.removeAll { $0.life <= 0 }
    }

    /// Stars for the night: lived through it; still bright at dawn; one loop that caught four or more.
    var stars: Int { outcome == 1 ? 1 + (light >= lightMax * 0.4 ? 1 : 0) + (bestLoop >= 4 ? 1 : 0) : 0 }
}
