import Foundation

// The day: the lamp shop in the lighthouse's base. People bring lamps that have gone out; each wants a colour of
// light, made from the crystals Moss dug up — one crystal for a plain colour, two or three mixed for the others.

enum LampColor: String, Codable, CaseIterable {
    case amber, blue, red, green, purple, orange, white

    var recipe: [Gem] {
        switch self {
        case .amber: return [.amber]
        case .blue: return [.blue]
        case .red: return [.red]
        case .green: return [.amber, .blue]
        case .purple: return [.blue, .red]
        case .orange: return [.amber, .red]
        case .white: return [.amber, .blue, .red]
        }
    }
    var name: String {
        switch self {
        case .amber: return "琥珀光"
        case .blue: return "蓝光"
        case .red: return "红光"
        case .green: return "绿光"
        case .purple: return "紫光"
        case .orange: return "橙光"
        case .white: return "白光"
        }
    }
    var rgb: UInt32 {
        switch self {
        case .amber: return 0xFFD36B
        case .blue: return 0x8AC4FF
        case .red: return 0xFF8A8A
        case .green: return 0x9AF0A0
        case .purple: return 0xC8A0FF
        case .orange: return 0xFFA860
        case .white: return 0xFFF8EC
        }
    }
    /// The colour a set of crystals makes, if it makes one.
    static func mix(_ gems: [Gem]) -> LampColor? {
        let s = gems.sorted { $0.rawValue < $1.rawValue }
        return allCases.first { $0.recipe.sorted { $0.rawValue < $1.rawValue } == s }
    }
}

struct Order: Codable, Equatable, Identifiable {
    var id: Int
    var who: String           // h d n (Hank, Dora, Lynn) or t1… townsfolk
    var color: LampColor
    var since: Int?           // the day they first came; after three days without a light they stop coming
    var pay: Int { 6 * color.recipe.count + (color.recipe.count > 1 ? 4 : 0) + (who == "h" ? 0 : 2) }
}

struct DigSave: Codable {
    var day = 1
    var coins = 0
    var gems: [Gem: Int] = [:]
    var trinkets: [Trinket: Int] = [:]
    var upgrades: [String: Int] = [:]
    var memories: [Int] = []
    var world = DigWorld(seed: 20261030)
    var orders: [Order] = []
    var nextOrder = 0
    var seen: Set<String> = []
    var nightDone = false          // tonight's dig is over: next is the shop
    var deepest = 0
    var progress: DigProgress?     // a night that was interrupted: picked up again where it stopped
    var lit: [String]?             // colours lit in the shop so far: they glow on the shelf

    static let key = "dig.save.v1"
    static func load() -> DigSave {
        guard let d = UserDefaults.standard.data(forKey: key), var s = try? JSONDecoder().decode(DigSave.self, from: d) else { return DigSave() }
        s.world.ensureMemories()
        return s
    }
    func save() { if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: DigSave.key) } }

    /// Who comes in today. The first days are written; after that people come for colours the dig can reach.
    mutating func openShop() {
        func add(_ who: String, _ c: LampColor) { orders.append(Order(id: nextOrder, who: who, color: c, since: day)); nextOrder += 1 }
        // whoever has waited three days without a light has stopped coming
        orders.removeAll { day - ($0.since ?? day) >= 3 }
        let key = "day\(day)"
        guard !seen.contains(key) else { return }
        seen.insert(key)
        switch day {
        case 1: add("h", .amber); add("n", .amber); add("d", .amber)
        case 2: add("t1", .amber); add("n", (upgrades["claw"] ?? 0) >= 1 ? .green : .amber)
        case 3:
            let blue = (upgrades["claw"] ?? 0) >= 1
            add("t2", .amber); add("h", blue ? .green : .amber); add("t3", blue ? .blue : .amber)
        default:
            var pool: [LampColor] = [.amber, .amber]
            if (upgrades["claw"] ?? 0) >= 1 { pool += [.blue, .green, .green] }
            if (upgrades["claw"] ?? 0) >= 2 { pool += [.red, .purple, .orange, .white] }
            let who = ["h", "d", "n", "t1", "t2", "t3"]
            var r = Rng(UInt64(day) * 7919)
            for i in 0..<min(3, 1 + day / 3) where orders.count < 4 {
                add(who[(day + i) % who.count], pool[Int(r.next() % UInt64(pool.count))])
            }
        }
    }

    /// Light a lamp with the chosen crystals: right colour → paid; wrong → the crystals come back.
    mutating func light(_ order: Order, with picked: [Gem]) -> Bool {
        guard LampColor.mix(picked) == order.color else { return false }
        for g in picked { gems[g, default: 0] -= 1 }
        var l = lit ?? []
        if !l.contains(order.color.rawValue) { l.append(order.color.rawValue) }
        lit = l
        coins += order.pay
        orders.removeAll { $0.id == order.id }
        return true
    }

    /// What she brought up goes on the shelf; the trinkets go to Hank for coins.
    mutating func bank(_ bag: Bag) -> Int {
        for (g, n) in bag.gems { gems[g, default: 0] += n }
        var c = 0
        for (t, n) in bag.trinkets {
            trinkets[t, default: 0] += n
            c += n * (t == .coin ? 5 : t == .button ? 3 : 2)
        }
        coins += c
        return c
    }

    static let upgradeCosts: [String: [Int]] = ["claw": [30, 90], "bag": [20, 60], "wick": [20, 60]]

    var goal: String { goal(depth: nil) }

    /// The one thing to do next, shown at the top all the time. With the depth she's at, a stone she has
    /// already gone past is pointed back up to.
    func goal(depth: Int?) -> String {
        let unread = (1...8).first { !memories.contains($0) }
        let depths = DigWorld.depths
        if let o = orders.first(where: { o in o.color.recipe.contains { g in (gems[g] ?? 0) < o.color.recipe.filter { $0 == g }.count } }) {
            let missing = o.color.recipe.first { g in (gems[g] ?? 0) < o.color.recipe.filter { $0 == g }.count }!
            let gname = missing == .amber ? "琥珀晶" : missing == .blue ? "蓝晶" : "红晶"
            if missing != .amber && (upgrades["claw"] ?? 0) < (missing == .blue ? 1 : 2) {
                return "\(gname)在石头里：先在琳恩那里升级爪子"
            }
            return "\(DigStory.name(o.who))要\(o.color.name)：去挖\(gname)"
        }
        if let n = unread {
            let need = depths[n]! >= 38 && (upgrades["claw"] ?? 0) < 2 ? "，要二级爪子" : depths[n]! >= 18 && (upgrades["claw"] ?? 0) < 1 ? "，要一级爪子" : ""
            if let d = depth, d > depths[n]! + 1 { return "往上：记忆石 \(n) 在 \(depths[n]!) 米，跟着金箭头" }
            return "往下挖：记忆石 \(n) 在 \(depths[n]!) 米深\(need)"
        }
        if !seen.contains("ending") { return "去最深的地方：\(DigWorld.nestDepth) 米" }
        return "点亮镇上的灯，往深处找光晶"
    }
}

enum DigStory {
    static func s(_ who: String, _ t: String) -> Say { Say(who: who, text: t) }
    static let intro: [Say] = [
        s("h", "灯塔……又黑了。"), s("m", "底下有亮亮的！我的！"), s("o", "……嗯。线我拉着。"),
    ]
    /// After a night, keyed by how many memory stones have been read: the town answers what she has found.
    static let afterNight: [Int: [Say]] = [
        1: [s("o", "……回来了。"), s("m", "看！好多亮亮的。"), s("h", "天亮了，有人拿着灭掉的灯来找你们。")],
        2: [s("n", "听说灯塔开了灯铺？"), s("m", "我的灯铺。"), s("o", "……我们的。")],
        3: [s("d", "地底下有一块会发光的石头吗？"), s("m", "有！上面刻着一个小石头。"), s("o", "像你。")],
        4: [s("t3", "我年轻时下过那口井。越往下，越觉得有人在背后跟着。"), s("m", "是影子吧。"), s("t3", "影子会戴王冠吗？")],
        5: [s("h", "主灯还是暗的。光被偷到最深的地方去了。"), s("o", "……那就挖到最深。")],
        6: [s("m", "奥托，我的影子呢？"), s("o", "……在你脚下。"), s("m", "它刚才是不是没跟上？")],
        7: [s("n", "你背包里的东西越来越多了。"), s("m", "都是我的。"), s("n", "嗯。那你的手还空着吗？")],
    ]

    /// The bottom of the well: what's said when she gets there, and after she has put the bag down and waved.
    static let nestMeet: [Say] = [s("x", "别过来！都是我的！"), s("m", "……我以前也这么说。")]
    static let ending: [Say] = [s("x", "……借你一半。"), s("o", "……回来吧。两个都回来。")]
    static let endingCard = "第一章 · 完"
    static func memoryLine(_ n: Int) -> String {
        switch n {
        case 1: return "台灯底下，一颗小石头站了起来。"
        case 2: return "它朝墙挥了挥手，墙上的影子也挥了挥手。它第一次有了伴。"
        case 3: return "它开始把东西一样一样搬回身边。墙上的影子还举着手，等它回头。"
        case 4: return "它抱紧一颗珠子，背过身去。墙上的影子也背过身去，头顶多了一顶歪王冠。"
        case 5: return "它越搬越多，抱都抱不过来。影子越来越大，王冠越来越清楚。它一次也没回头。"
        case 6: return "它松开珠子去够一颗新纽扣。影子从墙上下来，抢过珠子，跑进了台灯背后的暗处。"
        case 7: return "它回过头，脚下没有影子了。它放下瓶盖，放下硬币，两手空空，往暗处摸过去。"
        case 8: return "暗处最里面，小魔王抱着珠子在发抖。它看着他，朝他挥了挥手。"
        default: return ""
        }
    }
    static let customerName: [String: String] = ["t1": "邮差", "t2": "面包师", "t3": "老船长"]
    static let castNames: [String: String] = ["h": "汉克", "d": "朵拉", "n": "琳恩", "o": "奥托", "m": "莫斯", "x": "莫斯托"]
    static func name(_ who: String) -> String { castNames[who] ?? customerName[who] ?? "客人" }
}


/// A night stopped part-way (a call, the app put away): enough to carry on from the same spot.
struct DigProgress: Codable {
    var world: DigWorld
    var x: Double, y: Double
    var bag: Bag
    var light: Double
    var deepest: Int
}

/// What happens, kept on the device only, so a TestFlight round can be judged on numbers: opens, nights, depths,
/// stones, the ending, orders, upgrades — one line each, newest last.
enum Telemetry {
    static let key = "dig.log.v1"
    static func log(_ what: String) {
        var lines = UserDefaults.standard.stringArray(forKey: key) ?? []
        lines.append("\(Int(Date().timeIntervalSince1970)) \(what)")
        if lines.count > 800 { lines.removeFirst(lines.count - 800) }
        UserDefaults.standard.set(lines, forKey: key)
    }
    static var lines: [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }
}
