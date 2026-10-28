import AVFoundation
import UIKit

/// Synthesised sound: Otto's hum while his bulb is on, a low night wind, and short tones for actions.
/// Everything is generated here; there are no audio files.
final class Sound {
    static let shared = Sound()
    var enabled = true { didSet { hum(humOn); musicPlayer.volume = musicOn && enabled ? 0.55 : 0 } }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private var format: AVAudioFormat?
    private var started = false
    private var humOn = false
    private let musicPlayer = AVAudioPlayerNode()
    private var musicTheme = -1
    private var musicCache: [Int: AVAudioPCMBuffer] = [:]
    var musicOn = true { didSet { musicPlayer.volume = musicOn && enabled ? 0.55 : 0 } }
    // shared with the render thread
    private final class Voice { var target: Float = 0; var gain: Float = 0; var p1: Double = 0; var p2: Double = 0; var lfo: Double = 0; var wind: Float = 0; var windGain: Float = 0.012 }
    private let voice = Voice()

    private init() {
        let d = UserDefaults.standard
        enabled = d.object(forKey: "changye.sound") as? Bool ?? true
        musicOn = d.object(forKey: "changye.music") as? Bool ?? true
    }
    func save() {
        UserDefaults.standard.set(enabled, forKey: "changye.sound")
        UserDefaults.standard.set(musicOn, forKey: "changye.music")
    }

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
        engine.attach(musicPlayer)
        engine.connect(musicPlayer, to: engine.mainMixerNode, format: fmt)
        musicPlayer.volume = 0.55
        engine.mainMixerNode.outputVolume = 0.9
        try? engine.start()
    }

    /// A slow loop for each chapter (0 = title), composed here from a scale, a pad and a few plucked notes.
    func music(_ theme: Int) {
        start()
        guard theme != musicTheme, let fmt = format, engine.isRunning else { return }
        musicTheme = theme
        musicPlayer.stop()
        if let b = musicCache[theme] {
            musicPlayer.scheduleBuffer(b, at: nil, options: [.loops], completionHandler: nil)
            musicPlayer.play(); return
        }
        let sr = fmt.sampleRate
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let buf = Sound.compose(theme, sr: sr, fmt: fmt) else { return }
            DispatchQueue.main.async {
                guard let self, self.musicTheme == theme else { return }
                self.musicCache[theme] = buf
                self.musicPlayer.scheduleBuffer(buf, at: nil, options: [.loops], completionHandler: nil)
                self.musicPlayer.volume = self.musicOn && self.enabled ? 0.55 : 0
                self.musicPlayer.play()
            }
        }
    }

    private static func compose(_ theme: Int, sr: Double, fmt: AVAudioFormat) -> AVAudioPCMBuffer? {
        // per theme: root (Hz), scale steps (semitones), tempo, chord roots (scale degrees), voice colour
        let roots: [Double] = [146.83, 146.83, 220.0, 164.81, 146.83]
        let scales: [[Int]] = [[0, 2, 4, 7, 9], [0, 2, 4, 7, 9], [0, 3, 5, 7, 10], [0, 1, 3, 5, 7, 8, 10], [0, 2, 4, 7, 9, 11]]
        let bpms: [Double] = [56, 60, 72, 66, 64]
        let progressions: [[Int]] = [[0, 3, 4, 2], [0, 4, 3, 0], [0, 2, 3, 1], [0, 1, 3, 2], [0, 3, 4, 0]]
        let t = max(0, min(4, theme))
        let root = roots[t], scale = scales[t], beat = 60 / bpms[t]
        let bars = 8, beatsPerBar = 4
        let total = Int(Double(bars * beatsPerBar) * beat * sr)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(total)) else { return nil }
        buf.frameLength = AVAudioFrameCount(total)
        let out = buf.floatChannelData![0]
        for i in 0..<total { out[i] = 0 }
        func note(_ deg: Int, _ oct: Int) -> Double {
            let n = scale.count
            let d = ((deg % n) + n) % n, o = oct + (deg >= 0 ? deg / n : (deg - n + 1) / n)
            return root * pow(2, Double(scale[d] + 12 * o) / 12)
        }
        func add(_ f: Double, _ at: Double, _ dur: Double, _ vol: Float, pluck: Bool) {
            let s0 = Int(at * sr), n = Int(dur * sr)
            for i in 0..<n {
                let idx = (s0 + i) % total
                let tt = Double(i) / sr
                let env: Double = pluck ? exp(-tt * 3.2) * min(1, tt / 0.004) : sin(.pi * Double(i) / Double(n))
                let w = sin(2 * .pi * f * tt) + (pluck ? 0.25 * sin(4 * .pi * f * tt) : 0.3 * sin(2 * .pi * f * 1.5 * tt))
                out[idx] += Float(w * env) * vol
            }
        }
        var seed: UInt64 = UInt64(theme * 7919 + 17)
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
        let prog = progressions[t]
        for bar in 0..<bars {
            let chord = prog[bar % prog.count]
            let at = Double(bar * beatsPerBar) * beat
            // pad: root, third and fifth of the chord, an octave down, the whole bar
            for k in [0, 2, 4] { add(note(chord + k, -1), at, beat * Double(beatsPerBar) * 1.05, 0.045, pluck: false) }
            // melody: a few plucks on the beat or off, on chord tones mostly
            for b in 0..<beatsPerBar * 2 {
                if rnd() < (theme == 2 ? 0.45 : 0.32) {
                    let deg = chord + [0, 2, 4, 5, 7][Int(rnd() * 5)]
                    add(note(deg, 1), at + Double(b) * beat / 2, beat * 1.6, theme == 3 ? 0.05 : 0.06, pluck: true)
                }
            }
            // Mosto's long tone in his chapter
            if theme == 3 && bar % 4 == 3 { add(note(chord + 4, 0), at, beat * 4, 0.05, pluck: false) }
        }
        return buf
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
    static var on: Bool {
        get { UserDefaults.standard.object(forKey: "changye.haptics") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "changye.haptics") }
    }
    static func light() { if on { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    static func warn() { if on { UINotificationFeedbackGenerator().notificationOccurred(.warning) } }
    static func success() { if on { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
}
