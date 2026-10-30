import Foundation

/// A player made of rules, for pacing the whole game in tests: it digs down, steers toward the next memory stone,
/// takes crystals beside it, flashes at shadows, and goes home when the bag is full or the light is low. By day it
/// lights whatever lamps it can and buys upgrades (claw first).
struct DigBot {
    var side = 1.0
    var sideFor = 0.0
    var lastP = V2(0, 0)
    var stuck = 0.0

    mutating func steer(_ sim: inout DigSim, _ dt: Double) {
        if sim.light < sim.lightMax * 0.22 || sim.bag.count >= sim.capacity { sim.reelIn(); return }
        if sim.openMemory != nil { sim.openMemory = nil }
        if sim.shades.contains(where: { $0.p.dist(sim.p) < 30 }) { sim.flash() }
        let (fx, fy) = sim.tileAt(sim.p + V2(0, -1))
        // stuck: hop and change side
        if sim.p.dist(lastP) < 0.5 { stuck += dt } else { stuck = 0 }
        lastP = sim.p
        if stuck > 1.2 { side = -side; sideFor = 0.5; stuck = 0; sim.push(V2(0, -1)); return }
        if sideFor > 0 { sideFor -= dt; sim.push(V2(side, 0)); return }
        // the next memory stone, if it's not far below: go for it first
        var goal: (Int, Int)?
        if let m = sim.world.memories.sorted(by: { $0.key < $1.key }).first(where: { Cell(rawValue: sim.world.cells[$0.value]) == .memory })?.value {
            let mx = m % DigWorld.W, my = m / DigWorld.W
            if my >= fy - 1 && my - fy <= 12 && reachable(sim, mx, my) { goal = (mx, my) }
        } else if !sim.nestDone && sim.depth > 70 {
            goal = (DigWorld.nestX, DigWorld.nestY)
        }
        // otherwise the nearest crystal or trinket it can dig, not above it
        if goal == nil && sim.bag.count < sim.capacity {
            var best = 1e9
            for dy in -1...8 { for x in 0..<DigWorld.W {
                let y = fy + dy
                let c = sim.world.at(x, y)
                guard c == .amber || c == .trinket || c == .blue || c == .red, c.claw <= sim.claw, reachable(sim, x, y) else { continue }
                let d = Double(abs(x - fx)) + Double(abs(dy)) * 1.4
                if d < best { best = d; goal = (x, y) }
            } }
        }
        if let g = goal {
            let gx = g.0, gy = g.1
            if gy < fy { sim.push(V2(0, -1)); sideFor = 0.25; side = gx > fx ? 1 : -1; return }
            if gy == fy { sim.push(V2(gx > fx ? 1 : -1, 0)); return }
            if gx != fx && gy - fy <= 2 { sim.push(V2(gx > fx ? 1 : -1, 0)); return }
            if gx != fx { side = gx > fx ? 1 : -1 }
        }
        // dig down; if the ground below is too hard, go sideways for a bit
        let below = sim.world.at(fx, fy + 1)
        if below.solid && below.claw > sim.claw || below == .bedrock || below == .memoryRead {
            sideFor = 0.8; sim.push(V2(side, 0)); return
        }
        if let g = goal, g.0 != fx, sim.grounded, below.solid == false || below.claw <= sim.claw {
            // drift toward the goal's column on the way down
            if Int(sim.t * 2) % 3 == 0 { sim.push(V2(side, 0)); return }
        }
        sim.push(V2(0, 1))
    }

    /// Whether a cell can be dug or walked into with the claw it has (the cell itself, not the way there).
    private func reachable(_ sim: DigSim, _ x: Int, _ y: Int) -> Bool {
        let c = sim.world.at(x, y)
        return c == .air || c == .memory || (c.dig != nil && c.claw <= sim.claw)
    }

    /// One night, to the end.
    static func night(_ save: DigSave, seed: UInt64) -> DigSim {
        var sim = DigSim(world: save.world, upgrades: save.upgrades, seed: seed)
        sim.nestDone = save.seen.contains("ending")
        var bot = DigBot()
        let dt = 1.0 / 30
        var n = 0
        while sim.outcome == 0 && n < 30 * 400 {
            bot.steer(&sim, dt)
            sim.step(dt)
            if sim.atNest && !sim.nestDone { sim.nestDone = true; sim.reelIn() }
            sim.events = []
            n += 1
        }
        return sim
    }

    /// One whole day: the night's dig, the shop, the stall.
    static func day(_ s: inout DigSave) -> DigSim {
        let sim = night(s, seed: UInt64(s.day) * 977 + 13)
        s.world = sim.world
        _ = s.bank(sim.bag)
        s.deepest = max(s.deepest, sim.deepest)
        for n in 1...8 where sim.world.memories[n].map({ Cell(rawValue: sim.world.cells[$0]) == .memoryRead }) == true && !s.memories.contains(n) {
            s.memories.append(n)
        }
        if sim.nestDone { s.seen.insert("ending") }
        s.openShop()
        for o in s.orders where o.color.recipe.allSatisfy({ g in (s.gems[g] ?? 0) >= o.color.recipe.filter { $0 == g }.count }) {
            _ = s.light(o, with: o.color.recipe)
        }
        for key in ["claw", "bag", "wick", "claw", "bag", "wick"] {
            let lv = s.upgrades[key] ?? 0
            // the claw first: it opens the stone
            if key != "claw" && (s.upgrades["claw"] ?? 0) < 1 { continue }
            if key != "claw" && (s.upgrades["claw"] ?? 0) < 2 && s.deepest >= 30 && s.coins < 90 + 20 { continue }
            if let costs = DigSave.upgradeCosts[key], lv < costs.count, s.coins >= costs[lv] {
                s.coins -= costs[lv]; s.upgrades[key] = lv + 1
            }
        }
        s.day += 1
        return sim
    }
}
