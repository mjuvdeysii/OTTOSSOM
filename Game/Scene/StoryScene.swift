import SpriteKit
import UIKit

/// When the story scenes play.
enum Story {
    static func before(_ level: Int) -> String? { level == 0 ? "prologue" : nil }
    static func after(_ level: Int) -> String? {
        switch level {
        case 0: return "card1"
        case 9: return "ch1"
        case 18: return "ch2"
        case 27: return "ch3"
        case 36: return "finale"
        default: return nil
        }
    }
    /// The chapter card shown at the end of each scene (the only words in the story).
    static func card(_ scene: String) -> (String, String)? {
        switch scene {
        case "prologue": return ("序", "灯灭了")
        case "card1": return ("第一章", "矮桌")
        case "ch1": return ("第二章", "木架")
        case "ch2": return ("第三章", "靠垫山")
        case "ch3": return ("第四章", "键盘")
        case "finale": return ("尾声", "第 38 颗")
        default: return nil
        }
    }
}

/// The wordless scenes, played with the same figures as the levels on a small stage: the lamp-lit wall behind (where
/// shadows tell what the figures cannot say), the table top, the string of beads.
final class StoryScene: SKScene {
    let name_: String
    var onDone: (() -> Void)?
    private let stage = SKNode()
    private var u: CGFloat = 100          // one world unit in points
    private var tableY: CGFloat = 0       // where feet stand
    private var wallBottom: CGFloat = 0
    private let darkness = SKSpriteNode(color: UIColor(hex: 0x05081A), size: .zero)
    private let halo = SKSpriteNode(texture: Glow.radial)
    private var reduce: Bool { UIAccessibility.isReduceMotionEnabled }

    init(name: String, size: CGSize) {
        name_ = name
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = BoardScene.night
    }
    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        addChild(stage)
        u = min(size.width / 4.2, 130)
        tableY = size.height * 0.4
        wallBottom = size.height * 0.55
        buildRoom(surface: ["finale": "desk", "ch3": "cushion", "ch2": "shelf"][name_] ?? "table")
        switch name_ {
        case "prologue": prologue()
        case "card1": card1()
        case "ch1": ch1()
        case "ch2": ch2()
        case "ch3": ch3()
        case "finale": finale()
        default: finish(after: 0.1)
        }
    }

    // MARK: stage

    private func buildRoom(surface: String) {
        let wall = SKSpriteNode(texture: Glow.vertical(top: UIColor(hex: 0x1A2142), bottom: UIColor(hex: 0x2E3766)))
        wall.anchorPoint = .zero; wall.size = CGSize(width: size.width, height: size.height - wallBottom); wall.position = CGPoint(x: 0, y: wallBottom); wall.zPosition = 0
        stage.addChild(wall)
        let top = SKSpriteNode(texture: Art.texture("surface_\(surface)"))
        top.anchorPoint = CGPoint(x: 0.5, y: 1)
        top.size = CGSize(width: size.width * 1.2, height: (wallBottom - size.height * 0.2))
        top.position = CGPoint(x: size.width / 2, y: wallBottom); top.zPosition = 1
        stage.addChild(top)
        let edge = SKSpriteNode(texture: Art.texture("edge_\(surface)"))
        edge.anchorPoint = CGPoint(x: 0.5, y: 1); edge.size = CGSize(width: size.width * 1.2, height: size.height * 0.04)
        edge.position = CGPoint(x: size.width / 2, y: size.height * 0.2); edge.zPosition = 1
        stage.addChild(edge)
        darkness.anchorPoint = .zero; darkness.size = size; darkness.zPosition = 50; darkness.alpha = 0.35
        stage.addChild(darkness)
        halo.blendMode = .add; halo.color = BoardScene.lamp; halo.colorBlendFactor = 1; halo.zPosition = 60   // under the figures: it lights the table and the wall, not their faces
        halo.size = CGSize(width: u * 4.4, height: u * 4.4); halo.alpha = 0.55
        stage.addChild(halo)
    }

    private func figure(_ tex: String, x: CGFloat, depth: CGFloat = 0, scale: CGFloat = 1) -> SKSpriteNode {
        let n = SKSpriteNode(texture: Art.texture(tex))
        let s = Art.frame.unitsAcross * u * Art.figureScale * scale
        n.size = CGSize(width: s, height: s)
        n.anchorPoint = CGPoint(x: Art.frame.feetX, y: 1 - Art.frame.feetY)
        n.position = CGPoint(x: x, y: tableY + depth * u * 0.4)
        n.zPosition = 100 - depth * 10
        stage.addChild(n)
        if !reduce {
            let period = tex.hasPrefix("moss") ? 2.6 : tex.hasPrefix("otto") ? 3.8 : 3.1
            n.run(.repeatForever(.customAction(withDuration: period) { node, t in
                let k = (1 - cos(Double(t) / period * 2 * .pi)) / 2
                (node as? SKSpriteNode)?.yScale = 1 + CGFloat(k * 0.022)
            }))
        }
        return n
    }

    /// The figure's shadow on the wall, thrown by the lamp at `from`.
    private func shadow(of n: SKSpriteNode, lamp from: CGPoint) -> SKSpriteNode {
        let s = SKSpriteNode(texture: n.texture)
        s.size = CGSize(width: n.size.width * 1.7, height: n.size.height * 1.7)
        s.anchorPoint = n.anchorPoint
        s.color = UIColor(hex: 0x05070F); s.colorBlendFactor = 1; s.alpha = 0.55
        s.zPosition = 5
        follow(s, n, lamp: from)
        stage.addChild(s)
        return s
    }
    private func follow(_ s: SKSpriteNode, _ n: SKSpriteNode, lamp from: CGPoint) {
        s.run(.repeatForever(.sequence([.run { [weak self, weak s, weak n] in
            guard let self, let s, let n else { return }
            s.texture = n.texture
            let dx = n.position.x - from.x
            s.position = CGPoint(x: from.x + dx * 1.6, y: self.wallBottom + self.u * 0.15)
        }, .wait(forDuration: 1.0 / 30)])), withKey: "follow")
    }

    private func bead(at p: CGPoint, scale: CGFloat = 0.32, violet: Bool = false) -> SKSpriteNode {
        let n = SKSpriteNode(texture: Art.texture("prop_bead"))
        let s = Art.frame.unitsAcross * u * scale
        n.size = CGSize(width: s, height: s)
        n.anchorPoint = CGPoint(x: Art.frame.feetX, y: 1 - Art.frame.feetY)
        n.position = p; n.zPosition = 90
        if violet { n.color = UIColor(hex: 0x7B5BD6); n.colorBlendFactor = 0.75 }
        stage.addChild(n)
        return n
    }

    /// The string of beads lying across the table, `count` beads strung on it.
    private func string(count: Int, y: CGFloat, extend: Bool = false) -> [SKSpriteNode] {
        let path = CGMutablePath()
        let x0 = size.width * 0.04, x1 = extend ? size.width * 1.1 : size.width * 0.96
        path.move(to: CGPoint(x: x0, y: y))
        path.addCurve(to: CGPoint(x: x1, y: y + u * 0.1), control1: CGPoint(x: size.width * 0.35, y: y - u * 0.35), control2: CGPoint(x: size.width * 0.65, y: y + u * 0.4))
        let line = SKShapeNode(path: path)
        line.strokeColor = UIColor(hex: 0xC9483A); line.lineWidth = 2; line.zPosition = 80
        stage.addChild(line)
        var beads: [SKSpriteNode] = []
        for i in 0..<count {
            let t = CGFloat(i) / 36
            let p = cubic(CGPoint(x: x0, y: y), CGPoint(x: size.width * 0.35, y: y - u * 0.35), CGPoint(x: size.width * 0.65, y: y + u * 0.4), CGPoint(x: x1, y: y + u * 0.1), t * (extend ? 0.88 : 1))
            beads.append(bead(at: CGPoint(x: p.x, y: p.y - u * 0.04), scale: 0.13))
        }
        return beads
    }
    private func cubic(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, _ t: CGFloat) -> CGPoint {
        let m = 1 - t
        return CGPoint(x: m * m * m * a.x + 3 * m * m * t * b.x + 3 * m * t * t * c.x + t * t * t * d.x,
                       y: m * m * m * a.y + 3 * m * m * t * b.y + 3 * m * t * t * c.y + t * t * t * d.y)
    }

    private func set(_ n: SKSpriteNode, _ tex: String, after t: TimeInterval) {
        n.run(.sequence([.wait(forDuration: t), .run { n.texture = Art.texture(tex) }]))
    }
    private func hop(_ n: SKSpriteNode, to x: CGFloat, after t: TimeInterval, hops: Int = 1, dur: TimeInterval = 0.5) {
        let step = (x - n.position.x) / CGFloat(max(1, hops))
        var seq: [SKAction] = [.wait(forDuration: t)]
        for _ in 0..<hops {
            let up = SKAction.moveBy(x: step / 2, y: u * 0.12, duration: dur / 2 / Double(hops)); up.timingMode = .easeOut
            let dn = SKAction.moveBy(x: step / 2, y: -u * 0.12, duration: dur / 2 / Double(hops)); dn.timingMode = .easeIn
            seq += [up, dn]
        }
        n.run(.sequence(seq))
    }
    private func lamp(_ alpha: CGFloat, dark: CGFloat, after t: TimeInterval, dur: TimeInterval = 1.0) {
        halo.run(.sequence([.wait(forDuration: t), .fadeAlpha(to: alpha, duration: dur)]))
        darkness.run(.sequence([.wait(forDuration: t), .fadeAlpha(to: dark, duration: dur)]))
        // the figures stand above the darkness layer, so the night reaches them as the moon's blue
        run(.sequence([.wait(forDuration: t), .run { [weak self] in
            guard let self else { return }
            for case let n as SKSpriteNode in self.stage.children where n.zPosition >= 80 && n.zPosition < 200 {
                n.run(.colorize(with: BoardScene.moon, colorBlendFactor: min(0.85, dark * 0.95), duration: dur))
            }
        }]))
    }
    private func finish(after t: TimeInterval) {
        run(.sequence([.wait(forDuration: reduce ? min(t, 1.0) : t), .run { [weak self] in self?.onDone?() }]))
    }

    // MARK: 序 · 灯灭了

    private func prologue() {
        let beads = string(count: 36, y: tableY - u * 0.55)
        let otto = figure("otto_idle_E", x: size.width * 0.3, depth: 0.6)
        let moss = figure("moss_down", x: size.width * 0.56)
        let held = bead(at: CGPoint(x: moss.position.x + u * 0.42, y: tableY - u * 0.05), scale: 0.2)
        let bead0 = Art.bead("otto_idle_E") ?? CGPoint(x: 0.6, y: 0.43)
        let lampAt = CGPoint(x: otto.position.x + (bead0.x - 0.5) * otto.size.width, y: otto.position.y + (Art.frame.feetY - bead0.y) * otto.size.height)
        halo.position = lampAt
        let sm = shadow(of: moss, lamp: lampAt), so = shadow(of: otto, lamp: lampAt)
        // Moss will not let go of the last bead; Otto, tired, lets the lamp go out
        set(moss, "moss_wide", after: 1.0)
        set(otto, "otto_blink_E", after: 1.4); set(otto, "otto_idle_E", after: 1.6)
        set(otto, "otto_yawn_E", after: 2.6); set(otto, "otto_sleep_E", after: 4.3)
        lamp(0.06, dark: 0.82, after: 3.0, dur: 1.6)
        // the two shadows lean together on the wall and stand up as one
        let mid = CGPoint(x: size.width * 0.5, y: wallBottom + u * 0.15)
        for s in [sm, so] {
            s.run(.sequence([.wait(forDuration: 4.4), .run { s.removeAction(forKey: "follow") }, .group([.move(to: mid, duration: 1.2), .fadeAlpha(to: 0.8, duration: 1.2)]), .fadeOut(withDuration: 0.4)]))
        }
        let born = SKSpriteNode(texture: Art.texture("mosto_idle"))
        born.size = CGSize(width: sm.size.width * 1.1, height: sm.size.height * 1.1); born.anchorPoint = sm.anchorPoint
        born.color = .black; born.colorBlendFactor = 1; born.alpha = 0; born.position = mid; born.zPosition = 6
        stage.addChild(born)
        born.run(.sequence([.wait(forDuration: 5.6), .fadeAlpha(to: 0.85, duration: 0.4), .wait(forDuration: 0.5), .fadeOut(withDuration: 0.5)]))
        let mosto = figure("mosto_idle", x: size.width * 0.5, depth: 0.9)
        mosto.alpha = 0
        mosto.run(.sequence([.wait(forDuration: 6.3), .fadeIn(withDuration: 0.4)]))
        hop(mosto, to: size.width * 0.72, after: 6.8, hops: 2, dur: 0.6)
        set(mosto, "mosto_left", after: 7.4); set(mosto, "mosto_right", after: 7.9)
        // he takes every bead, the one in Moss's hands too
        for (i, b) in beads.enumerated() {
            b.run(.sequence([.wait(forDuration: 8.0 + Double(i) * 0.03), .group([.move(to: CGPoint(x: size.width * 0.72, y: tableY + u * 0.3), duration: 0.35), .fadeOut(withDuration: 0.35)])]))
        }
        held.run(.sequence([.wait(forDuration: 9.2), .group([.move(to: CGPoint(x: size.width * 0.72, y: tableY + u * 0.3), duration: 0.3), .fadeOut(withDuration: 0.3)])]))
        set(moss, "moss_up", after: 9.2)
        set(mosto, "mosto_blink", after: 9.6); set(mosto, "mosto_idle", after: 9.75)
        hop(mosto, to: size.width * 1.2, after: 10.0, hops: 3, dur: 0.9)
        // purple footprints where he went
        for k in 0..<4 {
            let f = SKShapeNode(ellipseOf: CGSize(width: u * 0.12, height: u * 0.06))
            f.fillColor = UIColor(hex: 0x7B5BD6); f.strokeColor = .clear; f.alpha = 0; f.zPosition = 85
            f.position = CGPoint(x: size.width * (0.78 + 0.08 * CGFloat(k)), y: tableY - u * 0.12 + CGFloat(k % 2) * u * 0.08)
            stage.addChild(f)
            f.run(.sequence([.wait(forDuration: 10.2 + Double(k) * 0.2), .fadeAlpha(to: 0.8, duration: 0.2)]))
        }
        // the lamp comes back on: an empty string, and a trail
        set(otto, "otto_wide_E", after: 11.0)
        lamp(0.55, dark: 0.35, after: 11.0, dur: 0.6)
        set(moss, "moss_left", after: 11.6); set(moss, "moss_right", after: 12.3); set(moss, "moss_wide", after: 13.0)
        set(otto, "otto_idle_E", after: 13.4)
        finish(after: 14.6)
    }

    // MARK: 第一章 card

    private func card1() {
        let otto = figure("otto_idle_E", x: size.width * 0.34, depth: 0.5)
        let moss = figure("moss_idle", x: size.width * 0.58)
        let b = Art.bead("otto_idle_E") ?? CGPoint(x: 0.6, y: 0.43)
        halo.position = CGPoint(x: otto.position.x + (b.x - 0.5) * otto.size.width, y: otto.position.y + (Art.frame.feetY - b.y) * otto.size.height)
        set(moss, "moss_right", after: 0.8)
        hop(moss, to: size.width * 0.66, after: 1.2)
        set(moss, "moss_wide", after: 1.8)
        finish(after: 2.8)
    }

    // MARK: 第一章 end: a crown glints where the light does not reach

    private func ch1() {
        lamp(0.25, dark: 0.7, after: 0, dur: 0.1)
        halo.position = CGPoint(x: size.width * 0.2, y: tableY + u)
        let moss = figure("moss_idle", x: size.width * 0.3)
        let crown = SKSpriteNode(texture: Art.texture("prop_crown"))
        let s = Art.frame.unitsAcross * u * 0.55
        crown.size = CGSize(width: s, height: s); crown.anchorPoint = CGPoint(x: 0.5, y: 1 - Art.frame.feetY)
        crown.position = CGPoint(x: size.width * 0.78, y: tableY + u * 0.4); crown.zPosition = 95; crown.alpha = 0
        crown.color = UIColor(hex: 0x2B3566); crown.colorBlendFactor = 0.5
        stage.addChild(crown)
        let spark = SKSpriteNode(texture: Glow.radial)
        spark.size = CGSize(width: u * 0.5, height: u * 0.5); spark.blendMode = .add; spark.color = BoardScene.lamp; spark.colorBlendFactor = 1
        spark.position = CGPoint(x: crown.position.x, y: crown.position.y + u * 0.3); spark.zPosition = 600; spark.alpha = 0
        stage.addChild(spark)
        crown.run(.sequence([.wait(forDuration: 1.0), .fadeAlpha(to: 0.8, duration: 0.3), .wait(forDuration: 1.0), .fadeOut(withDuration: 0.2)]))
        spark.run(.sequence([.wait(forDuration: 1.2), .fadeIn(withDuration: 0.1), .fadeOut(withDuration: 0.5)]))
        set(moss, "moss_right", after: 1.4); set(moss, "moss_wide", after: 2.6)
        finish(after: 3.6)
    }

    // MARK: 第二章 end: on the wall, a horned shadow does what Moss does, the other way round

    private func ch2() {
        let otto = figure("otto_idle_S", x: size.width * 0.5, depth: 0.8)
        let b = Art.bead("otto_idle_S") ?? CGPoint(x: 0.5, y: 0.4)
        let lampAt = CGPoint(x: otto.position.x + (b.x - 0.5) * otto.size.width, y: otto.position.y + (Art.frame.feetY - b.y) * otto.size.height)
        halo.position = lampAt
        let moss = figure("moss_idle", x: size.width * 0.5)
        _ = shadow(of: moss, lamp: lampAt)
        let horned = SKSpriteNode(texture: Art.texture("mosto_idle"))
        horned.size = CGSize(width: moss.size.width * 1.7, height: moss.size.height * 1.7); horned.anchorPoint = moss.anchorPoint
        horned.color = UIColor(hex: 0x05070F); horned.colorBlendFactor = 1; horned.alpha = 0.0; horned.zPosition = 5
        stage.addChild(horned)
        // the second shadow mirrors Moss's x around the lamp
        horned.run(.repeatForever(.sequence([.run { [weak self, weak moss, weak horned] in
            guard let self, let moss, let horned else { return }
            let dx = moss.position.x - lampAt.x
            horned.position = CGPoint(x: lampAt.x - dx * 1.6 + self.u * 0.9, y: self.wallBottom + self.u * 0.15 + (moss.position.y - self.tableY))
        }, .wait(forDuration: 1.0 / 30)])))
        horned.run(.sequence([.wait(forDuration: 0.8), .fadeAlpha(to: 0.5, duration: 0.6)]))
        hop(moss, to: size.width * 0.3, after: 1.2, hops: 2, dur: 0.8)
        set(moss, "moss_left", after: 1.2)
        set(moss, "moss_right", after: 2.4)
        hop(moss, to: size.width * 0.55, after: 2.8, hops: 2, dur: 0.8)
        set(moss, "moss_wide", after: 3.8)
        hop(moss, to: size.width * 0.55, after: 4.3, hops: 1, dur: 0.45)
        finish(after: 5.6)
    }

    // MARK: 第三章 end: Mosto runs for the desk, dropping beads

    private func ch3() {
        lamp(0.35, dark: 0.55, after: 0, dur: 0.1)
        for k in 0..<4 {
            let key = SKSpriteNode(texture: Art.texture(k % 2 == 0 ? "prop_key" : "prop_key2"))
            let s = Art.frame.unitsAcross * u * 0.7
            key.size = CGSize(width: s, height: s); key.anchorPoint = CGPoint(x: 0.5, y: 1 - Art.frame.feetY)
            key.position = CGPoint(x: size.width * (0.62 + 0.13 * CGFloat(k)), y: wallBottom - u * 0.1); key.zPosition = 40
            key.color = UIColor(hex: 0x2B3566); key.colorBlendFactor = 0.55
            stage.addChild(key)
        }
        let mosto = figure("mosto_right", x: size.width * 0.3)
        let moss = figure("moss_right", x: size.width * 0.05, depth: -0.2)
        let otto = figure("otto_idle_E", x: -size.width * 0.1, depth: 0.5)
        halo.position = CGPoint(x: -size.width * 0.05, y: tableY + u)
        hop(mosto, to: size.width * 0.85, after: 0.6, hops: 4, dur: 1.6)
        mosto.run(.sequence([.wait(forDuration: 1.4), .moveBy(x: 0, y: u * 0.25, duration: 0.5), .fadeOut(withDuration: 0.4)]))
        for k in 0..<3 {
            let b = bead(at: CGPoint(x: size.width * (0.45 + 0.13 * CGFloat(k)), y: tableY - u * 0.05), scale: 0.16)
            b.alpha = 0
            b.run(.sequence([.wait(forDuration: 0.9 + Double(k) * 0.3), .fadeIn(withDuration: 0.1)]))
        }
        hop(moss, to: size.width * 0.4, after: 1.8, hops: 3, dur: 1.1)
        hop(otto, to: size.width * 0.15, after: 2.0, hops: 2, dur: 1.4)
        halo.run(.sequence([.wait(forDuration: 2.0), .move(to: CGPoint(x: size.width * 0.2, y: tableY + u), duration: 1.4)]))
        set(moss, "moss_up", after: 3.2)
        finish(after: 4.4)
    }

    // MARK: 尾声: in the light, Moss offers a mint leaf; then the 38th bead

    private func finale() {
        let otto = figure("otto_idle_E", x: size.width * 0.18, depth: 0.5)
        let b = Art.bead("otto_idle_E") ?? CGPoint(x: 0.6, y: 0.43)
        let lampAt = CGPoint(x: otto.position.x + (b.x - 0.5) * otto.size.width, y: otto.position.y + (Art.frame.feetY - b.y) * otto.size.height)
        halo.position = lampAt
        lamp(0.75, dark: 0.3, after: 0, dur: 0.1)
        let mosto = figure("mosto_seen", x: size.width * 0.74)
        var pile: [SKSpriteNode] = []
        for k in 0..<9 {
            let p = bead(at: CGPoint(x: mosto.position.x + CGFloat(k % 3 - 1) * u * 0.18, y: tableY - u * 0.18 + CGFloat(k / 3) * u * 0.07), scale: 0.14)
            p.zPosition = 120; pile.append(p)
        }
        let moss = figure("moss_right", x: size.width * 0.36)
        _ = shadow(of: moss, lamp: lampAt); _ = shadow(of: mosto, lamp: lampAt); _ = shadow(of: otto, lamp: lampAt)
        hop(moss, to: size.width * 0.5, after: 1.0, hops: 2, dur: 1.0)
        set(moss, "moss_wide", after: 2.2)
        // a mint leaf from Moss's sprig, held out
        let leaf = SKSpriteNode(texture: StoryScene.leafTexture)
        leaf.size = CGSize(width: u * 0.3, height: u * 0.3)
        leaf.position = CGPoint(x: moss.position.x, y: moss.position.y + u * 0.95); leaf.zPosition = 130; leaf.alpha = 0
        stage.addChild(leaf)
        leaf.run(.sequence([.wait(forDuration: 2.6), .fadeIn(withDuration: 0.2),
                            .move(to: CGPoint(x: (moss.position.x + mosto.position.x) / 2 + u * 0.3, y: tableY + u * 0.5), duration: 1.2)]))
        set(mosto, "mosto_found", after: 4.2)
        for (k, p) in pile.enumerated() {
            p.run(.sequence([.wait(forDuration: 4.6 + Double(k) * 0.05), .colorize(with: BoardScene.lamp, colorBlendFactor: 0.4, duration: 0.3)]))
        }
        set(moss, "moss_glee", after: 4.8); set(otto, "otto_glee_E", after: 5.0)
        lamp(0.9, dark: 0.15, after: 5.0, dur: 1.2)
        // the epilogue: everything fades to the low table, the string full, a purple bead added at the end
        let fade = SKSpriteNode(color: UIColor(hex: 0x141A33), size: size)
        fade.anchorPoint = .zero; fade.zPosition = 900; fade.alpha = 0
        stage.addChild(fade)
        fade.run(.sequence([.wait(forDuration: 6.6), .fadeIn(withDuration: 0.6), .run { [weak self] in self?.epilogue() }, .fadeOut(withDuration: 0.6)]))
    }

    private func epilogue() {
        for n in stage.children where n !== darkness && n !== halo && n.zPosition < 900 { n.removeFromParent() }
        buildRoomOnly()
        let beads = string(count: 37, y: tableY - u * 0.55, extend: true)
        _ = beads
        let last = cubic(CGPoint(x: size.width * 0.04, y: tableY - u * 0.55), CGPoint(x: size.width * 0.35, y: tableY - u * 0.9), CGPoint(x: size.width * 0.65, y: tableY - u * 0.15), CGPoint(x: size.width * 1.1, y: tableY - u * 0.45), 0.92)
        let purple = bead(at: CGPoint(x: last.x, y: last.y + u * 0.6), scale: 0.15, violet: true)
        purple.run(.move(to: CGPoint(x: last.x, y: last.y - u * 0.04), duration: 0.6))
        let otto = figure("otto_idle_E", x: size.width * 0.22, depth: 0.6)
        _ = figure("moss_glee", x: size.width * 0.42)
        let mosto = figure("mosto_day", x: size.width * 0.68)
        let b = Art.bead("otto_idle_E") ?? CGPoint(x: 0.6, y: 0.43)
        halo.position = CGPoint(x: otto.position.x + (b.x - 0.5) * otto.size.width, y: otto.position.y + (Art.frame.feetY - b.y) * otto.size.height)
        lamp(0.6, dark: 0.3, after: 0, dur: 0.2)
        // and still, every night, he hides one
        let cup = SKSpriteNode(texture: Art.texture("prop_cup"))
        let s = Art.frame.unitsAcross * u * 0.6
        cup.size = CGSize(width: s, height: s); cup.anchorPoint = CGPoint(x: 0.5, y: 1 - Art.frame.feetY)
        cup.position = CGPoint(x: size.width * 0.86, y: tableY + u * 0.3); cup.zPosition = 95
        stage.addChild(cup)
        let one = bead(at: CGPoint(x: size.width * 0.6, y: tableY - u * 0.5), scale: 0.13)
        one.run(.sequence([.wait(forDuration: 1.8), .move(to: CGPoint(x: size.width * 0.84, y: tableY + u * 0.35), duration: 0.5), .fadeOut(withDuration: 0.1)]))
        hop(mosto, to: size.width * 0.8, after: 1.6, hops: 1, dur: 0.5)
        set(mosto, "mosto_right", after: 1.6)
        set(mosto, "mosto_blink", after: 2.6); set(mosto, "mosto_day", after: 2.8)
        finish(after: 4.0)
    }

    private func buildRoomOnly() { buildRoomSurfaces(surface: "table") }
    private func buildRoomSurfaces(surface: String) {
        darkness.removeFromParent(); halo.removeFromParent()
        buildRoom(surface: surface)
    }

    static let leafTexture: SKTexture = {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { c in
            let g = c.cgContext
            g.translateBy(x: -96, y: -22); g.scaleBy(x: 2.0, y: 2.0)
            g.addPath(FlatShapes.mintA); g.setFillColor(FlatArt.Pal.mint.cgColor); g.fillPath()
        }
        return SKTexture(image: img)
    }()
}
