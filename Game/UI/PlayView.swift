import SpriteKit
import SwiftUI

/// Keeps one level's scene alive across SwiftUI updates and republishes its changes.
final class PlayModel: ObservableObject {
    let scene: BoardScene
    @Published var moves = 0
    @Published var selected: Actor = .moss
    @Published var won = false
    @Published var canUndo = false

    init(info: LevelInfo) {
        scene = BoardScene(info: info, size: UIScreen.main.bounds.size)
        sync()
        scene.onChange = { [weak self] in self?.sync() }
    }
    func sync() {
        moves = scene.moves.count; selected = scene.selected; canUndo = !scene.moves.isEmpty
    }
}

struct PlayView: View {
    let level: Int
    var info: LevelInfo? { level < Levels.all.count ? Levels.all[level] : nil }

    var body: some View {
        if let info { LevelView(info: info, title: Levels.chapter(of: level).place, number: "\(level)") }
        else { Color.clear }
    }
}

/// A board with its controls. Used by the story levels and by 每夜躲猫猫.
struct LevelView: View {
    let info: LevelInfo
    let title: String
    let number: String
    var onDone: ((Int) -> Void)? = nil
    @EnvironmentObject var router: Router
    @StateObject private var model: PlayModel
    @State private var showWin = false

    init(info: LevelInfo, title: String, number: String, onDone: ((Int) -> Void)? = nil) {
        self.info = info; self.title = title; self.number = number; self.onDone = onDone
        _model = StateObject(wrappedValue: PlayModel(info: info))
    }

    var body: some View {
        ZStack {
            SpriteView(scene: model.scene)
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel(BoardSpeech.describe(model.scene))
                .accessibilityActions { accessibilityMoves }
            VStack(spacing: 0) {
                topBar
                Spacer()
                companions
            }
            .padding(.horizontal, 12)
            if showWin { winCard.transition(.opacity.combined(with: .scale(scale: 0.96))) }
        }
        .onAppear {
            model.scene.onWin = { _ in withAnimation(.easeOut(duration: 0.3)) { showWin = true } }
        }
    }

    private var topBar: some View {
        HStack(spacing: 4) {
            icon("chevron.left", "珠子小路") { router.screen = onDone == nil ? .map : .map }
            Spacer()
            VStack(spacing: 0) {
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
                Text(number).font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit()).opacity(0.65)
            }
            .foregroundStyle(Color(hex: 0xFFE2B0))
            .accessibilityElement(children: .combine)
            Spacer()
            icon("lightbulb", "提示") { model.scene.hint() }
            icon("arrow.uturn.backward", "撤销") { model.scene.undo() }.disabled(!model.canUndo).opacity(model.canUndo ? 1 : 0.35)
            icon("arrow.counterclockwise", "重来") { model.scene.restart() }.disabled(!model.canUndo).opacity(model.canUndo ? 1 : 0.35)
        }
        .padding(.top, 6)
    }

    private func icon(_ name: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(Color(hex: 0xFFE2B0))
                .background(Circle().fill(Color.white.opacity(0.06)))
        }
        .accessibilityLabel(label)
    }

    /// Who moves next: Moss or Otto. A tap on a companion on the board does the same; a swipe that starts on a
    /// companion moves that one.
    private var companions: some View {
        HStack(spacing: 18) {
            chooser(.moss, "moss_idle", "Moss")
            chooser(.otto, "otto_idle_S", "Otto")
        }
        .padding(.bottom, 18)
    }

    private func chooser(_ a: Actor, _ img: String, _ label: String) -> some View {
        let on = model.selected == a
        return Button { model.scene.selected = a } label: {
            ZStack {
                Circle().fill(on ? Color(hex: 0xFFC46E).opacity(0.22) : Color.white.opacity(0.06))
                Circle().stroke(on ? Color(hex: 0xFFC46E) : Color.white.opacity(0.12), lineWidth: on ? 2.5 : 1)
                if let i = Art.image(img) {
                    Image(uiImage: i).resizable().scaledToFill().frame(width: 92, height: 92).offset(y: 14)
                        .clipShape(Circle()).frame(width: 64, height: 64)
                }
            }
            .frame(width: 64, height: 64)
            .scaleEffect(on ? 1.06 : 0.94)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: on)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var winCard: some View {
        let par = info.par, moves = model.moves
        return VStack(spacing: 18) {
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(hex: 0xFFC27A), Color(hex: 0xE8862A), Color(hex: 0x9C4E16)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 2, endRadius: 40))
                    .frame(width: 66, height: 66).shadow(color: Color(hex: 0xFFB55C).opacity(0.7), radius: 18)
                if moves <= par {
                    Image(systemName: "leaf.fill").font(.system(size: 18)).foregroundStyle(Color(hex: 0x7FCBA0)).offset(x: 26, y: -26)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "figure.walk").font(.system(size: 13))
                Text("\(moves)").font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                if moves > par { Text("/ \(par)").font(.system(size: 15, design: .rounded).monospacedDigit()).opacity(0.6) }
            }
            .foregroundStyle(Color(hex: 0xFFE2B0))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("用了 \(moves) 步，最少 \(par) 步")
            HStack(spacing: 14) {
                Button { showWin = false; model.scene.removeAllActions(); router.screen = .map } label: {
                    Image(systemName: "circle.grid.3x3.fill").font(.system(size: 18, weight: .semibold)).frame(width: 54, height: 54)
                        .foregroundStyle(Color(hex: 0xFFE2B0)).background(Circle().fill(Color.white.opacity(0.08)))
                }
                .accessibilityLabel("珠子小路")
                Button {
                    showWin = false
                    if let onDone { onDone(moves) } else if let id = Int(number) { router.finished(id) }
                } label: {
                    Image(systemName: "arrow.right").font(.system(size: 22, weight: .bold)).frame(width: 72, height: 72)
                        .foregroundStyle(Color(hex: 0x141A33)).background(Circle().fill(Color(hex: 0xFFC46E)))
                }
                .accessibilityLabel("继续")
            }
        }
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color(hex: 0x1B2245).opacity(0.94)))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color(hex: 0xFFC46E).opacity(0.25)))
    }

    @ViewBuilder private var accessibilityMoves: some View {
        ForEach([Actor.moss, .otto], id: \.rawValue) { a in
            ForEach(Dir.allCases, id: \.rawValue) { d in
                Button("\(a == .moss ? "Moss" : "Otto") \(["向上", "向右", "向下", "向左"][d.rawValue])") {
                    model.scene.selected = a
                    model.scene.perform(Move(actor: a, dir: d))
                }
            }
        }
        Button("撤销") { model.scene.undo() }
        Button("提示") { model.scene.hint() }
    }
}

/// What VoiceOver reads for the board.
enum BoardSpeech {
    static func describe(_ s: BoardScene) -> String {
        let b = s.board, st = s.state, lit = b.lit(st)
        func at(_ i: Int) -> String { "第 \(b.y(i) + 1) 行第 \(b.x(i) + 1) 列" }
        var parts = ["Moss 在\(at(st.moss))", "Otto 在\(at(st.otto))，灯朝\(["北", "东", "南", "西"][st.facing.rawValue])"]
        if st.mosto >= 0 { parts.append("Mosto 在\(at(st.mosto))\(lit & bit(st.mosto) != 0 ? "，被照见" : "，在暗处")") }
        if b.bead >= 0 { parts.append("珠子在\(at(b.bead))") }
        if b.crown >= 0 { parts.append("王冠在\(at(b.crown))") }
        let around = Dir.allCases.compactMap { d -> String? in
            let x = b.x(st.moss) + d.dx, y = b.y(st.moss) + d.dy
            guard b.inside(x, y) else { return nil }
            return "\(["上", "右", "下", "左"][d.rawValue])\(lit & bit(y * b.width + x) != 0 ? "亮" : "暗")"
        }
        parts.append("Moss 四周：" + around.joined(separator: "、"))
        return parts.joined(separator: "；")
    }
}
