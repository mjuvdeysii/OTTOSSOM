import SwiftUI

/// The title: the three on the table under the lamp, the name and its reflection in the table's lacquer —
/// OTTOSSOM is MOSS OTTO read in a mirror. Tapping the three five times shatters them into the flat 2D world;
/// holding a finger on them for 3 seconds brings the 3D world back (the same easter egg as 摸索台灯).
struct TitleView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var progress: Progress
    @State private var taps = 0
    @State private var lastTap = Date.distantPast
    @State private var shatter = false
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                VStack(spacing: 2) {
                    Text("OTTOSSOM")
                        .font(.system(size: min(54, w * 0.13), weight: .heavy, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE2B0), Color(hex: 0xFFB55C)], startPoint: .top, endPoint: .bottom))
                    Text("OTTOSSOM")
                        .font(.system(size: min(54, w * 0.13), weight: .heavy, design: .rounded))
                        .tracking(4)
                        .scaleEffect(x: 1, y: -1)
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFB55C).opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                        .frame(height: min(54, w * 0.13) * 0.55, alignment: .top)
                        .clipped()
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("OTTOSSOM")
                .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 16)
                trio(width: w)
                Spacer(minLength: 16)
                Button {
                    if progress.solved.isEmpty { router.open(0) } else { router.screen = .map }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(hex: 0x141A33))
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(Color(hex: 0xFFC46E)))
                        .shadow(color: Color(hex: 0xFFB55C).opacity(0.6), radius: breathe ? 22 : 10)
                }
                .accessibilityLabel(progress.solved.isEmpty ? "开始" : "继续")
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear { if !reduce { withAnimation(.easeInOut(duration: 1.8).repeatForever()) { breathe = true } } }
    }

    private func trio(width w: CGFloat) -> some View {
        let s = min(w * 0.42, 220)
        return ZStack(alignment: .bottom) {
            // the lamp's pool of light on the table
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: 0xFFB55C).opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: s * 1.1))
                .frame(width: s * 2.6, height: s * 0.9)
                .offset(y: s * 0.18)
            HStack(alignment: .bottom, spacing: -s * 0.42) {
                figure("moss_wide", size: s).offset(y: s * 0.02)
                figure("otto_idle_W", size: s * 1.0)
                figure("mosto_idle", size: s * 0.92).offset(y: s * 0.04)
            }
            .scaleEffect(shatter ? 1.25 : 1)
            .opacity(shatter ? 0 : 1)
            .blur(radius: shatter ? 8 : 0)
        }
        .frame(height: s * 1.05)
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
        .onLongPressGesture(minimumDuration: 3) { setStyle(.solid) }
        .accessibilityElement()
        .accessibilityLabel("Moss、Otto 和 Mosto")
    }

    private func figure(_ name: String, size: CGFloat) -> some View {
        Group {
            if let img = Art.image(name) { Image(uiImage: img).resizable().scaledToFit() } else { Color.clear }
        }
        .frame(width: size, height: size)
        .id("\(name)-\(router.artEpoch)")
    }

    private func tapped() {
        let now = Date()
        taps = now.timeIntervalSince(lastTap) < 0.9 ? taps + 1 : 1
        lastTap = now
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4 + Double(taps) * 0.12)
        if taps >= 5 { taps = 0; setStyle(.flat) }
    }

    private func setStyle(_ style: ArtStyle) {
        guard ArtStyle.current != style else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeIn(duration: reduce ? 0 : 0.25)) { shatter = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduce ? 0.05 : 0.3)) {
            ArtStyle.current = style
            router.artEpoch += 1
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { shatter = false }
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}
