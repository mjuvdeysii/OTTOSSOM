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
            .background {
                if let bg = Art.background("top") {
                    GeometryReader { g in
                        Image(uiImage: bg.image).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: g.size.width, height: g.size.height).clipped()
                            .overlay(LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                    }
                    .ignoresSafeArea()
                } else {
                    TitleWorld().ignoresSafeArea()
                }
            }
    }

    private var content: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 24)
            Trio()
                .frame(height: 190)
                .onTapGesture(count: 5) { allOpen = true; Haptic.success() }
                .onAppear { Sound.shared.music(0) }
            Text("灯台索魔").font(.system(size: 44, weight: .semibold, design: .serif)).foregroundStyle(.white).tracking(10)
                .shadow(color: .black.opacity(0.6), radius: 10)
            Spacer(minLength: 12)
            VStack(spacing: 10) {
                ForEach(Content.chapters) { ch in
                    let open = allOpen || Progress.shared.unlocked(ch.id)
                    let done = Progress.shared.done.contains(ch.id)
                    Button {
                        router.screen = .chapter(ch.id)
                    } label: {
                        HStack(spacing: 14) {
                            Text(["一", "二", "三", "四"][ch.id - 1]).font(.system(size: 15, weight: .semibold, design: .serif))
                                .foregroundStyle(open ? gold : mutedText).frame(width: 22)
                            Text(ch.title).font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(open ? .white : mutedText)
                            Spacer()
                            ChapterFaces(hero: ch.hero).opacity(open ? 1 : 0.35)
                            Image(systemName: done ? "checkmark.circle.fill" : open ? "play.circle.fill" : "lock.fill")
                                .font(.title3).foregroundStyle(open ? gold : mutedText)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(panelBG.opacity(0.88), in: RoundedRectangle(cornerRadius: 14))
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

/// A memory read from a stone, or a moment the story needs: one picture, full screen, drifting slowly closer.
struct Vision: View {
    let image: UIImage
    @State private var zoom = 1.0
    var body: some View {
        GeometryReader { g in
            Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                .frame(width: g.size.width, height: g.size.height)
                .scaleEffect(zoom).clipped()
                .overlay(RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: g.size.width * 0.35, endRadius: g.size.height * 0.75))
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.linear(duration: 6)) { zoom = 1.08 } }
        .accessibilityHidden(true)
    }
}

/// The three of them on the title, breathing, blinking now and then.
struct Trio: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: -18) {
                sprite((t + 0.4).truncatingRemainder(dividingBy: 4.2) < 0.13 ? "otto_blink_E_n" : "otto_idle_E_n", t, 0)
                sprite((t + 1.3).truncatingRemainder(dividingBy: 3.7) < 0.13 ? "moss_blink_n" : "moss_right_n", t, 1)
                sprite((t + 2.1).truncatingRemainder(dividingBy: 4.4) < 0.13 ? "mosto_blink_n" : "mosto_left_n", t, 2)
            }
        }
        .accessibilityHidden(true)
    }
    private func sprite(_ name: String, _ t: Double, _ i: Int) -> some View {
        Group {
            if let ui = Art.uiImage(name) {
                Image(uiImage: ui).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 150).scaleEffect(x: 1, y: 1 + 0.02 * sin(t * 2.2 + Double(i)), anchor: .bottom)
            }
        }
    }
}

/// Who a chapter belongs to, as small faces.
struct ChapterFaces: View {
    let hero: String
    var body: some View {
        HStack(spacing: -10) {
            ForEach(names, id: \.self) { n in
                if let ui = Art.uiImage(n) {
                    Image(uiImage: ui).resizable().aspectRatio(contentMode: .fit).frame(width: 46, height: 60).offset(y: 4)
                }
            }
        }
        .frame(height: 40).clipped()
    }
    private var names: [String] {
        switch hero {
        case "otto": return ["otto_idle_E_n"]
        case "moss": return ["moss_idle_n"]
        case "mosto": return ["mosto_idle_n"]
        default: return ["otto_idle_E_n", "moss_idle_n"]
        }
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
    private let headH: CGFloat = 56

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
            if let v = model.vision, let ui = Art.uiImage(v, ext: "jpg") {
                Vision(image: ui).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: model.vision)
        .overlay {
            if model.finished { finishedView }
        }
        .animation(.easeInOut(duration: 0.45), value: model.card)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { Sound.shared.hum(false); router.screen = .title } label: {
                Image(systemName: "chevron.left").font(.headline).frame(width: 40, height: 40)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .foregroundStyle(.white)
            .accessibilityLabel("回到标题")
            HStack(spacing: 6) {
                ForEach(Array(model.chapter.steps.enumerated()).filter { $0.element.cut == nil }, id: \.offset) { i, _ in
                    Capsule().fill(i < model.stepIndex ? gold : i == model.stepIndex ? Color.white.opacity(0.85) : Color.white.opacity(0.15))
                        .frame(height: 4)
                }
            }
            HStack(spacing: 4) {
                Image(systemName: "shoeprints.fill").font(.caption)
                Text("\(model.state.steps)").font(.callout.monospacedDigit().weight(.semibold)).foregroundStyle(.white)
                Text("/ \(model.room.spec.par ?? 0)").font(.caption.monospacedDigit())
            }
            .foregroundStyle(mutedText)
            .fixedSize()
        }
        .frame(height: headH - 6, alignment: .center)
        .accessibilityElement(children: .contain)
    }

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            if let d = model.dialog { dialogView(d) } else { controls }
            HStack {
                Button { showSettings = true } label: { Image(systemName: "gearshape").frame(width: 40, height: 32) }
                    .accessibilityLabel("设置")
                Spacer()
                Button { model.requestHint() } label: { Image(systemName: "questionmark.circle").frame(width: 40, height: 32) }
                    .accessibilityLabel("提示")
                    .disabled(!model.canPlay || model.dialog != nil)
            }
            .font(.title3).foregroundStyle(mutedText)
            .padding(.bottom, 2)
        }
        .frame(height: panelH, alignment: .bottom)
    }

    /// Where the room goes on this screen: tiles stay a readable size, centred in the space between header and panel.
    private func layout(_ size: CGSize, _ ins: EdgeInsets) -> (T: CGFloat, origin: CGPoint) {
        let r = model.room
        let top = ins.top + headH, bottom = size.height - ins.bottom - panelH - 6
        let left = ins.leading + 8, right = size.width - ins.trailing - 8
        // a room is W cells wide and H·k deep on screen; the top row's figures stand up to a cell above it
        let K = Art.k, head: CGFloat = 0.9
        let T = max(20, min(72, floor(min((right - left) / CGFloat(r.w), (bottom - top) / (CGFloat(r.h) * K + head)))))
        let ox = floor((size.width - T * CGFloat(r.w)) / 2)
        let oy = floor(top + head * T + max(0, (bottom - top - T * (CGFloat(r.h) * K + head)) / 2))
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
                                   extent: CGRect(x: -o.x, y: -o.y, width: size.width, height: size.height), emotes: model.emotes)
            Canvas { ctx, _ in
                var c = ctx
                c.translateBy(x: o.x, y: o.y)
                Stage(f: frame, T: T).draw(&c)
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
            let x = Int(floor((v.location.x - o.x) / T)), y = Int(floor((v.location.y - o.y) / (T * Art.k)))
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
                    HStack(spacing: 12) {
                        Image(systemName: c.steps <= c.par ? "star.circle.fill" : "checkmark.circle.fill").font(.system(size: 34)).foregroundStyle(gold)
                        HStack(spacing: 4) {
                            Image(systemName: "shoeprints.fill").font(.caption)
                            Text("\(c.steps)").font(.title3.monospacedDigit().weight(.semibold))
                            Text("/ \(c.par)").font(.callout.monospacedDigit()).foregroundStyle(mutedText)
                        }
                        .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 22).padding(.vertical, 14)
                    .background(.black.opacity(0.72), in: Capsule())
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .position(x: size.width / 2, y: o.y + T * Art.k * CGFloat(r.h) / 2)
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
        HStack(spacing: 10) {
            if model.room.heroes.count > 1 {
                ForEach(Array(model.room.heroes.enumerated()), id: \.offset) { i, h in
                    Button { model.select(i) } label: { heroChip(h, on: i == model.active) }
                        .accessibilityLabel(h == .otto ? "Otto" : h == .moss ? "Moss" : "Mosto")
                        .accessibilityAddTraits(i == model.active ? .isSelected : [])
                }
                Spacer(minLength: 0)
            }
            if model.hero == .otto {
                iconButton(model.state.bulb ? "lightbulb.max.fill" : "lightbulb", on: model.state.bulb,
                           enabled: model.canPlay && !model.room.lockBulb, label: "灯珠") { _ = model.apply(.bulb) }
            }
            iconButton(actionIcon, on: false, enabled: model.canPlay && model.actionLabel != nil, label: model.actionLabel ?? "互动") { model.interact() }
            iconButton("arrow.uturn.backward", on: false, enabled: model.canPlay && !model.hist.isEmpty, label: "撤回") { model.undo() }
            iconButton("arrow.counterclockwise", on: false, enabled: model.canPlay && !model.hist.isEmpty, label: "重来") { model.reset() }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// What the action button does here, as a picture.
    private var actionIcon: String {
        switch model.actionLabel {
        case "点灯": return "lamp.floor.fill"
        case "摸": return "hand.point.up.left.fill"
        case "抓光": return "hand.raised.fill"
        case "放光": return "flame.fill"
        case "说话": return "ellipsis.bubble.fill"
        default: return "hand.tap"
        }
    }

    private func heroChip(_ h: Hero, on: Bool) -> some View {
        let name = h == .otto ? "otto_idle_E_n" : h == .moss ? "moss_idle_n" : "mosto_idle_n"
        return ZStack {
            Circle().fill(on ? gold.opacity(0.9) : panelBG.opacity(0.92))
            if let ui = Art.uiImage(name) {
                Image(uiImage: ui).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 92, height: 92 * 1.3).offset(y: h == .otto ? 4 : -6)
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(Circle())
        .overlay(Circle().stroke(on ? gold : Color.white.opacity(0.1), lineWidth: on ? 2.5 : 1))
    }

    private func iconButton(_ symbol: String, on: Bool, enabled: Bool, label: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: symbol).font(.system(size: 21, weight: .semibold))
                .frame(width: 54, height: 54)
                .background(on ? gold : panelBG.opacity(0.92), in: Circle())
                .foregroundStyle(on ? Color.black : .white)
                .overlay(Circle().stroke(Color.white.opacity(0.08)))
        }
        .disabled(!enabled).opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
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
        VStack(spacing: 22) {
            Trio().frame(height: 170)
            Text(model.chapter.id == 4 ? "灯台索魔" : "\(["一", "二", "三", "四"][model.chapter.id - 1]) · \(model.chapter.title)")
                .font(.system(size: 28, weight: .semibold, design: .serif)).foregroundStyle(.white).tracking(4)
            Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundStyle(gold)
            Button {
                router.screen = .title
            } label: {
                Image(systemName: "house.fill").font(.title2).frame(width: 64, height: 64).background(gold, in: Circle()).foregroundStyle(.black)
            }
            .accessibilityLabel("回到标题")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(nightBG.opacity(0.96).ignoresSafeArea())
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
