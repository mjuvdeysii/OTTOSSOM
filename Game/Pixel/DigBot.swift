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
        // a crystal or trinket right beside: take it
        for dx in [-1, 1] {
            let c = sim.world.at(fx + dx, fy)
            if (c == .amber || c == .trinket || (c == .blue && sim.claw >= 1) || (c == .red && sim.claw >= 2)) && sim.bag.count < sim.capacity {
                sim.push(V2(Double(dx), 0)); return
            }
        }
        // the next memory stone, if it's not far below: line up with it
        if let m = sim.world.memories.sorted(by: { $0.key < $1.key }).first(where: { Cell(rawValue: sim.world.cells[$0.value]) == .memory })?.value {
            let mx = m % DigWorld.W, my = m / DigWorld.W
            if my >= fy && my - fy <= 14 {
                if my == fy { sim.push(V2(mx > fx ? 1 : -1, 0)); return }
                if mx != fx && my - fy <= 3 { sim.push(V2(mx > fx ? 1 : -1, 0)); return }
                if mx != fx && my - fy > 3 && sim.grounded {
                    // dig down, but drift toward its column on the way
                    side = mx > fx ? 1 : -1
                }
            }
        } else if !sim.nestDone {
            let nx = DigWorld.nestX
            if abs(nx - fx) > 1 && sim.grounded && sim.depth > 80 { sim.push(V2(nx > fx ? 1 : -1, 0)); return }
        }
        // dig down; if the ground below is too hard, go sideways for a bit
        let below = sim.world.at(fx, fy + 1)
        if below.solid && below.claw > sim.claw || below == .bedrock || below == .memoryRead {
            sideFor = 0.45; sim.push(V2(side, 0)); return
        }
        sim.push(V2(0, 1))
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
            if let costs = DigSave.upgradeCosts[key], lv < costs.count, s.coins >= costs[lv] {
                s.coins -= costs[lv]; s.upgrades[key] = lv + 1
            }
        }
        s.day += 1
        return sim
    }
}
