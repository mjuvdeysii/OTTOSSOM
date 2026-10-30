import Foundation

// The night: Moss digs into the dark under the lighthouse with Otto's bead. The world is a grid of 8-pixel tiles that
// stays dug from night to night; what she brings back up feeds the lamp shop by day. Pure rules, no drawing, so
// tests can run whole nights.

enum Cell: UInt8 {
    case air = 0, soil, clay, stone, rock, bedrock, amber, blue, red, trinket, memory, memoryRead, mote, grass

    var solid: Bool { self != .air }
    /// Seconds to dig with a bare claw; nil: can't be dug.
    var dig: Double? {
        switch self {
        case .air, .bedrock: return nil
        case .soil, .grass, .mote: return 0.22
        case .clay: return 0.42
        case .trinket: return 0.3
        case .amber: return 0.45
        case .stone: return 0.7
        case .blue: return 0.8
        case .rock: return 1.1
        case .red: return 1.2
        case .memory, .memoryRead: return nil
        }
    }
    /// Claw level needed.
    var claw: Int {
        switch self {
        case .stone, .blue: return 1
        case .rock, .red: return 2
        default: return 0
        }
    }
}

enum Gem: String, Codable, CaseIterable { case amber, blue, red }
enum Trinket: String, Codable, CaseIterable { case button, coin, cap }

struct DigWorld: Codable {
    static let W = 12, H = 100, ground = 5      // rows above `ground` are sky
    var cells: [UInt8]
    var memories: [Int: Int] = [:]              // memory number → cell index (to place them)

    init(seed: UInt64) {
        var r = Rng(seed)
        let W = DigWorld.W, H = DigWorld.H, G = DigWorld.ground
        cells = [UInt8](repeating: 0, count: W * H)
        // layers with ragged boundaries: soil, clay, stone, rock
        var edges: [[Int]] = []
        for base in [8, 18, 36] {
            var row: [Int] = []
            var e = base
            for _ in 0..<W { e = max(base - 2, min(base + 2, e + Int(r.next() % 3) - 1)); row.append(e) }
            edges.append(row)
        }
        for y in G..<H {
            let d = y - G
            for x in 0..<W {
                let t: Cell = y == H - 1 ? .bedrock : d == 0 ? .grass : d < edges[0][x] ? .soil : d < edges[1][x] ? .clay : d < edges[2][x] ? .stone : .rock
                cells[y * W + x] = t.rawValue
            }
        }
        func walk(_ n: Int, _ x0: Int, _ y0: Int, _ t: Cell, _ only: Set<Cell>, grid: inout [UInt8], rng: inout Rng) {
            var x = x0, y = y0
            for _ in 0..<n {
                if x >= 0 && x < W && y > G && y < H - 1 {
                    let cur = Cell(rawValue: grid[y * W + x]) ?? .air
                    if only.contains(cur) { grid[y * W + x] = t.rawValue }
                }
                switch rng.next() % 4 { case 0: x += 1; case 1: x -= 1; case 2: y += 1; default: y -= 1 }
            }
        }
        var grid = cells
        // pockets of the next material in each layer, so the ground reads in patches, not noise
        for _ in 0..<10 { walk(5 + Int(r.next() % 6), Int(r.next() % UInt64(W)), G + 3 + Int(r.next() % 12), .clay, [.soil], grid: &grid, rng: &r) }
        for _ in 0..<12 { walk(5 + Int(r.next() % 7), Int(r.next() % UInt64(W)), G + 12 + Int(r.next() % 20), .stone, [.clay], grid: &grid, rng: &r) }
        for _ in 0..<12 { walk(5 + Int(r.next() % 7), Int(r.next() % UInt64(W)), G + 24 + Int(r.next() % 30), .clay, [.stone], grid: &grid, rng: &r) }
        for _ in 0..<16 { walk(6 + Int(r.next() % 8), Int(r.next() % UInt64(W)), G + 34 + Int(r.next() % UInt64(H - G - 36)), .stone, [.rock], grid: &grid, rng: &r) }
        // crystal veins: amber near the top, blue in clay and stone, red in the deep rock
        for _ in 0..<9 { walk(2 + Int(r.next() % 3), Int(r.next() % UInt64(W)), G + 3 + Int(r.next() % 16), .amber, [.soil, .clay], grid: &grid, rng: &r) }
        for _ in 0..<7 { walk(2 + Int(r.next() % 3), Int(r.next() % UInt64(W)), G + 20 + Int(r.next() % 40), .amber, [.clay, .stone], grid: &grid, rng: &r) }
        for _ in 0..<10 { walk(2 + Int(r.next() % 3), Int(r.next() % UInt64(W)), G + 12 + Int(r.next() % 40), .blue, [.clay, .stone], grid: &grid, rng: &r) }
        for _ in 0..<9 { walk(2 + Int(r.next() % 3), Int(r.next() % UInt64(W)), G + 30 + Int(r.next() % UInt64(H - G - 32)), .red, [.rock, .stone], grid: &grid, rng: &r) }
        cells = grid
        // odds and ends: the things Moss can't leave, and motes of old light
        for y in (G + 1)..<(H - 1) {
            let d = y - G
            for x in 0..<W {
                let c = Cell(rawValue: cells[y * W + x]) ?? .air
                guard c == .soil || c == .clay || c == .stone || c == .rock else { continue }
                let u = r.unit()
                if u < (d < 20 ? 0.045 : 0.03) { cells[y * W + x] = Cell.trinket.rawValue }
                else if u < (d < 20 ? 0.085 : 0.06) { cells[y * W + x] = Cell.mote.rawValue }
            }
        }
        // caves: blobs of air below the first few rows, where the shadows live
        for _ in 0..<18 {
            let cx = Int(r.unit() * Double(W)), cy = G + 7 + Int(r.unit() * Double(H - G - 12))
            let rx = 1 + Int(r.unit() * 2), ry = 1
            for y in (cy - ry)...(cy + ry) { for x in (cx - rx)...(cx + rx) where x >= 0 && x < W && y > G + 3 && y < H - 1 {
                let dx = Double(x - cx) / Double(rx), dy = Double(y - cy) / Double(ry)
                if dx * dx + dy * dy <= 1.1 { cells[y * W + x] = Cell.air.rawValue }
            } }
        }
        // memory stones at fixed depths, in the middle third so they're found
        for (n, d) in [(1, 6), (2, 15), (3, 26), (4, 42)] {
            let x = 3 + Int(r.unit() * Double(W - 6)), y = G + d
            cells[y * W + x] = Cell.memory.rawValue
            memories[n] = y * W + x
        }
    }

    func at(_ x: Int, _ y: Int) -> Cell {
        if x < 0 || x >= DigWorld.W { return .bedrock }
        if y < 0 { return .air }
        if y >= DigWorld.H { return .bedrock }
        return Cell(rawValue: cells[y * DigWorld.W + x]) ?? .air
    }
    mutating func set(_ x: Int, _ y: Int, _ t: Cell) {
        guard x >= 0, x < DigWorld.W, y >= 0, y < DigWorld.H else { return }
        cells[y * DigWorld.W + x] = t.rawValue
    }
    func memoryAt(_ x: Int, _ y: Int) -> Int? { memories.first { $0.value == y * DigWorld.W + x }?.key }
}

struct Bag: Codable, Equatable {
    var gems: [Gem: Int] = [:]
    var trinkets: [Trinket: Int] = [:]
    var count: Int { gems.values.reduce(0, +) + trinkets.values.reduce(0, +) }
    mutating func halve() {
        for g in Gem.allCases { gems[g] = (gems[g] ?? 0) / 2 }
        for t in Trinket.allCases { trinkets[t] = (trinkets[t] ?? 0) / 2 }
    }
}

struct Shade {
    var id: Int
    var p: V2
    var v = V2(0, 0)
    var dir = 1.0
    var hurt = 0.0
    var moth = false
}

enum DigEvent: Equatable { case dug(Cell), gem(Gem), trinket(Trinket), mote, full, memory(Int), flash(Int), hurt, home, dark, hard, step, land }

struct DigSim {
    static let T = 16.0
    var world: DigWorld
    var p: V2                      // Moss's feet (bottom centre), pixels
    var v = V2(0, 0)
    var grounded = false
    var face = 1.0
    var stick = V2(0, 0)           // the player's push, -1…1 each way
    var digging: (x: Int, y: Int, t: Double)?
    var light: Double
    var lightMax: Double
    var bag = Bag()
    var capacity: Int
    var claw: Int
    var shades: [Shade] = []
    var flashCD = 0.0
    var flashAt = -9.0
    var hurtCD = 0.0
    var t = 0.0
    var outcome = 0                // 0 digging; 1 came home with everything; -1 light out (half the bag lost)
    var events: [DigEvent] = []
    var thread: [V2] = []          // the light thread back up to Otto: Moss's path with the loops taken out
    var deepest = 0
    var openMemory: Int?           // a memory stone she's touching
    var pops: [(p: V2, icon: String, t0: Double)] = []   // what she just picked up, rising off her
    var bits: [Spark] = []         // chips of what she dug
    var rng: Rng
    var nextID = 0
    let otto: V2

    static let walk = 64.0, gravity = 640.0, jumpV = 168.0, maxFall = 260.0
    static let halfW = 6.0, height = 14.0

    init(world: DigWorld, upgrades: [String: Int], seed: UInt64) {
        self.world = world
        claw = upgrades["claw"] ?? 0
        capacity = 8 + (upgrades["bag"] ?? 0) * 4
        lightMax = 75 + Double(upgrades["wick"] ?? 0) * 30
        light = lightMax
        rng = Rng(seed)
        let gy = Double(DigWorld.ground) * DigSim.T
        otto = V2(48, gy)
        p = V2(104, gy)
        // the shaft she dug last time stays; shadows wait in the caves
        for y in (DigWorld.ground + 6)..<(DigWorld.H - 2) {
            for x in 1..<(DigWorld.W - 1) where world.at(x, y) == .air && world.at(x, y + 1).solid && world.at(x - 1, y) == .air && world.at(x + 1, y) == .air {
                if rng.unit() < 0.3 {
                    let d = y - DigWorld.ground
                    shades.append(Shade(id: nextID, p: V2((Double(x) + 0.5) * DigSim.T, Double(y + 1) * DigSim.T), moth: d > 16 && rng.unit() < 0.4))
                    nextID += 1
                }
            }
        }
        thread = [otto + V2(-6, -25), p]
    }

    var depth: Int { max(0, Int(p.y / DigSim.T) - DigWorld.ground) }
    var drain: Double { 1 + Double(depth) / 50 }

    // MARK: input

    /// The player's push: x to walk, down to dig down, up to jump (or dig up).
    mutating func push(_ s: V2) { stick = s }

    /// A tap: Otto's bead flashes — shadows close by break.
    @discardableResult mutating func flash() -> Int {
        guard flashCD <= 0, outcome == 0 else { return 0 }
        flashCD = 1.0; flashAt = t
        light -= 2
        var n = 0
        let c = p + V2(0, -4)
        shades.removeAll { s in
            if s.p.dist(c) < 44 { n += 1; return true }
            return false
        }
        if n > 0 { light = min(lightMax, light + Double(n) * 4) }
        events.append(.flash(n))
        return n
    }

    /// Pull the thread: Otto reels her home with everything.
    mutating func reelIn() {
        guard outcome == 0 else { return }
        outcome = 1; events.append(.home)
    }

    // MARK: step

    mutating func step(_ dt: Double) {
        guard outcome == 0 else { return }
        t += dt
        flashCD = max(0, flashCD - dt); hurtCD = max(0, hurtCD - dt)
        light -= drain * dt
        moveMoss(dt)
        moveShades(dt)
        trackThread()
        for i in bits.indices { bits[i].v.y += 300 * dt; bits[i].p = bits[i].p + bits[i].v * dt; bits[i].life -= dt }
        bits.removeAll { $0.life <= 0 }
        pops.removeAll { t - $0.t0 > 0.9 }
        deepest = max(deepest, depth)
        if light <= 0 { light = 0; outcome = -1; bag.halve(); events.append(.dark) }
    }

    func tileAt(_ q: V2) -> (Int, Int) { (Int(floor(q.x / DigSim.T)), Int(floor(q.y / DigSim.T))) }

    private func solidAt(_ x: Double, _ y: Double) -> Bool {
        let (tx, ty) = tileAt(V2(x, y)); return world.at(tx, ty).solid
    }

    private func blocked(_ q: V2) -> Bool {
        // Moss's box: halfW either side of q.x, from q.y - height to q.y
        let xs = [q.x - DigSim.halfW, q.x + DigSim.halfW - 0.01], ys = [q.y - DigSim.height, q.y - DigSim.height / 2, q.y - 0.01]
        for x in xs { for y in ys where solidAt(x, y) { return true } }
        return false
    }

    private mutating func moveMoss(_ dt: Double) {
        let sx = abs(stick.x) > 0.25 ? (stick.x > 0 ? 1.0 : -1.0) : 0
        if sx != 0 { face = sx }
        let wantDown = stick.y > 0.55 && abs(stick.x) < 0.6
        let wantUp = stick.y < -0.55 && abs(stick.x) < 0.75

        // what she's pushing into gets dug
        var target: (Int, Int)?
        let (fx, fy) = tileAt(p + V2(0, -1))
        if wantDown && grounded { target = (fx, fy + 1) }
        else if sx != 0 {
            let (tx, ty) = tileAt(p + V2(sx * (DigSim.halfW + 1), -7))
            if world.at(tx, ty).solid { target = (tx, ty) }
        } else if wantUp && grounded && world.at(fx, fy - 1).solid {
            target = (fx, fy - 1)
        }
        if let tg = target {
            let tx = tg.0, ty = tg.1
            let tile = world.at(tx, ty)
            if tile == .memory || tile == .memoryRead {
                if let n = world.memoryAt(tx, ty) {
                    if tile == .memory { world.set(tx, ty, .memoryRead); events.append(.memory(n)) }
                    if openMemory == nil && tile == .memory { openMemory = n }
                }
                digging = nil
            } else if let base = tile.dig, tile.claw <= claw {
                if let d = digging, d.x == tx, d.y == ty {
                    let need = base * pow(0.75, Double(claw))
                    let nt = d.t + dt
                    if nt >= need { finishDig(tx, ty, tile) } else { digging = (tx, ty, nt) }
                } else { digging = (tx, ty, 0) }
            } else {
                if digging == nil || digging!.x != tx || digging!.y != ty { events.append(.hard) }
                digging = (tx, ty, -999)    // can't: remembered so the "too hard" note isn't repeated every frame
            }
        } else { digging = nil }

        // walking, jumping, falling — one axis at a time
        v.x = sx * DigSim.walk
        if wantUp && grounded { v.y = -DigSim.jumpV; grounded = false }
        // digging down: slide to the middle of the tile so she drops through the hole
        if wantDown && grounded {
            let cx = (Double(fx) + 0.5) * DigSim.T
            let d = cx - p.x
            if abs(d) > 0.5 { let q = V2(p.x + max(-60 * dt, min(60 * dt, d)), p.y); if !blocked(q) { p = q } }
        }
        v.y = min(DigSim.maxFall, v.y + DigSim.gravity * dt)
        var q = p
        q.x += v.x * dt
        if blocked(q) { q.x = p.x }
        q.x = max(DigSim.halfW, min(Double(DigWorld.W) * DigSim.T - DigSim.halfW, q.x))
        let was = grounded
        var q2 = q; q2.y += v.y * dt
        if blocked(q2) {
            if v.y > 0 {
                // land on the tile below
                q2.y = floor((q.y + v.y * dt) / DigSim.T) * DigSim.T
                if blocked(q2) { q2.y = q.y }
                grounded = true
                if !was && v.y > 120 { events.append(.land) }
            } else { q2.y = q.y }
            v.y = 0
        } else { grounded = false }
        p = q2
        if sx != 0 && grounded && Int(t * 8) != Int((t - dt) * 8) { events.append(.step) }
    }

    private mutating func finishDig(_ x: Int, _ y: Int, _ tile: Cell) {
        digging = nil
        let c = V2((Double(x) + 0.5) * DigSim.T, (Double(y) + 0.5) * DigSim.T)
        let col: UInt32 = tile == .amber ? 0xFF6BD3FF : tile == .blue ? 0xFFFFC48A : tile == .red ? 0xFF8A8AFF : tile == .stone || tile == .rock ? 0xFF76605C : 0xFF46364C
        for _ in 0..<7 {
            let a = rng.unit() * .pi - .pi, sp = 30 + rng.unit() * 50
            bits.append(Spark(p: c, v: V2(cos(a) * sp, sin(a) * sp), life: 0.35 + rng.unit() * 0.3, color: col))
        }
        switch tile {
        case .amber, .blue, .red:
            if bag.count >= capacity { events.append(.full); digging = (x, y, -999); return }
            let g: Gem = tile == .amber ? .amber : tile == .blue ? .blue : .red
            bag.gems[g, default: 0] += 1; events.append(.gem(g))
            pops.append((p + V2(0, -18), "icon_\(g.rawValue)", t))
        case .trinket:
            if bag.count >= capacity { events.append(.full); digging = (x, y, -999); return }
            let k = Trinket.allCases[Int(rng.next() % 3)]
            bag.trinkets[k, default: 0] += 1; events.append(.trinket(k))
            pops.append((p + V2(0, -18), "icon_\(k.rawValue)", t))
        case .mote:
            light = min(lightMax, light + 6); events.append(.mote)
            pops.append((p + V2(0, -18), "mote_0", t))
        default: break
        }
        world.set(x, y, .air)
        events.append(.dug(tile))
    }

    private mutating func moveShades(_ dt: Double) {
        let me = p + V2(0, -4)
        for i in shades.indices {
            var s = shades[i]
            let near = s.p.dist(me) < 72
            if s.moth {
                // moths drift to her and steal a gem
                let goal = near ? me : s.p + V2(cos(t + Double(s.id)) * 10, sin(t * 1.3 + Double(s.id)) * 6)
                s.v = (goal - s.p).norm * (near ? 26 : 8)
                s.p = s.p + s.v * dt
            } else {
                if near { s.dir = me.x < s.p.x ? -1 : 1 }
                let sp = near ? 26.0 : 10.0
                let nx = s.p.x + s.dir * sp * dt
                let (tx, ty) = tileAt(V2(nx + s.dir * 6, s.p.y - 6))
                let (bx, by) = tileAt(V2(nx + s.dir * 6, s.p.y + 1))
                if world.at(tx, ty).solid || !world.at(bx, by).solid { s.dir = -s.dir } else { s.p.x = nx }
                // they fall if the ground under them is dug away
                let (ux, uy) = tileAt(V2(s.p.x, s.p.y + 0.5))
                if !world.at(ux, uy).solid { s.p.y += 90 * dt }
            }
            shades[i] = s
        }
        guard hurtCD <= 0 else { return }
        for i in shades.indices where shades[i].p.dist(me + V2(0, -2)) < 11 {
            hurtCD = 1.2
            if shades[i].moth, let g = Gem.allCases.reversed().first(where: { (bag.gems[$0] ?? 0) > 0 }) {
                bag.gems[g]! -= 1
                shades.remove(at: i)
            } else {
                light -= 12
                v.y = -120
            }
            events.append(.hurt)
            return
        }
    }

    private mutating func trackThread() {
        guard let last = thread.last else { return }
        if p.dist(last) >= 10 {
            // going back over the path pulls the thread in
            if let k = thread.indices.dropLast().last(where: { thread[$0].dist(p) < 8 }), k >= 1 {
                thread.removeSubrange((k + 1)...)
            }
            thread.append(p)
        }
    }

    /// What's left to do before it's too dark: seconds of light.
    var secondsLeft: Int { Int(light / drain) }
}
