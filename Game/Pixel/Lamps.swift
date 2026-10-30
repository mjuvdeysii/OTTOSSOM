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

    static let key = "dig.save.v1"
    static func load() -> DigSave {
        guard let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(DigSave.self, from: d) else { return DigSave() }
        return s
    }
    func save() { if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: DigSave.key) } }

    /// Who comes in today. The first days are written; after that people come for colours the dig can reach.
    mutating func openShop() {
        func add(_ who: String, _ c: LampColor) { orders.append(Order(id: nextOrder, who: who, color: c)); nextOrder += 1 }
        let key = "day\(day)"
        guard !seen.contains(key) else { return }
        seen.insert(key)
        switch day {
        case 1: add("h", .amber); add("n", .amber); add("d", .blue)
        case 2: add("t1", .amber); add("n", .green)
        case 3: add("t2", .amber); add("h", .green); add("t3", .blue)
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

    /// The one thing to do next, shown at the top all the time.
    var goal: String {
        let unread = [1, 2, 3, 4].first { !memories.contains($0) }
        let depths = [1: 6, 2: 15, 3: 26, 4: 42]
        if let o = orders.first(where: { o in o.color.recipe.contains { g in (gems[g] ?? 0) < o.color.recipe.filter { $0 == g }.count } }) {
            let missing = o.color.recipe.first { g in (gems[g] ?? 0) < o.color.recipe.filter { $0 == g }.count }!
            let gname = missing == .amber ? "琥珀晶" : missing == .blue ? "蓝晶" : "红晶"
            if missing != .amber && (upgrades["claw"] ?? 0) < (missing == .blue ? 1 : 2) {
                return "\(DigStory.name(o.who))要\(o.color.name)：\(gname)在石头里，先升级爪子"
            }
            return "\(DigStory.name(o.who))要\(o.color.name)：去挖\(gname)"
        }
        if let n = unread { return "往下挖：第 \(n) 块记忆石在 \(depths[n]!) 米" }
        return "往更深的地方挖"
    }
}

enum DigStory {
    static func s(_ who: String, _ t: String) -> Say { Say(who: who, text: t) }
    static let intro: [Say] = [
        s("h", "主灯的光被一团黑东西偷走了。"), s("h", "灯塔底下的土里有光晶，能把灯重新点亮。"),
        s("m", "土里的东西……都是我的？"), s("o", "挖到的，拿回来。我在上面拉着线。"),
    ]
    static let afterNight: [Int: [Say]] = [
        1: [s("o", "……回来了。"), s("m", "看！好多亮亮的。"), s("h", "天亮了，有人拿着灭掉的灯来找你们。")],
        2: [s("n", "听说灯塔开了灯铺？"), s("m", "我的灯铺。"), s("o", "……我们的。")],
        3: [s("d", "地底下有一块会发光的石头吗？"), s("m", "有！上面刻着一个小石头。"), s("o", "像你。")],
    ]
    static func memoryLine(_ n: Int) -> String {
        switch n {
        case 1: return "台灯底下，一颗小石头站了起来。"
        case 2: return "它朝墙挥了挥手，墙上的影子也挥了挥手。它第一次有了伴。"
        case 3: return "它开始把东西一样一样搬回身边。墙上的影子还举着手，等它回头。"
        case 4: return "它抱紧一颗珠子，背过身去。墙上的影子也背过身去，头顶多了一顶歪王冠。"
        default: return ""
        }
    }
    static let customerName: [String: String] = ["t1": "邮差", "t2": "面包师", "t3": "老船长"]
    static func name(_ who: String) -> String { GameModel.names[who] ?? customerName[who] ?? "客人" }
}
