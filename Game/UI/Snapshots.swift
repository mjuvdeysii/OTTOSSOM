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
                router.screen = .snap(ch.id, room); await wait(2.2)
                say(String(format: "%d_%02d_%@", ch.id, i, room)); await wait(1.8)
            }
        }
        router.screen = .title; await wait(1)
        say("done")
    }
}
