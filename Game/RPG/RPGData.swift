import Foundation

// The first region's content, read from rpg.json (built and checked by Tools/rpg/build.py).

struct RPGExit: Codable { var at: [Int]; var to: String; var arrive: [Int]; var need: String? }
struct RPGThing: Codable { var id: String; var at: [Int] }
struct RPGNPC: Codable { var id: String; var sprite: String; var at: [Int]; var talk: String; var until: String?; var shop: [String]? }
struct RPGChest: Codable { var id: String; var at: [Int]; var item: String; var n: Int? }
struct RPGFoe: Codable { var id: String; var at: [Int]; var party: [String]; var roam: Int; var boss: Bool?; var quest: String? }
struct RPGTablet: Codable { var id: String; var at: [Int]; var lore: String }

struct RPGMap: Codable {
    var name: String
    var theme: String
    var music: Int
    var dark: Double
    var fog: Bool?
    var map: [String]
    var start: [Int]?
    var exits: [RPGExit]
    var lamps: [RPGThing]
    var npcs: [RPGNPC]
    var chests: [RPGChest]
    var foes: [RPGFoe]
    var tablets: [RPGTablet]
    var motes: [RPGThing]

    var w: Int { map.first?.count ?? 0 }
    var h: Int { map.count }
    func ch(_ p: Pt) -> Character {
        guard p.y >= 0, p.y < h, p.x >= 0, p.x < w else { return "#" }
        return Array(map[p.y])[p.x]
    }
    static let blocking: Set<Character> = ["#", "T", "R", "H", "~", "F", "i", "^", "B", "t", "x"]
    func terrainOpen(_ p: Pt) -> Bool { !RPGMap.blocking.contains(ch(p)) }
}

struct RPGItem: Codable {
    var name: String
    var kind: String          // use, equip, money
    var hero: String?
    var icon: String
    var price: Int
    var text: String
    var atk: Int?
    var df: Int?
    var hp: Int?
    var spd: Int?
    var light: Int?
}

struct RPGQuestStep: Codable { var id: String; var text: String; var map: String?; var x: Int?; var y: Int? }
struct RPGQuest: Codable { var name: String; var steps: [RPGQuestStep] }

struct RPGContent: Codable {
    var maps: [String: RPGMap]
    var items: [String: RPGItem]
    var quests: [String: RPGQuest]
    var lines: [String: [[String]]]

    static let shared: RPGContent = {
        guard let url = Bundle.main.url(forResource: "rpg", withExtension: "json"), let d = try? Data(contentsOf: url),
              let c = try? JSONDecoder().decode(RPGContent.self, from: d) else {
            return RPGContent(maps: [:], items: [:], quests: [:], lines: [:])
        }
        return c
    }()
}

extension Pt {
    init(_ a: [Int]) { self.init(a.count > 0 ? a[0] : 0, a.count > 1 ? a[1] : 0) }
}
