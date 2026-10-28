import SwiftUI

@main
struct ChangyeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}

enum Screen: Equatable { case title, chapter(Int), snap(Int, String) }

final class Router: ObservableObject {
    @Published var screen: Screen = .title
}

let nightBG = Color(.sRGB, red: 0.059, green: 0.071, blue: 0.125, opacity: 1)
let gold = Color(.sRGB, red: 0.949, green: 0.753, blue: 0.384, opacity: 1)
let mutedText = Color(.sRGB, red: 0.6, green: 0.63, blue: 0.74, opacity: 1)
let panelBG = Color(.sRGB, red: 0.09, green: 0.106, blue: 0.18, opacity: 1)

struct RootView: View {
    @StateObject private var router = Router()
    var body: some View {
        ZStack {
            nightBG.ignoresSafeArea()
            switch router.screen {
            case .title: TitleView().transition(.opacity)
            case .chapter(let id):
                if let ch = Content.chapters.first(where: { $0.id == id }) {
                    GameView(model: GameModel(chapter: ch)).id(id).transition(.opacity)
                }
            case .snap(let id, let room):
                if let ch = Content.chapters.first(where: { $0.id == id }) {
                    GameView(model: GameModel.preview(chapter: ch, room: room)).id(room)
                }
            }
        }
        .environmentObject(router)
        .animation(.easeInOut(duration: 0.35), value: router.screen)
        .task {
            if ProcessInfo.processInfo.arguments.contains("-snapshots") { await Snapshots.run(router) }
        }
    }
}

struct TitleView: View {
    static let trio = Room(RoomSpec(id: "title", name: "", day: 60, map: ["#####", "#OMX#", "#####"]))
    @EnvironmentObject var router: Router
    @State private var tick = 0
    @State private var allOpen = false
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { TitleWorld().ignoresSafeArea() }
    }

    private var content: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 24)
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let room = TitleView.trio
                    let frame = BoardFrame(room: room, state: room.start, prev: nil, e: 1, t: t, active: -1, face: [1, 1, -1], actors: [:],
                                           mainDim: false, dark: 0, hideHeroes: false, bulbR: 0, doudou: false)
                    let T = min(size.width / 3.2, 110)
                    var c = ctx
                    c.translateBy(x: (size.width - T * 3) / 2 - T, y: -T * 0.3)
                    let p = Painter(f: frame, T: T)
                    p.otto(&c, CGPoint(x: 1, y: 1), bulb: true, face: 1)
                    p.moss(&c, CGPoint(x: 2, y: 1), alpha: 1)
                    p.mosto(&c, CGPoint(x: 3, y: 1), alpha: 1, carry: true)
                }
            }
            .frame(height: 200)
            .onTapGesture(count: 5) { allOpen = true; Haptic.success() }
            .onAppear { Sound.shared.music(0) }
            Text("长夜").font(.system(size: 44, weight: .semibold, design: .serif)).foregroundStyle(.white).tracking(8)
            Text("太阳一百天没有升起").font(.callout).foregroundStyle(mutedText)
            Spacer(minLength: 12)
            VStack(spacing: 10) {
                ForEach(Content.chapters) { ch in
                    let open = allOpen || Progress.shared.unlocked(ch.id)
                    let done = Progress.shared.done.contains(ch.id)
                    Button {
                        router.screen = .chapter(ch.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("第\(["一", "二", "三", "四"][ch.id - 1])章 · \(ch.steps.filter { $0.cut == nil }.count) 间").font(.caption).foregroundStyle(mutedText)
                                Text(ch.title).font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(open ? .white : mutedText)
                            }
                            Spacer()
                            Text(done ? "已完成" : open ? (Progress.shared.step(ch.id) > 0 ? "继续" : "开始") : "未解锁")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(open ? gold : mutedText)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .background(panelBG, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
                    }
                    .disabled(!open)
                    .accessibilityLabel("第\(ch.id)章 \(ch.title)")
                }
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: 560)
    }
}

/// The title's backdrop: the lighthouse town under the long night, drawn by the same painter as the rooms.
struct TitleWorld: View {
    var body: some View {
        GeometryReader { g in
            TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                Canvas { ctx, size in
                    let room = TitleView.trio
                    let T = max(28, min(size.width, size.height) / 9)
                    let o = CGPoint(x: (size.width - T * 5) / 2, y: size.height * 0.36)
                    let frame = BoardFrame(room: room, state: room.start, prev: nil, e: 1, t: tl.date.timeIntervalSinceReferenceDate, active: -1,
                                           face: [1, 1, -1], actors: [:], mainDim: false, dark: 0, hideHeroes: true, bulbR: 0, doudou: false,
                                           extent: CGRect(x: -o.x, y: -o.y, width: size.width, height: size.height))
                    var c = ctx
                    c.translateBy(x: o.x, y: o.y)
                    let p = Painter(f: frame, T: T)
                    p.sceneryBack(&c, rings: false)
                    c.fill(Path(frame.extent!), with: .color(Color(.sRGB, red: 0.01, green: 0.015, blue: 0.04, opacity: 0.45)))
                    p.sceneryFront(&c)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .accessibilityHidden(true)
    }
}

struct GameView: View {
    @StateObject var model: GameModel
    @EnvironmentObject var router: Router
    @State private var showRules = false
    @State private var showSettings = false
    @State private var revealed = 0

    /// Height kept free at the bottom for the hint line, hero chips, actions and the small links.
    private let panelH: CGFloat = 214
    /// Height kept free at the top for the title row and progress.
    private let headH: CGFloat = 70

    var body: some View {
        GeometryReader { outer in
            let ins = outer.safeAreaInsets
            ZStack {
                GeometryReader { g in scene(g.size, ins) }.ignoresSafeArea()
                VStack(spacing: 0) {
                    header.padding(.top, 6)
                    Spacer(minLength: 0)
                    bottomPanel
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear { model.begin() }
        .sheet(isPresented: $showRules) { RulesView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .overlay {
            if let c = model.card {
                VStack(spacing: 8) {
                    Text(c.title).font(.system(size: 28, weight: .semibold, design: .serif)).foregroundStyle(.white).tracking(4)
                        .multilineTextAlignment(.center)
                    if !c.sub.isEmpty { Text(c.sub).font(.callout).foregroundStyle(mutedText).multilineTextAlignment(.center) }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.9).ignoresSafeArea())
                .transition(.opacity)
            }
        }
        .overlay {
            if model.finished { finishedView }
        }
        .animation(.easeInOut(duration: 0.45), value: model.card)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button { Sound.shared.hum(false); router.screen = .title } label: {
                    Image(systemName: "chevron.left").font(.headline).frame(width: 36, height: 36)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .accessibilityLabel("回到标题")
                Text("第\(["一", "二", "三", "四"][model.chapter.id - 1])章 · \(model.chapter.title)")
                    .font(.system(size: 17, weight: .semibold, design: .serif)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Text("第 \(model.room.spec.day) 天 · \(model.room.spec.name)").font(.caption).foregroundStyle(mutedText).lineLimit(1)
            }
            .foregroundStyle(.white)
            HStack(spacing: 6) {
                ForEach(Array(model.chapter.steps.enumerated()).filter { $0.element.cut == nil }, id: \.offset) { i, _ in
                    Capsule().fill(i < model.stepIndex ? gold : i == model.stepIndex ? Color.white.opacity(0.85) : Color.white.opacity(0.15))
                        .frame(height: 4)
                }
                Text("\(model.state.steps) 步 · 最少 \(model.room.spec.par ?? 0)").font(.caption.monospacedDigit()).foregroundStyle(mutedText)
                    .fixedSize()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("本章第 \(model.chapter.steps[0..<min(model.stepIndex + 1, model.chapter.steps.count)].filter { $0.cut == nil }.count) 间，已走 \(model.state.steps) 步，最少 \(model.room.spec.par ?? 0) 步")
        }
        .frame(height: headH - 6, alignment: .top)
    }

    private var bottomPanel: some View {
        VStack(spacing: 10) {
            Text(model.hint).font(.footnote).foregroundStyle(mutedText).frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 18)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.updatesFrequently)
            if let d = model.dialog { dialogView(d) } else { controls }
            HStack {
                Button { showSettings = true } label: { Label("设置", systemImage: "gearshape") }
                Spacer()
                Button { model.requestHint() } label: { Label("提示", systemImage: "lightbulb") }
                    .disabled(!model.canPlay || model.dialog != nil)
                Spacer()
                Button("怎么玩") { showRules = true }
            }
            .font(.footnote).foregroundStyle(mutedText)
            .padding(.bottom, 4)
        }
        .frame(height: panelH, alignment: .bottom)
    }

    /// Where the room goes on this screen: tiles stay a readable size, centred in the space between header and panel.
    private func layout(_ size: CGSize, _ ins: EdgeInsets) -> (T: CGFloat, origin: CGPoint) {
        let r = model.room
        let top = ins.top + headH, bottom = size.height - ins.bottom - panelH - 6
        let left = ins.leading + 8, right = size.width - ins.trailing - 8
        let T = max(20, min(72, floor(min((right - left) / CGFloat(r.w), (bottom - top) / CGFloat(r.h)))))
        let ox = floor((size.width - T * CGFloat(r.w)) / 2)
        let oy = floor(top + max(0, (bottom - top - T * CGFloat(r.h)) / 2))
        return (T, CGPoint(x: ox, y: oy))
    }

    private func scene(_ size: CGSize, _ ins: EdgeInsets) -> some View {
        let r = model.room
        let (T, o) = layout(size, ins)
        return TimelineView(.animation) { tl in
            let now = tl.date
            let e = min(1, now.timeIntervalSince(model.animStart) / model.animDur)
            let eased = 1 - pow(1 - e, 3)
            let frame = BoardFrame(room: r, state: model.state, prev: model.prev, e: eased, t: now.timeIntervalSinceReferenceDate,
                                   active: model.active, face: model.face, actors: model.actors, mainDim: model.mainDim, dark: model.dark,
                                   hideHeroes: model.hideHeroes, bulbR: model.bulbR, doudou: Progress.shared.flags.contains("doudou"),
                                   hint: model.hintMark, dots: model.pathDots,
                                   tap: model.tapMark.map { ($0.p, now.timeIntervalSince($0.at)) },
                                   extent: CGRect(x: -o.x, y: -o.y, width: size.width, height: size.height))
            Canvas { ctx, _ in
                var c = ctx
                c.translateBy(x: o.x, y: o.y)
                Painter(f: frame, T: T).draw(&c)
                // panels read better over a darker floor of the scene
                let fade = Gradient(colors: [.black.opacity(0), .black.opacity(0.7)])
                ctx.fill(Path(CGRect(x: 0, y: size.height - ins.bottom - panelH - 30, width: size.width, height: ins.bottom + panelH + 30)),
                         with: .linearGradient(fade, startPoint: CGPoint(x: 0, y: size.height - ins.bottom - panelH - 30), endPoint: CGPoint(x: 0, y: size.height - ins.bottom - panelH + 40)))
                ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: ins.top + headH)),
                         with: .linearGradient(Gradient(colors: [.black.opacity(0.55), .black.opacity(0)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: ins.top + headH)))
            }
        }
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { v in
            let x = Int(floor((v.location.x - o.x) / T)), y = Int(floor((v.location.y - o.y) / T))
            if x >= 0, y >= 0, x < r.w, y < r.h { model.tap(Pt(x, y)) }
        })
        .overlay(alignment: .topLeading) {
            ZStack {
                if let b = model.banner, model.card == nil {
                    Text(b).font(.system(size: 15, weight: .semibold, design: .serif)).foregroundStyle(.white).tracking(3)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(.black.opacity(0.6), in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .position(x: size.width / 2, y: o.y + 22)
                }
                if let c = model.cleared {
                    VStack(spacing: 6) {
                        Text(c.steps <= c.par ? "完美" : "过关").font(.system(size: 30, weight: .semibold, design: .serif)).foregroundStyle(gold)
                        Text(c.steps <= c.par ? "\(c.steps) 步，正好是最少步数" : "\(c.steps) 步 · 最少 \(c.par) 步").font(.callout).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 26).padding(.vertical, 16)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .position(x: size.width / 2, y: o.y + T * CGFloat(r.h) / 2)
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .animation(.spring(duration: 0.4), value: model.banner)
            .animation(.spring(duration: 0.4), value: model.cleared)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("游戏画面：点地面让角色走过去")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            if model.room.heroes.count > 1 {
                HStack(spacing: 8) {
                    ForEach(Array(model.room.heroes.enumerated()), id: \.offset) { i, h in
                        Button { model.select(i) } label: {
                            Text(h == .otto ? "Otto" : h == .moss ? "Moss" : "Mosto")
                                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(i == model.active ? gold : panelBG.opacity(0.92), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(i == model.active ? Color.black : .white)
                        }
                        .accessibilityAddTraits(i == model.active ? .isSelected : [])
                    }
                }
            }
            HStack(spacing: 8) {
                if model.hero == .otto {
                    ctl(model.state.bulb ? "灯珠：亮" : "灯珠", on: model.state.bulb, enabled: model.canPlay && !model.room.lockBulb) { _ = model.apply(.bulb) }
                }
                ctl(model.actionLabel ?? "互动", on: false, enabled: model.canPlay && model.actionLabel != nil) { model.interact() }
                ctl("撤回", on: false, enabled: model.canPlay && !model.hist.isEmpty) { model.undo() }
                ctl("重来", on: false, enabled: model.canPlay && !model.hist.isEmpty) { model.reset() }
            }
        }
    }

    private func ctl(_ title: String, on: Bool, enabled: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(title).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                .background(on ? gold : panelBG.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(on ? Color.black : .white)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08)))
        }
        .disabled(!enabled).opacity(enabled ? 1 : 0.4)
    }

    private func dialogView(_ d: Dialog) -> some View {
        let full = d.text.count
        let done = revealed >= full
        return HStack(alignment: .top, spacing: 12) {
            if let kind = Portrait.kind(d.who) { Portrait(kind: kind).frame(width: 54, height: 54) }
            VStack(alignment: .leading, spacing: 10) {
                if !d.who.isEmpty { Text(d.who).font(.caption.weight(.bold)).foregroundStyle(gold) }
                if !d.text.isEmpty {
                    ZStack(alignment: .topLeading) {
                        Text(d.text).font(.body).opacity(0)   // reserves the final height so the box doesn't grow
                        Text(String(d.text.prefix(revealed))).font(.body).foregroundStyle(.white)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(d.text)
                }
                if d.options.isEmpty {
                    Text(done ? "点一下继续" : " ").font(.caption2).foregroundStyle(mutedText).frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    ForEach(Array(d.options.enumerated()), id: \.offset) { i, o in
                        Button { model.answer(i) } label: {
                            Text(o).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                .background(nightBG, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1)))
                        }
                        .foregroundStyle(.white)
                        .disabled(!done)
                        .opacity(done ? 1 : 0.4)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBG.opacity(0.94), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture {
            if !done { revealed = full } else if d.options.isEmpty { model.answer(0) }
        }
        .task(id: d.id) {
            revealed = 0
            for k in 1...max(1, full) {
                try? await Task.sleep(for: .milliseconds(38))
                if Task.isCancelled { return }
                if revealed >= full { return }
                revealed = k
            }
        }
        .accessibilityAddTraits(.isButton)
    }

    private var finishedView: some View {
        VStack(spacing: 16) {
            Text(model.chapter.id == 4 ? "长夜 · 完" : "第\(["一", "二", "三", "四"][model.chapter.id - 1])章 · \(model.chapter.title)")
                .font(.system(size: 26, weight: .semibold, design: .serif)).foregroundStyle(.white)
            Text(model.chapter.id < 4 ? "下一章已经打开" : "谢谢你陪他们走完这一夜").foregroundStyle(mutedText)
            Button {
                router.screen = .title
            } label: {
                Text("回到标题").font(.headline).padding(.horizontal, 28).padding(.vertical, 12).background(gold, in: Capsule()).foregroundStyle(.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(nightBG.opacity(0.96))
    }
}

struct RulesView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("走") { Text("点地面，角色就走过去。走错了就「撤回」，或者「重来」这个房间。") }
                Section("Otto · 照") { Text("「灯珠」亮着时，够得着的影子每一步都朝他挪一格。站到灯旁边按「点灯」。亮着的格子，就是光够得着的范围。") }
                Section("Moss · 摸") { Text("走进石头就能推它。石头压住压板，门就开。站到石碑旁边按「摸」，能读到它记得的事。") }
                Section("Mosto · 抓") { Text("站到亮着的灯旁边按「抓光」，再到窝或暗着的灯旁边按「放光」。翅膀能飞过水，也能从影子中间穿过去。抱着光时，影子会跟着他。") }
                Section("迷路的影子") { Text("它们不坏，只是冷，会往有光的地方挪。一盏灯边上挤了两个影子，灯就被压暗；挨着影子的灯点不着。") }
                Section("第四章") { Text("点下面的名字换人。三个人都走到出口，才算过关。") }
            }
            .navigationTitle("怎么玩")
            .toolbar { Button("好") { dismiss() } }
        }
        .preferredColorScheme(.dark)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var sound = Sound.shared.enabled
    @State private var music = Sound.shared.musicOn
    @State private var haptics = Haptic.on
    @State private var confirmReset = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("音效", isOn: $sound).onChange(of: sound) { _, v in Sound.shared.enabled = v; Sound.shared.save() }
                    Toggle("音乐", isOn: $music).onChange(of: music) { _, v in Sound.shared.musicOn = v; Sound.shared.save() }
                    Toggle("震动", isOn: $haptics).onChange(of: haptics) { _, v in Haptic.on = v }
                }
                Section {
                    Button("清除全部进度", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("进度只保存在这台设备上。")
                }
                Section("关于") {
                    Text("《长夜》—— Otto、Moss 与 Mosto 的故事。本作在开发过程中使用了 AI 辅助。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .toolbar { Button("好") { dismiss() } }
            .confirmationDialog("清除全部进度？", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("清除", role: .destructive) { Progress.shared.resetAll(); dismiss() }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// A speaker's face next to their line, drawn with the same painter as the board.
struct Portrait: View {
    enum Kind { case otto, moss, mosto }
    let kind: Kind
    static func kind(_ who: String) -> Kind? { who == "Otto" ? .otto : who == "Moss" ? .moss : who == "Mosto" ? .mosto : nil }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            Canvas { ctx, size in
                let room = TitleView.trio
                let frame = BoardFrame(room: room, state: room.start, prev: nil, e: 1, t: tl.date.timeIntervalSinceReferenceDate, active: -1,
                                       face: [1, 1, -1], actors: [:], mainDim: false, dark: 0, hideHeroes: false, bulbR: 0, doudou: false)
                let T = size.width * (kind == .otto ? 0.95 : 1.15)
                var c = ctx
                c.translateBy(x: (size.width - T) / 2 - T, y: size.height - T * (kind == .otto ? 1.9 : 1.92))
                let p = Painter(f: frame, T: T)
                switch kind {
                case .otto: p.otto(&c, CGPoint(x: 1, y: 1), bulb: true, face: 1)
                case .moss: p.moss(&c, CGPoint(x: 1, y: 1), alpha: 1)
                case .mosto: p.mosto(&c, CGPoint(x: 1, y: 1), alpha: 1, carry: false)
                }
            }
        }
        .background(nightBG, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }
}
