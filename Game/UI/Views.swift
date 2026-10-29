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

enum Screen: Equatable { case title, chapter(Int), snap(Int, String), scene(Int, String, String), rules, adventure(Bool), probe(String) }

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
            case .rules:
                RulesView(upTo: 4)
            case .adventure(let fresh):
                AdventureView(w: World(fresh: fresh)).transition(.opacity)
            case .probe(let what):
                AdventureView(w: World.probe(what)).id(what)
            case .scene(let id, let room, let script):
                if let ch = Content.chapters.first(where: { $0.id == id }) {
                    GameView(model: GameModel.preview(chapter: ch, room: room, script: script)).id(script)
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
    @State private var allOpen = false
    @State private var breathe = false
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                GeometryReader { g in
                    if let ui = Art.uiImage("v_title", ext: "jpg") {
                        // the key art, rendered like the icon: the three on the crest, the sun asleep without its fire
                        Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: g.size.width, height: g.size.height, alignment: .top)
                            .scaleEffect(breathe ? 1.035 : 1.0, anchor: UnitPoint(x: 0.5, y: 0.45))
                            .clipped()
                            .overlay(alignment: .top) {
                                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom).frame(height: g.size.height * 0.28)
                            }
                            .overlay(alignment: .bottom) {
                                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom).frame(height: g.size.height * 0.5)
                            }
                    } else {
                        TitleWorld()
                    }
                }
                .ignoresSafeArea()
                .onAppear { withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { breathe = true } }
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("灯台索魔")
                    .font(.system(size: 46, weight: .heavy, design: .serif))
                    .tracking(12)
                    .foregroundStyle(LinearGradient(colors: [Color(0xfff3d6), Color(0xf2c062)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(0xffb04a).opacity(0.45), radius: 14)
                    .shadow(color: .black.opacity(0.7), radius: 3, y: 2)
                Text("OTTOSSOM").font(.system(size: 12, weight: .semibold, design: .rounded)).tracking(7)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(.top, 36)
            .onTapGesture(count: 5) { allOpen = true; Haptic.success() }
            .onAppear { Sound.shared.music(0) }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 200)
            VStack(spacing: 10) {
                journeyCards
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: 560)
    }

    @State private var confirmNew = false

    /// Continue where the save left off, or start the journey again.
    private var journeyCards: some View {
        VStack(spacing: 10) {
            if World.hasSave, let sv = World.peek() {
                Button { router.screen = .adventure(false) } label: {
                    journeyCard(title: "继续旅程", sub: "\(RPGContent.shared.maps[sv.map]?.name ?? "") · 奥托 Lv\(sv.members.first?.level ?? 1)", icon: "play.fill", primary: true,
                                faces: sv.members.map { $0.hero })
                }
                .buttonStyle(.plain)
            }
            Button {
                if World.hasSave { confirmNew = true } else { router.screen = .adventure(true) }
            } label: {
                journeyCard(title: World.hasSave ? "新的旅程" : "开始旅程", sub: "灯塔城 · 主灯被吞的那一夜", icon: World.hasSave ? "plus" : "play.fill", primary: !World.hasSave, faces: [.otto])
            }
            .buttonStyle(.plain)
            .confirmationDialog("从头开始？现在的进度会被覆盖。", isPresented: $confirmNew, titleVisibility: .visible) {
                Button("从头开始", role: .destructive) { router.screen = .adventure(true) }
            }
        }
    }

    private func journeyCard(title: String, sub: String, icon: String, primary: Bool, faces: [Hero]) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: -14) { ForEach(faces, id: \.self) { h in Face(hero: h).frame(width: 52, height: 52) } }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 20, weight: .bold, design: .serif)).foregroundStyle(.white)
                Text(sub).font(.caption).foregroundStyle(mutedText).lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: icon).font(.system(size: 15, weight: .bold))
                .foregroundStyle(primary ? Color.black : gold)
                .frame(width: 38, height: 38)
                .background(primary ? gold : Color.white.opacity(0.08), in: Circle())
        }
        .padding(.leading, 10).padding(.trailing, 14).padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(panelBG.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(LinearGradient(colors: [Color.white.opacity(primary ? 0.25 : 0.1), Color.white.opacity(0.03)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    private func chapterCard(_ ch: Chapter) -> some View {
        let open = allOpen || Progress.shared.unlocked(ch.id)
        let done = Progress.shared.done.contains(ch.id)
        let rooms = ch.steps.filter { $0.cut == nil }.count
        let at = Progress.shared.step(ch.id)
        let cleared = done ? rooms : ch.steps.prefix(at).filter { $0.cut == nil }.count
        return Button { router.screen = .chapter(ch.id) } label: {
            HStack(spacing: 14) {
                ChapterFaces(hero: ch.hero, open: open)
                VStack(alignment: .leading, spacing: 5) {
                    Text("第\(["一", "二", "三", "四"][ch.id - 1])章").font(.system(size: 12, weight: .semibold, design: .serif)).tracking(2)
                        .foregroundStyle(open ? gold : mutedText)
                    Text(ch.title).font(.system(size: 20, weight: .bold, design: .serif)).foregroundStyle(open ? .white : mutedText)
                    HStack(spacing: 4) {
                        ForEach(0..<rooms, id: \.self) { i in
                            Capsule().fill(i < cleared ? gold : Color.white.opacity(open ? 0.22 : 0.1)).frame(width: 10, height: 3)
                        }
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: done ? "checkmark" : open ? "play.fill" : "lock.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(open ? Color.black : mutedText)
                    .frame(width: 38, height: 38)
                    .background(open ? gold : Color.white.opacity(0.08), in: Circle())
            }
            .padding(.leading, 10).padding(.trailing, 14).padding(.vertical, 10)
            .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(panelBG.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(LinearGradient(colors: [Color.white.opacity(open ? 0.22 : 0.08), Color.white.opacity(0.03)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .environment(\.colorScheme, .dark)
        }
        .buttonStyle(.plain)
        .disabled(!open)
        .accessibilityLabel("第\(ch.id)章 \(ch.title)，已过 \(cleared) / \(rooms) 间\(open ? "" : "，未解锁")")
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

/// Who a chapter belongs to: their faces in round frames, cropped from the game's own sprites.
struct ChapterFaces: View {
    let hero: String
    var open = true
    var body: some View {
        HStack(spacing: -14) {
            ForEach(names, id: \.self) { n in
                ZStack {
                    Circle().fill(RadialGradient(colors: [Color(0x3a4270), Color(0x161a30)], center: .center, startRadius: 2, endRadius: 30))
                    if let ui = Art.uiImage(n) {
                        Image(uiImage: ui).resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 84, height: 84 * 1.3).offset(y: n.hasPrefix("otto") ? 6 : n.hasPrefix("mosto") ? -4 : -6)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(Circle().stroke(open ? gold.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 1.5))
                .saturation(open ? 1 : 0.2).opacity(open ? 1 : 0.6)
            }
        }
        .accessibilityHidden(true)
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
                                           face: [1, 1, -1], actors: [:], mainDim: false, dark: 0, hideHeroes: true, bulbR: 0,
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
        .sheet(isPresented: $showRules) { RulesView(upTo: model.chapter.id) }
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
            VStack(spacing: 6) {
                GoalBar(model: model)
                HStack(spacing: 4) {
                    ForEach(Array(model.chapter.steps.enumerated()).filter { $0.element.cut == nil }, id: \.offset) { i, _ in
                        Capsule().fill(i < model.stepIndex ? gold : i == model.stepIndex ? Color.white.opacity(0.85) : Color.white.opacity(0.15))
                            .frame(height: 3)
                    }
                }
            }
            .frame(maxWidth: .infinity)
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
        VStack(spacing: 10) {
            if model.dialog == nil { CoachLine(model: model) }
            if let d = model.dialog { dialogView(d) } else { controls }
            HStack(spacing: 6) {
                Button { showSettings = true } label: { Image(systemName: "gearshape").frame(width: 40, height: 32) }
                    .accessibilityLabel("设置")
                Button { showRules = true } label: { Image(systemName: "book").frame(width: 40, height: 32) }
                    .accessibilityLabel("怎么玩")
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
                                   hideHeroes: model.hideHeroes, bulbR: model.bulbR, flags: Progress.shared.flags,
                                   hint: model.hintMark, dots: model.pathDots,
                                   tap: model.tapMark.map { ($0.p, now.timeIntervalSince($0.at)) },
                                   extent: CGRect(x: -o.x, y: -o.y, width: size.width, height: size.height), emotes: model.emotes, poses: model.poses, flies: model.flies)
            Canvas { ctx, _ in
                var c = ctx
                let (z, fc) = model.cam.now(now)
                if z > 1.001 {
                    // a scene's close-up: the focus cell glides to the middle of the screen as the room grows
                    let f = CGPoint(x: (fc.x + 0.5) * T, y: (fc.y + 0.5) * T * Art.k)
                    let mid = CGPoint(x: size.width / 2, y: size.height * 0.46)
                    let a = CGFloat(min(1, (z - 1) / 0.35))
                    let anchor = CGPoint(x: o.x + f.x + (mid.x - o.x - f.x) * a, y: o.y + f.y + (mid.y - o.y - f.y) * a)
                    c.translateBy(x: anchor.x, y: anchor.y)
                    c.scaleBy(x: CGFloat(z), y: CGFloat(z))
                    c.translateBy(x: -f.x, y: -f.y)
                } else {
                    c.translateBy(x: o.x, y: o.y)
                }
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
                if let step = model.coach, let cell = step.cell, model.canPlay, !model.walking {
                    GhostHand().position(x: o.x + (CGFloat(cell.x) + 0.5) * T, y: o.y + (CGFloat(cell.y) + 0.5) * T * Art.k)
                        .transition(.opacity)
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
                    Button { model.select(i) } label: { heroChip(h, on: i == model.active).modifier(CoachRing(on: model.coach?.button == "hero\(i)")) }
                        .accessibilityLabel(h == .otto ? "Otto" : h == .moss ? "Moss" : "Mosto")
                        .accessibilityAddTraits(i == model.active ? .isSelected : [])
                }
                Spacer(minLength: 0)
            }
            if model.hero == .otto {
                iconButton(model.state.bulb ? "lightbulb.max.fill" : "lightbulb", on: model.state.bulb,
                           enabled: model.canPlay && !model.room.lockBulb, label: "灯珠") { _ = model.apply(.bulb) }
                    .modifier(CoachRing(on: model.coach?.button == "bulb"))
            }
            iconButton(actionIcon, on: model.actionLabel != nil && model.canPlay, enabled: model.canPlay && model.actionLabel != nil, label: model.actionLabel ?? "互动") { model.interact() }
                .modifier(CoachRing(on: model.coach?.button == "act" || (model.actionLabel != nil && model.canPlay)))
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
                    Text("《灯台索魔》—— 奥托、莫斯与莫斯托的故事。本作在开发过程中使用了 AI 辅助。")
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
                                       face: [1, 1, -1], actors: [:], mainDim: false, dark: 0, hideHeroes: false, bulbR: 0)
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
