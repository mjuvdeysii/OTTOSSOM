import Foundation

// 《灯台索魔》 battles — turn-based, with every foe's next move shown above its head. The same rules as the balance
// model in Tools/rpg/sim.py (tune there, then here).
//
// A round: the party picks one action each; then everyone acts in order of speed. Light is shared by the party:
// 3 at the start, +1 every round, up to 10; Otto's skills spend it, Moss's touch and defending earn it, and foes
// that drain take it away (the maw keeps what it takes and spews it back when it holds five).

struct Rng: RandomNumberGenerator {
    var s: UInt64
    init(_ seed: UInt64) { s = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func int(_ lo: Int, _ hi: Int) -> Int { lo + Int(next() % UInt64(hi - lo + 1)) }
}

enum FoeKind: String, Codable, CaseIterable {
    case shade, shell, moth, fang, bigshade, maw

    var name: String {
        switch self {
        case .shade: return "冷影"
        case .shell: return "石壳影"
        case .moth: return "灯蛾"
        case .fang: return "尖影"
        case .bigshade: return "窖口大影"
        case .maw: return "灯吞"
        }
    }
    /// hp, atk, def, spd, light ×, physical ×, xp, motes
    var base: (hp: Int, atk: Int, def: Int, spd: Double, light: Double, phys: Double, xp: Int, motes: Int) {
        switch self {
        case .shade: return (30, 16, 1, 5, 1.5, 1.0, 6, 3)
        case .shell: return (44, 17, 6, 3, 0.5, 1.5, 9, 5)
        case .moth: return (20, 13, 0, 9, 1.25, 1.0, 7, 4)
        case .fang: return (40, 16, 2, 6, 1.0, 1.0, 10, 5)
        case .bigshade: return (150, 19, 3, 4, 1.25, 1.0, 40, 30)
        case .maw: return (280, 17, 4, 5, 1.0, 1.0, 80, 60)
        }
    }
    var isBoss: Bool { self == .bigshade || self == .maw }
    /// What it's weak to, in words for the "touch" card.
    var weakness: String {
        switch self {
        case .shade: return "怕光"
        case .shell: return "怕撞，光打在壳上只剩一半"
        case .moth: return "怕光，强光能把它晃晕"
        case .fang: return "蓄力时推它一下，咬就落空"
        case .bigshade: return "怕光；先清掉它叫来的冷影"
        case .maw: return "攒满五团光就会吐出来；肚子发亮时怕强光，「我的！」能把光抢回来"
        }
    }
}

enum Intent: String, Codable {
    case hit, drain1, drain2, shell, charge, bite, flutter, slam, summon, spew

    var icon: String {
        switch self {
        case .hit, .slam: return "burst.fill"
        case .bite: return "bolt.fill"
        case .flutter: return "wind"
        case .drain1, .drain2: return "drop.halffull"
        case .shell: return "shield.fill"
        case .charge: return "hourglass"
        case .summon: return "plus.circle.fill"
        case .spew: return "sun.max.trianglebadge.exclamationmark.fill"
        }
    }
    var label: String {
        switch self {
        case .hit: return "攻击"
        case .slam: return "重击"
        case .bite: return "猛咬"
        case .flutter: return "扑全体"
        case .drain1: return "偷 1 光"
        case .drain2: return "偷 2 光"
        case .shell: return "缩壳"
        case .charge: return "蓄力"
        case .summon: return "叫帮手"
        case .spew: return "吐光·全体"
        }
    }
    var power: Double {
        switch self {
        case .hit: return 1.0
        case .slam: return 1.3
        case .bite: return 2.2
        case .flutter: return 0.6
        case .spew: return 1.8
        default: return 0
        }
    }
}

enum SkillID: String, Codable, CaseIterable {
    case shine, warm, flare, vigil, bump, touch, shove, mine, defend, item, flee
}

enum Aim { case foe, allFoes, ally, party, none }

struct Skill {
    let id: SkillID
    let name: String
    let icon: String
    let hero: Hero?          // nil: anyone
    let cost: Int
    let level: Int
    let aim: Aim
    let text: String

    static let all: [SkillID: Skill] = [
        .shine: Skill(id: .shine, name: "照", icon: "light.max", hero: .otto, cost: 1, level: 1, aim: .foe, text: "一束光，单体。影子怕光。"),
        .warm: Skill(id: .warm, name: "暖光", icon: "sun.haze.fill", hero: .otto, cost: 2, level: 1, aim: .party, text: "全队回复三成多的生命。"),
        .flare: Skill(id: .flare, name: "强光", icon: "sun.max.fill", hero: .otto, cost: 4, level: 3, aim: .allFoes, text: "照亮全场，打所有敌人；灯蛾会被晃晕。"),
        .vigil: Skill(id: .vigil, name: "守夜", icon: "shield.lefthalf.filled", hero: .otto, cost: 0, level: 5, aim: .none, text: "这一回合替莫斯挨打，自己受伤减半，+1 光。"),
        .bump: Skill(id: .bump, name: "撞", icon: "circle.circle.fill", hero: .moss, cost: 0, level: 1, aim: .foe, text: "用整个身子撞过去。石壳怕撞。"),
        .touch: Skill(id: .touch, name: "摸", icon: "hand.point.up.left.fill", hero: .moss, cost: 0, level: 1, aim: .foe, text: "摸一摸，看穿弱点和接下来两步；+2 光。"),
        .shove: Skill(id: .shove, name: "推", icon: "arrow.right.circle.fill", hero: .moss, cost: 0, level: 2, aim: .foe, text: "推一把，伤害小，但它这一回合的动作会被推后。"),
        .mine: Skill(id: .mine, name: "我的！", icon: "hand.raised.fill", hero: .moss, cost: 0, level: 4, aim: .foe, text: "扑上去，把它偷走的光全抢回来。"),
        .defend: Skill(id: .defend, name: "防御", icon: "shield.fill", hero: nil, cost: 0, level: 1, aim: .none, text: "受到的伤害减半，+1 光。"),
        .item: Skill(id: .item, name: "道具", icon: "bag.fill", hero: nil, cost: 0, level: 1, aim: .none, text: "用一件道具。"),
        .flee: Skill(id: .flee, name: "逃跑", icon: "figure.run", hero: nil, cost: 0, level: 1, aim: .none, text: "七成机会逃掉。Boss 战逃不了。"),
    ]
}

struct Fighter: Identifiable {
    let id: Int
    var name: String
    var hero: Hero?
    var kind: FoeKind?
    var maxHP: Int
    var hp: Int
    var atk: Int
    var def: Int
    var spd: Double
    var lightX = 1.0
    var physX = 1.0
    var stun = 0
    var slow = false
    var shell = false
    var revealed = false
    var stolen = 0
    var intents: [Intent] = []
    var isFoe: Bool { kind != nil }
    var alive: Bool { hp > 0 }
}

struct BattleAction: Equatable {
    var actor: Int
    var skill: SkillID
    var target: Int? = nil
    var item: String? = nil
}

enum BattleEvent: Equatable {
    case act(Int, String)                    // who, what (a skill or intent name)
    case damage(Int, Int, weak: Bool, resisted: Bool)
    case heal(Int, Int)
    case light(Int)                          // change of the party's light
    case stolen(Int, Int)                    // foe took n light
    case regain(Int, Int)                    // took n light back from foe
    case stun(Int), slow(Int), reveal(Int), shell(Int), guarding(Int), defend(Int)
    case summon(Int)
    case ko(Int)
    case fled(Bool)
}

enum BattleOutcome: Equatable { case ongoing, won, lost, fled }

struct BattleState {
    var fighters: [Fighter]
    var light = 3
    var round = 0
    var rng: Rng
    var outcome: BattleOutcome = .ongoing
    var boss: Bool
    var nextID: Int

    var party: [Fighter] { fighters.filter { !$0.isFoe } }
    var foes: [Fighter] { fighters.filter { $0.isFoe } }
    func index(_ id: Int) -> Int? { fighters.firstIndex { $0.id == id } }
    func fighter(_ id: Int) -> Fighter? { fighters.first { $0.id == id } }
}

/// The party as it walks into a fight.
struct PartyStats {
    var hero: Hero
    var level: Int
    var maxHP: Int
    var hp: Int
    var atk: Int
    var def: Int
    var spd: Double
}

enum Battle {
    static let lightMax = 10

    static func makeFoe(_ k: FoeKind, id: Int, rng: inout Rng) -> Fighter {
        let b = k.base
        var f = Fighter(id: id, name: k.name, hero: nil, kind: k, maxHP: b.hp, hp: b.hp, atk: b.atk, def: b.def, spd: b.spd,
                        lightX: b.light, physX: b.phys)
        f.intents = [pick(k, &rng), pick(k, &rng)]
        return f
    }

    static func start(party: [PartyStats], foes: [FoeKind], seed: UInt64, startLight: Int = 3) -> BattleState {
        var rng = Rng(seed)
        var fs: [Fighter] = party.enumerated().map { i, p in
            Fighter(id: i, name: p.hero == .otto ? "奥托" : p.hero == .moss ? "莫斯" : "莫斯托", hero: p.hero, kind: nil,
                    maxHP: p.maxHP, hp: p.hp, atk: p.atk, def: p.def, spd: p.spd)
        }
        var id = 10
        for k in foes { fs.append(makeFoe(k, id: id, rng: &rng)); id += 1 }
        // two of the same get told apart
        var seen: [String: Int] = [:]
        for i in fs.indices where fs[i].isFoe {
            let n = fs[i].name; seen[n, default: 0] += 1
            if foes.filter({ $0.name == n }).count > 1 { fs[i].name = n + ["甲", "乙", "丙", "丁"][min(3, seen[n]! - 1)] }
        }
        var s = BattleState(fighters: fs, light: startLight, rng: rng, boss: foes.contains { $0.isBoss }, nextID: id)
        s.round = 1
        return s
    }

    static func pick(_ k: FoeKind, _ rng: inout Rng) -> Intent {
        let r = rng.unit()
        switch k {
        case .shade: return r < 0.4 ? .drain1 : .hit
        case .shell: return r < 0.4 ? .shell : .hit
        case .moth: return r < 0.5 ? .drain2 : .flutter
        case .fang: return r < 0.45 ? .charge : .hit
        case .bigshade: return r < 0.3 ? .summon : r < 0.5 ? .drain2 : .slam
        case .maw: return r < 0.5 ? .drain2 : .bite
        }
    }

    static func damage(_ atk: Int, _ power: Double, _ mult: Double, _ def: Int, _ rng: inout Rng) -> Int {
        max(1, Int((Double(atk) * power * mult - Double(def) * 0.5).rounded()) + rng.int(-1, 1))
    }

    /// Who can do what right now (skills the hero has learned and can pay for).
    static func usable(_ s: BattleState, _ f: Fighter, level: Int) -> [Skill] {
        let mine: [SkillID] = f.hero == .otto ? [.shine, .warm, .flare, .vigil] : f.hero == .moss ? [.bump, .touch, .shove, .mine] : []
        return (mine + [.defend, .item, .flee]).compactMap { Skill.all[$0] }.filter { $0.level <= level }
    }

    /// The light multiplier a light skill gets against this foe right now (the maw's belly glows from 3 stolen).
    static func lightMult(_ f: Fighter) -> Double { f.lightX * (f.kind == .maw && f.stolen >= 3 ? 2.0 : 1.0) }

    /// Plays one round: the party's actions and every foe's shown intent, in speed order.
    static func resolve(_ s: inout BattleState, _ actions: [BattleAction]) -> [BattleEvent] {
        var ev: [BattleEvent] = []
        guard s.outcome == .ongoing else { return ev }
        let acts = Dictionary(uniqueKeysWithValues: actions.map { ($0.actor, $0) })
        let defending = Set(actions.filter { $0.skill == .defend }.map { $0.actor })
        let ottoID = s.party.first { $0.hero == .otto }?.id
        let mossID = s.party.first { $0.hero == .moss }?.id
        let vigil = actions.contains { $0.skill == .vigil && $0.actor == ottoID }
        for d in defending { ev.append(.defend(d)) }
        if vigil, let o = ottoID { ev.append(.guarding(o)) }
        // speed order; party first on ties
        let order = s.fighters.filter { $0.alive }.sorted { a, b in a.spd != b.spd ? a.spd > b.spd : (!a.isFoe && b.isFoe) }.map { $0.id }
        for id in order {
            guard s.outcome == .ongoing, let i = s.index(id), s.fighters[i].alive else { continue }
            if s.fighters[i].isFoe {
                foeTurn(&s, i, vigil: vigil, otto: ottoID, moss: mossID, defending: defending, &ev)
            } else if let a = acts[id] {
                heroTurn(&s, i, a, &ev)
            }
            settle(&s, &ev)
        }
        if s.outcome == .ongoing {
            s.round += 1
            let before = s.light
            s.light = min(lightMax, s.light + 1)
            if s.light != before { ev.append(.light(s.light - before)) }
        }
        return ev
    }

    private static func settle(_ s: inout BattleState, _ ev: inout [BattleEvent]) {
        if s.foes.allSatisfy({ !$0.alive }) { s.outcome = .won }
        else if s.party.allSatisfy({ !$0.alive }) { s.outcome = .lost }
    }

    private static func hurt(_ s: inout BattleState, _ t: Int, _ amount: Int, weak: Bool, resisted: Bool, _ ev: inout [BattleEvent]) {
        guard let i = s.index(t), s.fighters[i].alive else { return }
        s.fighters[i].hp = max(0, s.fighters[i].hp - amount)
        ev.append(.damage(t, amount, weak: weak, resisted: resisted))
        if s.fighters[i].hp == 0 { ev.append(.ko(t)) }
    }

    private static func liveTarget(_ s: BattleState, _ t: Int?) -> Int? {
        if let t, let f = s.fighter(t), f.alive, f.isFoe { return t }
        return s.foes.first { $0.alive }?.id
    }

    private static func heroTurn(_ s: inout BattleState, _ i: Int, _ a: BattleAction, _ ev: inout [BattleEvent]) {
        let me = s.fighters[i]
        guard let sk = Skill.all[a.skill] else { return }
        if s.light < sk.cost { ev.append(.act(me.id, "光不够")); return }
        ev.append(.act(me.id, sk.name))
        if sk.cost > 0 { s.light -= sk.cost; ev.append(.light(-sk.cost)) }
        switch a.skill {
        case .shine:
            guard let t = liveTarget(s, a.target), let ti = s.index(t) else { return }
            let m = lightMult(s.fighters[ti])
            var d = damage(me.atk, 1.0, m, s.fighters[ti].def, &s.rng)
            if s.fighters[ti].shell { d /= 2 }
            hurt(&s, t, d, weak: m > 1.01, resisted: m < 0.99 || s.fighters[ti].shell, &ev)
        case .flare:
            for f in s.foes where f.alive {
                guard let ti = s.index(f.id) else { continue }
                let m = lightMult(f)
                var d = damage(me.atk, 0.9, m, f.def, &s.rng)
                if f.shell { d /= 2 }
                hurt(&s, f.id, d, weak: m > 1.01, resisted: m < 0.99 || f.shell, &ev)
                if f.kind == .moth, s.fighters[ti].alive { s.fighters[ti].stun = 1; ev.append(.stun(f.id)) }
            }
        case .warm:
            for p in s.party where p.alive {
                guard let pi = s.index(p.id) else { continue }
                let h = min(p.maxHP - p.hp, Int((Double(p.maxHP) * 0.35).rounded()))
                s.fighters[pi].hp += h
                ev.append(.heal(p.id, h))
            }
        case .vigil:
            s.light = min(lightMax, s.light + 1); ev.append(.light(1))
        case .bump, .shove, .mine:
            guard let t = liveTarget(s, a.target), let ti = s.index(t) else { return }
            let power = a.skill == .bump ? 1.0 : a.skill == .shove ? 0.6 : 1.2
            let m = s.fighters[ti].physX
            var d = damage(me.atk, power, m, s.fighters[ti].def, &s.rng)
            if s.fighters[ti].shell && a.skill != .bump { d /= 2 }
            hurt(&s, t, d, weak: m > 1.01, resisted: m < 0.99, &ev)
            if a.skill == .shove, s.fighters[ti].alive { s.fighters[ti].slow = true; ev.append(.slow(t)) }
            if a.skill == .mine, s.fighters[ti].stolen > 0 {
                let n = s.fighters[ti].stolen
                s.fighters[ti].stolen = 0
                let before = s.light
                s.light = min(lightMax, s.light + n)
                ev.append(.regain(t, n)); ev.append(.light(s.light - before))
            }
        case .touch:
            guard let t = liveTarget(s, a.target), let ti = s.index(t) else { return }
            s.fighters[ti].revealed = true; ev.append(.reveal(t))
            let before = s.light
            s.light = min(lightMax, s.light + 2); ev.append(.light(s.light - before))
        case .defend:
            let before = s.light
            s.light = min(lightMax, s.light + 1); ev.append(.light(s.light - before))
        case .item:
            useItem(&s, me.id, a.item ?? "", a.target, &ev)
        case .flee:
            if s.boss { ev.append(.fled(false)); return }
            let ok = s.rng.unit() < 0.7
            ev.append(.fled(ok))
            if ok { s.outcome = .fled }
        }
    }

    static func useItem(_ s: inout BattleState, _ user: Int, _ item: String, _ target: Int?, _ ev: inout [BattleEvent]) {
        switch item {
        case "tea":
            let t = target.flatMap { s.fighter($0) }.flatMap { $0.isFoe ? nil : $0 } ?? s.party.filter { $0.alive }.min { $0.hp < $1.hp }
            guard let p = t, p.alive, let pi = s.index(p.id) else { return }
            let h = min(p.maxHP - p.hp, 40)
            s.fighters[pi].hp += h; ev.append(.heal(p.id, h))
        case "oil":
            let before = s.light
            s.light = min(lightMax, s.light + 3); ev.append(.light(s.light - before))
        case "jar":
            for f in s.foes where f.alive { hurt(&s, f.id, 14, weak: false, resisted: false, &ev) }
        default: break
        }
    }

    private static func foeTurn(_ s: inout BattleState, _ i: Int, vigil: Bool, otto: Int?, moss: Int?, defending: Set<Int>, _ ev: inout [BattleEvent]) {
        if s.fighters[i].stun > 0 { s.fighters[i].stun -= 1; ev.append(.act(s.fighters[i].id, "晕着")); return }
        if s.fighters[i].slow { s.fighters[i].slow = false; ev.append(.act(s.fighters[i].id, "被推开了")); return }
        guard let kind = s.fighters[i].kind, !s.fighters[i].intents.isEmpty else { return }
        let it = s.fighters[i].intents.removeFirst()
        s.fighters[i].intents.append(pick(kind, &s.rng))
        s.fighters[i].shell = false
        let me = s.fighters[i]
        ev.append(.act(me.id, it.label))
        let living = s.party.filter { $0.alive }.map { $0.id }
        guard !living.isEmpty else { return }
        func strike(_ target: Int, _ power: Double) {
            var t = target
            var guarded = false
            if vigil, let o = otto, let m = moss, t == m, s.fighter(o)?.alive == true { t = o; guarded = true }
            guard let tf = s.fighter(t) else { return }
            var d = damage(me.atk, power, 1.0, tf.def, &s.rng)
            if defending.contains(t) || (guarded || (vigil && t == otto)) { d = d / 2 }
            hurt(&s, t, max(1, d), weak: false, resisted: false, &ev)
        }
        func someone() -> Int { living[Int(s.rng.next() % UInt64(living.count))] }
        switch it {
        case .hit, .slam, .bite: strike(someone(), it.power)
        case .flutter, .spew:
            for t in living { strike(t, it.power) }
            if it == .spew { s.fighters[i].stolen = 0 }
        case .shell:
            s.fighters[i].shell = true; ev.append(.shell(me.id))
        case .charge:
            s.fighters[i].intents[0] = .bite
        case .drain1, .drain2:
            let n = it == .drain1 ? 1 : 2
            let got = min(s.light, n)
            if got > 0 { s.light -= got; ev.append(.light(-got)); ev.append(.stolen(me.id, got)) }
            s.fighters[i].stolen += got
            if got < n {      // nothing left to take: it bites the light out of someone instead
                strike(someone(), 0.5 * Double(n - got))
                if kind == .maw { s.fighters[i].stolen += n - got; ev.append(.stolen(me.id, n - got)) }
            }
            if kind == .shade, s.fighters[i].alive {
                let h = min(4, s.fighters[i].maxHP - s.fighters[i].hp)
                if h > 0 { s.fighters[i].hp += h; ev.append(.heal(me.id, h)) }
            }
            if kind == .maw, s.fighters[i].stolen >= 5 { s.fighters[i].intents[0] = .spew }
        case .summon:
            if s.foes.filter({ $0.alive }).count < 3 {
                var f = makeFoe(.shade, id: s.nextID, rng: &s.rng)
                f.name = "冷影"
                s.nextID += 1
                s.fighters.append(f)
                ev.append(.summon(f.id))
            }
        }
    }

    /// A simple sensible player, for the balance test and the auto-battle hint.
    static func suggest(_ s: BattleState, levels: [Hero: Int], tea: Int) -> [BattleAction] {
        var out: [BattleAction] = []
        let alive = s.foes.filter { $0.alive }
        guard !alive.isEmpty else { return out }
        var light = s.light
        for p in s.party where p.alive {
            let lv = levels[p.hero ?? .otto] ?? 1
            if p.hero == .moss {
                if lv >= 4, let maw = alive.first(where: { $0.kind == .maw && $0.stolen >= 3 }) { out.append(.init(actor: p.id, skill: .mine, target: maw.id)) }
                else if lv >= 2, let c = alive.first(where: { $0.intents.first == .charge }) { out.append(.init(actor: p.id, skill: .shove, target: c.id)) }
                else if light < 4, let u = alive.first(where: { !$0.revealed && ($0.kind?.isBoss == true || $0.kind == .shell || $0.kind == .fang) }) {
                    out.append(.init(actor: p.id, skill: .touch, target: u.id)); light += 2
                } else {
                    let t = alive.max { a, b in a.physX != b.physX ? a.physX < b.physX : a.hp > b.hp }!
                    out.append(.init(actor: p.id, skill: .bump, target: t.id))
                }
            } else {
                let low = s.party.filter { $0.alive && Double($0.hp) < Double($0.maxHP) * 0.45 }
                if !low.isEmpty && light >= 2 { out.append(.init(actor: p.id, skill: .warm)); light -= 2 }
                else if let l = low.min(by: { $0.hp < $1.hp }), tea > 0 { out.append(.init(actor: p.id, skill: .item, target: l.id, item: "tea")) }
                else if alive.count >= 3 && light >= 4 && lv >= 3 { out.append(.init(actor: p.id, skill: .flare)); light -= 4 }
                else if light >= 1 {
                    let t = alive.max { a, b in lightMult(a) != lightMult(b) ? lightMult(a) < lightMult(b) : a.hp > b.hp }!
                    out.append(.init(actor: p.id, skill: .shine, target: t.id)); light -= 1
                } else { out.append(.init(actor: p.id, skill: .defend)) }
            }
        }
        return out
    }
}
