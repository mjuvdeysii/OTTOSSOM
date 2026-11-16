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

    /// The simulator may take longer than a frame to capture. Hold this scene until the host confirms it.
    static func capture(_ name: String) async -> Bool {
        say(name)
        let ack = dir.appendingPathComponent("ack.txt")
        for _ in 0..<600 {
            if Task.isCancelled { return false }
            if (try? String(contentsOf: ack, encoding: .utf8)) == name { return true }
            await wait(0.1)
        }
        say("failed_\(name)")
        return false
    }

    static func run(_ router: Router) async {
        Sound.shared.enabled = false
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("ack.txt"))
        router.screen = .dig("title"); await wait(4.5)
        guard await capture("00_title") else { return }
        for (what, hold) in [("dig", 9.0), ("deep", 9.0), ("memory", 4.0), ("ending", 4.0), ("shop", 4.0), ("delivery", 4.0), ("shoptalk", 4.0), ("evening", 4.0), ("companions", 4.0), ("shadowfriend", 4.0), ("townempty", 4.0), ("townlights", 4.0), ("lit_evening", 4.0), ("evening_compact", 4.0), ("shadowfriend_compact", 4.0), ("townlights_compact", 4.0), ("shop_compact", 4.0), ("delivery_compact", 4.0)] {
            router.screen = .dig(what); await wait(hold)
            guard await capture("dg_\(what)") else { return }
        }
        router.screen = .title; await wait(1)
        say("done")
    }
}
