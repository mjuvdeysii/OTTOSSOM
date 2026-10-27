import SwiftUI

@main
struct OttossomApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}

/// Where the player is: the title, the bead path, a level, or a story scene between them.
enum Screen: Equatable {
    case title
    case map
    case play(Int)
    case story(String, then: Int?)     // then: the level to open after the scene (nil: back to the map)
    case nightly
}

final class Router: ObservableObject {
    @Published var screen: Screen = .title
    /// Bumped when the art style changes, so every picture is drawn again.
    @Published var artEpoch = 0

    func open(_ level: Int) {
        let p = Progress.shared
        // a story scene before the level, the first time only
        if let s = Story.before(level), !p.seenScenes.contains(s) { screen = .story(s, then: level); return }
        screen = .play(level)
    }

    func finished(_ level: Int) {
        let p = Progress.shared
        if let s = Story.after(level), !p.seenScenes.contains(s) {
            let next = level + 1 < Levels.all.count ? level + 1 : nil
            screen = .story(s, then: next); return
        }
        if level + 1 < Levels.all.count { open(level + 1) } else { screen = .map }
    }
}

struct RootView: View {
    @StateObject private var router = Router()
    @StateObject private var progress = Progress.shared

    var body: some View {
        ZStack {
            Color(uiColor: BoardScene.night).ignoresSafeArea()
            switch router.screen {
            case .title: TitleView().transition(.opacity)
            case .map: MapView().transition(.opacity)
            case .play(let id): PlayView(level: id).id("\(id)-\(router.artEpoch)").transition(.opacity)
            case .story(let name, let then): StoryView(name: name, then: then).id(name).transition(.opacity)
            case .nightly: NightlyView().id(router.artEpoch).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: router.screen)
        .environmentObject(router)
        .environmentObject(progress)
        .task {
            if ProcessInfo.processInfo.arguments.contains("-snapshots") { await Snapshots.run(router) }
        }
    }
}
