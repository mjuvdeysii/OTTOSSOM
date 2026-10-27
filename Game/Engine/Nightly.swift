import Foundation

/// 每夜躲猫猫: one new board each night, made on the device from the date and proved solvable by the solver before it
/// is shown (the same measures as Tools/gen.py: a short line, real decisions, Mosto's mirror in play).
enum Nightly {
    struct Rng { var s: UInt64
        mutating func next() -> UInt64 { s &+= 0x9E3779B97F4A7C15; var z = s; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31) }
        mutating func int(_ n: Int) -> Int { Int(next() % UInt64(max(1, n))) }
        mutating func range(_ a: Int, _ b: Int) -> Int { a + int(b - a + 1) }
        mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    }

    /// The night a date belongs to: before 6:00 it is still the previous night.
    static func night(_ date: Date = Date()) -> String {
        let d = date.addingTimeInterval(-6 * 3600)
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyyMMdd"
        return f.string(from: d)
    }

    static func make(night: String) -> LevelInfo? {
        var rng = Rng(s: UInt64(night) ?? 1)
        let deadline = Date().addingTimeInterval(6)
        var best: (LevelInfo, Double)?
        var tries = 0
        while tries < 400 && Date() < deadline {
            tries += 1
            let mode: MostoMode = [MostoMode.none, .shadow, .pair][rng.int(3)]
            guard let rows = board(&rng, mode: mode) else { continue }
            let facing = "NESW".map { String($0) }[rng.int(4)]
            guard let b = try? Board(rows: rows, facing: Dir(letter: Character(facing))!, mode: mode),
                  let dist = Solver.distances(b, limit: 60_000), let par = dist[b.start], (9...20).contains(par),
                  let sol = Solver.solve(b) else { continue }
            let (hard, mirror) = measure(b, sol.moves, dist)
            if mode != .none && mirror < 3 { continue }
            let score = hard / Double(par)
            if hard < 14 { continue }
            let info = LevelInfo(id: 1000 + (Int(night) ?? 0) % 4, chapter: 5, rows: rows, facing: facing, mode: mode, par: par, solution: sol.moves.map { $0.description })
            if best == nil || score > best!.1 { best = (info, score) }
            if score > 1.6 { break }
        }
        return best?.0
    }

    private static func measure(_ b: Board, _ moves: [Move], _ dist: [GameState: Int]) -> (Double, Int) {
        var s = b.start, hard = 0.0, mirror = 0
        for m in moves {
            let next = b.moves(s)
            let good = next.filter { dist[$0.1] == (dist[s] ?? 0) - 1 }.count
            hard += -log(Double(max(1, good)) / Double(max(1, next.count)))
            let n = b.step(s, m)!
            if s.mosto >= 0, n.mosto >= 0, n.mosto != s.mosto { mirror += 1 }
            s = n
        }
        return (hard, mirror)
    }

    private static func board(_ rng: inout Rng, mode: MostoMode) -> [String]? {
        let w = 5 + rng.int(2), h = 6 + rng.int(3)
        var g = [[Character]](repeating: [Character](repeating: ".", count: w), count: h)
        for _ in 0..<rng.range(1, 3) {
            if rng.unit() < 0.6 {
                let y = rng.range(1, h - 2), x0 = rng.range(0, w - 2), x1 = rng.range(x0 + 1, w)
                for x in x0..<x1 { g[y][x] = "_" }
            } else {
                let x = rng.int(w), y0 = rng.range(0, h - 2), y1 = rng.range(y0 + 1, h)
                for y in y0..<y1 { g[y][x] = "_" }
            }
        }
        for _ in 0..<rng.range(0, 3) { g[rng.int(h)][rng.int(w)] = "_" }
        for _ in 0..<rng.range(2, 5) { g[rng.int(h)][rng.int(w)] = "T" }
        for _ in 0..<rng.range(0, 2) { let y = rng.int(h), x = rng.int(w); if g[y][x] == "." { g[y][x] = "B" } }
        if mode != .none { for _ in 0..<rng.range(0, 3) { let y = rng.int(h), x = rng.int(w); if g[y][x] == "_" { g[y][x] = "=" } } }
        var floors: [(Int, Int)] = []
        for y in 0..<h { for x in 0..<w where g[y][x] == "." { floors.append((x, y)) } }
        guard floors.count >= 9 else { return nil }
        floors = floors.map { ($0, -Double($0.1) - rng.unit() * 3) }.sorted { $0.1 < $1.1 }.map { $0.0 }
        g[floors[0].1][floors[0].0] = "M"; g[floors[1].1][floors[1].0] = "O"
        var rest = Array(floors.dropFirst(2))
        if mode != .shadow {
            let k = rest.indices.min { Double(rest[$0].1) + rng.unit() * 3 < Double(rest[$1].1) + rng.unit() * 3 }!
            let p = rest.remove(at: k); g[p.1][p.0] = "*"
        }
        if mode != .none { let p = rest.remove(at: rng.int(rest.count)); g[p.1][p.0] = "X" }
        if mode == .pair { let p = rest.remove(at: rng.int(rest.count)); g[p.1][p.0] = "C" }
        return g.map { String($0) }
    }
}
