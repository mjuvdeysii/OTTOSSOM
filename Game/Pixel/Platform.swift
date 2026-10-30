import UIKit
import CoreHaptics

/// The real safe area of the window (the game's views ignore it to draw edge to edge, so they ask here).
enum SafeArea {
    static var window: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
    }
    static var top: CGFloat { window?.safeAreaInsets.top ?? 47 }
    static var bottom: CGFloat { window?.safeAreaInsets.bottom ?? 34 }
}

/// Touch you can feel, in layers: a sharp tick for a crystal, a dull double knock when a shadow drinks the light,
/// a heartbeat when the light is low, a slow swell for a memory, a long rise at the nest. Falls back to the plain
/// impact generators where Core Haptics isn't there.
enum Feel {
    enum Kind { case gem, hurt, heartbeat, memory, nest, hard, light }
    static var engine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        let e = try? CHHapticEngine()
        e?.isAutoShutdownEnabled = true
        e?.resetHandler = { try? engine?.start() }
        try? e?.start()
        return e
    }()

    static func play(_ k: Kind) {
        guard Haptic.on else { return }
        guard let e = engine else { fallback(k); return }
        func tap(_ t: Double, _ i: Float, _ s: Float) -> CHHapticEvent {
            CHHapticEvent(eventType: .hapticTransient, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: i),
                                                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: s)], relativeTime: t)
        }
        func swell(_ t: Double, _ d: Double, _ i: Float) -> CHHapticEvent {
            CHHapticEvent(eventType: .hapticContinuous, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: i),
                                                                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)], relativeTime: t, duration: d)
        }
        var events: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []
        switch k {
        case .gem: events = [tap(0, 0.6, 0.8)]
        case .hurt: events = [tap(0, 1.0, 0.2), tap(0.09, 0.8, 0.2)]
        case .heartbeat: events = [tap(0, 0.7, 0.3), tap(0.14, 0.45, 0.3)]
        case .hard: events = [tap(0, 0.4, 0.1)]
        case .light: events = [tap(0, 0.35, 0.6)]
        case .memory:
            events = [swell(0, 0.8, 1)]
            curves = [CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [.init(relativeTime: 0, value: 0.2), .init(relativeTime: 0.8, value: 0.5)], relativeTime: 0)]
        case .nest:
            events = [swell(0, 1.5, 1)]
            curves = [CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [.init(relativeTime: 0, value: 0.1), .init(relativeTime: 1.5, value: 0.9)], relativeTime: 0)]
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            try e.start()
            try e.makePlayer(with: pattern).start(atTime: 0)
        } catch { fallback(k) }
    }

    private static func fallback(_ k: Kind) {
        switch k {
        case .gem, .light, .hard: Haptic.light()
        case .hurt, .heartbeat: Haptic.warn()
        case .memory, .nest: Haptic.success()
        }
    }
}
