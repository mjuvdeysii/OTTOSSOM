import SwiftUI

/// 每夜躲猫猫: tonight's board, made on the device and proved solvable before it is shown.
struct NightlyView: View {
    @EnvironmentObject var router: Router
    @State private var info: LevelInfo?
    @State private var failed = false
    @AppStorage("nightly.done") private var doneNight = ""
    @AppStorage("nightly.night") private var lastNight = ""

    var body: some View {
        ZStack {
            if let info {
                LevelView(info: info, title: "每夜躲猫猫", number: doneNight == Nightly.night() ? "✓" : "", onDone: { _ in
                    doneNight = Nightly.night()
                    router.screen = .map
                })
            } else {
                VStack(spacing: 16) {
                    if let img = Art.image(failed ? "mosto_blink" : "mosto_idle") {
                        Image(uiImage: img).resizable().scaledToFit().frame(width: 150, height: 150)
                    }
                    if failed {
                        Button { router.screen = .map } label: {
                            Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).frame(width: 54, height: 54)
                                .foregroundStyle(Color(hex: 0xFFE2B0)).background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .accessibilityLabel("返回")
                    } else {
                        ProgressView().tint(Color(hex: 0xFFC46E))
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(failed ? "今晚的珠子没有藏好" : "Mosto 正在藏珠子")
            }
        }
        .task {
            let night = Nightly.night()
            let made = await Task.detached(priority: .userInitiated) { Nightly.make(night: night) }.value
            if let made {
                if lastNight != night { Progress.shared.saveMoves(made.id, []); lastNight = night }
                info = made
            } else { failed = true }
        }
    }
}
