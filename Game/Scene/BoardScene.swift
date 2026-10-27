import SpriteKit
import UIKit

/// One level on the table at night. The scene draws the board as a small diorama seen from 35° above (the camera of
/// Tools/art), lights it from Otto's bead exactly as the rules light it, and turns swipes into moves.
final class BoardScene: SKScene {
    // MARK: inputs and outputs
    let info: LevelInfo
    let board: Board
    private(set) var state: GameState
    private(set) var history: [GameState] = []
    private(set) var moves: [Move] = []
    var selected: Actor = .moss { didSet { updateSelection(); onChange?() } }
    var onChange: (() -> Void)?
    var onWin: ((Int) -> Void)?
    private(set) var finished = false

    // MARK: geometry
    static let tilt: CGFloat = 35 * .pi / 180
    /// A cell's depth on screen, as a share of its width. Deeper than the 35° camera would draw it (0.57), so that a
    /// figure standing behind another stays in view; the eye reads the table as a little steeper, never as wrong.
    private let K: CGFloat = 0.72
    private let H = cos(BoardScene.tilt)                 // one unit of height on screen
    private var c: CGFloat = 60                          // cell width in points
    private var left: CGFloat = 0, top: CGFloat = 0

    // MARK: nodes
    private let world = SKNode()
    private var floorNodes: [Int: SKNode] = [:]
    private var bridgeNodes: [Int: SKSpriteNode] = [:]
    private var blockNodes: [SKSpriteNode] = []
    private var sunkNodes: [Int: SKSpriteNode] = [:]
    private var tallNodes: [Int: SKSpriteNode] = [:]
    private var goalNodes: [SKSpriteNode] = []
    private let moss = SKSpriteNode()
    private let otto = SKSpriteNode()
    private let mosto = SKSpriteNode()
    private let selection = SKShapeNode()
    private let dark = SKSpriteNode()
    private let darkOld = SKSpriteNode()
    private let warm = SKSpriteNode()
    private let halo = SKSpriteNode()
    private let hintNode = SKNode()
    private var busy = false
    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    private let tap = UIImpactFeedbackGenerator(style: .light)
    private let bump = UIImpactFeedbackGenerator(style: .rigid)

    // MARK: palette
    static let night = UIColor(hex: 0x141A33)
    static let moon = UIColor(hex: 0x2B3566)
    static let lamp = UIColor(hex: 0xFFC46E)

    init(info: LevelInfo, size: CGSize) {
        self.info = info
        let b = info.board()
        self.board = b
        self.state = b.start
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = BoardScene.night
        anchorPoint = .zero
        let saved = Progress.shared.savedMoves(info.id)
        for s in saved {
            guard s.count == 2, let a = Actor(rawValue: s.first!), let d = Dir(letter: s.last!) else { break }
            let m = Move(actor: a, dir: d)
            guard let n = board.step(state, m), !board.won(n) else { break }
            history.append(state); moves.append(m); state = n
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: building

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        view.ignoresSiblingOrder = true
        build()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard world.parent != nil, oldSize != size else { return }
        build()
    }

    /// Room at the top for the HUD, at the bottom for the companion buttons.
    var insets = UIEdgeInsets(top: 96, left: 16, bottom: 132, right: 16)

    private func layout() {
        let w = CGFloat(board.width), h = CGFloat(board.height)
        let availW = size.width - insets.left - insets.right
        let availH = size.height - insets.top - insets.bottom
        // the board's screen height: its rows, the front lip, and the tallest figure standing in the back row
        c = min(availW / w, availH / (h * K + 0.25 * H + 1.1 * H))
        c = min(c, 92)
        left = (size.width - c * w) / 2
        let boardH = h * c * K, lip = 0.25 * H * c, above = 1.1 * H * c
        let total = above + boardH + lip
        let bottom = insets.bottom + (availH - total) / 2
        top = bottom + lip + boardH
    }

    /// The ground point at the centre of cell i.
    func point(_ i: Int) -> CGPoint {
        CGPoint(x: left + (CGFloat(board.x(i)) + 0.5) * c, y: top - (CGFloat(board.y(i)) + 0.5) * c * K)
    }
    private func z(_ i: Int, _ k: CGFloat = 0) -> CGFloat { 100 + CGFloat(board.y(i)) * 10 + k }

    private func figureSize(_ figure: Bool) -> CGSize {
        let s = Art.frame.unitsAcross * c * (figure ? Art.figureScale : 1)
        return CGSize(width: s, height: s)
    }
    private func prop(_ name: String, at i: Int, scale: CGFloat = 1) -> SKSpriteNode {
        let n = SKSpriteNode(texture: Art.texture(name))
        n.size = figureSize(false)
        n.setScale(scale)
        n.anchorPoint = CGPoint(x: Art.frame.feetX, y: 1 - Art.frame.feetY)
        n.position = point(i)
        n.zPosition = z(i, 2)
        addShadow(n, width: c * 0.78)
        return n
    }

    /// A soft contact shadow under a thing or a figure, darkest under its feet (as under the app's figures).
    private func addShadow(_ n: SKSpriteNode, width: CGFloat) {
        n.childNode(withName: "shadow")?.removeFromParent()
        let s = SKSpriteNode(texture: Glow.radial)
        s.name = "shadow"
        s.color = UIColor(hex: 0x05070F); s.colorBlendFactor = 1; s.alpha = 0.55
        // children are drawn in the parent's scale; undo the parent's size so the shadow keeps its own
        s.size = CGSize(width: width / max(n.xScale, 0.01), height: width * K * 0.8 / max(n.yScale, 0.01))
        s.position = .zero
        s.zPosition = -0.5
        n.addChild(s)
    }

    private func build() {
        world.removeAllChildren(); world.removeFromParent()
        floorNodes = [:]; bridgeNodes = [:]; blockNodes = []; sunkNodes = [:]; tallNodes = [:]; goalNodes = []
        addChild(world)
        layout()
        let chapter = Levels.chapter(of: info.id)
        buildRoom()
        let surface = Art.texture("surface_\(chapter.surface)")
        let edge = Art.texture("edge_\(chapter.surface)")
        let tiles = 4.0   // the surface picture spans 4 × 4 cells
        for i in 0..<(board.width * board.height) {
            let g = board.ground[i]
            if g == .gap || g == .bridge {
                if g == .bridge { buildBridge(i) }
                continue
            }
            let x = CGFloat(board.x(i)), y = CGFloat(board.y(i))
            let r = CGRect(x: x.truncatingRemainder(dividingBy: tiles) / tiles, y: 1 - (y.truncatingRemainder(dividingBy: tiles) + 1) / tiles, width: 1 / tiles, height: 1 / tiles)
            let tile = SKSpriteNode(texture: SKTexture(rect: r, in: surface))
            tile.size = CGSize(width: c + 0.6, height: c * K + 0.6)
            tile.position = point(i)
            tile.zPosition = 10
            world.addChild(tile)
            floorNodes[i] = tile
            // the table's front edge where nothing stands in front of it
            let below = board.y(i) + 1 < board.height ? i + board.width : -1
            if below < 0 || board.ground[below] == .gap || board.ground[below] == .bridge {
                let lip = SKSpriteNode(texture: SKTexture(rect: CGRect(x: r.minX, y: 0, width: r.width, height: 1), in: edge))
                lip.size = CGSize(width: c + 0.6, height: 0.25 * H * c)
                lip.anchorPoint = CGPoint(x: 0.5, y: 1)
                lip.position = CGPoint(x: point(i).x, y: point(i).y - c * K / 2 + 0.3)
                lip.zPosition = 11
                world.addChild(lip)
            }
            if g == .tall {
                let names = chapter.talls
                let name = names[(board.x(i) * 7 + board.y(i) * 3 + info.id) % names.count]
                let n = prop("prop_\(name)", at: i)
                world.addChild(n); tallNodes[i] = n
            }
        }
        if board.bead >= 0 {
            let n = prop("prop_bead", at: board.bead)
            n.name = "bead"; world.addChild(n); goalNodes.append(n)
            if !reduceMotion {
                n.run(.repeatForever(.sequence([.moveBy(x: 0, y: c * 0.05, duration: 1.2), .moveBy(x: 0, y: -c * 0.05, duration: 1.2)])))
            }
        }
        if board.crown >= 0 {
            let n = prop("prop_crown", at: board.crown)
            n.name = "crown"; world.addChild(n); goalNodes.append(n)
        }
        // light
        for n in [dark, darkOld] { n.anchorPoint = .zero; n.position = .zero; n.zPosition = 50; n.removeFromParent(); world.addChild(n) }
        warm.anchorPoint = .zero; warm.position = .zero; warm.zPosition = 51; warm.blendMode = .add; warm.removeFromParent(); world.addChild(warm)
        halo.texture = Glow.radial; halo.blendMode = .add; halo.zPosition = 900; halo.removeFromParent(); world.addChild(halo)
        // figures
        for (n, figure) in [(moss, true), (otto, true), (mosto, true)] {
            n.removeAllActions(); n.removeFromParent()
            n.size = figureSize(figure)
            n.anchorPoint = CGPoint(x: Art.frame.feetX, y: 1 - Art.frame.feetY)
            n.xScale = 1; n.yScale = 1
            world.addChild(n)
            addShadow(n, width: c * 0.7)
        }
        selection.removeFromParent()
        selection.path = CGPath(ellipseIn: CGRect(x: -c * 0.36, y: -c * 0.36 * K, width: c * 0.72, height: c * 0.72 * K), transform: nil)
        selection.strokeColor = BoardScene.lamp.withAlphaComponent(0.85); selection.lineWidth = 2; selection.fillColor = BoardScene.lamp.withAlphaComponent(0.12)
        selection.glowWidth = 3
        world.addChild(selection)
        hintNode.removeFromParent(); world.addChild(hintNode)
        startIdle()
        render(animated: false)
    }

    private func buildRoom() {
        // the room at night: a dark wall at the top, the floor far below in the gaps
        let bg = SKSpriteNode(texture: Glow.vertical(top: UIColor(hex: 0x232B4F), bottom: UIColor(hex: 0x0D1126)))
        bg.anchorPoint = .zero; bg.size = size; bg.zPosition = -10
        world.addChild(bg)
        let floor = SKSpriteNode(color: UIColor(hex: 0x0A0D1E), size: CGSize(width: c * CGFloat(board.width) + c, height: c * K * CGFloat(board.height) + c))
        floor.anchorPoint = CGPoint(x: 0.5, y: 1)
        floor.position = CGPoint(x: size.width / 2, y: top + c * 0.3)
        floor.alpha = 0.5; floor.zPosition = -5
        world.addChild(floor)
    }

    private func buildBridge(_ i: Int) {
        let n = SKSpriteNode(texture: Art.texture("prop_bridge"))
        n.size = CGSize(width: c * 0.96, height: c * K * 0.96)
        n.position = point(i); n.zPosition = 12
        world.addChild(n); bridgeNodes[i] = n
    }

    // MARK: drawing a state

    private func spriteName(_ base: String, _ st: String) -> String { "\(base)_\(st)" }

    private func ottoName(_ st: String = "idle") -> String { "otto_\(st)_\(String(state.facing.letter))" }

    func render(animated: Bool, moved: Move? = nil, from old: GameState? = nil) {
        let lit = board.lit(state)
        let dur = animated && !reduceMotion ? 0.2 : 0
        // light
        updateLight(lit, animated: animated)
        // bridges: there only in the dark (or while Mosto stands on one)
        for (i, n) in bridgeNodes {
            let on = lit & bit(i) == 0 || state.mosto == i
            let filled = state.filled & bit(i) != 0
            n.run(.fadeAlpha(to: filled ? 0 : on ? 1 : 0.08, duration: dur))
            if filled { showSunk(i) }
        }
        // blocks
        var have = blockNodes
        var used: [SKSpriteNode] = []
        for i in 0..<(board.width * board.height) where state.blocks & bit(i) != 0 {
            let n: SKSpriteNode
            if let o = old, o.blocks & bit(i) == 0, let m = moved {
                // the block that was pushed: find the node at the cell behind
                let from = i - m.dir.dx - m.dir.dy * board.width
                if let k = have.firstIndex(where: { $0.userData?["cell"] as? Int == from }) { n = have.remove(at: k) }
                else if let k = have.firstIndex(where: { state.blocks & bit(($0.userData?["cell"] as? Int) ?? -1) == 0 }) { n = have.remove(at: k) }
                else { n = newBlock(i) }
            } else if let k = have.firstIndex(where: { $0.userData?["cell"] as? Int == i }) {
                n = have.remove(at: k)
            } else if let k = have.firstIndex(where: { state.blocks & bit(($0.userData?["cell"] as? Int) ?? -1) == 0 }) {
                n = have.remove(at: k)
            } else { n = newBlock(i) }
            n.userData = ["cell": i]
            n.zPosition = z(i, 2)
            n.run(.move(to: point(i), duration: dur))
            n.alpha = 1
            used.append(n)
        }
        for n in have {
            // pushed into a gap: it drops and becomes floor
            if let cell = n.userData?["cell"] as? Int, let m = moved {
                let into = cell + m.dir.dx + m.dir.dy * board.width
                if into >= 0 && into < board.ground.count && state.filled & bit(into) != 0 {
                    n.zPosition = z(into, -1)
                    n.run(.sequence([.move(to: point(into), duration: dur), .group([.moveBy(x: 0, y: -c * 0.25, duration: dur), .fadeOut(withDuration: dur)]), .removeFromParent()]))
                    showSunk(into, after: dur * 2)
                    continue
                }
            }
            n.removeFromParent()
        }
        blockNodes = used
        for (i, n) in sunkNodes { n.isHidden = state.filled & bit(i) == 0 }
        // figures
        place(moss, at: state.moss, name: mossName(moved: moved, old: old), dur: dur, hop: moved?.actor == .moss)
        place(otto, at: state.otto, name: ottoName(), dur: dur, hop: false)
        if state.mosto >= 0 {
            mosto.isHidden = false
            let seen = lit & bit(state.mosto) != 0
            var name = seen ? "mosto_seen" : "mosto_idle"
            if !seen, let o = old, o.mosto != state.mosto, o.mosto >= 0 {
                name = board.x(state.mosto) < board.x(o.mosto) ? "mosto_left" : board.x(state.mosto) > board.x(o.mosto) ? "mosto_right" : "mosto_idle"
            }
            place(mosto, at: state.mosto, name: name, dur: dur, hop: old.map { $0.mosto != state.mosto } ?? false)
        } else if board.mode != .none, !mosto.isHidden, old?.mosto ?? -1 >= 0 {
            // caught
            mosto.texture = Art.texture("mosto_found")
        } else if board.mode == .none {
            mosto.isHidden = true
        }
        tint(lit, dur: dur)
        updateSelection()
        positionHalo()
    }

    private func mossName(moved: Move?, old: GameState?) -> String {
        guard let m = moved, m.actor == .moss, old?.moss != state.moss else { return "moss_idle" }
        switch m.dir { case .e: return "moss_right"; case .w: return "moss_left"; case .n: return "moss_up"; case .s: return "moss_down" }
    }

    private func newBlock(_ i: Int) -> SKSpriteNode {
        let n = prop("prop_block", at: i)
        world.addChild(n)
        return n
    }

    private func showSunk(_ i: Int, after: TimeInterval = 0) {
        if sunkNodes[i] == nil {
            let n = SKSpriteNode(texture: Art.texture("prop_blockTop"))
            n.size = CGSize(width: c * 0.98, height: c * K * 0.98)
            n.position = point(i); n.zPosition = 12
            world.addChild(n); sunkNodes[i] = n
            n.alpha = 0
        }
        sunkNodes[i]!.isHidden = false
        sunkNodes[i]!.run(.sequence([.wait(forDuration: after), .fadeIn(withDuration: 0.12)]))
    }

    private func place(_ n: SKSpriteNode, at i: Int, name: String, dur: TimeInterval, hop: Bool) {
        n.texture = Art.texture(name)
        n.zPosition = z(i, 5)
        let p = point(i)
        if dur == 0 || n.position == p { n.position = p; return }
        n.removeAction(forKey: "move")
        let up = SKAction.moveBy(x: 0, y: c * 0.18, duration: dur / 2); up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -c * 0.18, duration: dur / 2); down.timingMode = .easeIn
        let slide = SKAction.move(to: p, duration: dur); slide.timingMode = .easeInEaseOut
        n.run(hop ? .group([slide, .sequence([up, down])]) : slide, withKey: "move")
    }

    /// Lit figures and things take the lamp's warmth; those in the dark take the moon's blue.
    private func tint(_ lit: UInt64, dur: TimeInterval) {
        func apply(_ n: SKSpriteNode, _ i: Int, base: CGFloat = 0.5) {
            let on = lit & bit(i) != 0
            n.run(.colorize(with: on ? UIColor(hex: 0xFFE2B0) : BoardScene.moon, colorBlendFactor: on ? 0.12 : base, duration: dur))
        }
        apply(moss, state.moss)
        apply(otto, state.otto, base: 0.3)
        if state.mosto >= 0 { apply(mosto, state.mosto, base: 0.35) }
        for (i, n) in tallNodes { apply(n, i, base: 0.6) }
        for n in blockNodes { if let i = n.userData?["cell"] as? Int { apply(n, i, base: 0.6) } }
        for n in goalNodes {
            let i = n.name == "bead" ? board.bead : board.crown
            apply(n, i, base: 0.25)
        }
    }

    private func updateLight(_ lit: UInt64, animated: Bool) {
        let images = Glow.lightMaps(board: board, lit: lit, otto: state.otto, facing: state.facing, cell: c, k: K, left: left, top: top, size: size)
        darkOld.texture = dark.texture; darkOld.size = size; darkOld.alpha = animated && !reduceMotion ? 1 : 0
        dark.texture = SKTexture(image: images.dark); dark.size = size
        warm.texture = SKTexture(image: images.warm); warm.size = size
        if animated && !reduceMotion {
            dark.alpha = 0; warm.alpha = 0
            dark.run(.fadeIn(withDuration: 0.22)); warm.run(.fadeIn(withDuration: 0.22)); darkOld.run(.fadeOut(withDuration: 0.22))
        } else { dark.alpha = 1; warm.alpha = 1 }
    }

    private func positionHalo() {
        let name = ottoName()
        let b = Art.bead(name) ?? CGPoint(x: 0.4, y: 0.3)
        let s = otto.size
        let p = CGPoint(x: otto.position.x + (b.x - Art.frame.feetX) * s.width, y: otto.position.y + (Art.frame.feetY - b.y) * s.height)
        halo.removeAction(forKey: "move")
        halo.run(.move(to: p, duration: reduceMotion ? 0 : 0.2), withKey: "move")
        halo.size = CGSize(width: c * 1.1, height: c * 1.1)
        halo.color = BoardScene.lamp; halo.colorBlendFactor = 1; halo.alpha = 0.9
        halo.zPosition = otto.zPosition + 1
    }

    private func updateSelection() {
        let i = selected == .moss ? state.moss : state.otto
        selection.position = point(i)
        selection.zPosition = z(i, 1)
        selection.isHidden = finished
    }

    // MARK: life

    private func startIdle() {
        guard !reduceMotion else { return }
        // breathing: Moss quick (2.6 s), Otto slow (3.8 s), Mosto in between
        for (n, period, amp) in [(moss, 2.6, 0.025), (otto, 3.8, 0.018), (mosto, 3.1, 0.022)] {
            let a = SKAction.customAction(withDuration: period) { node, t in
                let k = (1 - cos(Double(t) / period * 2 * .pi)) / 2
                (node as? SKSpriteNode)?.yScale = 1 + CGFloat(k * amp)
                (node as? SKSpriteNode)?.xScale = 1 - CGFloat(k * amp * 0.5)
            }
            n.run(.repeatForever(a), withKey: "breathe")
        }
        blinkLoop(moss, every: 3...6, name: { [weak self] in self?.moss.texture == Art.texture("moss_idle") ? "moss_blink" : nil }, back: "moss_idle")
        blinkLoop(otto, every: 4...8, name: { [weak self] in self.map { $0.otto.texture == Art.texture($0.ottoName()) ? $0.ottoName(Int.random(in: 0..<5) == 0 ? "yawn" : "blink") : nil } ?? nil },
                  back: nil, long: true)
        blinkLoop(mosto, every: 5...9, name: { [weak self] in self?.mosto.texture == Art.texture("mosto_idle") ? "mosto_blink" : nil }, back: "mosto_idle")
        // the lamp's own slow pulse
        halo.run(.repeatForever(.sequence([.fadeAlpha(to: 0.75, duration: 1.6), .fadeAlpha(to: 0.95, duration: 1.6)])), withKey: "pulse")
    }

    private func blinkLoop(_ n: SKSpriteNode, every: ClosedRange<Double>, name: @escaping () -> String?, back: String?, long: Bool = false) {
        let act = SKAction.sequence([
            .wait(forDuration: Double.random(in: every)),
            .run { [weak self, weak n] in
                guard let self, let n, !self.busy, let nm = name() else { return }
                let before = n.texture
                n.texture = Art.texture(nm)
                let hold = nm.contains("yawn") ? 1.7 : long ? 0.18 : 0.11
                n.run(.sequence([.wait(forDuration: hold), .run { if n.texture == Art.texture(nm) { n.texture = before } }]))
            },
        ])
        n.run(.repeatForever(act), withKey: "blink")
    }

    // MARK: input

    private var touchStart: CGPoint?
    private var touchActor: Actor?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        touchStart = p
        touchActor = actor(at: p)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let s = touchStart else { return }
        let p = t.location(in: self)
        let dx = p.x - s.x, dy = p.y - s.y
        let dist = hypot(dx, dy)
        defer { touchStart = nil; touchActor = nil }
        if dist < 14 {
            // a tap on a companion chooses who moves next
            if let a = touchActor, a != selected { selected = a; tap.impactOccurred(intensity: 0.5) }
            return
        }
        // screen directions: up the screen is north (away from the viewer)
        let d: Dir = abs(dx) > abs(dy) ? (dx > 0 ? .e : .w) : (dy > 0 ? .n : .s)
        let who = touchActor ?? selected
        if who != selected { selected = who }
        perform(Move(actor: who, dir: d))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchStart = nil; touchActor = nil }

    private func actor(at p: CGPoint) -> Actor? {
        func hit(_ n: SKSpriteNode, _ i: Int) -> Bool {
            let q = point(i)
            return abs(p.x - q.x) < c * 0.55 && p.y > q.y - c * 0.35 && p.y < q.y + c * 1.0
        }
        if hit(otto, state.otto) { return .otto }
        if hit(moss, state.moss) { return .moss }
        return nil
    }

    // MARK: moves

    func perform(_ m: Move) {
        guard !busy, !finished else { return }
        hintNode.removeAllChildren()
        guard let n = board.step(state, m), n != state else {
            nudge(m)
            return
        }
        let old = state
        history.append(state); moves.append(m); state = n
        Progress.shared.saveMoves(info.id, moves.map { $0.description })
        tap.impactOccurred()
        busy = true
        render(animated: true, moved: m, from: old)
        let wait = reduceMotion ? 0.05 : 0.22
        run(.wait(forDuration: wait)) { [weak self] in
            guard let self else { return }
            self.busy = false
            if self.board.won(self.state) { self.win() }
            self.onChange?()
        }
        onChange?()
    }

    /// Nothing happens: the one who tried leans that way and back.
    private func nudge(_ m: Move) {
        bump.impactOccurred(intensity: 0.6)
        let n = m.actor == .moss ? moss : otto
        guard !reduceMotion else { return }
        let dx = CGFloat(m.dir.dx) * c * 0.08, dy = -CGFloat(m.dir.dy) * c * 0.08 * K
        n.run(.sequence([.moveBy(x: dx, y: dy, duration: 0.07), .moveBy(x: -dx, y: -dy, duration: 0.1)]))
    }

    func undo() {
        guard !busy, !finished, let prev = history.popLast() else { return }
        moves.removeLast()
        state = prev
        Progress.shared.saveMoves(info.id, moves.map { $0.description })
        mosto.isHidden = state.mosto < 0 && board.mode == .none
        render(animated: true)
        onChange?()
    }

    func restart() {
        guard !busy, !finished, !history.isEmpty else { return }
        state = board.start; history = []; moves = []
        Progress.shared.saveMoves(info.id, [])
        mosto.isHidden = board.mode == .none
        render(animated: true)
        onChange?()
    }

    /// The next move on a shortest line, shown without words: the one to move bounces, and a streak of lamplight
    /// points the way.
    func hint() {
        guard !busy, !finished else { return }
        let b = board, s = state
        DispatchQueue.global(qos: .userInitiated).async {
            let m = Solver.hint(b, from: s)
            DispatchQueue.main.async { [weak self] in
                guard let self, let m, self.state == s else { return }
                self.showHint(m)
            }
        }
    }

    private func showHint(_ m: Move) {
        hintNode.removeAllChildren()
        selected = m.actor
        let who = m.actor == .moss ? moss : otto
        let from = m.actor == .moss ? state.moss : state.otto
        let p = point(from)
        let target = CGPoint(x: p.x + CGFloat(m.dir.dx) * c * 0.7, y: p.y - CGFloat(m.dir.dy) * c * K * 0.7)
        let streak = SKSpriteNode(texture: Glow.radial)
        streak.size = CGSize(width: c * 0.7, height: c * 0.7 * K)
        streak.color = BoardScene.lamp; streak.colorBlendFactor = 1; streak.blendMode = .add
        streak.position = p; streak.zPosition = 950; streak.alpha = 0
        hintNode.addChild(streak)
        let go = SKAction.sequence([.group([.fadeIn(withDuration: 0.15), .move(to: target, duration: 0.6)]), .fadeOut(withDuration: 0.3), .move(to: p, duration: 0)])
        streak.run(.repeat(go, count: 3)) { [weak self] in self?.hintNode.removeAllChildren() }
        if m.actor == .otto && m.dir != state.facing {
            // a turn: the bead glances that way
            halo.run(.sequence([.moveBy(x: CGFloat(m.dir.dx) * c * 0.15, y: -CGFloat(m.dir.dy) * c * 0.15, duration: 0.2), .moveBy(x: -CGFloat(m.dir.dx) * c * 0.15, y: CGFloat(m.dir.dy) * c * 0.15, duration: 0.3)]))
        }
        if !reduceMotion {
            who.run(.sequence([.moveBy(x: 0, y: c * 0.12, duration: 0.12), .moveBy(x: 0, y: -c * 0.12, duration: 0.16)]))
        }
    }

    // MARK: winning

    private func win() {
        finished = true
        updateSelection()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        moss.texture = Art.texture("moss_glee")
        otto.texture = Art.texture(ottoName("glee"))
        if info.id < 1000 { Progress.shared.finish(info.id, moves: moves.count) }
        Progress.shared.saveMoves(info.id, [])
        let count = moves.count
        var seq: [SKAction] = []
        if board.mode == .shadow {
            // caught in the light: Mosto opens his eyes, lets go of the bead, and slips back into the dark
            mosto.isHidden = false
            mosto.texture = Art.texture("mosto_found")
            mosto.removeAction(forKey: "move")
            mosto.position = CGPoint(x: point(state.moss).x + c * 0.45, y: point(state.moss).y)
            let away = CGPoint(x: mosto.position.x + c * 0.8, y: mosto.position.y)
            mosto.zPosition = moss.zPosition - 1
            let bead = prop("prop_bead", at: state.moss)
            bead.setScale(0.6); bead.alpha = 0
            world.addChild(bead)
            seq = [.wait(forDuration: 0.5),
                   .run { bead.run(.group([.fadeIn(withDuration: 0.2), .moveBy(x: 0, y: self.c * 0.5, duration: 0.6)])) },
                   .run { [weak self] in self?.mosto.run(.group([.move(to: away, duration: 0.6), .fadeOut(withDuration: 0.6)])) },
                   .wait(forDuration: 0.9)]
        } else {
            let goal = goalNodes.first { $0.name == "bead" }
            seq = [.wait(forDuration: 0.25),
                   .run { goal?.removeAllActions(); goal?.run(.group([.moveBy(x: 0, y: self.c * 0.9, duration: 0.7), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.3)])])) },
                   .wait(forDuration: 0.8)]
            if board.mode == .pair { mosto.texture = Art.texture("mosto_found") }
        }
        if !reduceMotion {
            moss.run(.sequence([.moveBy(x: 0, y: c * 0.25, duration: 0.16), .moveBy(x: 0, y: -c * 0.25, duration: 0.2)]))
        }
        run(.sequence(seq)) { [weak self] in self?.onWin?(count) }
    }
}
