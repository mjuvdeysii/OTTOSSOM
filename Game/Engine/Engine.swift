import Foundation

// MARK: Rules
//
// The game's rules, exactly as Tools/engine.py states them (that file is the reference; the test target and
// Tools/check_levels.py both solve every level and must find the same shortest solution).
//
//  Moss   one step onto a lit cell; pushes a block one cell (into a gap it fills the gap); never onto a night bridge.
//  Otto   a swipe in a new direction turns the lamp; in the direction he already faces, he steps. He never pushes.
//  Mosto  after each step Moss takes, he tries the mirrored step (east and west swapped): dark cells only, night
//         bridges allowed, pushes blocks. In `.shadow` levels Moss catches him by stepping onto him while he is lit.
//  Light  Otto's cell and the 8 around it, plus a 90° cone ahead, stopped by tall things and blocks.

enum Dir: Int, CaseIterable, Codable, Sendable {
    case n = 0, e, s, w
    var dx: Int { [0, 1, 0, -1][rawValue] }
    var dy: Int { [-1, 0, 1, 0][rawValue] }
    var mirrored: Dir { self == .e ? .w : self == .w ? .e : self }
    var letter: Character { Array("NESW")[rawValue] }
    init?(letter: Character) { guard let i = Array("NESW").firstIndex(of: letter) else { return nil }; self.init(rawValue: i) }
}

enum Ground: UInt8, Sendable { case floor, gap, tall, bridge }

enum MostoMode: String, Codable, Sendable { case none, shadow, pair, mirror }

enum Actor: Character, Sendable { case moss = "M", otto = "O", mosto = "X" }

struct Move: Hashable, Sendable, CustomStringConvertible {
    let actor: Actor
    let dir: Dir
    var description: String { "\(actor.rawValue)\(dir.letter)" }
}

/// A cell index is y * width + x; boards have at most 64 cells, so sets of cells are bit masks.
struct GameState: Hashable, Sendable {
    var moss: Int
    var otto: Int
    var facing: Dir
    var mosto: Int          // -1: not on the board (none, or caught)
    var blocks: UInt64
    var filled: UInt64
}

@inline(__always) func bit(_ i: Int) -> UInt64 { 1 << UInt64(i) }

final class Board: @unchecked Sendable {
    let name: String
    let width: Int, height: Int
    let ground: [Ground]
    let start: GameState
    let mode: MostoMode
    let bead: Int     // -1 when the level has none
    let crown: Int
    let rows: [String]
    private var litCache: [LitKey: UInt64] = [:]
    private let lock = NSLock()

    private struct LitKey: Hashable { let otto: Int; let facing: Dir; let blocks: UInt64; let filled: UInt64 }

    enum BoardError: Error { case bad(String) }

    init(name: String = "", rows: [String], facing: Dir, mode: MostoMode) throws {
        self.name = name; self.rows = rows; self.mode = mode
        height = rows.count
        width = rows.map { $0.count }.max() ?? 0
        guard width * height <= 64, width > 0 else { throw BoardError.bad("board too large") }
        var g: [Ground] = [], blocks: UInt64 = 0
        var moss = -1, otto = -1, mosto = -1, bead = -1, crown = -1
        for (y, row) in rows.enumerated() {
            let chars = Array(row)
            for x in 0..<width {
                let c: Character = x < chars.count ? chars[x] : "_"
                let i = y * width + x
                switch c {
                case "M", "O", "X", ".", "*", "C", "B": g.append(.floor)
                case "_", " ": g.append(.gap)
                case "T": g.append(.tall)
                case "=": g.append(.bridge)
                default: throw BoardError.bad("unknown cell \(c)")
                }
                switch c {
                case "M": moss = i
                case "O": otto = i
                case "X": mosto = i
                case "*": bead = i
                case "C": crown = i
                case "B": blocks |= bit(i)
                default: break
                }
            }
        }
        guard moss >= 0, otto >= 0 else { throw BoardError.bad("Moss and Otto must be on the board") }
        guard (mosto >= 0) == (mode != .none) else { throw BoardError.bad("Mosto and mode disagree") }
        guard mode == .shadow || bead >= 0 else { throw BoardError.bad("no bead") }
        guard (mode == .pair || mode == .mirror) == (crown >= 0) else { throw BoardError.bad("crown and mode disagree") }
        ground = g; self.bead = bead; self.crown = crown
        start = GameState(moss: moss, otto: otto, facing: facing, mosto: mosto, blocks: blocks, filled: 0)
    }

    @inline(__always) func x(_ i: Int) -> Int { i % width }
    @inline(__always) func y(_ i: Int) -> Int { i / width }
    @inline(__always) func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height }

    /// The ground at cell i, with filled gaps counted as floor.
    func groundAt(_ s: GameState, _ i: Int) -> Ground {
        let g = ground[i]
        if (g == .gap || g == .bridge) && s.filled & bit(i) != 0 { return .floor }
        return g
    }

    private func blocksLight(_ s: GameState, _ i: Int) -> Bool { groundAt(s, i) == .tall || s.blocks & bit(i) != 0 }

    func lit(_ s: GameState) -> UInt64 {
        let key = LitKey(otto: s.otto, facing: s.facing, blocks: s.blocks, filled: s.filled)
        lock.lock(); if let v = litCache[key] { lock.unlock(); return v }; lock.unlock()
        let v = computeLit(s)
        lock.lock(); litCache[key] = v; lock.unlock()
        return v
    }

    private func computeLit(_ s: GameState) -> UInt64 {
        let ox = x(s.otto), oy = y(s.otto)
        var out: UInt64 = 0
        for dx in -1...1 { for dy in -1...1 where inside(ox + dx, oy + dy) { out |= bit((oy + dy) * width + ox + dx) } }
        let fx = s.facing.dx, fy = s.facing.dy, lx = -fy, ly = fx
        for f in 1...max(width, height) {
            for l in -f...f {
                let qx = ox + fx * f + lx * l, qy = oy + fy * f + ly * l
                guard inside(qx, qy) else { continue }
                let q = qy * width + qx
                if out & bit(q) != 0 { continue }
                if sightLine(s, ox, oy, qx, qy) { out |= bit(q) }
            }
        }
        return out
    }

    private func sightLine(_ s: GameState, _ ax: Int, _ ay: Int, _ bx: Int, _ by: Int) -> Bool {
        let n = 4 * max(abs(bx - ax), abs(by - ay))
        guard n > 1 else { return true }
        for i in 1..<n {
            let cx = (2 * (ax * n + (bx - ax) * i) + n) / (2 * n)
            let cy = (2 * (ay * n + (by - ay) * i) + n) / (2 * n)
            if (cx == ax && cy == ay) || (cx == bx && cy == by) { continue }
            if blocksLight(s, cy * width + cx) { return false }
        }
        return true
    }

    private func neighbour(_ i: Int, _ d: Dir) -> Int? {
        let nx = x(i) + d.dx, ny = y(i) + d.dy
        return inside(nx, ny) ? ny * width + nx : nil
    }

    private func push(_ s: GameState, from q: Int, _ d: Dir, occupied: [Int]) -> (UInt64, UInt64)? {
        guard let r = neighbour(q, d), s.blocks & bit(r) == 0, !occupied.contains(r) else { return nil }
        let g = groundAt(s, r)
        var blocks = s.blocks & ~bit(q), filled = s.filled
        if g == .floor && r != bead && r != crown { blocks |= bit(r) }
        else if g == .gap || g == .bridge { filled |= bit(r) }
        else { return nil }
        return (blocks, filled)
    }

    private func mostoStep(_ s: GameState, _ d: Dir) -> GameState {
        guard let q = neighbour(s.mosto, d), q != s.moss, q != s.otto, lit(s) & bit(q) == 0 else { return s }
        var n = s
        if s.blocks & bit(q) != 0 {
            guard let (b, f) = push(s, from: q, d, occupied: [s.moss, s.otto, s.mosto]) else { return s }
            n.blocks = b; n.filled = f; n.mosto = q
            return n
        }
        let g = groundAt(s, q)
        if g == .floor || g == .bridge { n.mosto = q; return n }
        return s
    }

    /// Moss's mirrored step on the other side: only onto a lit cell; if he cannot, he stays.
    private func mossFollow(_ s: GameState, _ d: Dir) -> GameState {
        guard let q = neighbour(s.moss, d), q != s.otto, q != s.mosto, lit(s) & bit(q) != 0 else { return s }
        var n = s
        if s.blocks & bit(q) != 0 {
            guard let (b, f) = push(s, from: q, d, occupied: [s.otto, s.mosto]) else { return s }
            n.blocks = b; n.filled = f; n.moss = q
            return n
        }
        guard groundAt(s, q) == .floor else { return s }
        n.moss = q
        return n
    }

    /// The state after one swipe, or nil when the swipe does nothing.
    func step(_ s: GameState, _ m: Move) -> GameState? {
        let d = m.dir
        if m.actor == .mosto {
            guard mode == .mirror else { return nil }
            let n = mostoStep(s, d)
            if n == s { return nil }
            return mossFollow(n, d.mirrored)
        }
        if m.actor == .moss && mode == .mirror { return nil }
        if m.actor == .otto {
            if d != s.facing { var n = s; n.facing = d; return n }
            guard let q = neighbour(s.otto, d), q != s.moss, q != s.mosto, s.blocks & bit(q) == 0, groundAt(s, q) == .floor else { return nil }
            var n = s; n.otto = q; return n
        }
        guard let q = neighbour(s.moss, d), q != s.otto, lit(s) & bit(q) != 0 else { return nil }
        if q == s.mosto {
            if mode == .shadow && groundAt(s, q) == .floor { var n = s; n.moss = q; n.mosto = -1; return n }
            return nil
        }
        var n = s
        if s.blocks & bit(q) != 0 {
            let occ = s.mosto >= 0 ? [s.otto, s.mosto] : [s.otto]
            guard let (b, f) = push(s, from: q, d, occupied: occ) else { return nil }
            n.blocks = b; n.filled = f; n.moss = q
        } else {
            guard groundAt(s, q) == .floor else { return nil }
            n.moss = q
        }
        if n.mosto >= 0 { n = mostoStep(n, d.mirrored) }
        return n
    }

    func won(_ s: GameState) -> Bool {
        switch mode {
        case .shadow: return s.mosto < 0
        case .pair, .mirror: return s.moss == bead && s.mosto == crown
        case .none: return s.moss == bead
        }
    }

    static let storyMoves: [Move] = [Actor.moss, .otto].flatMap { a in Dir.allCases.map { Move(actor: a, dir: $0) } }
    static let mirrorMoves: [Move] = [Actor.mosto, .otto].flatMap { a in Dir.allCases.map { Move(actor: a, dir: $0) } }
    /// The one the player walks: Moss, or Mosto on the other side.
    var walker: Actor { mode == .mirror ? .mosto : .moss }

    func moves(_ s: GameState) -> [(Move, GameState)] {
        (mode == .mirror ? Board.mirrorMoves : Board.storyMoves).compactMap { m in
            guard let n = step(s, m), n != s else { return nil }
            return (m, n)
        }
    }
}

// MARK: Solver

struct Solution: Sendable {
    let moves: [Move]
    let states: Int
}

enum Solver {
    /// Every reachable state and its distance to the nearest win (nil when the board cannot be won from there).
    static func distances(_ b: Board, from s0: GameState? = nil, limit: Int = 400_000) -> [GameState: Int]? {
        let start = s0 ?? b.start
        var index: [GameState: Int] = [start: 0]
        var states: [GameState] = [start]
        var edges: [[Int]] = []
        var head = 0
        while head < states.count {
            let s = states[head]; head += 1
            if states.count > limit { return nil }
            var e: [Int] = []
            for (_, n) in b.moves(s) {
                if let j = index[n] { e.append(j) } else { index[n] = states.count; e.append(states.count); states.append(n) }
            }
            edges.append(e)
        }
        var rev = [[Int]](repeating: [], count: states.count)
        for (i, e) in edges.enumerated() { for j in e { rev[j].append(i) } }
        var dist = [Int](repeating: -1, count: states.count)
        var queue: [Int] = []
        for (i, s) in states.enumerated() where b.won(s) { dist[i] = 0; queue.append(i) }
        var qh = 0
        while qh < queue.count {
            let i = queue[qh]; qh += 1
            for p in rev[i] where dist[p] < 0 { dist[p] = dist[i] + 1; queue.append(p) }
        }
        var out: [GameState: Int] = [:]
        for (i, s) in states.enumerated() where dist[i] >= 0 { out[s] = dist[i] }
        return out
    }

    /// The shortest solution; ties broken by move order (Moss before Otto, N E S W), as the reference does.
    static func solve(_ b: Board, from s0: GameState? = nil) -> Solution? {
        let start = s0 ?? b.start
        guard let dist = distances(b, from: start), var d = dist[start] else { return nil }
        var s = start, path: [Move] = []
        while d > 0 {
            guard let (m, n) = b.moves(s).first(where: { dist[$0.1] == d - 1 }) else { return nil }
            path.append(m); s = n; d -= 1
        }
        return Solution(moves: path, states: dist.count)
    }

    /// The next move on a shortest line from s (the hint): a forward search that stops at the first win, so it stays
    /// quick even on the largest boards.
    static func hint(_ b: Board, from s: GameState, limit: Int = 600_000) -> Move? {
        if b.won(s) { return nil }
        var first: [GameState: Move] = [:]
        var queue: [GameState] = []
        for (m, n) in b.moves(s) where first[n] == nil {
            if b.won(n) { return m }
            first[n] = m; queue.append(n)
        }
        var head = 0
        while head < queue.count, first.count < limit {
            let cur = queue[head]; head += 1
            let m0 = first[cur]!
            for (_, n) in b.moves(cur) where first[n] == nil && n != s {
                if b.won(n) { return m0 }
                first[n] = m0; queue.append(n)
            }
        }
        return nil
    }
}
