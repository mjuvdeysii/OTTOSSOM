import XCTest
@testable import OTTOSSOM

/// The outside judge for the rooms. Every room was designed and checked with the reference rules in
/// Tools/rooms/core.js, which stored its shortest solution (par) in rooms.json. Here the Swift engine:
///   · replays that solution move by move and must win in exactly par moves, and
///   · for every room small enough, solves it on its own and must find the same length and the same state count.
final class RoomTests: XCTestCase {
    func testContentLoads() {
        XCTAssertEqual(Content.chapters.count, 4)
        XCTAssertEqual(Content.rooms.count, 26)
        for ch in Content.chapters { for st in ch.steps {
            if let r = st.room { XCTAssertNotNil(Content.rooms[r], "missing room \(r)") }
            for s in [st.intro, st.outro, st.cut].compactMap({ $0 }) { XCTAssertNotNil(Content.story[s], "missing script \(s)") }
        } }
    }

    func testReferenceSolutionsReplay() {
        for (id, spec) in Content.rooms.sorted(by: { $0.key < $1.key }) {
            let r = Room(spec); r.keyGiven = true
            var s = r.start
            for m in spec.solution ?? [] {
                let parts = m.split(separator: ":")
                guard parts.count == 2, let ci = Int(parts[0]), let v = Verb(rawValue: String(parts[1])) else { XCTFail("\(id): bad move \(m)"); break }
                guard let n = r.step(s, ci, v) else { XCTFail("\(id): move \(m) refused"); break }
                s = n
            }
            XCTAssertTrue(r.won(s), "\(id): the reference solution does not win")
            XCTAssertEqual(spec.solution?.count, spec.par, "\(id)")
        }
    }

    func testSwiftSolverMatchesPar() {
        var report: [String] = []
        for (id, spec) in Content.rooms.sorted(by: { $0.key < $1.key }) {
            if (spec.states ?? 0) > 200_000 { report.append("\(id)\tpar \(spec.par ?? -1)\treplay only (\(spec.states ?? 0) states)"); continue }
            guard let res = Solver.solve(spec) else { XCTFail("\(id): Swift finds no solution"); continue }
            XCTAssertEqual(res.path.count, spec.par, "\(id): Swift \(res.path.count), reference \(spec.par ?? -1)")
            XCTAssertEqual(res.states, spec.states, "\(id): explored states differ")
            report.append("\(id)\tpar \(spec.par ?? -1)\tswift \(res.path.count)\tstates \(res.states)")
        }
        let out = ProcessInfo.processInfo.environment["LEVEL_REPORT"] ?? NSTemporaryDirectory() + "rooms.txt"
        try? report.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8)
    }

    func testRulesByHand() {
        // a lit lamp with two shadows close by: lighting works, then they drift in and crowd it out
        let r = Room(RoomSpec(id: "t", name: "", day: 1, map: ["#######", "#.S.S.#", "#..L..#", "#..O..#", "#######"]))
        let s = r.step(r.start, 0, .light)
        XCTAssertNotNil(s)
        XCTAssertEqual(s?.lit.first, false)
        // Moss pushes boulders, Otto doesn't
        let r2 = Room(RoomSpec(id: "t2", name: "", day: 1, map: ["######", "#.B.O#", "#M...#", "######"], goal: "none"))
        XCTAssertNil(r2.step(r2.start, 0, .left).flatMap { r2.step($0, 0, .left) })
        XCTAssertNotNil(r2.step(r2.start, 1, .up).flatMap { r2.step($0, 1, .right) })
        // the thief walks to a lit lamp and takes its light; walls, the lamp and a boulder then hold him
        let r3 = Room(RoomSpec(id: "t3", name: "", day: 1, map: ["#######", "###L###", "###.###", "#W....#", "#O...M#", "#######"], goal: "trap"))
        var s3 = r3.start
        XCTAssertNil(r3.step(s3, 0, .light))                          // Otto isn't next to the lamp
        s3.c[0] = Pt(3, 2); s3.lit[0] = true
        let a = r3.step(s3, 0, .down)                                  // Otto blocks the only way in: the thief waits
        XCTAssertEqual(a?.thief, Pt(1, 3))
        let b = a.flatMap { r3.step($0, 0, .right) }                   // the way is clear: one step toward the lamp
        XCTAssertEqual(b?.thief, Pt(2, 3))
        XCTAssertEqual(b.flatMap { r3.step($0, 0, .right) }?.thief, Pt(3, 3))
    }
}
