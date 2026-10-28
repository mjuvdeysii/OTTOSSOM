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
    @EnvironmentObject var router: Router
    @State private var tick = 0
    @State private var allOpen = false
    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 24)
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let spec = RoomSpec(id: "title", name: "", day: 60, map: ["#####", "#OMX#", "#####"])
                    let room = Room(spec)
                    let frame = BoardFrame(room: room, state: room.start, prev: nil, e: 1, t: t, active: -1, face: [1, 1, -1], actors: [:],
                                           mainDim: false, dark: 0, hideHeroes: false, bulbR: 0, doudou: false)
                    let T = min(size.width / 3.2, 110)
                    var c = ctx
                    c.translateBy(x: (size.width - T * 3) / 2 - T, y: -T * 0.2)
                    let p = Painter(f: frame, T: T)
                    p.otto(&c, CGPoint(x: 1, y: 1), bulb: true, face: 1)
                    p.moss(&c, CGPoint(x: 2, y: 1), alpha: 1)
                    p.mosto(&c, CGPoint(x: 3, y: 1), alpha: 1, carry: true)
                }
            }
            .frame(height: 150)
            .onTapGesture(count: 5) { allOpen = true; Haptic.success() }
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
                                Text("第\(["一", "二", "三", "四"][ch.id - 1])章").font(.caption).foregroundStyle(mutedText)
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

struct GameView: View {
    @StateObject var model: GameModel
    @EnvironmentObject var router: Router
    @State private var soundOn = Sound.shared.enabled
    @State private var showRules = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button { Sound.shared.hum(false); router.screen = .title } label: { Image(systemName: "chevron.left").font(.headline) }
                    .accessibilityLabel("回到标题")
                Text("第\(["一", "二", "三", "四"][model.chapter.id - 1])章 · \(model.chapter.title)").font(.system(size: 17, weight: .semibold, design: .serif))
                Spacer()
                Text("第 \(model.room.spec.day) 天 · \(model.room.spec.name)").font(.caption).foregroundStyle(mutedText)
            }
            .foregroundStyle(.white)
            board
            Text(model.hint).font(.footnote).foregroundStyle(mutedText).frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 20)
                .accessibilityAddTraits(.updatesFrequently)
            if let d = model.dialog { dialogView(d) } else { controls }
            HStack {
                Button(soundOn ? "声音：开" : "声音：关") { soundOn.toggle(); Sound.shared.enabled = soundOn }
                Spacer()
                Button("怎么玩") { showRules = true }
            }
            .font(.footnote).foregroundStyle(mutedText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.top, 8)
        .frame(maxWidth: 560)
        .onAppear { model.begin() }
        .sheet(isPresented: $showRules) { RulesView() }
        .overlay {
            if model.finished { finishedView }
        }
    }

    private var board: some View {
        let r = model.room
        return GeometryReader { geo in
            let T = floor(min(geo.size.width / CGFloat(r.w), geo.size.height / CGFloat(r.h)))
            TimelineView(.animation) { tl in
                let now = tl.date
                let e = min(1, now.timeIntervalSince(model.animStart) / model.animDur)
                let eased = 1 - pow(1 - e, 3)
                let frame = BoardFrame(room: r, state: model.state, prev: model.prev, e: eased, t: now.timeIntervalSinceReferenceDate,
                                       active: model.active, face: model.face, actors: model.actors, mainDim: model.mainDim, dark: model.dark,
                                       hideHeroes: model.hideHeroes, bulbR: model.bulbR, doudou: Progress.shared.flags.contains("doudou"))
                Canvas { ctx, _ in
                    var c = ctx
                    c.translateBy(x: (geo.size.width - T * CGFloat(r.w)) / 2, y: 0)
                    Painter(f: frame, T: T).draw(&c)
                }
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { v in
                let ox = (geo.size.width - T * CGFloat(r.w)) / 2
                let x = Int(floor((v.location.x - ox) / T)), y = Int(floor(v.location.y / T))
                if x >= 0, y >= 0, x < r.w, y < r.h { model.tap(Pt(x, y)) }
            })
            .overlay {
                if let c = model.card {
                    VStack(spacing: 8) {
                        Text(c.title).font(.system(size: 28, weight: .semibold, design: .serif)).foregroundStyle(.white).tracking(4)
                        if !c.sub.isEmpty { Text(c.sub).font(.callout).foregroundStyle(mutedText) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.86))
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.45), value: model.card)
        }
        .aspectRatio(CGFloat(r.w) / CGFloat(r.h), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("游戏画面：点地面让角色走过去")
    }

    private var controls: some View {
        VStack(spacing: 8) {
            if model.room.heroes.count > 1 {
                HStack(spacing: 8) {
                    ForEach(Array(model.room.heroes.enumerated()), id: \.offset) { i, h in
                        Button { model.select(i) } label: {
                            Text(h == .otto ? "Otto" : h == .moss ? "Moss" : "Mosto")
                                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(i == model.active ? gold : panelBG, in: RoundedRectangle(cornerRadius: 10))
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
                .background(on ? gold : panelBG, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(on ? Color.black : .white)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08)))
        }
        .disabled(!enabled).opacity(enabled ? 1 : 0.4)
    }

    private func dialogView(_ d: Dialog) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !d.who.isEmpty { Text(d.who).font(.caption.weight(.bold)).foregroundStyle(gold) }
            if !d.text.isEmpty { Text(d.text).font(.body).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true) }
            if d.options.isEmpty {
                Text("点一下继续").font(.caption2).foregroundStyle(mutedText).frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                ForEach(Array(d.options.enumerated()), id: \.offset) { i, o in
                    Button { model.answer(i) } label: {
                        Text(o).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            .background(nightBG, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1)))
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBG, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture { if d.options.isEmpty { model.answer(0) } }
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
