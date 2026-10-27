import SwiftUI
import UIKit

/// CI only (launched with -snapshots): walks through the screens one by one and says which one is showing in
/// Documents/snap/now.txt, so the workflow can take a simulator screenshot of each; it also writes sprite sheets of
/// every figure in both styles. Nothing here runs for players.
@MainActor
enum Snapshots {
    static var dir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("snap")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func say(_ name: String) {
        try? name.write(to: dir.appendingPathComponent("now.txt"), atomically: true, encoding: .utf8)
    }

    static func wait(_ s: Double) async { try? await Task.sleep(for: .milliseconds(Int(s * 1000))) }

    static func run(_ router: Router) async {
        let p = Progress.shared
        p.resetAll()
        for style in [ArtStyle.solid, .flat] {
            ArtStyle.current = style
            sheet(style == .solid ? "sheet_3d" : "sheet_2d")
        }
        ArtStyle.current = .solid; router.artEpoch += 1
        router.screen = .title; await wait(2.5); say("01_title"); await wait(2.5)
        // a few beads found, for the bead path
        for i in 0..<12 { p.finish(i, moves: i < Levels.all.count ? Levels.all[i].par + (i % 3 == 0 ? 0 : 2) : 1) }
        for s in ["prologue", "card1", "ch1", "ch2", "ch3", "finale"] { p.saw(s) }
        router.screen = .map; await wait(2.5); say("02_map"); await wait(2.5)
        for id in [0, 4, 12, 16, 21, 26, 30, 36] where id < Levels.all.count {
            router.screen = .play(id); await wait(3); say(String(format: "10_level_%02d", id)); await wait(2.5)
        }
        // a won level: the solution played back
        if Levels.all.count > 3 {
            p.saveMoves(3, Array(Levels.all[3].solution.dropLast()))
            router.screen = .play(3); await wait(2.5); say("20_before_last_move"); await wait(2.5)
        }
        for (name, at) in [("prologue", 6.0), ("prologue", 12.0), ("ch2", 3.0), ("finale", 5.5), ("finale", 9.5)] {
            router.screen = .story(name, then: nil); await wait(at); say("30_story_\(name)_\(Int(at))"); await wait(2.0)
            router.screen = .map; await wait(0.8)
        }
        ArtStyle.current = .flat; router.artEpoch += 1
        router.screen = .title; await wait(2.5); say("40_title_2d"); await wait(2.5)
        for id in [21, 30] where id < Levels.all.count {
            router.screen = .play(id); await wait(3); say("41_level_2d_\(id)"); await wait(2.5)
        }
        ArtStyle.current = .solid; router.artEpoch += 1
        router.screen = .nightly; await wait(8); say("50_nightly"); await wait(2.5)
        p.resetAll()
        say("done")
    }

    /// Every figure picture in one style, on the night colour, with its name.
    static func sheet(_ file: String) {
        var names: [String] = []
        names += ["idle", "left", "right", "up", "down", "blink", "wide", "glee", "sleep", "hop"].map { "moss_\($0)" }
        for f in ["S", "E", "N", "W"] { names += ["idle", "blink", "yawn", "glee", "wide", "sleep"].map { "otto_\($0)_\(f)" } }
        names += ["idle", "left", "right", "blink", "seen", "found", "day"].map { "mosto_\($0)" }
        names += ["prop_bead", "prop_crown", "prop_block", "prop_cup", "prop_book", "prop_rings", "prop_tower", "prop_jar", "prop_knob", "prop_roll", "prop_key", "prop_key2", "prop_mug"]
        let cell: CGFloat = 200, cols = 8
        let rows = (names.count + cols - 1) / cols
        let img = UIGraphicsImageRenderer(size: CGSize(width: cell * CGFloat(cols), height: cell * CGFloat(rows))).image { c in
            UIColor(hex: 0x232B4F).setFill(); c.fill(CGRect(x: 0, y: 0, width: cell * CGFloat(cols), height: cell * CGFloat(rows)))
            for (i, n) in names.enumerated() {
                let r = CGRect(x: CGFloat(i % cols) * cell, y: CGFloat(i / cols) * cell, width: cell, height: cell)
                Art.image(n)?.draw(in: r)
                (n as NSString).draw(at: CGPoint(x: r.minX + 6, y: r.maxY - 18), withAttributes: [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.white.withAlphaComponent(0.7)])
            }
        }
        try? img.pngData()?.write(to: dir.appendingPathComponent("\(file).png"))
    }
}
