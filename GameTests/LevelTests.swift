import XCTest
@testable import OTTOSSOM

/// The outside judge for the levels: the Swift engine solves every level on its own and must find exactly the
/// shortest solution that the Python reference (Tools/engine.py) found when the levels were built.
final class LevelTests: XCTestCase {
    func testThirtySevenBeads() {
        XCTAssertEqual(Levels.all.count, 37)
        XCTAssertEqual(Levels.all.map(\.id), Array(0...36))
    }

    func testEveryLevelSolvesToItsPar() {
        var report: [String] = []
        for info in Levels.all {
            let b = info.board()
            guard let sol = Solver.solve(b) else { XCTFail("level \(info.id) has no solution"); continue }
            XCTAssertEqual(sol.moves.count, info.par, "level \(info.id): Swift finds \(sol.moves.count), the reference \(info.par)")
            XCTAssertEqual(sol.moves.map(\.description), info.solution, "level \(info.id): solutions differ")
            // and the reference solution, played move by move, wins
            var s = b.start
            for m in info.solution {
                let mv = Move(actor: Actor(rawValue: m.first!)!, dir: Dir(letter: m.last!)!)
                guard let n = b.step(s, mv) else { XCTFail("level \(info.id): move \(m) refused"); break }
                s = n
            }
            XCTAssertTrue(b.won(s), "level \(info.id): reference solution does not win")
            report.append("\(info.id)\t\(info.mode.rawValue)\tpar \(info.par)\tstates \(sol.states)")
        }
        let out = ProcessInfo.processInfo.environment["LEVEL_REPORT"] ?? NSTemporaryDirectory() + "levels.txt"
        try? report.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8)
    }

    func testRulesByHand() throws {
        // Moss cannot step into the dark; Otto turns before he steps; Otto never pushes
        let b = try Board(rows: ["..*..", ".....", ".....", ".MB..", ".O..."], facing: .s, mode: .none)
        var s = b.start
        XCTAssertNil(b.step(s, Move(actor: .moss, dir: .n)).flatMap { b.step($0, Move(actor: .moss, dir: .n)) }, "two steps north are dark while the lamp faces south")
        s = b.step(s, Move(actor: .otto, dir: .n))!
        XCTAssertEqual(s.facing, .n); XCTAssertEqual(s.otto, b.start.otto)
        XCTAssertNotNil(b.step(s, Move(actor: .moss, dir: .e)), "Moss pushes the block")
        // mirror: Mosto steps west when Moss steps east, never into the light
        let m = try Board(rows: ["X....", ".....", "..M..", "..O.."], facing: .n, mode: .shadow)
        let n = m.step(m.start, Move(actor: .moss, dir: .w))!
        XCTAssertEqual(m.x(n.mosto), 0, "Mosto does not step into the light")
    }

    func testNightlyBoardsAreSolvable() {
        for night in ["20261027", "20261028", "20261231"] {
            let t = Date()
            guard let info = Nightly.make(night: night) else { XCTFail("no board for \(night)"); continue }
            XCTAssertLessThan(Date().timeIntervalSince(t), 8)
            XCTAssertEqual(Solver.solve(info.board())?.moves.count, info.par)
        }
    }
}
