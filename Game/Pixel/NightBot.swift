import Foundation

/// A player made of rules, for balancing the nights in tests and for the CI screenshots: it wakes Otto when the
/// light is low, loops Mosto when he's out, loops the maw when its belly glows, loops a shell that's getting close,
/// and otherwise runs small circles round Otto so the thread sweeps and the trail closes on whatever comes near.
struct NightBot {
    var a = 0.0
    var skill = 1.0          // 1: quick hands; lower is slower and sloppier

    mutating func steer(_ sim: inout NightSim, _ dt: Double) {
        if sim.light < sim.lightMax * 0.45, sim.wakeCD <= 0 { _ = sim.wake() }
        let center: V2
        var r = 15.0
        if let th = sim.thief, th.state <= 1 {
            center = th.p
        } else if let m = sim.maw, m.hp > 0, m.belly >= 1 || !sim.foes.contains(where: { $0.p.dist(sim.otto) < 45 }) {
            center = m.p + V2(0, 6); r = 17
        } else if let sh = sim.foes.filter({ $0.type == .shell && $0.p.dist(sim.otto) < 75 }).min(by: { $0.p.dist(sim.otto) < $1.p.dist(sim.otto) }) {
            center = sh.p
        } else {
            center = sim.otto + V2(0, -4); r = 24
        }
        a += 155 * skill / r * dt
        sim.touch(center + V2(cos(a) * r, sin(a) * r))
    }

    /// Plays one night to the end (or a time limit) at 60 steps a second.
    static func play(_ spec: NightSpec, seed: UInt64, upgrades: [String: Int] = [:], skill: Double = 1, w: Double = 195, h: Double = 422) -> NightSim {
        var sim = NightSim(spec: spec, w: w, h: h, seed: seed, upgrades: upgrades)
        var bot = NightBot(skill: skill)
        let dt = 1.0 / 60
        var n = 0
        while sim.outcome == 0 && n < 60 * 240 {
            bot.steer(&sim, dt)
            sim.step(dt)
            sim.events = []
            n += 1
        }
        return sim
    }
}
