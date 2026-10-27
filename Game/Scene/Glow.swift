import SpriteKit
import CoreImage
import UIKit

/// Light drawn as pictures: the night's darkness with the lamp's lit cells cut out of it (soft-edged), the lamp's
/// warmth over those cells, and small glow textures.
enum Glow {
    static let radial: SKTexture = {
        let s: CGFloat = 128
        let img = UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { c in
            let cs = CGColorSpaceCreateDeviceRGB()
            let g = CGGradient(colorsSpace: cs, colors: [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.35).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 0.25, 1])!
            c.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0, endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: s / 2, options: [])
        }
        return SKTexture(image: img)
    }()

    static func vertical(top: UIColor, bottom: UIColor) -> SKTexture {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 256)).image { c in
            let cs = CGColorSpaceCreateDeviceRGB()
            let g = CGGradient(colorsSpace: cs, colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!
            c.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
        }
        return SKTexture(image: img)
    }

    private static let ci = CIContext(options: [.useSoftwareRenderer: false])

    /// The darkness (normal blend) and the warmth (added) for one lit set, in scene coordinates.
    static func lightMaps(board: Board, lit: UInt64, otto: Int, facing: Dir, cell c: CGFloat, k: CGFloat,
                          left: CGFloat, top: CGFloat, size: CGSize) -> (dark: UIImage, warm: UIImage) {
        let scale: CGFloat = 0.5
        let W = max(1, size.width * scale), H = max(1, size.height * scale)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        // scene coordinates have y up; images have y down
        func rect(_ i: Int, grow: CGFloat) -> CGRect {
            let x = left + CGFloat(board.x(i)) * c, yTop = top - CGFloat(board.y(i)) * c * k
            return CGRect(x: (x - grow) * scale, y: (size.height - yTop - grow * k) * scale, width: (c + grow * 2) * scale, height: (c * k + grow * 2 * k) * scale)
        }
        // 1. the lit cells as a soft mask
        let mask = UIGraphicsImageRenderer(size: CGSize(width: W, height: H), format: fmt).image { r in
            let g = r.cgContext
            g.setFillColor(UIColor.white.cgColor)
            for i in 0..<(board.width * board.height) where lit & bit(i) != 0 {
                g.fill(rect(i, grow: c * 0.02))
            }
        }
        let blurred = blur(mask, radius: c * 0.14 * scale) ?? mask
        // 2. darkness with the mask cut out
        let dark = UIGraphicsImageRenderer(size: CGSize(width: W, height: H), format: fmt).image { r in
            let g = r.cgContext
            g.setFillColor(UIColor(hex: 0x0B1030, alpha: 0.72).cgColor)
            g.fill(CGRect(x: 0, y: 0, width: W, height: H))
            blurred.draw(in: CGRect(x: 0, y: 0, width: W, height: H), blendMode: .destinationOut, alpha: 0.92)
        }
        // 3. warmth: strongest by Otto, fading with distance, only where lit
        let ox = left + (CGFloat(board.x(otto)) + 0.5) * c, oy = top - (CGFloat(board.y(otto)) + 0.5) * c * k
        let center = CGPoint(x: (ox + CGFloat(facing.dx) * c * 0.3) * scale, y: (size.height - oy - CGFloat(-facing.dy) * c * k * 0.3) * scale)
        let warm = UIGraphicsImageRenderer(size: CGSize(width: W, height: H), format: fmt).image { r in
            let g = r.cgContext
            blurred.draw(in: CGRect(x: 0, y: 0, width: W, height: H))
            g.setBlendMode(.sourceIn)
            let cs = CGColorSpaceCreateDeviceRGB()
            let lamp = UIColor(hex: 0xFFB55C)
            let grad = CGGradient(colorsSpace: cs, colors: [lamp.withAlphaComponent(0.42).cgColor, lamp.withAlphaComponent(0.16).cgColor, lamp.withAlphaComponent(0.04).cgColor] as CFArray, locations: [0, 0.4, 1])!
            g.drawRadialGradient(grad, startCenter: center, startRadius: 0, endCenter: center, endRadius: c * 5 * scale, options: [.drawsAfterEndLocation])
        }
        return (dark, warm)
    }

    private static func blur(_ img: UIImage, radius: CGFloat) -> UIImage? {
        guard let cg = img.cgImage else { return nil }
        let input = CIImage(cgImage: cg)
        guard let f = CIFilter(name: "CIGaussianBlur") else { return nil }
        f.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        f.setValue(radius, forKey: kCIInputRadiusKey)
        guard let out = f.outputImage?.cropped(to: input.extent), let res = ci.createCGImage(out, from: input.extent) else { return nil }
        return UIImage(cgImage: res)
    }
}
