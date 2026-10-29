import Foundation

struct ChapterStep: Codable {
    var room: String?
    var cut: String?
    var intro: String?
    var outro: String?
}

struct Chapter: Codable, Identifiable {
    var id: Int
    var title: String
    var hero: String
    var steps: [ChapterStep]
}

private struct RoomFile: Codable {
    var chapters: [Chapter]
    var rooms: [String: RoomSpec]
}

/// Chapters, rooms and story scripts, read once from the app bundle.
enum Content {
    static let shared: (chapters: [Chapter], rooms: [String: RoomSpec]) = {
        guard let url = Bundle.main.url(forResource: "rooms", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let f = try? JSONDecoder().decode(RoomFile.self, from: data) else { return ([], [:]) }
        return (f.chapters, f.rooms)
    }()
    static var chapters: [Chapter] { shared.chapters }
    static var rooms: [String: RoomSpec] { shared.rooms }

    /// story.json: script name → list of commands (dictionaries)
    static let story: [String: [[String: Any]]] = {
        guard let url = Bundle.main.url(forResource: "story", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var out: [String: [[String: Any]]] = [:]
        for (k, v) in obj { out[k] = v as? [[String: Any]] ?? [] }
        return out
    }()
}

/// What the player has done, kept between launches.
final class Progress {
    static let shared = Progress()
    private let d = UserDefaults.standard
    private let doneKey = "changye.done", stepKey = "changye.step", flagKey = "changye.flags"

    var done: Set<Int> {
        get { Set(d.array(forKey: doneKey) as? [Int] ?? []) }
        set { d.set(Array(newValue), forKey: doneKey) }
    }
    func step(_ chapter: Int) -> Int { (d.dictionary(forKey: stepKey) as? [String: Int])?["\(chapter)"] ?? 0 }
    func setStep(_ chapter: Int, _ i: Int) {
        var m = d.dictionary(forKey: stepKey) as? [String: Int] ?? [:]
        m["\(chapter)"] = i; d.set(m, forKey: stepKey)
    }
    var flags: Set<String> {
        get {
            // "doudou" was Dora's lantern before the cast took their English names
            var f = Set(d.stringArray(forKey: flagKey) ?? [])
            if f.remove("doudou") != nil { f.insert("dora") }
            return f
        }
        set { d.set(Array(newValue), forKey: flagKey) }
    }
    func unlocked(_ chapter: Int) -> Bool { chapter == 1 || done.contains(chapter - 1) }
    func resetAll() { [doneKey, stepKey, flagKey].forEach { d.removeObject(forKey: $0) } }
}
