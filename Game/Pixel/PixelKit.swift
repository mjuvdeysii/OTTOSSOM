import UIKit

// A tiny pixel renderer: everything is drawn into one small RGBA framebuffer, one game pixel at a time, and shown
// magnified with nearest-neighbour filtering — so sprites, the thread, the trail and the light all sit on the same
// pixel grid. Colours are UInt32 in memory order R, G, B, A (written 0xAABBGGRR).

struct PSprite {
    let w: Int, h: Int
    let px: [UInt32]
}

enum PixelArt {
    static var cache: [String: PSprite] = [:]

    static func sprite(_ name: String) -> PSprite? {
        if let s = cache[name] { return s }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Pixel")
                ?? Bundle.main.url(forResource: name, withExtension: "png"),
              let img = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
        let s = decode(img)
        cache[name] = s
        return s
    }

    static func decode(_ img: CGImage) -> PSprite {
        let w = img.width, h = img.height
        var buf = [UInt32](repeating: 0, count: w * h)
        buf.withUnsafeMutableBytes { raw in
            let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return PSprite(w: w, h: h, px: buf)
    }

    static func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: Int = 255) -> UInt32 {
        UInt32(a) << 24 | UInt32(b) << 16 | UInt32(g) << 8 | UInt32(r)
    }
    static func hex(_ h: UInt32) -> UInt32 { rgb(Int(h >> 16 & 0xff), Int(h >> 8 & 0xff), Int(h & 0xff)) }
}

struct Frame {
    let w: Int, h: Int
    var px: [UInt32]
    var ox = 0, oy = 0          // camera offset (screen shake)

    init(w: Int, h: Int) { self.w = w; self.h = h; px = [UInt32](repeating: 0xFF000000, count: w * h) }

    @inline(__always) mutating func set(_ x: Int, _ y: Int, _ c: UInt32) {
        let X = x + ox, Y = y + oy
        if X >= 0 && Y >= 0 && X < w && Y < h { px[Y * w + X] = c }
    }
    @inline(__always) func get(_ x: Int, _ y: Int) -> UInt32 { x >= 0 && y >= 0 && x < w && y < h ? px[y * w + x] : 0 }

    /// A coloured pixel blended over what's there (k: 0…1).
    @inline(__always) mutating func blend(_ x: Int, _ y: Int, _ c: UInt32, _ k: Double) {
        let X = x + ox, Y = y + oy
        guard X >= 0 && Y >= 0 && X < w && Y < h else { return }
        let i = Y * w + X, d = px[i]
        func ch(_ v: UInt32, _ s: UInt32) -> UInt32 { (v >> s) & 0xff }
        let r = UInt32(Double(ch(d, 0)) * (1 - k) + Double(ch(c, 0)) * k)
        let g = UInt32(Double(ch(d, 8)) * (1 - k) + Double(ch(c, 8)) * k)
        let b = UInt32(Double(ch(d, 16)) * (1 - k) + Double(ch(c, 16)) * k)
        px[i] = 0xFF000000 | b << 16 | g << 8 | r
    }

    /// Lighten (add) a colour.
    @inline(__always) mutating func add(_ x: Int, _ y: Int, _ c: UInt32, _ k: Double) {
        let X = x + ox, Y = y + oy
        guard X >= 0 && Y >= 0 && X < w && Y < h else { return }
        let i = Y * w + X, d = px[i]
        func ch(_ v: UInt32, _ s: UInt32) -> Double { Double((v >> s) & 0xff) }
        let r = UInt32(min(255, ch(d, 0) + ch(c, 0) * k)), g = UInt32(min(255, ch(d, 8) + ch(c, 8) * k)), b = UInt32(min(255, ch(d, 16) + ch(c, 16) * k))
        px[i] = 0xFF000000 | b << 16 | g << 8 | r
    }

    mutating func clear(_ c: UInt32) { for i in px.indices { px[i] = c } }

    /// The background picture, centred; whatever it doesn't cover is filled with its edge colour.
    mutating func back(_ s: PSprite) {
        let x0 = (w - s.w) / 2, y0 = (h - s.h) / 2
        for y in 0..<h {
            let sy = min(s.h - 1, max(0, y - y0))
            for x in 0..<w {
                let sx = min(s.w - 1, max(0, x - x0))
                px[y * w + x] = s.px[sy * s.w + sx] | 0xFF000000
            }
        }
    }

    /// A sprite with its feet (bottom centre) at (x, y). Fully transparent pixels are skipped.
    mutating func draw(_ s: PSprite, feet x: Int, _ y: Int, flip: Bool = false, alpha: Double = 1, tint: UInt32? = nil) {
        let x0 = x - s.w / 2, y0 = y - s.h + 1
        for j in 0..<s.h {
            for i in 0..<s.w {
                let c = s.px[j * s.w + (flip ? s.w - 1 - i : i)]
                if c >> 24 < 128 { continue }
                if let t = tint { blend(x0 + i, y0 + j, t, 0.85); continue }
                if alpha >= 1 { set(x0 + i, y0 + j, c | 0xFF000000) } else { blend(x0 + i, y0 + j, c, alpha) }
            }
        }
    }

    mutating func line(_ a: V2, _ b: V2, _ c: UInt32, glow: UInt32? = nil) {
        var x0 = Int(a.x.rounded()), y0 = Int(a.y.rounded())
        let x1 = Int(b.x.rounded()), y1 = Int(b.y.rounded())
        let dx = abs(x1 - x0), dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        while true {
            if let g = glow { add(x0 + 1, y0, g, 0.35); add(x0 - 1, y0, g, 0.35); add(x0, y0 + 1, g, 0.35); add(x0, y0 - 1, g, 0.35) }
            set(x0, y0, c)
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
        }
    }

    mutating func rect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: UInt32) {
        for j in 0..<rh { for i in 0..<rw { set(x + i, y + j, c) } }
    }

    /// Night over the picture: darker the farther from any light, in a few hard bands with a 2×2 dither between
    /// them — pixel-art light, not a smooth gradient. Lights: centre, radius, strength.
    mutating func night(base: Double, lights: [(V2, Double, Double)]) {
        // the light at each pixel: the brightest light that reaches it, each light only touching its own box
        var lm = [Double](repeating: 0, count: w * h)
        for (c, r, k) in lights {
            let cx = Int(c.x) + ox, cy = Int(c.y) + oy
            let ry = Int(r / 1.15) + 1, rx = Int(r) + 1
            let r2 = r * r
            let ya = max(0, cy - ry), yb = min(h, cy + ry + 1), xa = max(0, cx - rx), xb = min(w, cx + rx + 1)
            guard ya < yb, xa < xb else { continue }
            for y in ya..<yb {
                let dy = Double(y - cy) * 1.15
                for x in xa..<xb {
                    let dx = Double(x - cx)
                    let d2 = dx * dx + dy * dy
                    if d2 < r2 { let v = k * (1 - d2.squareRoot() / r); if v > lm[y * w + x] { lm[y * w + x] = v } }
                }
            }
        }
        let bayer: [Double] = [0, 0.45, 0.675, 0.225]
        let ms = [base, base + (1 - base) * 0.45, base + (1 - base) * 0.75, 1.0]
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                let band = min(3, Int(lm[i] * 3.2 + bayer[(y & 1) * 2 + (x & 1)]))
                let m = ms[band]
                if m >= 0.999 { continue }
                let d = px[i]
                let r = UInt32(Double(d & 0xff) * m), g = UInt32(Double((d >> 8) & 0xff) * m), b = UInt32(Double((d >> 16) & 0xff) * (m * 0.85 + 0.15 * min(1, m + 0.2)))
                px[i] = 0xFF000000 | b << 16 | g << 8 | r
            }
        }
    }

    func cgImage() -> CGImage? {
        let data = px.withUnsafeBytes { Data($0) }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider, decode: nil,
                       shouldInterpolate: false, intent: .defaultIntent)
    }
}
