import SwiftUI

/// A held body pose or a little piece of acting (a stomp, a spin, a squash) on someone, for a while.
struct Pose {
    var state: String?      // sprite state to show instead of the idle one ("yawn", "sleep", "mine", "lit"…)
    var fx: String?         // flat, tall, wag, stomp, shake, spin, shrink, slump, nod
    var at = Date()
    var dur: Double = 1
}

/// A mote of the sun's fire flying from one cell to another (a light stolen, a light given back).
struct Fly {
    var from: CGPoint
    var to: CGPoint
    var at = Date()
    var dur: Double
}

/// One beat of a room's lesson: what to do (an icon and a few words), where (a cell or a button), and the condition that
/// moves the lesson on.
struct CoachStep: Equatable {
    var icon: String
    var text: String
    var cell: Pt?
    var button: String?     // "bulb", "act", "hero0", "hero1", "undo"
    var until: String
}

struct Figure {
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

struct ClearInfo: Equatable { var steps: Int; var par: Int }
struct HintMark: Equatable { var hero: Int; var verb: Verb; var target: Pt? }
struct TapMark: Equatable { var p: Pt; var at: Date }
/// A feeling shown over someone's head, in a picture instead of words.
struct Emote: Equatable { var icon: String; var at: Date }

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
    @Published var actors: [String: Figure] = [:]
    @Published var mainDim = false
    @Published var dark: Double = 0
    @Published var hideHeroes = false
    @Published var bulbR: Double = 3
    /// A passing remark in the coach line (why that didn't work, a hint); clears itself after a few seconds.
    @Published var hint = "" {
        didSet {
            let h = hint
            guard !h.isEmpty else { return }
            Task { try? await Task.sleep(for: .milliseconds(4200)); if self.hint == h { self.hint = "" } }
        }
    }
    @Published var coach: CoachStep?
    private var lesson: [CoachStep] = []
    private var lessonAt = 0
    private var lessonBase = 0
    @Published var dialog: Dialog?
    @Published var card: CardInfo?
    @Published var busy = false
    @Published var finished = false
    @Published var walking = false
    @Published var banner: String?
    @Published var cleared: ClearInfo?
    @Published var hintMark: HintMark?
    @Published var pathDots: [Pt] = []
    @Published var tapMark: TapMark?
    @Published var hintsUsed = 0
    @Published var emotes: [String: Emote] = [:]
    @Published var vision: String?
    @Published var poses: [String: Pose] = [:]
    @Published var flies: [Fly] = []
    private var guided = false
    private var lastInput = Date()
    private var dialogCont: CheckedContinuation<Int, Never>?
    private var started = false

    static let names: [String: String] = ["h": "汉克", "d": "朵拉", "n": "琳恩", "o": "奥托", "m": "莫斯", "x": "莫斯托", "": ""]

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
    var previewScript: String?
    static func preview(chapter: Chapter, room: String, script: String? = nil) -> GameModel {
        let m = GameModel(chapter: chapter)
        m.isPreview = true
        m.previewScript = script
        m.load(room)
        m.state.bulb = m.room.heroes.contains(.otto)
        return m
    }

    func begin() {
        if isPreview, !started, previewScript == nil {
            started = true
            startLesson()
            return
        }
        if isPreview, !started, let sc = previewScript {
            started = true
            Task { busy = true; await run(sc) }
            return
        }
        guard !started, !isPreview else { return }
        started = true
        Sound.shared.music(chapter.id)
        Task { await enterStep() }
    }

    // MARK: flow
    func load(_ id: String) {
        guard let spec = Content.rooms[id] else { return }
        let r = Room(spec)
        room = r; state = r.start; prev = nil; hist = []; active = 0; actors = [:]
        hintMark = nil; pathDots = []; cleared = nil
        dark = 0; bulbR = Double(r.rOtto); hint = ""; hideHeroes = false; emotes = [:]; guided = false
        poses = [:]; flies = []; coach = nil; lesson = []; lessonAt = 0
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
        startLesson()
    }

    private func showBanner(_ text: String) {
        banner = text
        Task {
            try? await Task.sleep(for: .milliseconds(1800))
            if banner == text { banner = nil }
        }
    }

    private func advance() {
        stepIndex += 1
        Progress.shared.setStep(chapter.id, stepIndex < chapter.steps.count ? stepIndex : 0)
    }

    private func roomCleared() async {
        busy = true
        var fl = Progress.shared.flags; fl.insert("taught:\(room.spec.id)"); Progress.shared.flags = fl
        Sound.shared.win(); Haptic.success()
        hintMark = nil; pathDots = []
        cleared = ClearInfo(steps: state.steps, par: room.spec.par ?? state.steps)
        try? await Task.sleep(for: .milliseconds(1700))
        cleared = nil
        try? await Task.sleep(for: .milliseconds(250))
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
                actors[k] = Figure(kind: k, x: Double(at[0]), y: Double(at[1]), carry: c["carry"] as? Bool ?? false)
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
                room.keyGiven = true; objectWillChange.send(); Sound.shared.light(); Haptic.success(); checkLesson()
            } else if c["fade"] != nil {
                await fadeOut()
            } else if let who = c["emote"] as? String, let icon = c["icon"] as? String {
                emotes[who] = Emote(icon: icon, at: Date())
                Sound.shared.talk()
                try? await Task.sleep(for: .milliseconds(c["ms"] as? Int ?? 1000))
                emotes[who] = nil
                try? await Task.sleep(for: .milliseconds(120))
            } else if let v = c["vision"] as? String {
                if Art.uiImage(v, ext: "jpg") != nil {
                    vision = v
                    Sound.shared.touch()
                    try? await Task.sleep(for: .milliseconds(c["ms"] as? Int ?? 3000))
                    vision = nil
                    try? await Task.sleep(for: .milliseconds(500))
                }
            } else if let who = c["pose"] as? String {
                let ms = c["ms"] as? Int ?? 900
                if c["clear"] != nil { poses[who] = nil; continue }
                poses[who] = Pose(state: c["as"] as? String, fx: c["fx"] as? String, at: Date(), dur: Double(c["dur"] as? Int ?? ms) / 1000)
                try? await Task.sleep(for: .milliseconds(ms))
                if c["hold"] == nil { poses[who] = nil }
            } else if let pts = c["fly"] as? [Any], pts.count == 2, let p0 = spot(pts[0]), let p1 = spot(pts[1]) {
                let ms = c["ms"] as? Int ?? 800
                let f = Fly(from: p0, to: p1, dur: Double(ms) / 1000)
                flies.append(f); Sound.shared.touch()
                try? await Task.sleep(for: .milliseconds(ms))
                flies.removeAll { $0.at == f.at }
            } else if let f = c["unset"] as? String {
                var fl = Progress.shared.flags; fl.remove(f); Progress.shared.flags = fl
            } else if c["guide"] != nil {
                guide()
            } else if let f = c["set"] as? String {
                var fl = Progress.shared.flags; fl.insert(f); Progress.shared.flags = fl
            }
        }
    }

    /// A place on the board for a script: [x, y], or someone by name — a hero's letter, a story actor, a townsperson's letter.
    private func spot(_ v: Any) -> CGPoint? {
        if let a = v as? [Double], a.count == 2 { return CGPoint(x: a[0], y: a[1]) }
        if let a = v as? [Int], a.count == 2 { return CGPoint(x: a[0], y: a[1]) }
        guard let who = v as? String else { return nil }
        let heroKey: [String: Hero] = ["o": .otto, "m": .moss]
        if who == "x", let t = state.thief { return CGPoint(x: t.x, y: t.y) }
        if who == "x", let i = room.index(of: .mosto), i < state.c.count { return CGPoint(x: state.c[i].x, y: state.c[i].y) }
        if let h = heroKey[who], let i = room.index(of: h), i < state.c.count { return CGPoint(x: state.c[i].x, y: state.c[i].y) }
        if let a = actors[who] { return CGPoint(x: a.x, y: a.y) }
        if who.count == 1, let c = who.first, let p = room.npcs.first(where: { $0.value == c })?.key { return CGPoint(x: p.x, y: p.y) }
        return nil
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

    /// Early rooms teach by showing, not telling: when the player hasn't moved for a while, the next move glows.
    private func guide() {
        guided = true
        lastInput = Date()
        let roomID = room.spec.id
        Task {
            while guided && room.spec.id == roomID && !finished {
                try? await Task.sleep(for: .milliseconds(500))
                if canPlay && !walking && hintMark == nil && coach == nil && Date().timeIntervalSince(lastInput) > 6 {
                    requestHint(); lastInput = Date()
                }
            }
        }
    }
    func touched() { lastInput = Date() }

    // MARK: lessons

    /// A room's lesson ("teach:<room>" in story.json) runs the first time the room is played: one beat at a time, each
    /// pointing at the cell or button to use, moving on by itself once the player has done it.
    func startLesson() {
        let id = room.spec.id
        guard let raw = Content.story["teach:\(id)"], isPreview || !Progress.shared.flags.contains("taught:\(id)") else { coach = nil; return }
        lesson = raw.compactMap { d in
            guard let icon = d["icon"] as? String, let text = d["text"] as? String else { return nil }
            let cell = (d["cell"] as? [Int]).flatMap { $0.count == 2 ? Pt($0[0], $0[1]) : nil }
            return CoachStep(icon: icon, text: text, cell: cell, button: d["button"] as? String, until: d["until"] as? String ?? "won")
        }
        lessonAt = 0; lessonBase = state.steps
        coach = lesson.first
        checkLesson()
    }

    func checkLesson() {
        guard !lesson.isEmpty else { return }
        var moved = false
        while lessonAt < lesson.count && met(lesson[lessonAt].until) { lessonAt += 1; lessonBase = state.steps; moved = true }
        let next = lessonAt < lesson.count ? lesson[lessonAt] : nil
        if next != coach { coach = next }
        if moved { Haptic.light() }
    }

    private func met(_ c: String) -> Bool {
        let parts = c.split(separator: ":").map(String.init)
        let arg = parts.count > 1 ? parts[1] : ""
        let me = state.c[min(active, state.c.count - 1)]
        let litCount = state.lit.indices.filter { state.lit[$0] && !room.nest[$0] }.count
        switch parts[0] {
        case "moved": return state.steps > lessonBase
        case "at": let q = arg.split(separator: ",").compactMap { Int($0) }; return q.count == 2 && me == Pt(q[0], q[1])
        case "near": let q = arg.split(separator: ",").compactMap { Int($0) }; return q.count == 2 && me.dist(Pt(q[0], q[1])) == 1
        case "lit": return litCount >= (Int(arg) ?? 1)
        case "litAll": return room.lampsOK(state)
        case "bulb": return state.bulb == (arg != "off")
        case "carry": return state.carry == (arg != "off")
        case "drift": return state.shadows != room.start.shadows
        case "pushed": return state.boulders != room.start.boulders
        case "plates": return room.platesDown(state)
        case "key": return room.keyGiven
        case "exit": return room.exitOpen(state)
        case "select": return active == (Int(arg) ?? 0)
        case "thief": return state.thief != room.start.thief
        case "won": return room.won(state)
        default: return false
        }
    }

    // MARK: hints
    func verbText(_ v: Verb) -> String {
        switch v {
        case .up: return "往上走"
        case .down: return "往下走"
        case .left: return "往左走"
        case .right: return "往右走"
        case .bulb: return state.bulb ? "关上灯珠" : "打开灯珠"
        case .light: return "点灯"
        case .take: return "抓光"
        case .give: return "放光"
        }
    }
    func heroName(_ h: Hero) -> String { h == .otto ? "奥托" : h == .moss ? "莫斯" : "莫斯托" }

    func requestHint() {
        guard canPlay, !walking else { return }
        hintsUsed += 1
        if room.needKey && !room.keyGiven && room.lampsOK(state) {
            hint = room.spec.id == "gate" ? "灯都亮了。去找汉克，把城门钥匙交给他。" : "先去摸一摸石碑。"
            return
        }
        let spec = room.spec, st = state, key = room.keyGiven, atStart = hist.isEmpty
        hint = "想一想……"
        busy = true
        Task {
            let res = await Task.detached(priority: .userInitiated) { () -> Solver.Result? in
                let r = Room(spec); r.keyGiven = key || r.needKey
                return Solver.search(r, from: st, cap: 350_000)
            }.value
            busy = false
            var move: (Int, Verb)? = res?.path.first
            if move == nil, atStart, let first = spec.solution?.first {
                let parts = first.split(separator: ":")
                if parts.count == 2, let ci = Int(parts[0]), let v = Verb(rawValue: String(parts[1])) { move = (ci, v) }
            }
            guard let m = move else {
                hint = hist.isEmpty ? "这一间路太多，先自己试试。" : "从这里走不出去了。撤回几步，或者重来。"
                return
            }
            let ci = m.0, v = m.1
            if ci != active { active = ci }
            let target = v.delta.map { state.c[ci] + $0 }
            hintMark = HintMark(hero: ci, verb: v, target: target)
            let who: String = room.heroes.count > 1 ? heroName(room.heroes[ci]) : ""
            let left: Int = res?.path.count ?? (spec.par ?? 0)
            hint = "\(who)\(verbText(v))。还差 \(left) 步。"
            Haptic.light()
        }
    }

    // MARK: play
    var canPlay: Bool { dialog == nil && !busy && card == nil }
    var hero: Hero { room.heroes[active] }

    @discardableResult
    func apply(_ v: Verb) -> Bool {
        lastInput = Date()
        var ev: [Event] = []
        guard let n = room.step(state, active, v, &ev) else { return false }
        hintMark = nil
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
            case .dim: Sound.shared.dim(); Haptic.warn(); hint = "两个影子挤在灯边，灯暗了。可以撤回。"
            case .take: Sound.shared.take(); Haptic.light()
            case .push: Sound.shared.push(); Haptic.light()
            case .bulb(let on): Sound.shared.hum(on)
            case .steal: Sound.shared.dim(); Haptic.warn()
            case .thief, .drift: break
            }
        }
        if room.spec.id == "outside" {
            bulbR = max(1, 3 - Double(state.steps) * 0.28)
            dark = min(0.9, 0.35 + Double(state.steps) * 0.07)
        }
        checkLesson()
        if room.won(state) { coach = nil; Task { await roomCleared() } }
        return true
    }

    func undo() {
        lastInput = Date()
        guard canPlay, let last = hist.popLast() else { return }
        prev = nil; state = last; hint = ""
        Sound.shared.hum(state.bulb)
        checkLesson()
    }

    func reset() {
        lastInput = Date()
        guard canPlay, !hist.isEmpty else { return }
        prev = nil; state = room.start; hist = []; hint = ""
        bulbR = Double(room.rOtto)
        if room.spec.id == "outside" { dark = 0.35 }
        Sound.shared.hum(state.bulb)
    }

    func select(_ i: Int) {
        lastInput = Date()
        guard i < room.heroes.count else { return }
        active = i
        Haptic.light()
        checkLesson()
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
        if room.crowdedLampNear(state, active) { hint = "灯边挨着影子，点不着。先用灯珠把影子引开。" }
    }

    func talk(_ c: Character) {
        let name = "talk:\(room.spec.id):\(c)"
        guard Content.story[name] != nil else { return }
        busy = true
        Task { await run(name); busy = false; checkLesson() }
    }

    func touch(_ p: Pt) {
        guard hero == .moss else { hint = "只有莫斯读得出石头记得的事。"; return }
        let name = "touch:\(room.spec.id):\(p.x),\(p.y)"
        busy = true
        Sound.shared.touch()
        Task {
            if Content.story[name] != nil { await run(name) } else { _ = await present(who: "", text: "什么也没记住。", options: []) }
            busy = false
            checkLesson()
        }
    }

    private func exitRefused() {
        Sound.shared.no()
        if !room.lampsOK(state) {
            switch room.goal {
            case "nests": hint = "窝里还没放进光，出口不开。"
            case "carry": hint = "手里还没有光。先去抓一团。"
            default: hint = "灯还没全点亮，出口不开。"
            }
        } else if room.needKey && !room.keyGiven {
            hint = room.spec.id == "gate" ? "城门钥匙还在奥托手里。去找汉克。" : "先去摸一摸石碑。"
        }
    }

    /// A tap on the board, in tile coordinates.
    func tap(_ p: Pt) {
        lastInput = Date()
        guard canPlay, !walking else { return }
        tapMark = TapMark(p: p, at: Date())
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
        var dots: [Pt] = []; var p = state.c[active]
        for v in verbs { p = p + v.delta!; dots.append(p) }
        pathDots = dots
        Task {
            defer { pathDots = [] }
            for (i, v) in verbs.enumerated() {
                guard canPlay else { break }
                if !pathDots.isEmpty { pathDots.removeFirst() }
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
