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

    /// Each chapter has its own written theme, built from the three characters' voices (the character bible):
    /// Otto a low warm hum (C3), Moss a short bright pluck (G5), Mosto a long tone that slides up from a semitone below.
    /// 0 = title (all three, sparse), 1 = Otto, 2 = Moss, 3 = Mosto, 4 = the chase (all three, together).
    private enum Timbre { case hum, pluck, glide, pad }
    private struct Note { var at: Double; var len: Double; var midi: Int; var voice: Timbre; var vol: Float }

    private static func score(_ theme: Int) -> (bpm: Double, beats: Double, notes: [Note]) {
        var n: [Note] = []
        func add(_ v: Timbre, _ vol: Float, _ seq: [(Double, Double, Int)]) { for (a, l, m) in seq { n.append(Note(at: a, len: l, midi: m, voice: v, vol: vol)) } }
        // pads: a slow progression under everything (C, Am, F, G — the lamp-lit town)
        let padC = [48, 52, 55], padAm = [45, 48, 52], padF = [41, 45, 48], padG = [43, 47, 50], padEm = [40, 43, 47]
        func pads(_ chords: [[Int]], _ vol: Float) { for (i, c) in chords.enumerated() { for m in c { n.append(Note(at: Double(i) * 4, len: 4.3, midi: m, voice: .pad, vol: vol)) } } }
        // Otto: slow, low, warm — it rises a little and settles, like someone too tired to sing loud
        let otto: [(Double, Double, Int)] = [(0, 2, 48), (2, 1, 52), (3, 1, 55), (4, 3, 57), (7, 1, 55), (8, 2, 53), (10, 2, 52), (12, 4, 50),
                                              (16, 2, 48), (18, 1, 52), (19, 1, 55), (20, 2, 60), (22, 2, 59), (24, 3, 57), (27, 1, 55), (28, 4, 48)]
        // Moss: quick and curious, a little figure that keeps poking at the same note
        let moss: [(Double, Double, Int)] = [(0, 0.5, 79), (0.5, 0.5, 81), (1, 0.5, 79), (2, 0.5, 76), (3, 1, 79), (4, 0.5, 84), (4.5, 0.5, 83), (5, 1, 81),
                                              (6, 0.5, 79), (7, 1, 76), (8, 0.5, 79), (8.5, 0.5, 81), (9, 0.5, 84), (10, 1, 86), (11, 0.5, 84), (12, 2, 79),
                                              (16, 0.5, 79), (16.5, 0.5, 79), (17, 0.5, 81), (18, 1, 76), (20, 0.5, 74), (20.5, 0.5, 76), (21, 1, 79), (22, 2, 81),
                                              (24, 0.5, 84), (25, 0.5, 81), (26, 0.5, 79), (27, 1, 76), (28, 2, 79), (30, 1, 74)]
        // Mosto: long tones that slide up into place, in a minor key, with a grin of a half step
        let mosto: [(Double, Double, Int)] = [(0, 3, 57), (3, 1, 56), (4, 4, 60), (8, 3, 59), (11, 1, 57), (12, 4, 64), (16, 3, 65), (19, 1, 64),
                                               (20, 4, 60), (24, 2, 62), (26, 2, 63), (28, 4, 57)]
        // the second half answers the first: the chapter's melody again, softer, with the next
        // character's motif creeping in under it (Otto → Moss → Mosto → all), and a slow bass on the chord roots
        func second(_ base: [Note], _ answer: [(Double, Double, Int)], _ voice: Timbre, _ vol: Float) -> [Note] {
            var out = base.map { var x = $0; x.at += 32; if x.voice != .pad { x.vol *= 0.7 }; return x }
            for (a, l, m) in answer { out.append(Note(at: a + 32, len: l, midi: m, voice: voice, vol: vol)) }
            return out
        }
        func bass(_ roots: [Int], _ vol: Float) -> [Note] {
            roots.enumerated().map { Note(at: Double($0.offset) * 4, len: 3.6, midi: $0.element, voice: .hum, vol: vol) }
        }
        let bpm: Double
        switch theme {
        case 1:
            pads([padC, padAm, padF, padG, padC, padAm, padF, padC], 0.035)
            add(.hum, 0.11, otto)
            bpm = 58
        case 2:
            pads([padC, padEm, padF, padC, padAm, padEm, padF, padG], 0.03)
            add(.pluck, 0.07, moss)
            add(.hum, 0.05, [(0, 4, 48), (8, 4, 53), (16, 4, 45), (24, 4, 43)])
            bpm = 76
        case 3:
            pads([padAm, padF, padAm, padEm, padAm, padF, padG, padAm], 0.032)
            add(.glide, 0.08, mosto)
            add(.pluck, 0.035, [(2, 0.5, 69), (6, 0.5, 68), (14, 0.5, 72), (22, 0.5, 71), (30, 0.5, 69)])
            bpm = 66
        case 4:
            pads([padAm, padF, padC, padG, padAm, padF, padG, padC], 0.035)
            add(.glide, 0.06, mosto)
            add(.hum, 0.08, otto)
            add(.pluck, 0.045, moss.filter { $0.0 >= 16 })
            bpm = 70
        default:
            pads([padC, padAm, padF, padG, padC, padAm, padF, padC], 0.03)
            add(.hum, 0.08, otto.filter { $0.0 < 16 })
            add(.pluck, 0.05, moss.filter { $0.0 >= 16 })
            add(.glide, 0.05, [(28, 4, 59)])   // at the very end, Mosto's tone slides up into Otto's
            bpm = 56
        }
        let first = n
        let roots: [Int]
        var answer: [(Double, Double, Int)] = [], av: Timbre = .pluck, avol: Float = 0.03
        switch theme {
        case 1: roots = [36, 33, 29, 31, 36, 33, 29, 36]; answer = moss.filter { $0.0 < 16 }; av = .pluck; avol = 0.03
        case 2: roots = [36, 28, 29, 36, 33, 28, 29, 31]; answer = mosto.filter { $0.0 < 16 }; av = .glide; avol = 0.035
        case 3: roots = [33, 29, 33, 28, 33, 29, 31, 33]; answer = otto.filter { $0.0 >= 16 }; av = .hum; avol = 0.05
        case 4: roots = [33, 29, 36, 31, 33, 29, 31, 36]; answer = mosto.map { ($0.0, $0.1, $0.2 + 12) }; av = .glide; avol = 0.03
        default: roots = [36, 33, 29, 31, 36, 33, 29, 36]; answer = moss.filter { $0.0 < 16 }; av = .pluck; avol = 0.025
        }
        var all = first + second(first, answer, av, avol)
        all += bass((roots + roots).map { $0 + 12 }, 0.04)
        return (bpm, 64, all)
    }

    private static func compose(_ theme: Int, sr: Double, fmt: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sc = score(theme)
        return render(sc.notes, bpm: sc.bpm, beats: sc.beats, sr: sr, fmt: fmt, wrap: true)
    }

    private static func render(_ notes: [Note], bpm: Double, beats: Double, sr: Double, fmt: AVAudioFormat, wrap: Bool) -> AVAudioPCMBuffer? {
        let sc = (bpm: bpm, beats: beats, notes: notes)
        let beat = 60 / sc.bpm
        let total = Int(sc.beats * beat * sr)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(total)) else { return nil }
        buf.frameLength = AVAudioFrameCount(total)
        let out = buf.floatChannelData![0]
        for i in 0..<total { out[i] = 0 }
        func hz(_ m: Double) -> Double { 440 * pow(2, (m - 69) / 12) }
        for note in sc.notes {
            let s0 = Int(note.at * beat * sr), len = note.len * beat, n = Int((len + (note.voice == .pluck ? 0.6 : 0.25)) * sr)
            var phase = 0.0, phase2 = 0.0
            for i in 0..<n {
                let tt = Double(i) / sr
                var f = hz(Double(note.midi)), env = 0.0, w = 0.0
                switch note.voice {
                case .pluck:
                    env = exp(-tt * 4.5) * min(1, tt / 0.003)
                    phase += f / sr; w = sin(2 * .pi * phase) + 0.3 * sin(4 * .pi * phase) * exp(-tt * 9)
                case .hum:
                    let a = min(1, tt / 0.25), r = max(0, min(1, (len + 0.2 - tt) / 0.35))
                    env = a * r
                    f *= 1 + 0.004 * sin(2 * .pi * 4.6 * tt)
                    phase += f / sr; phase2 += f * 2 / sr
                    w = sin(2 * .pi * phase) + 0.28 * sin(2 * .pi * phase2) + 0.12 * sin(2 * .pi * phase * 3)
                case .glide:
                    let slide = max(0, 1 - tt / 0.35)          // from a semitone below, up into the note
                    f = hz(Double(note.midi) - slide)
                    let a = min(1, tt / 0.3), r = max(0, min(1, (len + 0.2 - tt) / 0.5))
                    env = a * r
                    phase += f / sr; phase2 += f * 1.5 / sr
                    w = sin(2 * .pi * phase) + 0.18 * sin(2 * .pi * phase2)
                case .pad:
                    env = sin(.pi * min(1, tt / (len + 0.25)))
                    phase += f / sr
                    w = sin(2 * .pi * phase) + 0.2 * sin(2 * .pi * phase * 2.003)
                }
                let k = s0 + i
                if wrap { out[k % total] += Float(w * env) * note.vol } else if k < total { out[k] += Float(w * env) * note.vol }
            }
        }
        // a soft limiter, so stacked voices never clip
        for i in 0..<total { out[i] = tanhf(out[i] * 1.4) / 1.4 }
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

    /// A character's motif, a few notes in their own voice, for the moments that are theirs.
    enum Who { case otto, moss, mosto }
    func motif(_ who: Who) {
        guard enabled else { return }
        start()
        guard let fmt = format, engine.isRunning else { return }
        let notes: [Note]
        switch who {
        case .otto: notes = [Note(at: 0, len: 0.8, midi: 60, voice: .hum, vol: 0.09), Note(at: 0.6, len: 1.2, midi: 64, voice: .hum, vol: 0.08)]
        case .moss: notes = [Note(at: 0, len: 0.3, midi: 79, voice: .pluck, vol: 0.07), Note(at: 0.25, len: 0.3, midi: 81, voice: .pluck, vol: 0.07),
                             Note(at: 0.5, len: 0.6, midi: 84, voice: .pluck, vol: 0.07)]
        case .mosto: notes = [Note(at: 0, len: 0.9, midi: 57, voice: .glide, vol: 0.08), Note(at: 0.7, len: 1.0, midi: 60, voice: .glide, vol: 0.07)]
        }
        guard let buf = Sound.render(notes, bpm: 90, beats: 3, sr: fmt.sampleRate, fmt: fmt, wrap: false) else { return }
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
    // the dig: each ground has its own sound
    func digSoft() { tones([96, 72], 0.07, 0.07) }
    func digClay() { tones([82, 64], 0.09, 0.08, square: true) }
    func digStone() { tones([620, 410], 0.06, 0.05, square: true) }
    func chime(_ k: Int) { tones([[1046, 1568], [1175, 1760], [880, 1318]][k % 3], 0.4, 0.06) }
    func heartbeat() { tones([58, 52], 0.12, 0.09) }
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
