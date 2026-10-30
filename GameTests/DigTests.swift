import XCTest
@testable import OTTOSSOM

/// The dig and the shop: the world, digging, the bag, the light, mixing colours, paying.
final class DigTests: XCTestCase {
    func testWorld() {
        let w = DigWorld(seed: 20261030)
        XCTAssertEqual(w.cells.count, DigWorld.W * DigWorld.H)
        for x in 0..<DigWorld.W { XCTAssertEqual(w.at(x, DigWorld.H - 1), .bedrock); XCTAssertEqual(w.at(x, DigWorld.ground), .grass) }
        XCTAssertEqual(Set(w.memories.keys), [1, 2, 3, 4])
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
