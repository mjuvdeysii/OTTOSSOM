import SwiftUI

/// CI only (launched with -snapshots): shows the title and every room one by one and says which is showing in
/// Documents/snap/now.txt, so the workflow can take a simulator screenshot of each. Nothing here runs for players.
@MainActor
enum Snapshots {
    static var dir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("snap")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static func say(_ name: String) { try? name.write(to: dir.appendingPathComponent("now.txt"), atomically: true, encoding: .utf8) }
    static func wait(_ s: Double) async { try? await Task.sleep(for: .milliseconds(Int(s * 1000))) }

    static func run(_ router: Router) async {
        Sound.shared.enabled = false
        router.screen = .title; await wait(4.5); say("00_title"); await wait(2.0)
        for ch in Content.chapters {
            for (i, st) in ch.steps.enumerated() {
                guard let room = st.room, st.cut == nil else { continue }
                router.screen = .snap(ch.id, room); await wait(3.6)
                say(String(format: "%d_%02d_%@", ch.id, i, room)); await wait(2.6)
            }
        }
        // the story scenes, caught mid-acting (Dora's lantern lit, so its whole arc plays)
        Progress.shared.flags = ["dora", "doraStolen"]
        let scenes: [(Int, String, String, [Double])] = [
            (1, "outside", "c1_end", [1.6, 3.2]), (1, "street", "c1_d60", [3.0, 9.4]), (2, "lamp", "c2_d30", [4.6, 2.4]),
            (3, "city", "c3_city", [2.6, 1.6]), (4, "nest", "c4_end", [1.4, 2.6]), (4, "street", "c4_home", [4.6, 4.2, 3.0])]
        for (ch, room, script, at) in scenes {
            router.screen = .scene(ch, room, script)
            for (k, t) in at.enumerated() { await wait(t); say("9_\(script)_\(k)") }
            await wait(3.0)   // the simulator's screenshot lags the cue; let it land before the scene changes
        }
        Progress.shared.flags = []
        router.screen = .title; await wait(1)
        say("done")
    }
}
