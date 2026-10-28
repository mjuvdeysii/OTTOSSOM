import AVFoundation
import UIKit

/// Synthesised sound: Otto's hum while his bulb is on, a low night wind, and short tones for actions.
/// Everything is generated here; there are no audio files.
final class Sound {
    static let shared = Sound()
    var enabled = true { didSet { hum(humOn) } }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private var format: AVAudioFormat?
    private var started = false
    private var humOn = false
    // shared with the render thread
    private final class Voice { var target: Float = 0; var gain: Float = 0; var p1: Double = 0; var p2: Double = 0; var lfo: Double = 0; var wind: Float = 0; var windGain: Float = 0.012 }
    private let voice = Voice()

    private init() {}

    private func start() {
        guard !started else { return }
        started = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let sr = engine.outputNode.inputFormat(forBus: 0).sampleRate
        let rate = sr > 0 ? sr : 44100
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return }
        format = fmt
        let v = voice
        let src = AVAudioSourceNode { _, _, frameCount, abl -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            for frame in 0..<Int(frameCount) {
                v.gain += (v.target - v.gain) * 0.0008
                v.lfo += 4.2 / rate
                let vib = sin(v.lfo * 2 * .pi) * 1.6
                v.p1 += (110 + vib) / rate
                v.p2 += 165.4 / rate
                if v.p1 > 1 { v.p1 -= 1 }
                if v.p2 > 1 { v.p2 -= 1 }
                if v.lfo > 1 { v.lfo -= 1 }
                let hum = Float(sin(v.p1 * 2 * .pi) + 0.35 * sin(v.p2 * 2 * .pi)) * v.gain
                // wind: low-passed noise
                v.wind += (Float.random(in: -1...1) - v.wind) * 0.02
                let s = hum + v.wind * v.windGain
                for b in buffers {
                    let ptr = b.mData?.assumingMemoryBound(to: Float.self)
                    ptr?[frame] = s
                }
            }
            return noErr
        }
        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: fmt)
        for _ in 0..<4 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: fmt)
            players.append(p)
        }
        engine.mainMixerNode.outputVolume = 0.9
        try? engine.start()
    }

    func hum(_ on: Bool) {
        humOn = on
        start()
        voice.target = (on && enabled) ? 0.05 : 0
        voice.windGain = enabled ? 0.012 : 0
    }

    private func tones(_ freqs: [Double], _ dur: Double, _ vol: Float, square: Bool = false) {
        guard enabled else { return }
        start()
        guard let fmt = format, engine.isRunning else { return }
        let sr = fmt.sampleRate
        let gap = dur * 0.6
        let total = Int((gap * Double(freqs.count - 1) + dur) * sr)
        guard total > 0, let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(total)) else { return }
        buf.frameLength = AVAudioFrameCount(total)
        let out = buf.floatChannelData![0]
        for i in 0..<total { out[i] = 0 }
        for (k, f) in freqs.enumerated() {
            let off = Int(gap * Double(k) * sr), n = Int(dur * sr)
            for i in 0..<n where off + i < total {
                let t = Double(i) / sr
                let env = Float(min(1, t / 0.01) * exp(-t * 6 / dur))
                var w = sin(2 * .pi * f * t)
                if square { w = w > 0 ? 0.6 : -0.6 }
                out[off + i] += Float(w) * env * vol
            }
        }
        let p = players[next % players.count]; next += 1
        p.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        if !p.isPlaying { p.play() }
    }

    func step() { tones([180], 0.06, 0.05) }
    func light() { tones([523, 784, 1046], 0.35, 0.08) }
    func dim() { tones([392, 262, 196], 0.4, 0.08) }
    func take() { tones([660, 990], 0.25, 0.07) }
    func push() { tones([110, 92], 0.12, 0.09) }
    func touch() { tones([880, 1320], 0.3, 0.05) }
    func talk() { tones([660], 0.05, 0.03) }
    func no() { tones([150], 0.12, 0.03, square: true) }
    func win() { tones([392, 523, 659, 784], 0.5, 0.07) }
}

enum Haptic {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func warn() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
