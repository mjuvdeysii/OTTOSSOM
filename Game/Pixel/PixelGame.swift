import SwiftUI

// The game around the nights: the title, the lighthouse town between nights (talk, upgrades, the five nights),
// and one night with its HUD and its ending.

struct PixelSave: Codable {
    var stars: [Int: Int] = [:]          // night → best stars
    var motes = 0
    var upgrades: [String: Int] = [:]
    var seen: Set<String> = []

    static let key = "pixel.save.v1"
    static func load() -> PixelSave {
        guard let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(PixelSave.self, from: d) else { return PixelSave() }
        return s
    }
    func save() { if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: PixelSave.key) } }
    var unlocked: Int { (stars.filter { $0.value > 0 }.keys.max() ?? 0) + 1 }
}

struct Upgrade: Identifiable {
    let id: String, name: String, text: String, icon: String
    let costs: [Int]
    static let all: [Upgrade] = [
        Upgrade(id: "wick", name: "灯芯", text: "光更足，光丝更长", icon: "flame.fill", costs: [25, 60, 120]),
        Upgrade(id: "shade", name: "灯罩", text: "影子吸走的光更少", icon: "shield.fill", costs: [30, 70, 140]),
        Upgrade(id: "leaf", name: "叶子", text: "莫斯跑得更快", icon: "leaf.fill", costs: [20, 50, 100]),
        Upgrade(id: "glow", name: "余光", text: "轨迹留得更久，圈套得更大", icon: "sparkles", costs: [30, 70, 140]),
        Upgrade(id: "snore", name: "鼾声", text: "叫醒奥托的间隔更短", icon: "zzz", costs: [20, 50, 100]),
    ]
}

let pxGold = Color(0xffd36b), pxCream = Color(0xfff1c4), pxInk = Color(0x0b0a18), pxPanel = Color(0x1c1830), pxEdge = Color(0x6a5a9a)

/// A pixel panel: dark fill, a 1-pixel light edge, a 1-pixel dark outline, square corners cut by one pixel.
struct PixelPanel: ViewModifier {
    let pt: CGFloat
    var fill: Color = pxPanel
    func body(content: Self.Content) -> some View {
        content
            .background(fill)
            .overlay(Rectangle().strokeBorder(pxEdge, lineWidth: pt))
            .padding(pt)
            .background(pxInk)
    }
}

struct PixelButton: View {
    let title: String
    let k: Int
    var primary = true
    var action: () -> Void
    var body: some View {
        let pt = CGFloat(k) / UIScreen.main.scale
        Button(action: { Haptic.light(); action() }) {
            Text(title).font(PixelFont.font(1, k: k)).foregroundStyle(primary ? pxInk : pxCream)
                .padding(.horizontal, pt * 8).padding(.vertical, pt * 4)
                .frame(minWidth: pt * 70)
                .background(primary ? pxGold : pxPanel)
                .overlay(alignment: .bottom) { Rectangle().fill(primary ? Color(0xa86a18) : pxInk).frame(height: pt * 2) }
                .padding(pt).background(pxInk)
        }
        .buttonStyle(.plain)
    }
}

// MARK: the whole game

struct PixelGameView: View {
    @State private var save: PixelSave
    @State private var screen: Screen
    @State private var talk: [Say] = []
    @State private var afterTalk: (() -> Void)?
    @State private var shop = false
    private let probe: String?
    enum Screen: Equatable { case title, town, night(Int) }

    /// `probe` (CI screenshots only) opens one moment of the game with a made-up save.
    init(probe: String? = nil) {
        self.probe = probe
        var sv = PixelSave.load(), sc = Screen.title, tk: [Say] = [], sh = false
        if let p = probe {
            sv = PixelSave(stars: [1: 3, 2: 2], motes: 86, upgrades: ["wick": 1], seen: ["teach_drag", "teach_loop"])
            switch p {
            case "town": sc = .town
            case "talk": sc = .town; tk = ChapterOne.before[4] ?? []
            case "shop": sc = .town; sh = true
            case "night1": sc = .night(1); sv.seen = []
            case "night3": sc = .night(3)
            case "night5": sc = .night(5)
            case "result": sc = .night(2)
            default: sc = .title
            }
        }
        _save = State(initialValue: sv); _screen = State(initialValue: sc); _talk = State(initialValue: tk); _shop = State(initialValue: sh)
    }

    var body: some View {
        GeometryReader { g in
            let sc = PixelScale(size: g.size)
            ZStack {
                Color.black.ignoresSafeArea()
                switch screen {
                case .title: PixelTitle(scale: sc, save: save) { go(.town) }
                case .town: PixelTown(scale: sc, save: $save, shop: $shop, play: { n in startNight(n) })
                case .night(let n):
                    NightScreen(spec: ChapterOne.nights[n - 1], scale: sc, save: $save, demo: probe != nil, preset: probe == "result" ? 1 : 0) { won in endNight(n, won) }.id(n)
                }
                if !talk.isEmpty { TalkBox(scale: sc, lines: $talk) { let a = afterTalk; afterTalk = nil; a?() } }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onAppear { if probe == nil { Sound.shared.music(0) } }
    }

    private func go(_ s: Screen) { withAnimation(.easeInOut(duration: 0.25)) { screen = s } }

    private func startNight(_ n: Int) {
        talk = ChapterOne.before[n] ?? []
        afterTalk = { go(.night(n)); Sound.shared.music(n == 5 ? 4 : 3) }
        if talk.isEmpty { afterTalk?() }
    }
    private func endNight(_ n: Int, _ won: Bool) {
        if probe != nil { return }
        Sound.shared.music(1)
        go(.town)
        if won, let lines = ChapterOne.after[n], !save.seen.contains("after\(n)") {
            save.seen.insert("after\(n)"); save.save()
            talk = lines; afterTalk = nil
        }
    }
}

/// Lines between nights: a pixel box at the bottom with the speaker's face; tap to go on.
struct TalkBox: View {
    let scale: PixelScale
    @Binding var lines: [Say]
    var done: () -> Void
    @State private var shown = 0
    var body: some View {
        let pt = scale.pt, k = scale.k
        if let l = lines.first {
            VStack {
                Spacer()
                HStack(alignment: .top, spacing: pt * 6) {
                    if let face = TalkBox.face(l.who) {
                        PixelImage(name: face, pt: pt * 2).frame(width: pt * 44, height: pt * 44)
                            .background(Color(0x141a33)).clipped()
                    }
                    VStack(alignment: .leading, spacing: pt * 3) {
                        if let n = GameModel.names[l.who], !n.isEmpty { Text(n).font(PixelFont.font(1, k: k)).foregroundStyle(pxGold) }
                        ZStack(alignment: .topLeading) {
                            Text(l.text).font(PixelFont.font(1, k: k)).opacity(0)
                            Text(String(l.text.prefix(shown))).font(PixelFont.font(1, k: k)).foregroundStyle(l.who.isEmpty ? Color(0xb8c0e0) : pxCream)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(pt * 2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(pt * 8)
                .modifier(PixelPanel(pt: pt))
                .padding(.horizontal, pt * 6)
                .padding(.bottom, pt * 18)
            }
            .contentShape(Rectangle())
            .background(Color.black.opacity(0.35).ignoresSafeArea())
            .onTapGesture {
                if shown < l.text.count { shown = l.text.count; return }
                lines.removeFirst(); Sound.shared.talk()
                if lines.isEmpty { done() }
            }
            .task(id: "\(lines.count)\(l.text)") {
                shown = 0
                for i in 1...max(1, l.text.count) {
                    try? await Task.sleep(for: .milliseconds(35))
                    if Task.isCancelled || shown >= l.text.count { return }
                    shown = i
                }
            }
        }
    }
    static func face(_ who: String) -> String? {
        switch who {
        case "o": return "otto_idle_0"
        case "m": return "moss_idle_0"
        case "x": return "mosto_fly_0"
        case "h": return "npc_hank"
        case "d": return "npc_dora"
        case "n": return "npc_lynn"
        default: return nil
        }
    }
}

/// A pixel sprite as a SwiftUI image, magnified with no smoothing.
struct PixelImage: View {
    let name: String
    let pt: CGFloat
    var body: some View {
        if let s = PixelArt.sprite(name), let img = Frame.image(of: s) {
            Image(decorative: img, scale: 1).interpolation(.none).resizable()
                .frame(width: CGFloat(s.w) * pt, height: CGFloat(s.h) * pt)
        }
    }
}

extension Frame {
    static func image(of s: PSprite) -> CGImage? {
        let data = s.px.withUnsafeBytes { Data($0) }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: s.w, height: s.h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: s.w * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil,
                       shouldInterpolate: false, intent: .defaultIntent)
    }
}

// MARK: title

struct PixelTitle: View {
    let scale: PixelScale
    let save: PixelSave
    var start: () -> Void
    @State private var t = 0.0
    var body: some View {
        let pt = scale.pt, k = scale.k
        ZStack {
            PixelBackdrop(name: "title", scale: scale, zoom: 2)
            VStack(spacing: pt * 6) {
                Spacer().frame(height: pt * 50)
                Text("灯台索魔").font(PixelFont.font(3, k: k)).foregroundStyle(pxGold)
                    .shadow(color: pxInk, radius: 0, x: pt, y: pt).shadow(color: pxInk, radius: 0, x: -pt, y: pt)
                    .shadow(color: pxInk, radius: 0, x: pt, y: -pt).shadow(color: pxInk, radius: 0, x: -pt, y: -pt)
                    .shadow(color: Color(0xa86a18), radius: 0, x: 0, y: pt * 2)
                Text("OTTOSSOM").font(PixelFont.font(1, k: k)).foregroundStyle(Color(0xb8c0e0)).tracking(pt * 3)
                Spacer().frame(height: pt * 14)
                PixelButton(title: save.unlocked > 1 || save.motes > 0 ? "继续守夜" : "开始守夜", k: k) { start() }
                    .opacity(t > 0 ? 1 : 0.6)
                Spacer()
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { t = 1 } }
    }
}

/// A full-screen pixel picture, scaled by whole pixels and anchored at the bottom.
struct PixelBackdrop: View {
    let name: String
    let scale: PixelScale
    var zoom: CGFloat = 1
    var body: some View {
        GeometryReader { g in
            if let s = PixelArt.sprite(name), let img = Frame.image(of: s) {
                let w = CGFloat(s.w) * scale.pt * zoom, h = CGFloat(s.h) * scale.pt * zoom
                Image(decorative: img, scale: 1).interpolation(.none).resizable()
                    .frame(width: w, height: h)
                    .position(x: g.size.width / 2, y: g.size.height - h / 2)
            }
        }
        .background(Color(0x070a18))
        .ignoresSafeArea()
    }
}

// MARK: the town between nights

struct PixelTown: View {
    let scale: PixelScale
    @Binding var save: PixelSave
    @Binding var shop: Bool
    var play: (Int) -> Void
    var body: some View {
        let pt = scale.pt, k = scale.k
        ZStack {
            PixelBackdrop(name: "town", scale: scale)
            VStack(spacing: pt * 5) {
                HStack {
                    Text("灯塔城").font(PixelFont.font(1, k: k)).foregroundStyle(pxCream)
                    Spacer()
                    HStack(spacing: pt * 3) {
                        PixelImage(name: "mote_0", pt: pt * 2)
                        Text("\(save.motes)").font(PixelFont.font(1, k: k)).foregroundStyle(pxGold)
                    }
                }
                .padding(.horizontal, pt * 10).padding(.vertical, pt * 5)
                .modifier(PixelPanel(pt: pt))
                .padding(.horizontal, pt * 6).padding(.top, pt * 30)
                Spacer()
                VStack(spacing: pt * 4) {
                    ForEach(ChapterOne.nights, id: \.id) { n in
                        let open = n.id <= save.unlocked
                        let st = save.stars[n.id] ?? 0
                        Button { if open { play(n.id) } } label: {
                            HStack(spacing: pt * 6) {
                                Text(open ? n.name : "？？？").font(PixelFont.font(1, k: k)).foregroundStyle(open ? pxCream : Color(0x6a6480))
                                Spacer()
                                HStack(spacing: pt * 2) {
                                    ForEach(0..<3, id: \.self) { i in
                                        Text("★").font(PixelFont.font(1, k: k)).foregroundStyle(i < st ? pxGold : Color(0x3a3450))
                                    }
                                }
                            }
                            .padding(.horizontal, pt * 8).padding(.vertical, pt * 5)
                            .modifier(PixelPanel(pt: pt, fill: n.id == save.unlocked ? Color(0x2c2450) : pxPanel))
                        }
                        .buttonStyle(.plain).disabled(!open)
                    }
                    PixelButton(title: "琳恩的小摊", k: k, primary: false) { shop = true }
                }
                .padding(.horizontal, pt * 10)
                .padding(.bottom, pt * 18)
            }
            if shop { UpgradeShop(scale: scale, save: $save) { shop = false } }
        }
    }
}

struct UpgradeShop: View {
    let scale: PixelScale
    @Binding var save: PixelSave
    var close: () -> Void
    var body: some View {
        let pt = scale.pt, k = scale.k
        VStack(spacing: pt * 4) {
            HStack {
                Text("琳恩的小摊").font(PixelFont.font(1, k: k)).foregroundStyle(pxGold)
                Spacer()
                PixelImage(name: "mote_0", pt: pt * 2)
                Text("\(save.motes)").font(PixelFont.font(1, k: k)).foregroundStyle(pxGold)
            }
            ForEach(Upgrade.all) { u in
                let lv = save.upgrades[u.id] ?? 0
                let cost = lv < u.costs.count ? u.costs[lv] : nil
                VStack(alignment: .leading, spacing: pt * 3) {
                    HStack(spacing: pt * 6) {
                        Text(u.name).font(PixelFont.font(1, k: k)).foregroundStyle(pxCream)
                        HStack(spacing: pt * 2) {
                            ForEach(0..<3, id: \.self) { i in
                                Rectangle().fill(i < lv ? pxGold : Color(0x3a3450)).frame(width: pt * 5, height: pt * 5)
                            }
                        }
                        Spacer(minLength: pt * 4)
                        if let c = cost {
                            PixelButton(title: "\(c)", k: k, primary: save.motes >= c) {
                                guard save.motes >= c else { Sound.shared.no(); return }
                                save.motes -= c; save.upgrades[u.id] = lv + 1; save.save(); Sound.shared.light()
                            }
                        } else {
                            Text("满").font(PixelFont.font(1, k: k)).foregroundStyle(pxGold)
                        }
                    }
                    Text(u.text).font(PixelFont.font(1, k: k)).foregroundStyle(Color(0x9a94b8)).lineLimit(1).minimumScaleFactor(0.8)
                }
                .padding(.horizontal, pt * 6).padding(.vertical, pt * 4)
                .modifier(PixelPanel(pt: pt))
            }
            PixelButton(title: "好", k: k) { close() }
        }
        .padding(pt * 6)
        .modifier(PixelPanel(pt: pt, fill: Color(0x141024)))
        .padding(.horizontal, pt * 6)
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.85).ignoresSafeArea())
    }
}

// MARK: one night

struct NightScreen: View {
    let spec: NightSpec
    let scale: PixelScale
    @Binding var save: PixelSave
    var demo = false
    var preset = 0
    var done: (Bool) -> Void
    @State private var motes = 0
    @State private var outcome = 0
    @State private var stars = 0
    @State private var teach: String?
    @State private var banner: String?
    @State private var paused = false
    @State private var combo: String?
    @State private var seed = UInt64.random(in: 1...999_999)

    var body: some View {
        let pt = scale.pt, k = scale.k
        ZStack {
            NightCanvasView(spec: spec, scale: scale, seed: seed, upgrades: save.upgrades, paused: paused || outcome != 0, demo: demo,
                            onEvents: handle, onTick: { sim in
                                if motes != sim.collected { motes = sim.collected }
                                if outcome == 0 && sim.outcome != 0 { outcome = sim.outcome; stars = sim.stars; finish(sim) }
                            })
            .id(seed)
            .frame(width: CGFloat(scale.w) * scale.pt, height: CGFloat(scale.h) * scale.pt)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ignoresSafeArea()
            VStack(spacing: pt * 3) {
                HStack {
                    Button { paused.toggle() } label: {
                        Text(paused ? "▶" : "Ⅱ").font(PixelFont.font(1, k: k)).foregroundStyle(pxCream)
                            .frame(width: pt * 16, height: pt * 14).modifier(PixelPanel(pt: pt))
                    }.buttonStyle(.plain)
                    Spacer()
                    HStack(spacing: pt * 2) {
                        PixelImage(name: "mote_0", pt: pt * 2)
                        Text("\(motes)").font(PixelFont.font(1, k: k)).foregroundStyle(pxGold)
                    }
                }
                .padding(.horizontal, pt * 4).padding(.top, pt * 44)
                if let t = teach {
                    Text(t).font(PixelFont.font(1, k: k)).foregroundStyle(pxCream).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(pt * 6).modifier(PixelPanel(pt: pt)).padding(.horizontal, pt * 10)
                        .transition(.opacity)
                }
                if let c = combo {
                    Text(c).font(PixelFont.font(2, k: k)).foregroundStyle(pxGold).shadow(color: pxInk, radius: 0, x: pt, y: pt)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                if let b = banner {
                    Text(b).font(PixelFont.font(2, k: k)).foregroundStyle(pxCream).shadow(color: pxInk, radius: 0, x: pt, y: pt)
                        .padding(.bottom, pt * 60).transition(.opacity)
                }
            }
            .allowsHitTesting(true)
            if paused && outcome == 0 {
                VStack(spacing: pt * 6) {
                    Text("暂停").font(PixelFont.font(2, k: k)).foregroundStyle(pxCream)
                    PixelButton(title: "继续", k: k) { paused = false }
                    PixelButton(title: "回灯塔城", k: k, primary: false) { done(false) }
                }
                .padding(pt * 12).modifier(PixelPanel(pt: pt))
            }
            if outcome != 0 { result(pt: pt, k: k) }
        }
        .animation(.easeInOut(duration: 0.3), value: teach)
        .animation(.spring(duration: 0.3), value: combo)
        .animation(.easeInOut(duration: 0.4), value: banner)
        .onAppear {
            if preset != 0 {
                Task { try? await Task.sleep(for: .milliseconds(2500)); motes = 23; stars = 2; outcome = preset }
            }
            banner = spec.name
            Task { try? await Task.sleep(for: .milliseconds(1800)); banner = nil }
            if let key = spec.teach, !save.seen.contains("teach_\(key)") {
                Task {
                    try? await Task.sleep(for: .milliseconds(900))
                    teach = ChapterOne.teach(key)
                    save.seen.insert("teach_\(key)"); save.save()
                    try? await Task.sleep(for: .milliseconds(6500))
                    teach = nil
                }
            }
        }
    }

    private func handle(_ evs: [NightEvent]) {
        for e in evs {
            switch e {
            case .pop: Sound.shared.step()
            case .mote: Sound.shared.talk()
            case .loop(let n):
                Sound.shared.light(); Haptic.success()
                if n >= 2 { combo = "套住 \(n)！"; Task { try? await Task.sleep(for: .milliseconds(900)); combo = nil } }
            case .drink: Sound.shared.dim(); Haptic.warn()
            case .wake: Sound.shared.motif(.otto); Haptic.light()
            case .steal:
                Sound.shared.motif(.mosto); Haptic.warn()
                if !save.seen.contains("teach_thief") { save.seen.insert("teach_thief"); save.save(); show(ChapterOne.teach("thief")) }
            case .caught: Sound.shared.win(); combo = "索魔！"; Task { try? await Task.sleep(for: .milliseconds(1100)); combo = nil }
            case .escaped: Sound.shared.dim()
            case .mawHit: Sound.shared.push(); Haptic.success()
            case .mawDown: Sound.shared.win()
            case .bounce: Sound.shared.no()
            case .dawn: Sound.shared.win()
            case .dark: Sound.shared.dim()
            }
        }
    }
    private func show(_ t: String) {
        teach = t
        Task { try? await Task.sleep(for: .milliseconds(5000)); if teach == t { teach = nil } }
    }

    private func finish(_ sim: NightSim) {
        save.motes += sim.collected
        if sim.outcome == 1 { save.stars[spec.id] = max(save.stars[spec.id] ?? 0, sim.stars) }
        save.save()
    }

    private func result(pt: CGFloat, k: Int) -> some View {
        VStack(spacing: pt * 6) {
            Text(outcome == 1 ? "天亮了" : "灯灭了").font(PixelFont.font(3, k: k)).foregroundStyle(outcome == 1 ? pxGold : Color(0xb8c0e0))
            if outcome == 1 {
                HStack(spacing: pt * 4) {
                    ForEach(0..<3, id: \.self) { i in Text("★").font(PixelFont.font(2, k: k)).foregroundStyle(i < stars ? pxGold : Color(0x3a3450)) }
                }
            }
            HStack(spacing: pt * 3) {
                PixelImage(name: "mote_0", pt: pt * 2)
                Text("+\(motes)").font(PixelFont.font(1, k: k)).foregroundStyle(pxGold)
            }
            PixelButton(title: outcome == 1 ? "回灯塔城" : "再守一次", k: k) {
                if outcome == 1 { done(true) } else { seed &+= 7; motes = 0; stars = 0; outcome = 0; Sound.shared.touch() }
            }
            if outcome != 1 { PixelButton(title: "回灯塔城", k: k, primary: false) { done(false) } }
        }
        .padding(pt * 14)
        .modifier(PixelPanel(pt: pt))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5).ignoresSafeArea())
    }
}
