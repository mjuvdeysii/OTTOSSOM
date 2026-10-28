import Foundation

// 《长夜》 rules — one grid engine for all four chapters. Rule for rule the same as Tools/rooms/core.js (the reference
// the rooms were designed and checked with); CI solves every room with both and the shortest solutions must agree.
//
// Map legend: # wall · . floor · ~ water (only Mosto flies over) · L dark lamp · l lit lamp · N dark nest
// S lost shadow · B boulder · P plate · D door · T tablet · E exit · O Otto · M Moss · X Mosto · other lowercase: people

enum Hero: String, CaseIterable, Codable { case otto, moss, mosto }

enum Tile: Equatable { case wall, floor, water, lamp, plate, door, tablet, exit, npc }

struct Pt: Hashable, Codable {
    var x: Int, y: Int
    init(_ x: Int, _ y: Int) { self.x = x; self.y = y }
    static func + (a: Pt, b: Pt) -> Pt { Pt(a.x + b.x, a.y + b.y) }
    func dist(_ o: Pt) -> Int { abs(x - o.x) + abs(y - o.y) }
}

enum Verb: String, CaseIterable, Codable {
    case up, down, left, right, bulb, light, take, give
    var delta: Pt? {
        switch self {
        case .up: return Pt(0, -1)
        case .down: return Pt(0, 1)
        case .left: return Pt(-1, 0)
        case .right: return Pt(1, 0)
        default: return nil
        }
    }
    static let moves: [Verb] = [.up, .down, .left, .right]
}

struct RoomSpec: Codable {
    var id: String
    var name: String
    var day: Int
    var map: [String]
    var rOtto: Int?
    var rCarry: Int?
    var rLamp: Int?
    var goal: String?
    var lockBulb: Bool?
    var bulbOn: Bool?
    var carry: Bool?
    var needKey: Bool?
    var sun: Bool?
    var par: Int?
    var solution: [String]?
    var states: Int?
}

struct GameState: Hashable {
    var c: [Pt]
    var bulb: Bool
    var carry: Bool
    var shadows: [Pt]
    var boulders: [Pt]
    var lit: [Bool]
    var steps: Int = 0
    /// Mosto as the thief (chapter 4): he moves on his own after every action
    var thief: Pt? = nil

    /// the solver's identity for a state (step count and shadow order don't matter)
    var key: String {
        var s = c.map { "\($0.x),\($0.y)" }.joined(separator: ";")
        s += "|\(bulb ? 1 : 0)\(carry ? 1 : 0)|"
        s += shadows.map { "\($0.x),\($0.y)" }.sorted().joined(separator: ";") + "|"
        s += boulders.map { "\($0.x),\($0.y)" }.sorted().joined(separator: ";") + "|"
        s += lit.map { $0 ? "1" : "0" }.joined()
        if let t = thief { s += "|\(t.x),\(t.y)" }
        return s
    }
}

enum Event { case drift(Int), dim(Int), light(Int), take(Int), give(Int, nest: Bool), bulb(Bool), push, steal(Int), thief }

final class Room {
    let spec: RoomSpec
    let w: Int, h: Int
    private(set) var grid: [[Tile]]
    let npcs: [Pt: Character]
    let tablets: Set<Pt>
    let exits: [Pt]
    let plates: [Pt]
    let heroes: [Hero]
    let lampPos: [Pt]
    let nest: [Bool]
    let rOtto: Int, rCarry: Int, rLamp: Int
    let goal: String
    let lockBulb: Bool
    let needKey: Bool
    var keyGiven = false
    let start: GameState

    init(_ spec: RoomSpec) {
        self.spec = spec
        let rows = spec.map.map { Array($0) }
        let H = rows.count, W = rows.map { $0.count }.max() ?? 0
        h = H; w = W
        var grid: [[Tile]] = [], lamps: [(Pt, Bool, Bool)] = [], shadows: [Pt] = [], boulders: [Pt] = []
        var plates: [Pt] = [], exits: [Pt] = [], npcs: [Pt: Character] = [:], tablets = Set<Pt>(), chars: [Hero: Pt] = [:]
        var thief: Pt? = nil
        for y in 0..<H {
            var row: [Tile] = []
            for x in 0..<W {
                let ch: Character = x < rows[y].count ? rows[y][x] : "~"
                var t = Tile.floor
                let p = Pt(x, y)
                switch ch {
                case "#": t = .wall
                case "~": t = .water
                case "L", "l": t = .lamp; lamps.append((p, ch == "l", false))
                case "N": t = .lamp; lamps.append((p, false, true))
                case "S": shadows.append(p)
                case "B": boulders.append(p)
                case "P": t = .plate; plates.append(p)
                case "D": t = .door
                case "T": t = .tablet; tablets.insert(p)
                case "E": t = .exit; exits.append(p)
                case "O": chars[.otto] = p
                case "M": chars[.moss] = p
                case "X": chars[.mosto] = p
                case "W": thief = p
                case ".": break
                default:
                    if ch.isLowercase && ch.isLetter { t = .npc; npcs[p] = ch }
                }
                row.append(t)
            }
            grid.append(row)
        }
        self.grid = grid
        self.npcs = npcs; self.tablets = tablets; self.exits = exits; self.plates = plates
        let hs = Hero.allCases.filter { chars[$0] != nil }
        heroes = hs
        lampPos = lamps.map { $0.0 }; nest = lamps.map { $0.2 }
        rOtto = spec.rOtto ?? 3; rCarry = spec.rCarry ?? 2; rLamp = spec.rLamp ?? 2
        goal = spec.goal ?? "allLamps"; lockBulb = spec.lockBulb ?? false; needKey = spec.needKey ?? false
        start = GameState(c: hs.map { chars[$0]! }, bulb: spec.bulbOn ?? false, carry: spec.carry ?? false,
                          shadows: shadows, boulders: boulders, lit: lamps.map { $0.1 }, thief: thief)
    }

    func tile(_ p: Pt) -> Tile { (p.y < 0 || p.y >= h || p.x < 0 || p.x >= w) ? .wall : grid[p.y][p.x] }
    func index(of hero: Hero) -> Int? { heroes.firstIndex(of: hero) }

    func platesDown(_ s: GameState) -> Bool { plates.allSatisfy { s.boulders.contains($0) || s.c.contains($0) } }
    func lampsOK(_ s: GameState) -> Bool {
        switch goal {
        case "none", "trap": return true
        case "carry": return s.carry
        case "nests": return s.lit.indices.allSatisfy { !nest[$0] || s.lit[$0] }
        default: return s.lit.allSatisfy { $0 }
        }
    }
    func exitOpen(_ s: GameState) -> Bool { lampsOK(s) && !(needKey && !keyGiven) }

    func canEnter(_ s: GameState, _ ci: Int, _ p: Pt) -> Bool {
        let t = tile(p), who = heroes[ci]
        switch t {
        case .wall, .lamp, .npc, .tablet: return false
        case .water: if who != .mosto { return false }
        case .door: if !platesDown(s) { return false }
        case .exit: if !exitOpen(s) { return false }
        default: break
        }
        if s.c.contains(p) || s.boulders.contains(p) || s.thief == p { return false }
        if s.shadows.contains(p) && who != .mosto { return false }
        return true
    }
    private func shadowFree(_ s: GameState, _ p: Pt) -> Bool {
        let t = tile(p)
        let ok = t == .floor || t == .plate || t == .exit || (t == .door && platesDown(s))
        return ok && !s.shadows.contains(p) && !s.boulders.contains(p) && !s.c.contains(p) && s.thief != p
    }

    // MARK: the thief
    static let tdirs = [Pt(0, -1), Pt(1, 0), Pt(0, 1), Pt(-1, 0)]   // up, right, down, left
    func thiefFree(_ s: GameState, _ p: Pt) -> Bool {
        let t = tile(p)
        guard t == .floor || t == .plate || t == .exit || t == .water || (t == .door && platesDown(s)) else { return false }
        return !s.boulders.contains(p) && !s.c.contains(p)
    }
    /// A side that holds him for good — not a character, who can always step away.
    func thiefWall(_ s: GameState, _ p: Pt) -> Bool {
        let t = tile(p)
        return t == .wall || t == .lamp || t == .npc || t == .tablet || (t == .door && !platesDown(s)) || s.boulders.contains(p)
    }
    func trapped(_ s: GameState) -> Bool {
        guard let t = s.thief else { return false }
        return Room.tdirs.allSatisfy { thiefWall(s, t + $0) }
    }
    /// Takes the light of a lit lamp next to him, or steps along a shortest path toward the nearest cell next to one.
    func thiefMove(_ s: inout GameState, _ ev: inout [Event]) {
        guard let t = s.thief, !trapped(s) else { return }
        if let i = lampPos.indices.first(where: { s.lit[$0] && !nest[$0] && lampPos[$0].dist(t) == 1 }) {
            s.lit[i] = false; ev.append(.steal(i)); return
        }
        var dist: [Pt: Int] = [:], q: [Pt] = []
        for (i, lp) in lampPos.enumerated() where s.lit[i] && !nest[i] {
            for d in Room.tdirs {
                let c = lp + d
                if dist[c] == nil && (thiefFree(s, c) || c == t) { dist[c] = 0; q.append(c) }
            }
        }
        var h = 0
        while h < q.count {
            let c = q[h]; h += 1
            let d = dist[c]!
            for m in Room.tdirs {
                let n = c + m
                if dist[n] != nil { continue }
                if !(thiefFree(s, n) || n == t) { continue }
                dist[n] = d + 1; q.append(n)
            }
        }
        guard let here = dist[t] else { return }
        for m in Room.tdirs {
            let n = t + m
            if let d = dist[n], d < here, thiefFree(s, n) { s.thief = n; ev.append(.thief); return }
        }
    }

    /// Lost shadows are cold: each drifts one tile toward the nearest light within reach; then crowded lamps go out.
    func drift(_ s: inout GameState, _ ev: inout [Event]) {
        var att: [(Pt, Int)] = []
        if let oi = index(of: .otto), s.bulb { att.append((s.c[oi], rOtto)) }
        if let xi = index(of: .mosto), s.carry { att.append((s.c[xi], rCarry)) }
        for (i, p) in lampPos.enumerated() where s.lit[i] { att.append((p, rLamp)) }
        let order = s.shadows.indices.sorted { a, b in
            let pa = s.shadows[a], pb = s.shadows[b]
            return pa.y != pb.y ? pa.y < pb.y : pa.x < pb.x
        }
        for i in order {
            let p = s.shadows[i]
            var best: (Pt, Int)? = nil
            for (ap, r) in att {
                let d = p.dist(ap)
                if d <= r && (best == nil || d < best!.1) { best = (ap, d) }
            }
            guard let b = best, b.1 > 1 else { continue }
            let dx = b.0.x - p.x, dy = b.0.y - p.y
            let tries: [Pt] = abs(dx) >= abs(dy) ? [Pt(dx.signum(), 0), Pt(0, dy.signum())] : [Pt(0, dy.signum()), Pt(dx.signum(), 0)]
            for m in tries where !(m.x == 0 && m.y == 0) {
                let n = p + m
                if shadowFree(s, n) { s.shadows[i] = n; ev.append(.drift(i)); break }
            }
        }
        for (i, lp) in lampPos.enumerated() where s.lit[i] {
            if s.shadows.filter({ $0.dist(lp) == 1 }).count >= 2 { s.lit[i] = false; ev.append(.dim(i)) }
        }
    }

    private func someoneInClosedDoor(_ s: GameState) -> Bool {
        if platesDown(s) { return false }
        return s.c.contains { tile($0) == .door } || s.boulders.contains { tile($0) == .door }
    }

    func step(_ s0: GameState, _ ci: Int, _ v: Verb, _ ev: inout [Event]) -> GameState? {
        var s = s0
        let who = heroes[ci], p = s.c[ci]
        if let d = v.delta {
            let n = p + d
            if let bi = s.boulders.firstIndex(of: n) {
                guard who == .moss else { return nil }
                let b2 = n + d, t = tile(b2)
                guard t == .floor || t == .plate || (t == .door && platesDown(s)) else { return nil }
                if s.boulders.contains(b2) || s.c.contains(b2) || s.shadows.contains(b2) || s.thief == b2 { return nil }
                s.boulders[bi] = b2; ev.append(.push); s.c[ci] = n
            } else {
                guard canEnter(s, ci, n) else { return nil }
                s.c[ci] = n
            }
            if someoneInClosedDoor(s) { return nil }
        } else {
            switch v {
            case .bulb:
                guard who == .otto, !lockBulb else { return nil }
                s.bulb.toggle(); ev.append(.bulb(s.bulb))
            case .light:
                guard who == .otto else { return nil }
                var any = false
                for (i, lp) in lampPos.enumerated() where !s.lit[i] && !nest[i] && lp.dist(p) == 1 && !s.shadows.contains(where: { $0.dist(lp) == 1 }) {
                    s.lit[i] = true; any = true; ev.append(.light(i))
                }
                if !any { return nil }
            case .take:
                guard who == .mosto, !s.carry, let i = lampPos.indices.first(where: { s.lit[$0] && lampPos[$0].dist(p) == 1 }) else { return nil }
                s.lit[i] = false; s.carry = true; ev.append(.take(i))
            case .give:
                guard who == .mosto, s.carry, let i = lampPos.indices.first(where: { k in !s.lit[k] && lampPos[k].dist(p) == 1 && !s.shadows.contains(where: { q in q.dist(lampPos[k]) == 1 }) }) else { return nil }
                s.lit[i] = true; s.carry = false; ev.append(.give(i, nest: nest[i]))
            default: return nil
            }
        }
        s.steps += 1
        drift(&s, &ev)
        thiefMove(&s, &ev)
        // a door can't close on the thief either
        if let t = s.thief, !platesDown(s), tile(t) == .door { return nil }
        return s
    }
    func step(_ s: GameState, _ ci: Int, _ v: Verb) -> GameState? { var ev: [Event] = []; return step(s, ci, v, &ev) }

    func won(_ s: GameState) -> Bool {
        if goal == "trap" { return trapped(s) }
        return lampsOK(s) && s.c.allSatisfy { tile($0) == .exit }
    }

    /// Why can't this lamp be lit? (for the hint line)
    func crowdedLampNear(_ s: GameState, _ ci: Int) -> Bool {
        let p = s.c[ci]
        return lampPos.indices.contains { i in !s.lit[i] && lampPos[i].dist(p) == 1 && s.shadows.contains(where: { $0.dist(lampPos[i]) == 1 }) }
    }

    static func verbs(_ h: Hero) -> [Verb] { h == .otto ? [.bulb, .light] : h == .mosto ? [.take, .give] : [] }
}

/// Breadth-first search for the shortest solution — the CI judge for every room, and the in-game hint.
enum Solver {
    struct Result: Sendable { var path: [(Int, Verb)]; var states: Int }

    static func solve(_ spec: RoomSpec, cap: Int = 800_000) -> Result? {
        let r = Room(spec); r.keyGiven = true
        return search(r, from: r.start, cap: cap)
    }

    /// Shortest solution from any state of a room (uses the room's current key state).
    static func search(_ r: Room, from start: GameState, cap: Int) -> Result? {
        var start = start; start.steps = 0
        if r.won(start) { return Result(path: [], states: 1) }
        var acts: [(Int, Verb)] = []
        for (ci, h) in r.heroes.enumerated() { for v in Verb.moves + Room.verbs(h) { acts.append((ci, v)) } }
        var parent: [String: (String, Int, Verb)] = [:]
        var seen: Set<String> = [start.key]
        var queue = [start]; var head = 0
        while head < queue.count && seen.count < cap {
            let s = queue[head]; head += 1
            let ks = s.key
            for (ci, v) in acts {
                guard let n = r.step(s, ci, v) else { continue }
                let k = n.key
                if seen.contains(k) { continue }
                seen.insert(k); parent[k] = (ks, ci, v)
                if r.won(n) {
                    var path: [(Int, Verb)] = []; var cur = k
                    while let e = parent[cur] { path.insert((e.1, e.2), at: 0); cur = e.0 }
                    return Result(path: path, states: seen.count)
                }
                queue.append(n)
            }
        }
        return nil
    }
}
