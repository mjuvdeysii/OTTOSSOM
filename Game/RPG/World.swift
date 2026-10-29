import SwiftUI

// The adventure: where everyone is, what they carry, what's been done — and walking, talking, opening, fighting.

struct Member: Codable, Equatable {
    var hero: Hero
    var level = 1
    var xp = 0
    var hp: Int
    var equip: String?
}

struct SaveData: Codable {
    var map = "town"
    var x = 11
    var y = 18
    var members: [Member] = [Member(hero: .otto, hp: 46)]
    var bag: [String: Int] = ["tea": 2]
    var motes = 10
    var flags: Set<String> = []
    var opened: Set<String> = []
    var beaten: Set<String> = []
    var lit: Set<String> = []
    var quests: [String: Int] = ["main": 0]
    var lampMap = "town"
    var lampX = 11
    var lampY = 18
    var seen: [String: [Int]] = [:]       // fog: cells already seen, per map
    var battles = 0
}

enum Stats {
    static let levels = [0, 20, 50, 95, 155, 230, 320, 430, 99999]
    static let maxLevel = 8
    static func base(_ h: Hero, _ lv: Int) -> (hp: Int, atk: Int, def: Int, spd: Double) {
        let l = Double(lv - 1)
        switch h {
        case .otto: return (46 + 7 * (lv - 1), 9 + 2 * (lv - 1), 4 + (lv - 1), 4 + 0.5 * l)
        case .moss: return (36 + 5 * (lv - 1), 8 + 2 * (lv - 1), 3 + (lv - 1), 7 + l)
        case .mosto: return (40, 9, 3, 6)
        }
    }
    static func of(_ m: Member) -> PartyStats {
        var b = base(m.hero, m.level)
        if let e = m.equip, let it = RPGContent.shared.items[e] {
            b.hp += it.hp ?? 0; b.atk += it.atk ?? 0; b.def += it.df ?? 0; b.spd += Double(it.spd ?? 0)
        }
        return PartyStats(hero: m.hero, level: m.level, maxHP: b.hp, hp: min(m.hp, b.hp), atk: b.atk, def: b.def, spd: b.spd)
    }
    static func name(_ h: Hero) -> String { h == .otto ? "奥托" : h == .moss ? "莫斯" : "莫斯托" }
}

struct Line: Equatable { var who: String; var text: String }

struct Reward: Equatable {
    var xp: Int
    var motes: Int
    var ups: [String]
}

@MainActor
final class World: ObservableObject {
    @Published var s: SaveData
    @Published var pos: CGPoint                        // drawn position (cells), eased between steps
    @Published var face: Int = 1                       // -1 left, 1 right
    @Published var dir = "S"
    @Published var trail: [Pt] = []                    // where Moss walks: one step behind
    @Published var foePos: [String: Pt] = [:]
    @Published var lines: [Line] = []
    @Published var battle: BattleState?
    @Published var battleFoeID: String?
    @Published var reward: Reward?
    @Published var walking = false
    @Published var toast: String?
    @Published var menu = false
    @Published var shop: [String]?
    @Published var mapCard: String?
    @Published var ended = false
    var onLinesDone: (() -> Void)?
    private var lineCont: CheckedContinuation<Void, Never>?
    private var walkTask: Task<Void, Never>?

    var c: RPGContent { RPGContent.shared }
    var map: RPGMap { c.maps[s.map]! }
    var me: Pt { Pt(s.x, s.y) }
    var hasMoss: Bool { s.members.contains { $0.hero == .moss } }
    var busy: Bool { !lines.isEmpty || battle != nil || reward != nil || shop != nil || mapCard != nil }

    static let saveKey = "rpg.save.v1"
    static var hasSave: Bool { UserDefaults.standard.data(forKey: saveKey) != nil }

    init(fresh: Bool) {
        var start = SaveData()
        if !fresh, let d = UserDefaults.standard.data(forKey: World.saveKey), let sv = try? JSONDecoder().decode(SaveData.self, from: d) { start = sv }
        s = start
        pos = CGPoint(x: start.x, y: start.y)
        trail = [Pt(start.x, start.y)]
        placeFoes()
        reveal()
    }

    static func peek() -> SaveData? {
        guard let d = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(SaveData.self, from: d)
    }

    /// For the screenshots in CI: a world set up at a given moment, not saved.
    static func probe(_ what: String) -> World {
        let w = World(fresh: true)
        w.probing = true
        w.s.flags.insert("intro")
        switch what {
        case "town":
            break
        case "talk":
            w.s.x = 7; w.s.y = 5; w.pos = CGPoint(x: 7, y: 5)
            w.lines = (RPGContent.shared.lines["mossMeet"] ?? []).map { Line(who: $0[0], text: $0[1]) }
        case "battle":
            w.s.members.append(Member(hero: .moss, hp: 36)); w.s.flags.insert("moss")
            if let f = w.map.foes.first(where: { $0.id == "f_t1" }) { w.startBattle(f) }
        case "wilds":
            w.s.members.append(Member(hero: .moss, hp: 36)); w.s.flags.insert("moss")
            w.s.map = "wilds"; w.s.x = 7; w.s.y = 21; w.pos = CGPoint(x: 7, y: 21); w.trail = [w.me]; w.s.quests["main"] = 3; w.placeFoes()
        case "cellar":
            w.s.members.append(Member(hero: .moss, level: 3, hp: 46)); w.s.flags.insert("moss")
            w.s.map = "cellar1"; w.s.x = 5; w.s.y = 16; w.pos = CGPoint(x: 5, y: 16); w.trail = [w.me]; w.s.quests["main"] = 4; w.placeFoes(); w.reveal()
        case "boss":
            w.s.members = [Member(hero: .otto, level: 5, hp: 74), Member(hero: .moss, level: 5, hp: 56)]
            w.s.flags.insert("moss"); w.s.map = "cellar2"; w.s.x = 5; w.s.y = 8; w.pos = CGPoint(x: 5, y: 8); w.placeFoes()
            if let f = w.map.foes.first { w.startBattle(f) }
        case "menu":
            w.s.members.append(Member(hero: .moss, hp: 36)); w.s.flags.insert("moss"); w.s.bag["shadeOld"] = 1; w.s.quests["dora"] = 0
            w.menu = true
        default: break
        }
        return w
    }
    var probing = false

    func save() {
        guard !probing else { return }
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: World.saveKey) }
    }

    /// The opening, the first time.
    func begin() {
        Sound.shared.music(map.music)
        if probing { return }
        if !s.flags.contains("intro") {
            s.flags.insert("intro")
            Task { await say("intro"); save() }
        } else {
            mapCard = map.name
            Task { try? await Task.sleep(for: .milliseconds(1600)); mapCard = nil }
        }
    }

    // MARK: lines

    func say(_ key: String) async {
        guard let raw = c.lines[key] else { return }
        await say(raw.map { Line(who: $0.first ?? "", text: $0.count > 1 ? $0[1] : "") })
    }
    func say(_ ls: [Line]) async {
        lines = ls
        await withCheckedContinuation { cont in lineCont = cont }
    }
    func nextLine() {
        guard !lines.isEmpty else { return }
        lines.removeFirst()
        if lines.isEmpty, let k = lineCont { lineCont = nil; k.resume() }
    }

    // MARK: the map

    func placeFoes() {
        foePos = [:]
        for f in map.foes where !s.beaten.contains(f.id) { foePos[f.id] = Pt(f.at) }
    }

    func solid(_ p: Pt) -> Bool {
        let m = map
        if !m.terrainOpen(p) && !m.exits.contains(where: { Pt($0.at) == p }) { return true }
        if m.lamps.contains(where: { Pt($0.at) == p }) { return true }
        if m.chests.contains(where: { Pt($0.at) == p }) { return true }
        if m.tablets.contains(where: { Pt($0.at) == p }) { return true }
        if m.npcs.contains(where: { Pt($0.at) == p && visible($0) }) { return true }
        return false
    }
    func visible(_ n: RPGNPC) -> Bool { n.until.map { !s.flags.contains($0) } ?? true }

    func reveal() {
        guard map.fog == true else { return }
        var seen = Set(s.seen[s.map] ?? [])
        let r = 3
        for y in (s.y - r)...(s.y + r) { for x in (s.x - r)...(s.x + r) where abs(x - s.x) + abs(y - s.y) <= r + 1 {
            if x >= 0, y >= 0, x < map.w, y < map.h { seen.insert(y * map.w + x) }
        } }
        for l in map.lamps where s.lit.contains(l.id) {
            let p = Pt(l.at)
            for y in (p.y - 3)...(p.y + 3) { for x in (p.x - 3)...(p.x + 3) where abs(x - p.x) + abs(y - p.y) <= 4 {
                if x >= 0, y >= 0, x < map.w, y < map.h { seen.insert(y * map.w + x) }
            } }
        }
        s.seen[s.map] = Array(seen)
    }

    func path(to target: Pt, adjacentOK: Bool) -> [Pt]? {
        if me == target { return [] }
        var prev: [Pt: Pt] = [:]
        var q = [me]; var head = 0
        var seen: Set<Pt> = [me]
        while head < q.count {
            let p = q[head]; head += 1
            for d in [Pt(0, -1), Pt(1, 0), Pt(0, 1), Pt(-1, 0)] {
                let n = p + d
                if seen.contains(n) { continue }
                seen.insert(n)
                let goal = n == target
                if goal && adjacentOK && solid(n) {
                    var out: [Pt] = []; var c = p
                    while c != me { out.insert(c, at: 0); c = prev[c]! }
                    return out
                }
                if solid(n) { continue }
                prev[n] = p
                if goal {
                    var out: [Pt] = [n]; var c = p
                    while c != me { out.insert(c, at: 0); c = prev[c]! }
                    return out
                }
                q.append(n)
            }
        }
        return nil
    }

    /// A tap on the map: walk there, or next to the thing tapped and use it.
    func tap(_ p: Pt) {
        guard !busy else { return }
        walkTask?.cancel()
        if me.dist(p) == 1, solid(p) { use(p); return }
        let thing = solid(p)
        guard let route = path(to: p, adjacentOK: thing) else { Sound.shared.no(); return }
        walkTask = Task { await walk(route, then: thing ? p : nil) }
    }

    private func walk(_ route: [Pt], then target: Pt?) async {
        walking = true
        defer { walking = false }
        for n in route {
            if Task.isCancelled || busy { return }
            await step(to: n)
            if busy || ended { return }
        }
        if let t = target, me.dist(t) == 1 { use(t) }
    }

    private func step(to n: Pt) async {
        let from = me
        if n.x < from.x { face = -1; dir = "W" } else if n.x > from.x { face = 1; dir = "E" } else if n.y < from.y { dir = "N" } else { dir = "S" }
        s.x = n.x; s.y = n.y
        trail.insert(n, at: 0); if trail.count > 3 { trail.removeLast() }
        Sound.shared.step()
        let frames = 8
        for k in 1...frames {
            let t = CGFloat(k) / CGFloat(frames)
            pos = CGPoint(x: CGFloat(from.x) + CGFloat(n.x - from.x) * t, y: CGFloat(from.y) + CGFloat(n.y - from.y) * t)
            try? await Task.sleep(for: .milliseconds(18))
        }
        reveal()
        arrived()
        if battle == nil { moveFoes() }
    }

    /// After every step: exits, fireflies, the square, the boss rooms.
    private func arrived() {
        if let ex = map.exits.first(where: { Pt($0.at) == me }) { travel(ex); return }
        if let m = map.motes.first(where: { Pt($0.at) == me && !s.opened.contains($0.id) }) {
            s.opened.insert(m.id); Sound.shared.touch(); Haptic.light()
            Task { await say("fly"); checkQuests() }
        }
        if s.map == "town", quest("main") == "leave", me.dist(Pt(7, 7)) <= 2 { advance("main") }
        checkQuests()
        touchFoes()
    }

    private func travel(_ ex: RPGExit) {
        if let need = ex.need, !s.flags.contains(need) {
            // step back where we came from
            if let back = trail.dropFirst().first { s.x = back.x; s.y = back.y; pos = CGPoint(x: back.x, y: back.y) }
            Sound.shared.no()
            Task { await say(need == "moss" ? "gateLocked" : "miniBefore") }
            return
        }
        s.map = ex.to
        s.x = ex.arrive[0]; s.y = ex.arrive[1]
        pos = CGPoint(x: s.x, y: s.y)
        trail = [me]
        placeFoes(); reveal()
        Sound.shared.music(map.music)
        mapCard = map.name
        save()
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            mapCard = nil
            if s.map == "wilds", quest("main") == "gate" { advance("main") }
            if s.map == "cellar1", !s.flags.contains("cellarSeen") {
                s.flags.insert("cellarSeen"); if quest("main") == "cellar" { advance("main") }
                await say("miniBefore")
            }
            if s.map == "cellar2", !s.flags.contains("bossSeen") { s.flags.insert("bossSeen"); await say("bossBefore") }
        }
    }

    // MARK: foes on the map

    func moveFoes() {
        var rng = Rng(UInt64(s.x * 31 + s.y * 17 + s.battles * 7 + trail.count))
        for f in map.foes {
            guard let p = foePos[f.id], f.roam > 0 else { continue }
            let home = Pt(f.at)
            var options: [Pt] = []
            if p.dist(me) <= 4 {
                // chase: the step that closes in
                options = [Pt(0, -1), Pt(1, 0), Pt(0, 1), Pt(-1, 0)].map { p + $0 }.filter { $0.dist(me) < p.dist(me) }
            } else if rng.unit() < 0.5 {
                options = [Pt(0, -1), Pt(1, 0), Pt(0, 1), Pt(-1, 0)].map { p + $0 }.filter { $0.dist(home) <= f.roam }
            }
            let exits = Set(map.exits.map { Pt($0.at) })
            options = options.filter { !solid($0) && !foePos.values.contains($0) && !exits.contains($0) }
            if options.contains(me) { foePos[f.id] = me }
            else if !options.isEmpty { foePos[f.id] = options[Int(rng.next() % UInt64(options.count))] }
        }
        touchFoes()
    }

    private func touchFoes() {
        guard battle == nil, lines.isEmpty else { return }
        if let hit = foePos.first(where: { $0.value.dist(me) <= 1 }), let f = map.foes.first(where: { $0.id == hit.key }) {
            startBattle(f)
        }
    }
    func isBoss(_ id: String) -> Bool { map.foes.first { $0.id == id }?.boss == true }

    // MARK: using things

    func use(_ p: Pt) {
        let m = map
        if let n = m.npcs.first(where: { Pt($0.at) == p && visible($0) }) { talk(n); return }
        if let ch = m.chests.first(where: { Pt($0.at) == p }) { open(ch); return }
        if let l = m.lamps.first(where: { Pt($0.at) == p }) { rest(at: l); return }
        if let t = m.tablets.first(where: { Pt($0.at) == p }) { read(t); return }
        Sound.shared.no()
    }

    func open(_ ch: RPGChest) {
        guard !s.opened.contains(ch.id) else { note("空的"); return }
        s.opened.insert(ch.id)
        let n = ch.n ?? 1
        if ch.item == "motes" { s.motes += n } else { s.bag[ch.item, default: 0] += n }
        let name = c.items[ch.item]?.name ?? ch.item
        Sound.shared.light(); Haptic.success()
        note("得到 \(name)\(n > 1 ? " ×\(n)" : "")")
        save()
    }

    func rest(at l: RPGThing) {
        let first = !s.lit.contains(l.id)
        s.lit.insert(l.id)
        s.lampMap = s.map; s.lampX = s.x; s.lampY = s.y
        for i in s.members.indices { s.members[i].hp = Stats.of(s.members[i]).maxHP }
        // the shadows creep back while you rest (not the bosses, not the ones a quest asked you to clear)
        let keep = Set(c.maps.values.flatMap { $0.foes }.filter { $0.boss == true || $0.quest != nil }.map { $0.id })
        s.beaten = s.beaten.intersection(keep)
        placeFoes(); reveal()
        Sound.shared.light(); Sound.shared.motif(.otto); Haptic.success()
        note("灯亮了 · 全员恢复 · 已存档")
        save()
        if first && !s.flags.contains("lampFirst") { s.flags.insert("lampFirst"); Task { await say("lampFirst") } }
    }

    func read(_ t: RPGTablet) {
        guard hasMoss else { Task { await say([Line(who: "o", text: "……看不懂。")]) }; return }
        Sound.shared.touch(); Sound.shared.motif(.moss)
        let first = !s.opened.contains(t.id)
        s.opened.insert(t.id)
        Task {
            await say(t.lore)
            if first {
                let n = ["stone1", "stone2", "stone3"].filter { s.opened.contains($0) }.count
                if quest("stones") == nil { s.quests["stones"] = 0 }
                if n >= 3 { s.flags.insert("mineEarly"); s.quests["stones"] = 1; gainXP(30, announce: true) }
                note("石碑 \(n)/3")
                save()
            }
        }
    }

    func talk(_ n: RPGNPC) {
        Task {
            switch n.id {
            case "moss":
                await say("mossMeet")
                s.flags.insert("moss")
                let lv = max(1, (s.members.first?.level ?? 1))
                s.members.append(Member(hero: .moss, level: lv, xp: s.members.first?.xp ?? 0, hp: Stats.base(.moss, lv).hp))
                trail = [me, me]
                Sound.shared.motif(.moss); Haptic.success()
                note("莫斯加入了队伍")
                if quest("main") == "leave" { advance("main") }
                if quest("main") == "moss" { advance("main") }
            case "hank":
                if quest("main") == "home" { await say("hankHome"); advance("main"); ended = true }
                else { await say("hank") }
            case "dora":
                switch quest("dora") {
                case nil: await say("dora"); s.quests["dora"] = 0
                case "find": await say("doraWait")
                case "back":
                    await say("doraDone"); s.bag["jar", default: 0] += 2; advance("dora"); s.flags.insert("doraLit"); note("得到 萤火罐 ×2")
                default: await say("doraAfter")
                }
            case "lynn":
                switch quest("net") {
                case nil: await say("lynn"); s.quests["net"] = 0
                case "clear": await say("lynnWait")
                case "back":
                    await say("lynnDone"); s.bag["tea", default: 0] += 3; s.bag["shadeCopper", default: 0] += 1; advance("net")
                    note("得到 暖茶 ×3、铜灯罩")
                default: await say("lynnShop")
                }
                shop = n.shop
            default: break
            }
            checkQuests()
            save()
        }
    }

    // MARK: quests

    func quest(_ q: String) -> String? {
        guard let i = s.quests[q], let steps = c.quests[q]?.steps, i < steps.count else { return nil }
        return steps[i].id
    }
    func advance(_ q: String) {
        guard let i = s.quests[q], let steps = c.quests[q]?.steps, i + 1 < steps.count else { return }
        s.quests[q] = i + 1
        Haptic.light()
        if q != "main" || steps[i + 1].map != nil { note("任务 · \(steps[i + 1].text)") }
    }
    func checkQuests() {
        if quest("dora") == "find", ["fly1", "fly2", "fly3"].allSatisfy({ s.opened.contains($0) }) { advance("dora") }
        if quest("net") == "clear", ["f_dock1", "f_dock2", "f_dock3"].allSatisfy({ s.beaten.contains($0) }) {
            advance("net"); Task { await say("netCleared") }
        }
    }
    /// The current main step with somewhere to go.
    var goal: (text: String, map: String?, at: Pt?) {
        guard let i = s.quests["main"], let st = c.quests["main"]?.steps[safe: i] else { return ("", nil, nil) }
        return (st.text, st.map, st.map != nil ? Pt(st.x ?? 0, st.y ?? 0) : nil)
    }
    /// Where on this map to head for the goal: the goal itself, or the exit toward its map.
    var goalHere: Pt? {
        let g = goal
        guard let gm = g.map else { return nil }
        if gm == s.map { return g.at }
        // breadth-first over the maps by their exits
        var prev: [String: (String, RPGExit)] = [:]
        var q = [s.map]; var seen: Set<String> = [s.map]
        while !q.isEmpty {
            let m = q.removeFirst()
            for ex in c.maps[m]?.exits ?? [] where !seen.contains(ex.to) {
                seen.insert(ex.to); prev[ex.to] = (m, ex); q.append(ex.to)
            }
        }
        var cur = gm
        while let step = prev[cur] {
            if step.0 == s.map { return Pt(step.1.at) }
            cur = step.0
        }
        return nil
    }

    // MARK: growth

    func gainXP(_ n: Int, announce: Bool) {
        for i in s.members.indices {
            s.members[i].xp += n
            while s.members[i].level < Stats.maxLevel && s.members[i].xp >= Stats.levels[s.members[i].level] {
                s.members[i].level += 1
                s.members[i].hp = Stats.of(s.members[i]).maxHP
                if announce { note("\(Stats.name(s.members[i].hero)) 升到 Lv\(s.members[i].level)") }
            }
        }
    }

    func learned(_ h: Hero, _ lv: Int, _ sk: SkillID) -> Bool {
        if sk == .mine && s.flags.contains("mineEarly") { return true }
        return (Skill.all[sk]?.level ?? 1) <= lv
    }

    func equip(_ item: String, on h: Hero) {
        guard let i = s.members.firstIndex(where: { $0.hero == h }), (s.bag[item] ?? 0) > 0 else { return }
        if let old = s.members[i].equip { s.bag[old, default: 0] += 1 }
        s.bag[item]! -= 1; if s.bag[item] == 0 { s.bag[item] = nil }
        s.members[i].equip = item
        s.members[i].hp = min(s.members[i].hp, Stats.of(s.members[i]).maxHP)
        Haptic.light(); save()
    }
    func useOutside(_ item: String, on h: Hero) {
        guard item == "tea", (s.bag[item] ?? 0) > 0, let i = s.members.firstIndex(where: { $0.hero == h }) else { return }
        let mx = Stats.of(s.members[i]).maxHP
        guard s.members[i].hp < mx else { return }
        s.members[i].hp = min(mx, s.members[i].hp + 40)
        s.bag[item]! -= 1; if s.bag[item] == 0 { s.bag[item] = nil }
        Sound.shared.light(); save()
    }
    func buy(_ item: String) {
        guard let it = c.items[item], s.motes >= it.price else { Sound.shared.no(); return }
        s.motes -= it.price; s.bag[item, default: 0] += 1
        Sound.shared.take(); Haptic.light(); save()
    }

    func note(_ t: String) {
        toast = t
        Task { try? await Task.sleep(for: .milliseconds(2200)); if toast == t { toast = nil } }
    }

    // MARK: battles

    func startBattle(_ f: RPGFoe) {
        walkTask?.cancel()
        let kinds = f.party.compactMap { FoeKind(rawValue: $0) }
        let party = s.members.map { Stats.of($0) }
        let bonus = s.members.compactMap { $0.equip }.compactMap { c.items[$0]?.light }.reduce(0, +)
        s.battles += 1
        battleFoeID = f.id
        Haptic.warn(); Sound.shared.dim()
        battle = Battle.start(party: party, foes: kinds, seed: UInt64(s.battles * 7919 + s.x * 13 + s.y), startLight: 3 + bonus)
        Sound.shared.music(f.boss == true ? 4 : 3)
    }

    /// The battle's over: write the party's HP back and hand out what was won.
    func endBattle() {
        guard let b = battle, let fid = battleFoeID else { return }
        let outcome = b.outcome
        battle = nil
        for p in b.party { if let i = s.members.firstIndex(where: { $0.hero == p.hero }) { s.members[i].hp = max(outcome == .won ? 1 : 0, p.hp) } }
        Sound.shared.music(map.music)
        switch outcome {
        case .won:
            s.beaten.insert(fid); foePos[fid] = nil
            let foes = b.foes.compactMap { $0.kind }
            let xp = foes.map { $0.base.xp }.reduce(0, +), motes = foes.map { $0.base.motes }.reduce(0, +)
            let before = s.members.map { $0.level }
            gainXP(xp, announce: false)
            s.motes += motes
            var ups: [String] = []
            for (i, m) in s.members.enumerated() where i < before.count && m.level > before[i] {
                let new = [SkillID.flare, .vigil, .shove, .mine].filter { Skill.all[$0]?.hero == m.hero && Skill.all[$0]?.level == m.level }
                ups.append("\(Stats.name(m.hero)) 升到 Lv\(m.level)" + (new.isEmpty ? "" : " · 学会「\(new.map { Skill.all[$0]!.name }.joined(separator: "」「"))」"))
            }
            reward = Reward(xp: xp, motes: motes, ups: ups)
            if fid == "f_mini" { s.flags.insert("bigshade"); advance("main") }
            if fid == "f_boss" {
                s.flags.insert("maw")
                Task { while reward != nil { try? await Task.sleep(for: .milliseconds(200)) }; await say("bossAfter"); advance("main"); save() }
            }
            checkQuests()
        case .fled:
            // step back a little so it doesn't start again at once
            if let back = trail.dropFirst().first { s.x = back.x; s.y = back.y; pos = CGPoint(x: back.x, y: back.y) }
            foePos[fid] = map.foes.first { $0.id == fid }.map { Pt($0.at) }
        case .lost:
            s.motes /= 2
            s.map = s.lampMap; s.x = s.lampX; s.y = s.lampY
            pos = CGPoint(x: s.x, y: s.y); trail = [me]
            for i in s.members.indices { s.members[i].hp = Stats.of(s.members[i]).maxHP }
            placeFoes(); reveal()
            Task { await say("defeat") }
        case .ongoing: break
        }
        battleFoeID = nil
        save()
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
