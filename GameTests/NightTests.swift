import XCTest
@testable import OTTOSSOM

/// The night: geometry, the loop, and balance. The rule bot (NightBot) stands in for a decent player: it should
/// win the early nights almost always and the later ones most of the time; a slow bot should lose more often.
final class NightTests: XCTestCase {
    func testGeometry() {
        XCTAssertEqual(Geo.segDist(V2(0, 5), V2(-10, 0), V2(10, 0)), 5, accuracy: 1e-9)
        XCTAssertNotNil(Geo.cross(V2(0, 0), V2(10, 10), V2(0, 10), V2(10, 0)))
        XCTAssertNil(Geo.cross(V2(0, 0), V2(10, 0), V2(0, 5), V2(10, 5)))
        let sq = [V2(0, 0), V2(10, 0), V2(10, 10), V2(0, 10)]
        XCTAssertTrue(Geo.inside(V2(5, 5), sq))
        XCTAssertFalse(Geo.inside(V2(15, 5), sq))
        XCTAssertEqual(abs(Geo.area(sq)), 100, accuracy: 1e-9)
    }

    func testLoopCatchesWhatsInside() {
        var sim = NightSim(spec: ChapterOne.nights[1], w: 195, h: 422, seed: 3)
        let c = sim.otto + V2(30, 10)
        sim.foes = [sim.makeFoe(.shell, at: c)]
        sim.moss = c + V2(14, 0)
        let dt = 1.0 / 60
        var a = 0.0
        for _ in 0..<90 {
            a += 10 * dt
            sim.touch(c + V2(cos(a) * 14, sin(a) * 14))
            sim.foes = sim.foes.map { var f = $0; f.p = c; f.v = V2(0, 0); return f }   // hold it still
            sim.step(dt)
            if sim.foes.isEmpty { break }
        }
        XCTAssertTrue(sim.foes.isEmpty, "a loop round a shell should catch it")
        XCTAssertGreaterThan(sim.motes.count + sim.collected, 0)
    }

    func testThreadSweepsShades() {
        var sim = NightSim(spec: ChapterOne.nights[0], w: 195, h: 422, seed: 4)
        let mid = (sim.otto + V2(-6, -25) + sim.moss + V2(0, -6)) * 0.5
        sim.foes = [sim.makeFoe(.shade, at: mid)]
        sim.step(1.0 / 60)
        XCTAssertTrue(sim.foes.isEmpty)
    }

    func testBalance() {
        var report: [String] = []
        for spec in ChapterOne.nights {
            var wins = 0, slowWins = 0, stars = 0, motes = 0
            let runs = 24
            for s in 0..<runs {
                let r = NightBot.play(spec, seed: UInt64(100 + s))
                if r.outcome == 1 { wins += 1; stars += r.stars }
                motes += r.collected
                if NightBot.play(spec, seed: UInt64(500 + s), skill: 0.55).outcome == 1 { slowWins += 1 }
            }
            let line = "NIGHTBAL night \(spec.id): bot \(wins)/\(runs) stars \(String(format: "%.1f", Double(stars) / Double(max(1, wins)))) motes \(motes / runs) · slow bot \(slowWins)/\(runs)"
            print(line); report.append(line)
            if spec.id <= 2 { XCTAssertGreaterThanOrEqual(wins, runs * 3 / 4, line) }
            XCTAssertGreaterThan(wins, 0, line)
        }
        try? report.joined(separator: "\n").write(to: FileManager.default.temporaryDirectory.appendingPathComponent("nightbal.txt"), atomically: true, encoding: .utf8)
    }
}
