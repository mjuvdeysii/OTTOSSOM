import Foundation

/// One of the 37 beads: a level on the bead path (Resources/levels.json, written by Tools/build_levels.py).
struct LevelInfo: Codable, Identifiable, Sendable {
    let id: Int              // 0…36, the month the bead stands for
    let chapter: Int         // 0 序, 1 矮桌, 2 木架, 3 靠垫山, 4 键盘
    let rows: [String]
    let facing: String
    let mode: MostoMode
    let par: Int             // shortest solution, proved by both solvers
    let solution: [String]

    func board() -> Board {
        // levels.json is checked by the test target, so a failure here is a build problem, not a player's
        try! Board(name: "\(id)", rows: rows, facing: Dir(letter: facing.first ?? "N") ?? .n, mode: mode)
    }
}

struct Chapter: Sendable {
    let index: Int
    let title: String
    let place: String
    let beads: ClosedRange<Int>
    /// The surface the chapter is played on (Resources/Art/surface_<name>.png) and its tall things.
    let surface: String
    let talls: [String]
}

enum Levels {
    static let all: [LevelInfo] = {
        guard let url = Bundle.main.url(forResource: "levels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([LevelInfo].self, from: data) else { return [] }
        return list.sorted { $0.id < $1.id }
    }()

    static let chapters: [Chapter] = [
        Chapter(index: 0, title: "序", place: "灯灭了", beads: 0...0, surface: "table", talls: ["cup", "book", "rings"]),
        Chapter(index: 1, title: "第一章", place: "矮桌", beads: 1...9, surface: "table", talls: ["cup", "book", "rings"]),
        Chapter(index: 2, title: "第二章", place: "木架", beads: 10...18, surface: "shelf", talls: ["tower", "jar", "rings"]),
        Chapter(index: 3, title: "第三章", place: "靠垫山", beads: 19...27, surface: "cushion", talls: ["knob", "roll", "jar"]),
        Chapter(index: 4, title: "第四章", place: "键盘", beads: 28...36, surface: "desk", talls: ["key", "key2", "mug"]),
    ]

    static func chapter(of id: Int) -> Chapter {
        if id >= 1000 { return chapters[1 + id % 4] }      // 每夜躲猫猫 moves from table to table
        return chapters.first { $0.beads.contains(id) } ?? chapters[0]
    }
}

/// What the player has done. Saved after every move; there is nothing to lose and no streak to keep.
final class Progress: ObservableObject {
    static let shared = Progress()
    private let d = UserDefaults.standard

    @Published private(set) var solved: [Int: Int]      // level → fewest moves
    @Published var seenScenes: Set<String>

    private init() {
        let raw = d.dictionary(forKey: "solved") as? [String: Int] ?? [:]
        solved = Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in Int(k).map { ($0, v) } })
        seenScenes = Set(d.stringArray(forKey: "scenes") ?? [])
    }

    func finish(_ level: Int, moves: Int) {
        let best = min(moves, solved[level] ?? .max)
        solved[level] = best
        d.set(Dictionary(uniqueKeysWithValues: solved.map { (String($0.key), $0.value) }), forKey: "solved")
    }

    func saw(_ scene: String) { seenScenes.insert(scene); d.set(Array(seenScenes), forKey: "scenes") }

    /// The next bead to find: the first not yet strung.
    var next: Int { (0..<max(1, Levels.all.count)).first { solved[$0] == nil } ?? Levels.all.count }
    var finishedStory: Bool { next >= Levels.all.count && !Levels.all.isEmpty }
    func isOpen(_ level: Int) -> Bool { level <= next }
    func perfect(_ level: Int) -> Bool {
        guard let m = solved[level], level < Levels.all.count else { return false }
        return m <= Levels.all[level].par
    }

    /// The moves made so far in an unfinished level, so leaving never loses anything.
    func savedMoves(_ level: Int) -> [String] { d.stringArray(forKey: "moves.\(level)") ?? [] }
    func saveMoves(_ level: Int, _ moves: [String]) { d.set(moves, forKey: "moves.\(level)") }

    func resetAll() {
        for k in d.dictionaryRepresentation().keys where k.hasPrefix("moves.") { d.removeObject(forKey: k) }
        solved = [:]; seenScenes = []
        d.removeObject(forKey: "solved"); d.removeObject(forKey: "scenes")
    }
}
