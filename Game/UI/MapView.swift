import SwiftUI

/// The bead path: 37 beads on a string, one for each month, chapter by chapter. Found beads are strung and glow;
/// the next one waits with a soft ring; beads found in the fewest moves carry a mint leaf.
struct MapView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var progress: Progress
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var pulse = false

    private let step: CGFloat = 66

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    ForEach(Levels.chapters, id: \.index) { ch in chapter(ch) }
                    if progress.finishedStory { nightlyCard.padding(.top, 28) }
                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                proxy.scrollTo("bead-\(min(progress.next, max(0, Levels.all.count - 1)))", anchor: .center)
                if !reduce { withAnimation(.easeInOut(duration: 1.2).repeatForever()) { pulse = true } }
            }
        }
    }

    private var header: some View {
        HStack {
            Button { router.screen = .title } label: {
                Image(systemName: "house.fill").font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44).foregroundStyle(Color(hex: 0xFFE2B0))
            }
            .accessibilityLabel("标题")
            Spacer()
            Text("OTTOSSOM").font(.system(size: 17, weight: .heavy, design: .rounded)).tracking(2)
                .foregroundStyle(Color(hex: 0xFFE2B0))
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(Color(hex: 0xE8862A)).frame(width: 10, height: 10)
                Text("\(progress.solved.count)/\(Levels.all.count)").font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color(hex: 0xFFE2B0).opacity(0.8))
            }
            .frame(width: 64, alignment: .trailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("已找回 \(progress.solved.count) 颗珠子，共 \(Levels.all.count) 颗")
        }
        .padding(.top, 8)
    }

    private func chapter(_ ch: Chapter) -> some View {
        let ids = Array(ch.beads).filter { $0 < Levels.all.count }
        return VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(ch.title).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Color(hex: 0xFFE2B0).opacity(0.6))
                Text(ch.place).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(Color(hex: 0xFFE2B0))
            }
            .padding(.top, 28).padding(.bottom, 12)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .topLeading) {
                    // the string
                    Path { p in
                        for (k, id) in ids.enumerated() {
                            let pt = pos(id, k, w)
                            if k == 0 { p.move(to: CGPoint(x: pt.x, y: pt.y - step / 2)) }
                            p.addLine(to: pt)
                        }
                        if let last = ids.indices.last { let pt = pos(ids[last], last, w); p.addLine(to: CGPoint(x: pt.x, y: pt.y + step / 2)) }
                    }
                    .stroke(Color(hex: 0xC9483A).opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    ForEach(Array(ids.enumerated()), id: \.element) { k, id in
                        bead(id).position(pos(id, k, w)).id("bead-\(id)")
                    }
                }
            }
            .frame(height: CGFloat(ids.count) * step)
        }
    }

    private func pos(_ id: Int, _ k: Int, _ w: CGFloat) -> CGPoint {
        CGPoint(x: w / 2 + sin(Double(id) * 1.05) * w * 0.28, y: step / 2 + CGFloat(k) * step)
    }

    @ViewBuilder private func bead(_ id: Int) -> some View {
        let done = progress.solved[id] != nil
        let open = progress.isOpen(id)
        let current = id == progress.next
        Button { router.open(id) } label: {
            ZStack {
                if current {
                    Circle().stroke(Color(hex: 0xFFC46E), lineWidth: 2).frame(width: 56, height: 56)
                        .scaleEffect(pulse ? 1.12 : 0.95).opacity(pulse ? 0.4 : 0.9)
                }
                Circle()
                    .fill(done ? AnyShapeStyle(RadialGradient(colors: [Color(hex: 0xFFC27A), Color(hex: 0xE8862A), Color(hex: 0x9C4E16)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 26))
                          : AnyShapeStyle(Color(hex: 0x2B3566).opacity(open ? 1 : 0.5)))
                    .frame(width: 42, height: 42)
                    .shadow(color: done ? Color(hex: 0xFFB55C).opacity(0.5) : .clear, radius: 8)
                Text("\(id)")
                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(done ? Color(hex: 0x3A1E08) : Color(hex: 0xFFE2B0).opacity(open ? 0.9 : 0.35))
                if progress.perfect(id) {
                    Image(systemName: "leaf.fill").font(.system(size: 12)).foregroundStyle(Color(hex: 0x7FCBA0))
                        .offset(x: 16, y: -16)
                }
            }
            .frame(width: 60, height: 60)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!open)
        .accessibilityLabel("第 \(id) 颗珠子" + (done ? "，已找回" : current ? "，下一颗" : open ? "" : "，未开放"))
    }

    private var nightlyCard: some View {
        Button { router.screen = .nightly } label: {
            HStack(spacing: 14) {
                if let img = Art.image("mosto_idle") { Image(uiImage: img).resizable().scaledToFit().frame(width: 72, height: 72) }
                VStack(alignment: .leading, spacing: 4) {
                    Text("每夜躲猫猫").font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(Color(hex: 0xFFE2B0))
                    Text("Mosto 今晚又藏起了一颗珠子。").font(.system(size: 14, design: .rounded)).foregroundStyle(Color(hex: 0xFFE2B0).opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "moon.stars.fill").foregroundStyle(Color(hex: 0xFFC46E))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: 0x232B4F)))
        }
        .buttonStyle(.plain)
    }
}
