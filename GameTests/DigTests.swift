import XCTest
@testable import OTTOSSOM

/// The dig and the shop: the world, digging, the bag, the light, mixing colours, paying.
final class DigTests: XCTestCase {
    func testWorld() {
        let w = DigWorld(seed: 20261030)
        XCTAssertEqual(w.cells.count, DigWorld.W * DigWorld.H)
        for x in 0..<DigWorld.W { XCTAssertEqual(w.at(x, DigWorld.H - 1), .bedrock); XCTAssertEqual(w.at(x, DigWorld.ground), .grass) }
        XCTAssertEqual(Set(w.memories.keys), Set(1...8))
        for (_, i) in w.memories { XCTAssertEqual(Cell(rawValue: w.cells[i]), .memory) }
    }

    func testDigsDownAndFalls() {
        var sim = DigSim(world: DigWorld(seed: 1), upgrades: [:], seed: 1)
        sim.push(V2(0, 1))
        for _ in 0..<(60 * 12) { sim.step(1.0 / 60) }
        XCTAssertGreaterThan(sim.depth, 3, "holding down should dig down")
        XCTAssertGreaterThan(sim.thread.count, 2)
    }

    func testWalksAndDigsSideways() {
        var w = DigWorld(seed: 2)
        for x in 0..<DigWorld.W { w.set(x, DigWorld.ground, .grass); w.set(x, DigWorld.ground + 1, .soil) }
        var sim = DigSim(world: w, upgrades: [:], seed: 2)
        let x0 = sim.p.x
        sim.push(V2(1, 0))
        for _ in 0..<60 { sim.step(1.0 / 60) }
        XCTAssertGreaterThan(sim.p.x, x0 + 20)
    }

    func testGemsFillTheBag() {
        var w = DigWorld(seed: 3)
        let y = DigWorld.ground + 1
        for x in 0..<DigWorld.W { w.set(x, y, .amber) }
        var sim = DigSim(world: w, upgrades: [:], seed: 3)
        sim.push(V2(0, 1))
        for _ in 0..<(60 * 3) { sim.step(1.0 / 60) }
        XCTAssertGreaterThanOrEqual(sim.bag.gems[.amber] ?? 0, 1)
    }

    func testHardTileNeedsClaw() {
        var w = DigWorld(seed: 4)
        for x in 0..<DigWorld.W { w.set(x, DigWorld.ground + 1, .stone); w.set(x, DigWorld.ground, .air) }
        var sim = DigSim(world: w, upgrades: [:], seed: 4)
        sim.push(V2(0, 1))
        for _ in 0..<(60 * 3) { sim.step(1.0 / 60) }
        XCTAssertTrue(sim.world.at(Int(sim.p.x / 16), DigWorld.ground + 1).solid, "stone stays without the claw")
        var sim2 = DigSim(world: w, upgrades: ["claw": 1], seed: 4)
        sim2.push(V2(0, 1))
        for _ in 0..<(60 * 3) { sim2.step(1.0 / 60) }
        XCTAssertGreaterThan(sim2.depth, 1)
    }

    func testLightOutHalvesTheBag() {
        var sim = DigSim(world: DigWorld(seed: 5), upgrades: [:], seed: 5)
        sim.bag.gems = [.amber: 4]; sim.bag.trinkets = [.coin: 3]
        sim.light = 0.01
        sim.step(0.1)
        XCTAssertEqual(sim.outcome, -1)
        XCTAssertEqual(sim.bag.gems[.amber], 2); XCTAssertEqual(sim.bag.trinkets[.coin], 1)
    }

    func testMixingAndPaying() {
        XCTAssertEqual(LampColor.mix([.blue, .amber]), .green)
        XCTAssertEqual(LampColor.mix([.red, .blue, .amber]), .white)
        XCTAssertNil(LampColor.mix([.amber, .amber]))
        var s = DigSave()
        s.gems = [.amber: 1, .blue: 1]
        s.openShop()
        XCTAssertEqual(s.orders.count, 3)
        let hank = s.orders[0]
        XCTAssertFalse(s.light(hank, with: [.blue]))
        XCTAssertTrue(s.light(hank, with: [.amber]))
        XCTAssertEqual(s.coins, hank.pay)
        XCTAssertEqual(s.gems[.amber], 0)
        XCTAssertFalse(s.goal.isEmpty)
        s.openShop()
        XCTAssertEqual(s.orders.count, 2, "the same day doesn't open twice")
    }

    func testSaveRoundTrip() throws {
        var s = DigSave(); s.gems = [.blue: 2]; s.memories = [1]; s.world.set(3, 9, .air)
        let d = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(DigSave.self, from: d)
        XCTAssertEqual(back.gems[.blue], 2); XCTAssertEqual(back.world.at(3, 9), .air)
    }
}

final class DigPaintTests: XCTestCase {
    func testPaintsAWholeDive() {
        var sim = DigSim(world: DigWorld(seed: 20261030), upgrades: ["claw": 1], seed: 7)
        let scale = PixelScale(size: CGSize(width: 402, height: 874))
        var f = Frame(w: scale.w, h: scale.h)
        var cam = 0.0
        for i in 0..<(60 * 20) {
            sim.push(i % 300 < 200 ? V2(0, 1) : V2(i % 600 < 450 ? 1 : -1, 0))
            if i % 90 == 0 { sim.flash() }
            sim.step(1.0 / 60)
            sim.events = []
            cam += (sim.p.y - Double(scale.h) * 0.45 - cam) * 0.1
            if i % 10 == 0 { DigPainter.paint(sim, into: &f, cam: cam, clock: Double(i) / 60, stick: (CGPoint(x: 100, y: 500), CGPoint(x: 120, y: 520)), scale: scale) }
        }
        XCTAssertNotNil(f.cgImage())
        XCTAssertGreaterThan(sim.depth, 3)
    }
}

/// Pacing: the rule player over two weeks of days. A decent player should find the first memory stone on the
/// first night, need the claw to go past the clay, and reach the bottom within about two weeks.
final class DigPacingTests: XCTestCase {
    func testTrace() {
        var s = DigSave()
        _ = DigBot.day(&s); _ = DigBot.day(&s)
        var sim = DigSim(world: s.world, upgrades: s.upgrades, seed: 990)
        var bot = DigBot()
        let dt = 1.0 / 30
        for n in 0..<(30 * 40) {
            bot.steer(&sim, dt)
            sim.step(dt)
            sim.events = []
            if n % 15 == 0 {
                let (fx, fy) = sim.tileAt(sim.p + V2(0, -1))
                let below = sim.world.at(fx, fy + 1), left = sim.world.at(fx - 1, fy), right = sim.world.at(fx + 1, fy)
                print("DIGTRACE t\(n / 30) p(\(Int(sim.p.x)),\(Int(sim.p.y))) f(\(fx),\(fy)) stick(\(sim.stick.x),\(sim.stick.y)) g\(sim.grounded) dig\(sim.digging.map { "\($0.x),\($0.y),\(String(format: "%.2f", $0.t))" } ?? "-") below \(below) l \(left) r \(right) side\(bot.side) sf\(String(format: "%.2f", bot.sideFor))")
            }
            if sim.outcome != 0 { break }
        }
    }

    func testTwoWeeks() {
        var s = DigSave()
        var lines: [String] = []
        var firstMemoryDay = 0, endingDay = 0
        for _ in 0..<16 {
            let d = s.day
            let sim = DigBot.day(&s)
            let up = "爪\(s.upgrades["claw"] ?? 0)包\(s.upgrades["bag"] ?? 0)芯\(s.upgrades["wick"] ?? 0)"
            lines.append("DIGBAL day \(d): deepest \(sim.deepest)m bag \(sim.bag.count) \(sim.outcome == 1 ? "home" : "dark") · memories \(s.memories.count) · coins \(s.coins) · \(up) · orders \(s.orders.count)")
            if firstMemoryDay == 0 && !s.memories.isEmpty { firstMemoryDay = d }
            if endingDay == 0 && s.seen.contains("ending") { endingDay = d }
        }
        lines.append("DIGBAL first memory day \(firstMemoryDay), ending day \(endingDay)")
        for l in lines { print(l) }
        XCTAssertGreaterThan(firstMemoryDay, 0)
        XCTAssertLessThanOrEqual(firstMemoryDay, 2)
        XCTAssertGreaterThanOrEqual(s.memories.count, 4, lines.joined(separator: "\n"))
    }
}
