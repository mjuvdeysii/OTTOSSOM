import XCTest
@testable import OTTOSSOM

/// The RPG's content and battles. Balance: a sensible player (Battle.suggest) must win the ordinary fights nearly
/// always, and the bosses most of the time at the level they're met; numbers come from Tools/rpg/sim.py.
final class RPGTests: XCTestCase {
    func testContentLoads() {
        let c = RPGContent.shared
        XCTAssertEqual(Set(c.maps.keys), ["town", "wilds", "cellar1", "cellar2"])
        for (id, m) in c.maps {
            XCTAssertTrue(m.map.allSatisfy { $0.count == m.w }, "\(id) ragged")
            for ex in m.exits { XCTAssertNotNil(c.maps[ex.to], "\(id) exit to \(ex.to)") }
            for ch in m.chests { XCTAssertNotNil(c.items[ch.item], "\(id) chest item \(ch.item)") }
            for f in m.foes { XCTAssertTrue(f.party.allSatisfy { FoeKind(rawValue: $0) != nil }, "\(id) foe \(f.id)") }
            for n in m.npcs { XCTAssertNotNil(c.lines[n.talk] ?? (n.id == "moss" ? [] : nil), "\(id) lines \(n.talk)") }
            for t in m.tablets { XCTAssertNotNil(c.lines[t.lore], "\(id) lore \(t.lore)") }
        }
        for k in ["intro", "mossMeet", "bossBefore", "bossAfter", "defeat", "hankHome"] { XCTAssertNotNil(c.lines[k], k) }
    }

    private func party(_ lv: Int) -> [PartyStats] {
        [Member(hero: .otto, level: lv, hp: 999), Member(hero: .moss, level: lv, hp: 999)].map { Stats.of($0) }
    }

    private func winRate(_ foes: [FoeKind], level: Int, runs: Int = 300) -> (Double, Double) {
        var wins = 0, rounds = 0
        for seed in 0..<runs {
            var s = Battle.start(party: party(level), foes: foes, seed: UInt64(seed))
            var tea = 2
            while s.outcome == .ongoing && s.round < 40 {
                let acts = Battle.suggest(s, levels: [.otto: level, .moss: level], tea: tea)
                tea -= acts.filter { $0.item == "tea" }.count
                _ = Battle.resolve(&s, acts)
            }
            if s.outcome == .won { wins += 1; rounds += s.round }
        }
        return (Double(wins) / Double(runs), wins > 0 ? Double(rounds) / Double(wins) : 0)
    }

    func testBalance() {
        var report: [String] = []
        let cases: [(String, [FoeKind], Int, Double)] = [
            ("town shade", [.shade], 1, 0.97), ("town 2 shades", [.shade, .shade], 1, 0.9),
            ("wilds shell", [.shell], 2, 0.95), ("wilds moth+shade", [.moth, .shade], 2, 0.95), ("wilds fang", [.fang], 2, 0.95),
            ("wilds shell+moth", [.shell, .moth], 3, 0.95), ("cellar fang+shade", [.fang, .shade], 3, 0.95),
            ("cellar 2 shells", [.shell, .shell], 3, 0.9), ("cellar 2 moths+shade", [.moth, .moth, .shade], 3, 0.9),
            ("big shade", [.bigshade], 4, 0.8), ("maw", [.maw], 5, 0.55),
        ]
        for (name, foes, lv, floor) in cases {
            let (r, rounds) = winRate(foes, level: lv)
            report.append("\(name)\tLv\(lv)\twin \(Int(r * 100))%\trounds \(String(format: "%.1f", rounds))")
            XCTAssertGreaterThanOrEqual(r, floor, "\(name): \(r)")
        }
        // the boss must not fall to plain attacks
        var naiveWins = 0
        for seed in 0..<200 {
            var s = Battle.start(party: party(5), foes: [.maw], seed: UInt64(seed))
            while s.outcome == .ongoing && s.round < 40 {
                let acts = s.party.filter { $0.alive }.map { p in
                    BattleAction(actor: p.id, skill: p.hero == .otto ? (s.light >= 1 ? .shine : .defend) : .bump, target: s.foes.first { $0.alive }?.id)
                }
                _ = Battle.resolve(&s, acts)
            }
            if s.outcome == .won { naiveWins += 1 }
        }
        report.append("maw, attacks only\twin \(naiveWins * 100 / 200)%")
        XCTAssertLessThan(naiveWins, 100, "the maw falls to plain attacks")
        if let path = ProcessInfo.processInfo.environment["LEVEL_REPORT"] {
            try? (report.joined(separator: "\n") + "\n").write(toFile: path + ".rpg", atomically: true, encoding: .utf8)
        }
        print(report.joined(separator: "\n"))
    }

    func testRulesBasics() {
        var s = Battle.start(party: party(1), foes: [.shade], seed: 1)
        let foe = s.foes[0].id
        let l0 = s.light
        _ = Battle.resolve(&s, [BattleAction(actor: 1, skill: .touch, target: foe), BattleAction(actor: 0, skill: .defend)])
        XCTAssertTrue(s.fighter(foe)!.revealed)
        XCTAssertGreaterThanOrEqual(s.light, min(Battle.lightMax, l0 + 2 + 1 + 1) - 1)   // touch +2, defend +1, round +1, a drain may take 1
        var s2 = Battle.start(party: party(1), foes: [.shade], seed: 2)
        let hp0 = s2.foes[0].hp
        _ = Battle.resolve(&s2, [BattleAction(actor: 0, skill: .shine, target: s2.foes[0].id), BattleAction(actor: 1, skill: .defend)])
        XCTAssertLessThan(s2.foes[0].hp, hp0 + 4)
    }
}
