import SpriteKit
import SwiftUI

/// A wordless scene, then its chapter card (the only words of the story), then on to the level.
struct StoryView: View {
    let name: String
    let then: Int?
    @EnvironmentObject var router: Router
    @State private var scene: StoryScene?
    @State private var showCard = false

    var body: some View {
        ZStack {
            if let scene { SpriteView(scene: scene).ignoresSafeArea().accessibilityHidden(true) }
            if showCard, let card = Story.card(name) {
                VStack(spacing: 6) {
                    Text(card.0).font(.system(size: 16, weight: .semibold, design: .rounded)).opacity(0.7)
                    Text(card.1).font(.system(size: 34, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color(hex: 0xFFE2B0))
                .padding(.horizontal, 36).padding(.vertical, 24)
                .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(hex: 0x141A33).opacity(0.86)))
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            VStack {
                HStack {
                    Spacer()
                    Button { done() } label: {
                        Image(systemName: "forward.end.fill").font(.system(size: 15, weight: .semibold))
                            .frame(width: 44, height: 44).foregroundStyle(Color(hex: 0xFFE2B0).opacity(0.75))
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .accessibilityLabel("跳过")
                }
                Spacer()
            }
            .padding(12)
        }
        .onAppear {
            let s = StoryScene(name: name, size: UIScreen.main.bounds.size)
            s.onDone = {
                withAnimation(.easeOut(duration: 0.35)) { showCard = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { done() }
            }
            scene = s
            UIAccessibility.post(notification: .announcement, argument: Story.card(name).map { "\($0.0)，\($0.1)" } ?? "")
        }
    }

    private func done() {
        guard router.screen == .story(name, then: then) else { return }
        Progress.shared.saw(name)
        if let then { router.screen = .play(then) } else { router.screen = .map }
    }
}
