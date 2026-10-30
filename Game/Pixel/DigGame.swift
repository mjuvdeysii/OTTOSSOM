import SwiftUI

// The whole game: night (dig) → morning (what came up) → day (the lamp shop) → evening (Lynn's upgrades) → night.
// The goal line at the top always says the one thing to do next.

struct DigGameView: View {
    @State private var save: DigSave
    @State private var phase: Phase
    @State private var talk: [Say] = []
    @State private var afterTalk: (() -> Void)?
    @State private var nightID = 0
    private let probe: String?
    enum Phase: Equatable { case title, night, shop, evening }

    init(probe: String? = nil) {
        self.probe = probe
        var sv = DigSave.load(), ph = Phase.title, tk: [Say] = []
        if let p = probe {
            sv = DigSave()
            sv.seen = ["intro"]
            switch p {
            case "dig", "memory": ph = .night
            case "deep":
                ph = .night
                // a shaft already dug part of the way down
                for y in DigWorld.ground...(DigWorld.ground + 12) { sv.world.set(6, y, .air) }
                sv.upgrades = ["claw": 1]
            case "shop":
                ph = .shop; sv.gems = [.amber: 3, .blue: 1]; sv.coins = 24; sv.openShop()
            case "shoptalk":
                ph = .shop; sv.gems = [.amber: 2]; sv.openShop(); tk = DigStory.afterNight[1] ?? []
            case "evening":
                ph = .evening; sv.coins = 46; sv.upgrades = ["bag": 1]; sv.memories = [1]
            default: ph = .title
            }
        }
        _save = State(initialValue: sv); _phase = State(initialValue: ph); _talk = State(initialValue: tk)
    }

    var body: some View {
        GeometryReader { g in
            let sc = PixelScale(size: g.size)
            ZStack {
                Color.black.ignoresSafeArea()
                switch phase {
                case .title:
                    PixelTitle(scale: sc, resume: save.day > 1 || save.seen.contains("intro")) { begin() }
                case .night:
                    DigNight(save: $save, scale: sc, demo: probe != nil, memoryProbe: probe == "memory") { endNight() }.id(nightID)
                case .shop:
                    LampShop(save: $save, scale: sc) { go(.evening) }
                case .evening:
                    Evening(save: $save, scale: sc) { startNight() }
                }
                if !talk.isEmpty { TalkBox(scale: sc, lines: $talk) { let a = afterTalk; afterTalk = nil; a?() } }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onAppear { if probe == nil { Sound.shared.music(0) } }
    }

    private func go(_ p: Phase) { withAnimation(.easeInOut(duration: 0.3)) { phase = p } }

    private func begin() {
        if !save.seen.contains("intro") {
            save.seen.insert("intro"); save.save()
            talk = DigStory.intro
            afterTalk = { go(.night); Sound.shared.music(3) }
        } else if save.nightDone {
            save.openShop(); save.save(); go(.shop); Sound.shared.music(1)
        } else { go(.night); Sound.shared.music(3) }
    }

    private func endNight() {
        if probe != nil { return }
        save.openShop(); save.save()
        go(.shop); Sound.shared.music(1)
        if let lines = DigStory.afterNight[save.day], !save.seen.contains("after\(save.day)") {
            save.seen.insert("after\(save.day)"); save.save()
            talk = lines; afterTalk = nil
        }
    }

    private func startNight() {
        save.day += 1; save.nightDone = false; save.save()
        nightID += 1
        go(.night); Sound.shared.music(3)
    }
}

// MARK: pieces of pixel UI

struct PixelBar: View {
    let value: Double
    let color: Color
    let pt: CGFloat
    var body: some View {
        GeometryReader { g in
            let n = max(1, Int(g.size.width / (pt * 2)))
            let lit = Int((Double(n) * max(0, min(1, value))).rounded(.up))
            HStack(spacing: 0) {
                ForEach(0..<n, id: \.self) { i in
                    Rectangle().fill(i < lit ? (i % 4 == 3 ? color.opacity(0.75) : color) : Color(0x241c34)).frame(width: pt * 2)
                }
            }
        }
        .frame(height: pt * 5)
        .padding(pt).background(pxInk)
    }
}

struct GoalLine: View {
    let text: String
    let scale: PixelScale
    var body: some View {
        let pt = scale.pt
        HStack(spacing: pt * 4) {
            Rectangle().fill(pxGold).frame(width: pt * 3, height: pt * 3)
            Text(text).font(PixelFont.font(1, k: scale.k)).foregroundStyle(pxCream).lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, pt * 6).padding(.vertical, pt * 4)
        .modifier(PixelPanel(pt: pt, fill: Color(0x141024).opacity(0.92)))
    }
}

struct Counter: View {
    let icon: String
    let text: String
    let scale: PixelScale
    var color: Color = pxCream
    var body: some View {
        HStack(spacing: scale.pt * 2) {
            PixelImage(name: icon, pt: scale.pt)
            Text(text).font(PixelFont.font(1, k: scale.k)).foregroundStyle(color).monospacedDigit()
        }
    }
}

// MARK: night

struct DigNight: View {
    @Binding var save: DigSave
    let scale: PixelScale
    var demo = false
    var memoryProbe = false
    var done: () -> Void
    @State private var sim: DigSim
    @State private var hud = HUD()
    @State private var command: String?
    @State private var hint: String?
    @State private var memory: Int?
    @State private var result: DigSim?
    @State private var banked = 0

    struct HUD: Equatable { var light = 1.0; var depth = 0; var bag = 0; var cap = 8; var secs = 0 }

    init(save: Binding<DigSave>, scale: PixelScale, demo: Bool, memoryProbe: Bool, done: @escaping () -> Void) {
        _save = save; self.scale = scale; self.demo = demo; self.memoryProbe = memoryProbe; self.done = done
        let s = save.wrappedValue
        _sim = State(initialValue: DigSim(world: s.world, upgrades: s.upgrades, seed: UInt64(s.day) * 977 + 13))
        if memoryProbe { _memory = State(initialValue: 3) }
    }

    var body: some View {
        let pt = scale.pt, k = scale.k
        ZStack {
            DigCanvasView(sim: sim, scale: scale, paused: memory != nil || result != nil, demo: demo, command: $command,
                          onEvents: handle, onTick: tick)
                .frame(width: CGFloat(scale.w) * pt, height: CGFloat(scale.h) * pt)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .ignoresSafeArea()
            VStack(spacing: pt * 4) {
                HStack(spacing: pt * 6) {
                    PixelImage(name: "mote_0", pt: pt)
                    PixelBar(value: hud.light, color: hud.light < 0.25 ? Color(0xff8a8a) : pxGold, pt: pt)
                    Text("\(hud.depth) 米").font(PixelFont.font(1, k: k)).foregroundStyle(pxCream).monospacedDigit()
                    Counter(icon: "icon_amber", text: "\(hud.bag)/\(hud.cap)", scale: scale, color: hud.bag >= hud.cap ? Color(0xff8a8a) : pxCream)
                }
                .padding(.horizontal, pt * 6).padding(.vertical, pt * 3)
                .modifier(PixelPanel(pt: pt, fill: Color(0x141024).opacity(0.92)))
                GoalLine(text: hint ?? save.goal, scale: scale)
                Spacer()
                HStack {
                    Spacer()
                    PixelButton(title: "收线回家", k: k, primary: hud.bag >= hud.cap || hud.light < 0.2) { command = "reel" }
                }
            }
            .padding(.horizontal, pt * 6).padding(.top, pt * 30).padding(.bottom, pt * 16)
            if let n = memory { MemoryPanel(n: n, scale: scale) { closeMemory(n) } }
            if let r = result { NightResult(sim: r, coins: banked, scale: scale) { done() } }
        }
        .onAppear {
            if !save.seen.contains("hint_move") {
                save.seen.insert("hint_move")
                hint = "按住屏幕拖动：往哪推，莫斯就往哪走、往哪挖"
                Task { try? await Task.sleep(for: .seconds(7)); if hint?.hasPrefix("按住") == true { hint = nil } }
            }
        }
    }

    private func tick(_ s: DigSim) {
        let h = HUD(light: s.light / s.lightMax, depth: s.depth, bag: s.bag.count, cap: s.capacity, secs: s.secondsLeft)
        if h != hud { hud = h }
        if result == nil && s.outcome != 0 { finish(s) }
    }

    private func say(_ key: String, _ text: String, _ secs: Double = 5) {
        guard !save.seen.contains(key) else { return }
        save.seen.insert(key)
        hint = text
        Task { try? await Task.sleep(for: .seconds(secs)); if hint == text { hint = nil } }
    }

    private func handle(_ evs: [DigEvent]) {
        for e in evs {
            switch e {
            case .dug(let t): if t == .soil || t == .clay || t == .grass { Sound.shared.push() }
            case .gem: Sound.shared.take(); Haptic.light(); say("hint_gem", "光晶装进背包了：背回灯铺能点灯")
            case .trinket: Sound.shared.touch(); say("hint_trinket", "「我的！」纽扣、硬币、瓶盖能换钱")
            case .mote: Sound.shared.light()
            case .full: Sound.shared.no(); say("hint_full", "背包满了：点「收线回家」", 6)
            case .hard: Sound.shared.no(); say("hint_hard", "这块太硬：白天去琳恩那里升级爪子", 6)
            case .memory(let n):
                Sound.shared.motif(.moss); Haptic.success()
                if !save.memories.contains(n) { save.memories.append(n); save.save() }
                memory = n
            case .flash(let n):
                Sound.shared.light()
                if n > 0 { Haptic.success() }
            case .hurt: Sound.shared.dim(); Haptic.warn(); say("hint_shade", "影子会吸走灯光：轻点屏幕，灯珠一闪就赶走它们", 6)
            case .home, .dark: break
            case .step, .land: break
            }
        }
    }

    private func closeMemory(_ n: Int) {
        memory = nil
        command = "closeMemory"
    }

    private func finish(_ s: DigSim) {
        var sv = save
        sv.world = s.world
        banked = sv.bank(s.bag)
        sv.deepest = max(sv.deepest, s.deepest)
        sv.nightDone = true
        sv.save()
        save = sv
        result = s
        if s.outcome == 1 { Sound.shared.win() } else { Sound.shared.dim() }
    }
}

struct MemoryPanel: View {
    let n: Int
    let scale: PixelScale
    var close: () -> Void
    var body: some View {
        let pt = scale.pt, k = scale.k
        VStack(spacing: pt * 6) {
            Text("记忆石 · \(n)").font(PixelFont.font(1, k: k)).foregroundStyle(pxGold)
            PixelImage(name: "memory_\(n)", pt: pt * 1.5)
                .overlay(Rectangle().strokeBorder(pxEdge, lineWidth: pt))
            Text(DigStory.memoryLine(n)).font(PixelFont.font(1, k: k)).foregroundStyle(pxCream)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).lineSpacing(pt * 2)
            PixelButton(title: "继续", k: k) { close() }
        }
        .padding(pt * 10)
        .modifier(PixelPanel(pt: pt, fill: Color(0x141024)))
        .padding(.horizontal, pt * 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7).ignoresSafeArea())
    }
}

struct NightResult: View {
    let sim: DigSim
    let coins: Int
    let scale: PixelScale
    var next: () -> Void
    var body: some View {
        let pt = scale.pt, k = scale.k
        VStack(spacing: pt * 6) {
            Text(sim.outcome == 1 ? "收线回家" : "灯灭了").font(PixelFont.font(2, k: k)).foregroundStyle(sim.outcome == 1 ? pxGold : Color(0xb8c0e0))
            if sim.outcome != 1 {
                Text("奥托把莫斯拉了回来，背包里的东西掉了一半").font(PixelFont.font(1, k: k)).foregroundStyle(Color(0x9a94b8))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            Text("最深 \(sim.deepest) 米").font(PixelFont.font(1, k: k)).foregroundStyle(pxCream)
            let items: [(String, Int)] = Gem.allCases.map { ("icon_\($0.rawValue)", sim.bag.gems[$0] ?? 0) } + Trinket.allCases.map { ("icon_\($0.rawValue)", sim.bag.trinkets[$0] ?? 0) }
            let shown = items.filter { $0.1 > 0 }
            if shown.isEmpty {
                Text("空手回来了").font(PixelFont.font(1, k: k)).foregroundStyle(Color(0x9a94b8))
            } else {
                HStack(spacing: pt * 6) {
                    ForEach(shown.indices, id: \.self) { i in Counter(icon: shown[i].0, text: "×\(shown[i].1)", scale: scale) }
                }
            }
            if coins > 0 { Counter(icon: "icon_coin", text: "汉克收走小玩意 +\(coins)", scale: scale, color: pxGold) }
            PixelButton(title: "天亮了", k: k) { next() }
        }
        .padding(pt * 10)
        .modifier(PixelPanel(pt: pt, fill: Color(0x141024)))
        .padding(.horizontal, pt * 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.6).ignoresSafeArea())
    }
}

// MARK: day: the lamp shop

struct LampShop: View {
    @Binding var save: DigSave
    let scale: PixelScale
    var close: () -> Void
    @State private var picked: [Gem] = []
    @State private var lit: LampColor?
    @State private var shake = false
    @State private var thanks: String?
    @State private var skipped: Set<Int> = []

    private var current: Order? { save.orders.first { !skipped.contains($0.id) } }

    static func portrait(_ who: String) -> String {
        switch who {
        case "h": return "npc_hank"
        case "d": return "npc_dora"
        case "n": return "npc_lynn"
        case "t1": return "npc_post"
        case "t2": return "npc_baker"
        default: return "npc_captain"
        }
    }

    var body: some View {
        let pt = scale.pt, k = scale.k
        ZStack {
            PixelBackdrop(name: "shop_bg", scale: scale)
            VStack(spacing: pt * 4) {
                HStack {
                    Text("第 \(save.day) 天 · 灯铺").font(PixelFont.font(1, k: k)).foregroundStyle(pxCream)
                    Spacer()
                    Counter(icon: "icon_coin", text: "\(save.coins)", scale: scale, color: pxGold)
                }
                .padding(.horizontal, pt * 8).padding(.vertical, pt * 4)
                .modifier(PixelPanel(pt: pt))
                if let o = current {
                    GoalLine(text: "点亮\(DigStory.name(o.who))的灯：\(o.color.name) = \(o.color.recipe.map(gemName).joined(separator: " + "))", scale: scale)
                    Spacer(minLength: pt * 4)
                    customer(o)
                    Spacer(minLength: pt * 4)
                    counter(o)
                } else {
                    Spacer()
                    VStack(spacing: pt * 6) {
                        Text(thanks ?? "今天的客人都走了").font(PixelFont.font(1, k: k)).foregroundStyle(pxCream)
                        PixelButton(title: "打烊", k: k) { close() }
                    }
                    .padding(pt * 10).modifier(PixelPanel(pt: pt))
                    Spacer()
                }
            }
            .padding(.horizontal, pt * 6).padding(.top, pt * 30).padding(.bottom, pt * 16)
        }
    }

    func gemName(_ g: Gem) -> String { g == .amber ? "琥珀晶" : g == .blue ? "蓝晶" : "红晶" }

    @ViewBuilder func customer(_ o: Order) -> some View {
        let pt = scale.pt, k = scale.k
        VStack(spacing: pt * 4) {
            HStack(alignment: .top, spacing: pt * 6) {
                PixelImage(name: LampShop.portrait(o.who), pt: pt * 3)
                VStack(alignment: .leading, spacing: pt * 3) {
                    Text(DigStory.name(o.who)).font(PixelFont.font(1, k: k)).foregroundStyle(pxGold)
                    HStack(spacing: pt * 4) {
                        Rectangle().fill(Color(o.color.rgb)).frame(width: pt * 8, height: pt * 8).overlay(Rectangle().strokeBorder(pxInk, lineWidth: pt))
                        Text(thanks ?? "想要\(o.color.name)").font(PixelFont.font(1, k: k)).foregroundStyle(pxCream)
                    }
                    Text("付 \(o.pay)").font(PixelFont.font(1, k: k)).foregroundStyle(Color(0x9a94b8))
                }
                .padding(pt * 6).modifier(PixelPanel(pt: pt))
            }
        }
    }

    @ViewBuilder func counter(_ o: Order) -> some View {
        let pt = scale.pt, k = scale.k
        VStack(spacing: pt * 6) {
            // the lamp: its glass takes the colour of what's put in
            ZStack {
                let mix = LampColor.mix(picked)
                Rectangle().fill(lit.map { Color($0.rgb) } ?? mix.map { Color($0.rgb).opacity(0.45) } ?? Color(0x1c2238))
                    .frame(width: pt * 8 * 4, height: pt * 13 * 4).offset(y: pt * 3)
                    .shadow(color: lit.map { Color($0.rgb) } ?? .clear, radius: lit == nil ? 0 : pt * 12)
                PixelImage(name: "lamp", pt: pt * 4)
            }
            .offset(x: shake ? pt * 3 : 0)
            // what's been put in
            HStack(spacing: pt * 4) {
                ForEach(0..<3, id: \.self) { i in
                    Button { if i < picked.count { picked.remove(at: i); Sound.shared.step() } } label: {
                        ZStack {
                            Rectangle().fill(Color(0x0e0c18)).frame(width: pt * 18, height: pt * 18)
                            if i < picked.count { PixelImage(name: "icon_\(picked[i].rawValue)", pt: pt) }
                        }
                        .overlay(Rectangle().strokeBorder(pxEdge, lineWidth: pt))
                    }.buttonStyle(.plain)
                }
            }
            // the shelf: crystals she brought up
            HStack(spacing: pt * 6) {
                ForEach(Gem.allCases, id: \.self) { g in
                    let have = (save.gems[g] ?? 0) - picked.filter { $0 == g }.count
                    Button {
                        guard have > 0, picked.count < 3, lit == nil else { Sound.shared.no(); return }
                        picked.append(g); Sound.shared.touch()
                    } label: {
                        VStack(spacing: pt * 2) {
                            PixelImage(name: "icon_\(g.rawValue)", pt: pt * 2)
                            Text("\(max(0, have))").font(PixelFont.font(1, k: k)).foregroundStyle(have > 0 ? pxCream : Color(0x5a5470))
                        }
                        .frame(width: pt * 34).padding(.vertical, pt * 4)
                        .modifier(PixelPanel(pt: pt))
                        .opacity(have > 0 ? 1 : 0.5)
                    }.buttonStyle(.plain)
                }
            }
            HStack(spacing: pt * 6) {
                PixelButton(title: "改天再来", k: k, primary: false) { later(o) }
                PixelButton(title: "点灯", k: k, primary: !picked.isEmpty) { tryLight(o) }
            }
        }
    }

    private func later(_ o: Order) {
        Sound.shared.step()
        picked = []
        skipped.insert(o.id)      // they'll come back another day
    }

    private func tryLight(_ o: Order) {
        guard !picked.isEmpty, lit == nil else { return }
        let mix = LampColor.mix(picked)
        if mix == o.color, save.light(o, with: picked) {
            lit = o.color; Sound.shared.win(); Haptic.success()
            thanks = "谢谢！"
            save.save()
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                lit = nil; picked = []; thanks = nil
            }
        } else {
            Sound.shared.no(); Haptic.warn()
            withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) { shake.toggle() }
            Task { try? await Task.sleep(for: .milliseconds(400)); shake = false; picked = [] }
        }
    }
}

// MARK: evening: Lynn's stall, then the night

struct Evening: View {
    @Binding var save: DigSave
    let scale: PixelScale
    var night: () -> Void
    static let items: [(String, String, [String])] = [
        ("claw", "爪子", ["能挖石头和蓝晶", "能挖硬岩和红晶"]),
        ("bag", "背包", ["多装 4 件", "再多装 4 件"]),
        ("wick", "灯芯", ["灯多亮 30 秒", "再多亮 30 秒"]),
    ]
    var body: some View {
        let pt = scale.pt, k = scale.k
        ZStack {
            PixelBackdrop(name: "town", scale: scale)
            VStack(spacing: pt * 4) {
                HStack {
                    Text("傍晚 · 琳恩的小摊").font(PixelFont.font(1, k: k)).foregroundStyle(pxCream)
                    Spacer()
                    Counter(icon: "icon_coin", text: "\(save.coins)", scale: scale, color: pxGold)
                }
                .padding(.horizontal, pt * 8).padding(.vertical, pt * 4)
                .modifier(PixelPanel(pt: pt))
                GoalLine(text: save.goal, scale: scale)
                Spacer()
                ForEach(Evening.items.indices, id: \.self) { idx in
                    let it = Evening.items[idx]
                    let lv = save.upgrades[it.0] ?? 0
                    let costs = DigSave.upgradeCosts[it.0] ?? []
                    HStack(spacing: pt * 6) {
                        VStack(alignment: .leading, spacing: pt * 2) {
                            HStack(spacing: pt * 4) {
                                Text(it.1).font(PixelFont.font(1, k: k)).foregroundStyle(pxCream)
                                HStack(spacing: pt * 2) {
                                    ForEach(0..<2, id: \.self) { i in Rectangle().fill(i < lv ? pxGold : Color(0x3a3450)).frame(width: pt * 5, height: pt * 5) }
                                }
                            }
                            Text(lv < 2 ? it.2[lv] : "已经最好了").font(PixelFont.font(1, k: k)).foregroundStyle(Color(0x9a94b8)).lineLimit(1)
                        }
                        Spacer(minLength: pt * 4)
                        if lv < costs.count {
                            let c = costs[lv]
                            PixelButton(title: "\(c)", k: k, primary: save.coins >= c) {
                                guard save.coins >= c else { Sound.shared.no(); return }
                                save.coins -= c; save.upgrades[it.0] = lv + 1; save.save(); Sound.shared.light(); Haptic.success()
                            }
                        }
                    }
                    .padding(.horizontal, pt * 6).padding(.vertical, pt * 4)
                    .modifier(PixelPanel(pt: pt))
                }
                HStack {
                    Text("记忆石 \(save.memories.count)/4").font(PixelFont.font(1, k: k)).foregroundStyle(Color(0x9a94b8))
                    Spacer()
                    PixelButton(title: "入夜，下井", k: k) { night() }
                }
                .padding(.top, pt * 4)
            }
            .padding(.horizontal, pt * 6).padding(.top, pt * 30).padding(.bottom, pt * 16)
        }
    }
}
