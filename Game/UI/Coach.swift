import SwiftUI

// Teaching the game: the goal at the top in pictures, a one-line coach above the buttons, a ghost hand on the cell or
// a ring on the button to use next, and a picture book of the rules where every page plays itself.

/// What this room asks for, in pictures, left to right: the lamps (or nests, or the fire, or Mosto shut in), the key,
/// then the exit. Each turns gold once it's done.
struct GoalBar: View {
    @ObservedObject var model: GameModel

    private struct Item: Identifiable { let id: String; let icon: String; let text: String?; let done: Bool; let label: String }

    private var items: [Item] {
        let r = model.room, s = model.state
        var out: [Item] = []
        let lamps = r.lampPos.indices.filter { !r.nest[$0] }
        let nests = r.lampPos.indices.filter { r.nest[$0] }
        switch r.goal {
        case "none": break
        case "trap":
            out.append(Item(id: "trap", icon: "lock.fill", text: nil, done: r.trapped(s), label: "把莫斯托四面围住"))
        case "carry":
            out.append(Item(id: "carry", icon: "flame.fill", text: s.carry ? "1/1" : "0/1", done: s.carry, label: "抓走太阳的火"))
        case "nests":
            let n = nests.filter { s.lit[$0] }.count
            out.append(Item(id: "nests", icon: "flame.fill", text: "\(n)/\(nests.count)", done: n == nests.count, label: "把光放进窝里，\(n)/\(nests.count)"))
        default:
            if !lamps.isEmpty {
                let n = lamps.filter { s.lit[$0] }.count
                out.append(Item(id: "lamps", icon: "lamp.floor.fill", text: "\(n)/\(lamps.count)", done: n == lamps.count, label: "点亮的灯，\(n)/\(lamps.count)"))
            }
        }
        if r.needKey {
            out.append(Item(id: "key", icon: r.spec.goal == "none" ? "hand.point.up.left.fill" : "key.fill", text: nil, done: r.keyGiven,
                            label: r.spec.goal == "none" ? "摸石碑" : "把钥匙交给汉克"))
        }
        if r.goal != "trap" {
            let open = r.exitOpen(s)
            out.append(Item(id: "exit", icon: open ? "door.left.hand.open" : "door.left.hand.closed", text: nil, done: open,
                            label: open ? "出口开着" : "出口关着"))
        }
        return out
    }

    var body: some View {
        let list = items
        HStack(spacing: 6) {
            ForEach(Array(list.enumerated()), id: \.element.id) { i, it in
                if i > 0 { Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(mutedText.opacity(0.7)) }
                HStack(spacing: 3) {
                    Image(systemName: it.icon).font(.system(size: 13, weight: .semibold))
                    if let t = it.text { Text(t).font(.system(size: 13, weight: .semibold).monospacedDigit()) }
                }
                .foregroundStyle(it.done ? Color.black : Color.white.opacity(0.85))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(it.done ? gold : Color.black.opacity(0.4), in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(it.label)
            }
        }
        .fixedSize()
        .animation(.spring(duration: 0.35), value: list.map { "\($0.id)\($0.done)\($0.text ?? "")" })
    }
}

/// The coach: what to do now, in a few words, with its icon. A passing remark (why a move didn't work, a hint) takes
/// its place for a few seconds.
struct CoachLine: View {
    @ObservedObject var model: GameModel
    var body: some View {
        Group {
            if !model.hint.isEmpty {
                line(icon: "info.circle.fill", text: model.hint, tint: mutedText)
            } else if let c = model.coach {
                line(icon: c.icon, text: c.text, tint: gold).id(c.text)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.hint)
        .animation(.easeInOut(duration: 0.25), value: model.coach)
    }

    private func line(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(tint).frame(width: 24)
            Text(text).font(.subheadline.weight(.medium)).foregroundStyle(.white)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(panelBG.opacity(0.92), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.35), lineWidth: 1))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// A gold ring breathing round the button the coach means.
struct CoachRing: ViewModifier {
    let on: Bool
    func body(content: Self.Content) -> some View {
        content.overlay {
            if on {
                TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                    let k = (sin(tl.date.timeIntervalSinceReferenceDate * 4) + 1) / 2
                    Circle().stroke(gold.opacity(0.35 + 0.55 * k), lineWidth: 2.5).scaleEffect(1.04 + 0.12 * k)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

/// A ghost finger tapping the cell the coach means.
struct GhostHand: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
            let press = t < 0.35 ? t / 0.35 : t < 0.5 ? 1 : max(0, 1 - (t - 0.5) / 0.3)
            ZStack {
                Circle().stroke(gold.opacity(0.9 * (1 - t)), lineWidth: 2.5).frame(width: 18 + 34 * t, height: 18 + 34 * t)
                Circle().fill(gold.opacity(0.25)).frame(width: 22, height: 22)
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                    .offset(x: 14, y: 22 - 8 * press)
                    .scaleEffect(1 - 0.08 * press)
            }
        }
        .frame(width: 70, height: 80)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: the picture book

struct RuleDemo: Identifiable {
    let id: String
    let chapter: Int
    let title: String
    let line: String
    let spec: RoomSpec
    let script: [(Int, Verb)]

    init(_ id: String, _ chapter: Int, _ title: String, _ line: String, _ map: [String], goal: String? = nil, rOtto: Int? = nil, _ script: String) {
        self.id = id; self.chapter = chapter; self.title = title; self.line = line
        spec = RoomSpec(id: "demo_\(id)", name: title, day: 0, map: map, rOtto: rOtto, goal: goal)
        self.script = script.split(separator: " ").compactMap { a in
            let p = a.split(separator: ":")
            guard p.count == 2, let ci = Int(p[0]), let v = Verb(rawValue: String(p[1])) else { return nil }
            return (ci, v)
        }
    }

    /// Every page plays a tiny room with the real rules (checked against Tools/rooms/core.js).
    static let all: [RuleDemo] = [
        RuleDemo("walk", 1, "走", "点地面，角色就走过去。走错了可以撤回或重来。", ["#######", "#O...E#", "#######"], "0:right 0:right 0:right 0:right"),
        RuleDemo("light", 1, "点灯", "站到暗灯旁边，点「点灯」。灯全亮了，出口才开。", ["#####", "#.L.#", "#...#", "#.O.#", "#####"], "0:up 0:light"),
        RuleDemo("bulb", 1, "灯珠引影子", "打开灯珠，够得着的影子每一步朝它挪一格。影子挡路，人过不去。",
                 ["#######", "#S....#", "#....O#", "#######"], rOtto: 4, "0:bulb 0:left 0:left"),
        RuleDemo("crowd", 1, "影子压灯", "一盏亮灯边挤了两个影子，灯就暗了。挨着影子的暗灯点不着。", ["#######", "#S.l.S#", "#..O..#", "#######"], "0:bulb"),
        RuleDemo("push", 2, "推石头", "莫斯往石头上走就能推动它。压板被压住，门就开。",
                 ["#######", "###E###", "###D###", "#M.B.P#", "#######"], goal: "none", "0:right 0:right 0:right 0:left 0:up 0:up"),
        RuleDemo("carry", 3, "抓光 · 放光", "莫斯托从亮灯里抓走光，放进暗灯或窝里。他能飞过水，也能穿过影子。",
                 ["########", "#l.X~.N#", "########"], goal: "nests", "0:left 0:take 0:right 0:right 0:right 0:give"),
        RuleDemo("steal", 4, "莫斯托偷光", "你每做一步，他也动一步：朝最近的亮灯飞，到了就偷走光。",
                 ["#####", "#.l.#", "#...#", "#W.O#", "#####"], goal: "trap", "0:bulb 0:bulb 0:bulb"),
        RuleDemo("trap", 4, "关住他", "墙、灯、石头、关着的门把他四面堵住，就抓到了。人站着不算。",
                 ["########", "###l####", "###.####", "#W...BM#", "########"], goal: "trap", "0:left 0:right 0:left 0:left"),
    ]
}

struct DemoBoard: View {
    let demo: RuleDemo
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            Canvas { ctx, size in
                let room = Room(demo.spec)
                let now = tl.date.timeIntervalSinceReferenceDate
                let t = now / 0.9
                let k = Int(t) % (demo.script.count + 3)
                let frac = t - floor(t)
                let played = DemoBoard.play(room, demo.script, upTo: min(k, demo.script.count))
                let animating = k >= 1 && k <= demo.script.count
                let e = animating ? 1 - pow(1 - min(1, frac * 3), 3) : 1
                let T = min(size.width / CGFloat(room.w), size.height / (CGFloat(room.h) * Art.k + 0.9))
                let ox = (size.width - T * CGFloat(room.w)) / 2
                let oy = (size.height - T * CGFloat(room.h) * Art.k) / 2 + T * 0.35
                let frame = BoardFrame(room: room, state: played.0, prev: animating ? played.1 : nil, e: e, t: now,
                                       active: played.3, face: played.2, actors: [:], mainDim: false, dark: 0.2, hideHeroes: false,
                                       bulbR: Double(room.rOtto))
                var c = ctx
                c.translateBy(x: ox, y: oy)
                Stage(f: frame, T: T).draw(&c)
            }
        }
        .accessibilityHidden(true)
    }

    static func play(_ room: Room, _ script: [(Int, Verb)], upTo k: Int) -> (GameState, GameState?, [Int], Int) {
        var s = room.start, prev: GameState? = nil, face = [1, 1, 1], active = 0
        for i in 0..<k {
            let (ci, v) = script[i]
            prev = s; active = ci
            if v == .left { face[ci] = -1 } else if v == .right { face[ci] = 1 }
            if let nx = room.step(s, ci, v) { s = nx }
        }
        return (s, prev, face, active)
    }
}

struct RulesView: View {
    @Environment(\.dismiss) var dismiss
    var upTo: Int = 4
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(RuleDemo.all.filter { $0.chapter <= max(upTo, Progress.shared.done.max() ?? 0) }) { d in
                        VStack(alignment: .leading, spacing: 8) {
                            DemoBoard(demo: d)
                                .frame(height: 150)
                                .frame(maxWidth: .infinity)
                                .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text(d.title).font(.headline).foregroundStyle(gold)
                            Text(d.line).font(.subheadline).foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(panelBG, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(16)
            }
            .background(nightBG.ignoresSafeArea())
            .navigationTitle("怎么玩")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("好") { dismiss() } }
        }
        .preferredColorScheme(.dark)
    }
}
