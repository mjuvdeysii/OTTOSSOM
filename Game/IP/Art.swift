import SpriteKit
import UIKit

/// Where the companions' pictures come from: the 3D renders in the bundle (default) or the flat drawings (the hidden
/// 2D world). Both share one frame, so swapping never moves a figure.
enum ArtStyle: String { case solid, flat
    static let key = "artStyle"
    static var current: ArtStyle {
        get { ArtStyle(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .solid }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key); Art.clear() }
    }
}

enum Art {
    /// The sprites' shared frame (Tools/art/characters.py): 512 px across 2.2 world units, the feet at this point.
    enum frame {
        static let unitsAcross: CGFloat = 2.2
        static let feetX: CGFloat = 0.5
        static let feetY: CGFloat = 0.7309
    }
    /// How large the companions stand on a one-unit cell.
    static let figureScale: CGFloat = 0.62

    private static var cache: [String: SKTexture] = [:]
    private static var images: [String: UIImage] = [:]
    static func clear() { cache.removeAll(); images.removeAll() }

    static func image(_ name: String) -> UIImage? {
        if let i = images[name] { return i }
        var img: UIImage?
        let isFigure = name.hasPrefix("moss_") || name.hasPrefix("otto_") || name.hasPrefix("mosto_")
        if isFigure && ArtStyle.current == .flat {
            img = FlatArt.image(name, size: 512)
        } else if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Art") {
            img = UIImage(contentsOfFile: url.path)
        }
        images[name] = img
        return img
    }

    static func texture(_ name: String) -> SKTexture {
        if let t = cache[name] { return t }
        let t = image(name).map { SKTexture(image: $0) } ?? SKTexture()
        t.filteringMode = .linear
        cache[name] = t
        return t
    }

    /// Lamp-bead and spade positions in each figure picture (fractions of the frame, from the top left).
    static let beads: [String: CGPoint] = {
        guard let url = Bundle.main.url(forResource: "characters", withExtension: "json", subdirectory: "Art"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var out: [String: CGPoint] = [:]
        for (k, v) in obj {
            if let d = v as? [String: Any], let b = d["bead"] as? [Double], b.count == 2 { out[k] = CGPoint(x: b[0], y: b[1]) }
        }
        return out
    }()

    /// Otto's bead in the flat drawing (the box's (20, 11.5), mirrored when he faces east).
    static func bead(_ name: String) -> CGPoint? {
        if ArtStyle.current == .flat && name.hasPrefix("otto_") {
            let k = 3.57 / 512.0
            let east = name.hasSuffix("_E")
            let bx = east ? 80.0 : 20.0
            return CGPoint(x: frame.feetX + (bx - 50) * k, y: frame.feetY + (11.5 - 90) * k)
        }
        if ArtStyle.current == .flat && name.hasPrefix("mosto_") {
            let k = 3.57 / 512.0
            return CGPoint(x: frame.feetX + (91.5 - 50) * k, y: frame.feetY + (47 - 90) * k)
        }
        return beads[name]
    }
}
