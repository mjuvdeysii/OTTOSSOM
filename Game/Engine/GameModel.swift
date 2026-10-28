import SwiftUI

struct Actor {
    var kind: String
    var x: Double
    var y: Double
    var alpha: Double = 1
    var carry = false
}

struct Dialog: Identifiable, Equatable {
    let id = UUID()
    var who: String
    var text: String
    var options: [String]
}

struct CardInfo: Equatable {
    var title: String
    var sub: String
}

/// One chapter being played: the room, its state, the story scripts and the player's taps.
@MainActor
final class GameModel: ObservableObject {
    let chapter: Chapter
    @Published var stepIndex: Int
    @Published var room: Room
    @Published var state: GameState
    @Published var prev: GameState?
    @Published var animStart = Date()
    var animDur: Double = 0.15
    @Published var hist: [GameState] = []
    @Published var active = 0
    @Published var face: [Int] = [1, 1, 1]
    @Published var actors: [String: Actor] = [:]
    @Published var mainDim = false
    @Published var dark: Double = 0
    @Published var hideHeroes = false
    @Published var bulbR: Double = 3
    @Published var hint = ""
    @Published var dialog: Dialog?
    @Published var card: CardInfo?
    @Published var busy = false
    @Published var finished = false
    @Published var walking = false
    private var dialogCont: CheckedContinuation<Int, Never>?
    private var started = false

    static let names: [String: String] = ["h": "老韩", "d": "豆豆", "n": "林嫂", "o": "Otto", "m": "Moss", "x": "Mosto", "": ""]

    init(chapter: Chapter) {
        self.chapter = chapter
        let i = min(Progress.shared.step(chapter.id), max(0, chapter.steps.count - 1))
        stepIndex = i
        let id = chapter.steps[i].room ?? chapter.steps.first(where: { $0.room != nil })?.room ?? "top"
        let r = Room(Content.rooms[id]!)
        room = r
        state = r.start
        bulbR = Double(r.rOtto)
    }

    var isPreview = false
    static func preview(chapter: Chapter, room: String) -> GameModel {
        let m = GameModel(chapter: chapter)
        m.isPreview = true
        m.load(room)
        m.state.bulb = m.room.heroes.contains(.otto)
        return m
    }

    func begin() {
        guard !started, !isPreview else { return }
        started = true
        Task { await enterStep() }
    }

    // MARK: flow
    func load(_ id: String) {
        guard let spec = Content.rooms[id] else { return }
        let r = Room(spec)
        room = r; state = r.start; prev = nil; hist = []; active = 0; actors = [:]
        dark = 0; bulbR = Double(r.rOtto); hint = ""; hideHeroes = false
        mainDim = (id == "top" && chapter.id == 1 && stepIndex > 4)
        Sound.shared.hum(state.bulb)
    }

    private func enterStep() async {
        guard stepIndex < chapter.steps.count else { finish(); return }
        let st = chapter.steps[stepIndex]
        busy = true
        if let cut = st.cut {
            load(st.room ?? "top")
            await run(cut)
            advance()
            await enterStep()
            return
        }
        load(st.room ?? "top")
        if let i = st.intro { await run(i) }
        busy = false
    }

    private func advance() {
        stepIndex += 1
        Progress.shared.setStep(chapter.id, stepIndex < chapter.steps.count ? stepIndex : 0)
    }

    private func roomCleared() async {
        busy = true
        Sound.shared.win(); Haptic.success()
        try? await Task.sleep(for: .milliseconds(350))
        if let o = chapter.steps[stepIndex].outro { await run(o) }
        advance()
        await enterStep()
    }

    private func finish() {
        var d = Progress.shared.done; d.insert(chapter.id); Progress.shared.done = d
        Progress.shared.setStep(chapter.id, 0)
        Sound.shared.hum(false)
        busy = true
        finished = true
    }

    // MARK: story scripts
    func run(_ name: String) async {
        guard let cmds = Content.story[name] else { return }
        await run(cmds)
    }

    private func branch(_ c: [String: Any], _ yes: Bool) -> [[String: Any]] {
        ((yes ? c["then"] : c["else"]) as? [[String: Any]]) ?? []
    }

    func run(_ cmds: [[String: Any]]) async {
        for c in cmds {
            if let t = c["card"] as? String {
                await showCard(t, c["sub"] as? String ?? "")
            } else if let opts = c["options"] as? [String] {
                let i = await present(who: "", text: c["ask"] as? String ?? "", options: opts)
                if let f = c["set"] as? String {
                    var fl = Progress.shared.flags
                    if i == 0 { fl.insert(f) } else { fl.remove(f) }
                    Progress.shared.flags = fl
                }
            } else if let who = c["say"] as? String {
                _ = await present(who: who, text: c["text"] as? String ?? "", options: [])
            } else if let h = c["hint"] as? String {
                hint = h
            } else if let ms = c["wait"] as? Int {
                try? await Task.sleep(for: .milliseconds(ms))
            } else if let k = c["actor"] as? String, let at = c["at"] as? [Int], at.count == 2 {
                actors[k] = Actor(kind: k, x: Double(at[0]), y: Double(at[1]))
            } else if let k = c["walk"] as? String, let path = c["path"] as? [[Int]] {
                await walkActor(k, path, c["ms"] as? Int ?? 400)
            } else if let k = c["remove"] as? String {
                actors[k] = nil
            } else if c["mainDim"] != nil {
                mainDim = true; Sound.shared.dim(); Haptic.warn()
                try? await Task.sleep(for: .milliseconds(300))
            } else if c["lampsAll"] != nil {
                state.lit = state.lit.map { _ in true }
            } else if let i = c["lamp"] as? Int {
                if i < state.lit.count { state.lit[i] = (c["lit"] as? Bool) ?? false; Sound.shared.dim() }
            } else if let k = c["carry"] as? String {
                actors[k]?.carry = true
            } else if c["hideHeroes"] != nil {
                hideHeroes = true
            } else if let d = c["dark"] as? Double {
                dark = d
            } else if let f = c["if"] as? String {
                await run(branch(c, Progress.shared.flags.contains(f)))
            } else if c["ifLamps"] != nil {
                await run(branch(c, room.lampsOK(state)))
            } else if c["ifKey"] != nil {
                await run(branch(c, room.keyGiven))
            } else if c["key"] != nil {
                room.keyGiven = true; objectWillChange.send(); Sound.shared.light(); Haptic.success()
            } else if c["fade"] != nil {
                await fadeOut()
            }
        }
    }

    func present(who: String, text: String, options: [String]) async -> Int {
        Sound.shared.talk()
        return await withCheckedContinuation { cont in
            dialogCont = cont
            dialog = Dialog(who: GameModel.names[who] ?? who, text: text, options: options)
        }
    }

    func answer(_ i: Int) {
        guard let c = dialogCont else { return }
        dialogCont = nil
        dialog = nil
        c.resume(returning: i)
    }

    private func showCard(_ t: String, _ s: String) async {
        card = CardInfo(title: t, sub: s)
        try? await Task.sleep(for: .milliseconds(2300))
        card = nil
        try? await Task.sleep(for: .milliseconds(450))
    }

    private func walkActor(_ k: String, _ path: [[Int]], _ ms: Int) async {
        for p in path where p.count == 2 {
            guard let a = actors[k] else { return }
            let fx = a.x, fy = a.y, tx = Double(p[0]), ty = Double(p[1])
            let n = max(1, ms / 16)
            for i in 1...n {
                let t = Double(i) / Double(n)
                actors[k]?.x = fx + (tx - fx) * t
                actors[k]?.y = fy + (ty - fy) * t
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func fadeOut() async {
        for _ in 0..<12 {
            bulbR = max(0, bulbR - 0.25); dark = min(1, dark + 0.06)
            try? await Task.sleep(for: .milliseconds(140))
        }
        state.bulb = false
        Sound.shared.hum(false)
    }

    // MARK: play
    var canPlay: Bool { dialog == nil && !busy && card == nil }
    var hero: Hero { room.heroes[active] }

    @discardableResult
    func apply(_ v: Verb) -> Bool {
        var ev: [Event] = []
        guard let n = room.step(state, active, v, &ev) else { return false }
        hist.append(state)
        prev = state
        state = n
        animStart = Date()
        animDur = v.delta == nil ? 0.22 : 0.15
        if v == .left { face[active] = -1 }
        if v == .right { face[active] = 1 }
        if v.delta != nil { Sound.shared.step() }
        for e in ev {
            switch e {
            case .light, .give: Sound.shared.light(); Haptic.light()
            case .dim: Sound.shared.dim(); Haptic.warn(); hint = "两个影子挤在灯边，灯被压暗了。可以撤回。"
            case .take: Sound.shared.take(); Haptic.light()
            case .push: Sound.shared.push(); Haptic.light()
            case .bulb(let on): Sound.shared.hum(on)
            case .drift: break
            }
        }
        if room.spec.id == "outside" {
            bulbR = max(1, 3 - Double(state.steps) * 0.28)
            dark = min(0.9, 0.35 + Double(state.steps) * 0.07)
        }
        if room.won(state) { Task { await roomCleared() } }
        return true
    }

    func undo() {
        guard canPlay, let last = hist.popLast() else { return }
        prev = nil; state = last; hint = ""
        Sound.shared.hum(state.bulb)
    }

    func reset() {
        guard canPlay, !hist.isEmpty else { return }
        prev = nil; state = room.start; hist = []; hint = "重来了。"
        bulbR = Double(room.rOtto)
        if room.spec.id == "outside" { dark = 0.35 }
        Sound.shared.hum(state.bulb)
    }

    func select(_ i: Int) {
        guard i < room.heroes.count else { return }
        active = i
        Haptic.light()
    }

    // contextual action
    private func adjacent(_ p: Pt) -> Bool { state.c[active].dist(p) == 1 }
    var adjacentNPC: (Pt, Character)? { room.npcs.first { adjacent($0.key) }.map { ($0.key, $0.value) } }
    var adjacentTablet: Pt? { room.tablets.first { adjacent($0) } }

    var actionLabel: String? {
        switch hero {
        case .otto:
            if room.lampPos.indices.contains(where: { !state.lit[$0] && !room.nest[$0] && adjacent(room.lampPos[$0]) }) { return "点灯" }
        case .moss:
            if adjacentTablet != nil { return "摸" }
        case .mosto:
            if state.carry, room.lampPos.indices.contains(where: { !state.lit[$0] && adjacent(room.lampPos[$0]) }) { return "放光" }
            if !state.carry, room.lampPos.indices.contains(where: { state.lit[$0] && adjacent(room.lampPos[$0]) }) { return "抓光" }
        }
        if adjacentNPC != nil { return "说话" }
        return nil
    }

    func interact() {
        guard canPlay else { return }
        switch actionLabel {
        case "点灯": if !apply(.light) { lampRefused() }
        case "抓光": _ = apply(.take)
        case "放光": if !apply(.give) { lampRefused() }
        case "摸": if let t = adjacentTablet { touch(t) }
        case "说话": if let n = adjacentNPC { talk(n.1) }
        default: Sound.shared.no()
        }
    }

    private func lampRefused() {
        Sound.shared.no()
        if room.crowdedLampNear(state, active) { hint = "灯边上挨着影子，点不着。先把影子引开。" }
    }

    func talk(_ c: Character) {
        let name = "talk:\(room.spec.id):\(c)"
        guard Content.story[name] != nil else { return }
        busy = true
        Task { await run(name); busy = false }
    }

    func touch(_ p: Pt) {
        guard hero == .moss else { hint = "只有 Moss 读得出石头记得的事。"; return }
        let name = "touch:\(room.spec.id):\(p.x),\(p.y)"
        busy = true
        Sound.shared.touch()
        Task {
            if Content.story[name] != nil { await run(name) } else { _ = await present(who: "", text: "什么也没记住。", options: []) }
            busy = false
        }
    }

    private func exitRefused() {
        Sound.shared.no()
        if !room.lampsOK(state) {
            switch room.goal {
            case "nests": hint = "窝里还没放进光。"
            case "carry": hint = "手里还没有光。"
            default: hint = "灯还没全点亮。"
            }
        } else if room.needKey && !room.keyGiven {
            hint = room.spec.id == "gate" ? "城门钥匙还在 Otto 手里。去找老韩。" : "还有东西没看。"
        }
    }

    /// A tap on the board, in tile coordinates.
    func tap(_ p: Pt) {
        guard canPlay, !walking else { return }
        if let i = state.c.firstIndex(of: p), room.heroes.count > 1 { select(i); return }
        let t = room.tile(p)
        if adjacent(p) {
            if t == .npc, let c = room.npcs[p] { talk(c); return }
            if t == .tablet { touch(p); return }
            if t == .lamp { interact(); return }
            if let d = Verb.moves.first(where: { state.c[active] + $0.delta! == p }) {
                if !apply(d) {
                    if t == .exit { exitRefused() } else { Sound.shared.no() }
                }
                return
            }
        }
        if t == .npc || t == .tablet || t == .lamp {
            // walk next to it
            let around = Verb.moves.map { p + $0.delta! }.filter { room.canEnter(state, active, $0) }
            if let best = around.compactMap({ path(to: $0) }).min(by: { $0.count < $1.count }) { walk(best) }
            return
        }
        if let pth = path(to: p) { walk(pth) } else { Sound.shared.no() }
    }

    private func path(to target: Pt) -> [Verb]? {
        let start = state.c[active]
        if start == target { return [] }
        var seen: Set<Pt> = [start]
        var queue: [(Pt, [Verb])] = [(start, [])]
        var head = 0
        while head < queue.count {
            let (p, pth) = queue[head]; head += 1
            for v in Verb.moves {
                let n = p + v.delta!
                if seen.contains(n) { continue }
                seen.insert(n)
                var probe = state; probe.c[active] = p
                guard room.canEnter(probe, active, n) || (n == target && room.tile(n) == .exit) else { continue }
                if n == target { return pth + [v] }
                queue.append((n, pth + [v]))
            }
        }
        return nil
    }

    private func walk(_ verbs: [Verb]) {
        walking = true
        Task {
            for (i, v) in verbs.enumerated() {
                guard canPlay else { break }
                if !apply(v) {
                    let n = state.c[active] + v.delta!
                    if i == verbs.count - 1 && room.tile(n) == .exit { exitRefused() } else { Sound.shared.no() }
                    break
                }
                try? await Task.sleep(for: .milliseconds(Int(animDur * 1000) + 15))
            }
            walking = false
        }
    }

}
