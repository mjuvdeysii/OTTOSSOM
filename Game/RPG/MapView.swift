import SwiftUI

/// The adventure screen: the map under a camera that follows Otto, with the party, people, chests, lamps and the
/// shadows that wander; the goal, the party's health and the menu on top; talk at the bottom.
struct AdventureView: View {
    @StateObject var w: World
    @EnvironmentObject var router: Router

    var body: some View {
        GeometryReader { g in
            ZStack {
                MapCanvas(w: w, size: g.size)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { v in tapped(v.location, g.size) })
                if w.battle == nil {
                    VStack(spacing: 8) {
                        topBar
                        Spacer(minLength: 0)
                        if !w.lines.isEmpty { DialogueBox(w: w) } else { partyBar }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }
                if let t = w.toast, w.battle == nil {
                    Text(t).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(.black.opacity(0.7), in: Capsule())
                        .overlay(Capsule().stroke(gold.opacity(0.5)))
                        .frame(maxHeight: .infinity, alignment: .top).padding(.top, 70)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
                if let name = w.mapCard {
                    Text(name).font(.system(size: 30, weight: .bold, design: .serif)).tracking(6)
                        .foregroundStyle(LinearGradient(colors: [Color(0xfff3d6), gold], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.8), radius: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.35).ignoresSafeArea())
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
                if w.battle != nil { BattleView(w: w).transition(.opacity) }
                if let r = w.reward { RewardView(w: w, r: r).transition(.opacity) }
                if w.ended && w.lines.isEmpty { EndCard(w: w).transition(.opacity) }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: w.battle == nil)
        .animation(.easeInOut(duration: 0.3), value: w.toast)
        .animation(.easeInOut(duration: 0.4), value: w.mapCard)
        .animation(.easeInOut(duration: 0.3), value: w.reward)
        .sheet(isPresented: $w.menu) { PartyMenu(w: w) }
        .sheet(isPresented: Binding(get: { w.shop != nil && w.lines.isEmpty }, set: { if !$0 { w.shop = nil } })) {
            ShopSheet(w: w, items: w.shop ?? [])
        }
        .onAppear { w.begin() }
        .persistentSystemOverlays(.hidden)
    }

    private func tapped(_ p: CGPoint, _ size: CGSize) {
        if !w.lines.isEmpty { w.nextLine(); return }
        let cam = MapCanvas.camera(w: w, size: size)
        let x = Int(floor((p.x - cam.x) / cam.T)), y = Int(floor((p.y - cam.y) / (cam.T * Art.k)))
        w.tap(Pt(x, y))
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { Sound.shared.hum(false); w.save(); router.screen = .title } label: {
                Image(systemName: "chevron.left").font(.headline).frame(width: 40, height: 40).background(.black.opacity(0.45), in: Circle())
            }
            .foregroundStyle(.white)
            .accessibilityLabel("回到标题")
            let g = w.goal
            HStack(spacing: 8) {
                Image(systemName: "flag.fill").font(.caption).foregroundStyle(gold)
                Text(g.text).font(.footnote.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .onTapGesture { w.menu = true }
            Button { w.menu = true } label: {
                Image(systemName: "bag.fill").font(.headline).frame(width: 40, height: 40).background(.black.opacity(0.45), in: Circle())
            }
            .foregroundStyle(gold)
            .accessibilityLabel("队伍与背包")
        }
    }

    private var partyBar: some View {
        HStack(spacing: 8) {
            ForEach(w.s.members, id: \.hero) { m in
                let st = Stats.of(m)
                HStack(spacing: 8) {
                    Face(hero: m.hero).frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(Stats.name(m.hero)).font(.caption.weight(.bold)).foregroundStyle(.white)
                            Spacer()
                            Text("Lv\(m.level)").font(.caption2.monospacedDigit()).foregroundStyle(gold)
                        }
                        Bar(value: Double(m.hp) / Double(max(1, st.maxHP)), tint: Color(0x7fd18b))
                        Text("\(m.hp)/\(st.maxHP)").font(.caption2.monospacedDigit()).foregroundStyle(mutedText)
                    }
                }
                .padding(8)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
            VStack(spacing: 2) {
                Image(systemName: "sparkle").foregroundStyle(gold)
                Text("\(w.s.motes)").font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(.white)
            }
            .frame(width: 46).padding(.vertical, 8)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("光屑 \(w.s.motes)")
        }
    }
}

struct Bar: View {
    var value: Double
    var tint: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(tint).frame(width: max(0, min(1, value)) * g.size.width)
            }
        }
        .frame(height: 5)
        .animation(.easeOut(duration: 0.3), value: value)
    }
}

/// A character's face in a round frame, cut from their sprite.
struct Face: View {
    var hero: Hero?
    var sprite: String? = nil
    var body: some View {
        let name = sprite ?? (hero == .otto ? "otto_idle_E_n" : hero == .moss ? "moss_idle_n" : "mosto_idle_n")
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(0x3a4270), Color(0x161a30)], center: .center, startRadius: 2, endRadius: 30))
            if let ui = Art.uiImage(name) {
                GeometryReader { g in
                    Image(uiImage: ui).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: g.size.width * 1.65, height: g.size.width * 1.65 * 1.3)
                        .position(x: g.size.width / 2, y: g.size.height / 2 + (name.hasPrefix("otto") ? g.size.height * 0.12 : -g.size.height * 0.1))
                }
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(gold.opacity(0.6), lineWidth: 1.2))
    }
}

struct DialogueBox: View {
    @ObservedObject var w: World
    @State private var shown = 0
    var body: some View {
        if let l = w.lines.first {
            let hero: Hero? = l.who == "o" ? .otto : l.who == "m" ? .moss : l.who == "x" ? .mosto : nil
            let npc: String? = l.who == "h" ? "npc_h_n" : l.who == "d" ? "npc_d_n" : l.who == "n" ? "npc_n_n" : nil
            let name = GameModel.names[l.who] ?? ""
            HStack(alignment: .top, spacing: 12) {
                if hero != nil || npc != nil { Face(hero: hero, sprite: npc).frame(width: 52, height: 52) }
                VStack(alignment: .leading, spacing: 6) {
                    if !name.isEmpty { Text(name).font(.caption.weight(.bold)).foregroundStyle(gold) }
                    ZStack(alignment: .topLeading) {
                        Text(l.text).font(.body).opacity(0)
                        Text(String(l.text.prefix(shown))).font(l.who.isEmpty ? .body.italic() : .body).foregroundStyle(l.who.isEmpty ? Color(0xd8dcf0) : .white)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    HStack { Spacer(); Image(systemName: "chevron.down").font(.caption2).foregroundStyle(mutedText).opacity(shown >= l.text.count ? 1 : 0) }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(panelBG.opacity(0.95), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold.opacity(0.25)))
            .contentShape(Rectangle())
            .onTapGesture { if shown < l.text.count { shown = l.text.count } else { w.nextLine() } }
            .task(id: "\(w.lines.count)\(l.text)") {
                shown = 0
                for k in 1...max(1, l.text.count) {
                    try? await Task.sleep(for: .milliseconds(32))
                    if Task.isCancelled || shown >= l.text.count { return }
                    shown = k
                }
            }
        }
    }
}

struct RewardView: View {
    @ObservedObject var w: World
    let r: Reward
    var body: some View {
        VStack(spacing: 16) {
            Text("胜利").font(.system(size: 34, weight: .heavy, design: .serif)).tracking(8)
                .foregroundStyle(LinearGradient(colors: [Color(0xfff3d6), gold], startPoint: .top, endPoint: .bottom))
            HStack(spacing: 22) {
                Label("\(r.xp)", systemImage: "star.fill")
                Label("\(r.motes)", systemImage: "sparkle")
            }
            .font(.title3.monospacedDigit().weight(.semibold)).foregroundStyle(.white)
            ForEach(r.ups, id: \.self) { u in
                Text(u).font(.callout.weight(.semibold)).foregroundStyle(gold).multilineTextAlignment(.center)
            }
            Text("点一下继续").font(.caption).foregroundStyle(mutedText).padding(.top, 8)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.78).ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { w.reward = nil }
    }
}

struct EndCard: View {
    @ObservedObject var w: World
    @EnvironmentObject var router: Router
    var body: some View {
        VStack(spacing: 18) {
            Text("第一区域 · 完").font(.system(size: 30, weight: .heavy, design: .serif)).tracking(6)
                .foregroundStyle(LinearGradient(colors: [Color(0xfff3d6), gold], startPoint: .top, endPoint: .bottom))
            Text("主灯又亮了。\n莫斯托抱着太阳的火，往影子国去了。").font(.callout).foregroundStyle(.white).multilineTextAlignment(.center)
            Text("下一个区域：影子国").font(.caption).foregroundStyle(mutedText)
            Button { router.screen = .title } label: {
                Image(systemName: "house.fill").font(.title2).frame(width: 64, height: 64).background(gold, in: Circle()).foregroundStyle(.black)
            }
            .accessibilityLabel("回到标题")
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(nightBG.opacity(0.95).ignoresSafeArea())
    }
}

// MARK: the map itself

struct MapCanvas: View {
    @ObservedObject var w: World
    let size: CGSize

    struct Cam { var x: CGFloat; var y: CGFloat; var T: CGFloat }
    @MainActor static func camera(w: World, size: CGSize) -> Cam {
        let T = floor(min(64, max(40, size.width / 8.4)))
        let K = Art.k
        var cx = (w.pos.x + 0.5) * T, cy = (w.pos.y + 0.5) * T * K
        // keep the camera over the map (the rendered ground runs a few cells past its edges, no further)
        let mw = CGFloat(w.map.w) * T, mh = CGFloat(w.map.h) * T * K
        let mx = 1.8 * T, my = 3.5 * T * K
        let fx = size.width / 2, fy = size.height * 0.52
        if mw + 2 * mx <= size.width { cx = mw / 2 } else { cx = min(max(cx, fx - mx), mw - (size.width - fx) + mx) }
        if mh + 2 * my <= size.height { cy = mh / 2 + (fy - size.height / 2) } else { cy = min(max(cy, fy - my), mh - (size.height - fy) + my) }
        return Cam(x: fx - cx, y: fy - cy, T: T)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40)) { tl in
            Canvas { ctx, sz in
                let cam = MapCanvas.camera(w: w, size: size)
                var c = ctx
                c.translateBy(x: cam.x, y: cam.y)
                MapPainter(w: w, T: cam.T, t: tl.date.timeIntervalSinceReferenceDate,
                           view: CGRect(x: -cam.x, y: -cam.y, width: sz.width, height: sz.height)).draw(&c)
            }
        }
        .background(Color(0x070a18))
    }
}

@MainActor
struct MapPainter {
    let w: World
    let T: CGFloat
    let t: Double
    let view: CGRect
    var K: CGFloat { Art.k }
    var m: RPGMap { w.map }

    func ground(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x + 0.5) * T, y: (p.y + 0.5) * T * K) }
    func gp(_ p: Pt) -> CGPoint { ground(CGPoint(x: p.x, y: p.y)) }

    func draw(_ ctx: inout GraphicsContext) {
        background(&ctx)
        goalMark(&ctx)
        var items: [(CGFloat, (inout GraphicsContext) -> Void)] = []
        for l in m.lamps {
            let lit = w.s.lit.contains(l.id)
            items.append((CGFloat(l.at[1]), { c in self.sprite(&c, lit ? "lantern_on" : "lantern_off", Pt(l.at)) }))
        }
        for ch in m.chests {
            let open = w.s.opened.contains(ch.id)
            items.append((CGFloat(ch.at[1]), { c in self.chest(&c, Pt(ch.at), open) }))
        }
        for n in m.npcs where w.visible(n) {
            var name = n.sprite
            if n.id == "dora", w.s.flags.contains("doraLit") { name = "npc_dl" }
            items.append((CGFloat(n.at[1]), { c in
                self.sprite(&c, name, Pt(n.at), bob: true)
                self.marker(&c, n, Pt(n.at))
            }))
        }
        for mo in m.motes where !w.s.opened.contains(mo.id) && w.quest("dora") != nil {
            items.append((CGFloat(mo.at[1]), { c in self.firefly(&c, Pt(mo.at)) }))
        }
        for (id, p) in w.foePos {
            let f = m.foes.first { $0.id == id }
            let kind = f?.party.first ?? "shade"
            items.append((CGFloat(p.y), { c in self.foe(&c, kind, p, boss: f?.boss == true) }))
        }
        // Moss one step behind, then Otto
        if w.hasMoss {
            let mp = w.trail.count > 1 ? w.trail[1] : w.me
            let mossState: String = w.dir == "W" ? "left" : w.dir == "E" ? "right" : w.dir == "N" ? "back" : "down"
            items.append((CGFloat(mp.y) - 0.01, { c in self.sprite(&c, "moss_\(mossState)", mp, eased: true) }))
        }
        let blink = (t + 0.4).truncatingRemainder(dividingBy: 4.2) < 0.13
        let od = w.dir == "N" ? "N" : w.dir == "W" ? "W" : w.dir == "E" ? "E" : "S"
        let oname = blink && od != "N" ? "otto_blink_\(od)" : "otto_idle_\(od)"
        items.append((w.pos.y + 0.001, { c in
            self.spriteAt(&c, oname, w.pos)
            self.bead(&c, oname, w.pos)
        }))
        for it in items.sorted(by: { $0.0 < $1.0 }) { it.1(&ctx) }
        night(&ctx)
        if m.fog == true { fog(&ctx) }
    }

    // MARK: layers

    func background(_ ctx: inout GraphicsContext) {
        if let bg = Art.background("rpg_\(w.s.map)") {
            let k = T / bg.pc
            ctx.draw(Image(uiImage: bg.image), in: CGRect(x: -bg.origin.x * k, y: -bg.origin.y * k, width: bg.image.size.width * k, height: bg.image.size.height * k))
            return
        }
        // no render yet: a plain painted map
        let theme = m.theme
        ctx.fill(Path(view), with: .color(theme == "cellar" ? Color(0x0a0a12) : theme == "wilds" ? Color(0x16261c) : Color(0x161a2c)))
        for y in 0..<m.h { for x in 0..<m.w {
            let ch = m.ch(Pt(x, y))
            let r = CGRect(x: CGFloat(x) * T, y: CGFloat(y) * T * K, width: T, height: T * K)
            var base: Color
            switch ch {
            case "#": base = theme == "wilds" ? Color(0x2a3a2a) : Color(0x2a3152)
            case "x": base = Color(0x1c1a26)
            case "~": base = Color(0x14264a)
            case "=": base = Color(0x7a5a3a)
            case ",", "T": base = theme == "town" ? Color(0x3a4a3a) : Color(0x34503a)
            default: base = theme == "cellar" ? Color(0x3a3644) : theme == "wilds" ? Color(0x5a5240) : Color(0x4a4e66)
            }
            ctx.fill(Path(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 3), with: .color(base))
            let c = CGPoint(x: r.midX, y: r.midY)
            switch ch {
            case "T":
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - T * 0.42, y: c.y - T * 0.75, width: T * 0.84, height: T * 0.84)), with: .color(Color(0x2e5a36)))
            case "R":
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - T * 0.32, y: c.y - T * 0.3, width: T * 0.64, height: T * 0.45)), with: .color(Color(0x6a6a74)))
            case "H":
                ctx.fill(Path(roundedRect: CGRect(x: c.x - T * 0.42, y: c.y - T * 0.6, width: T * 0.84, height: T * 0.7), cornerRadius: 4), with: .color(Color(0xc8bca8)))
                ctx.fill(Path(roundedRect: CGRect(x: c.x - T * 0.48, y: c.y - T * 0.8, width: T * 0.96, height: T * 0.3), cornerRadius: 4), with: .color(Color(0x8a3a3a)))
            case "^":
                ctx.fill(Path(roundedRect: CGRect(x: c.x - T * 0.45, y: c.y - T * 0.9, width: T * 0.9, height: T * 1.1), cornerRadius: 6), with: .color(Color(0xe8e0d0)))
            case "i":
                ctx.fill(Path(CGRect(x: c.x - 2, y: c.y - T * 0.8, width: 4, height: T * 0.8)), with: .color(Color(0x2a2a34)))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - T * 0.9, width: 12, height: 12)), with: .color(Color(0x3a3a44)))
            case "B":
                ctx.fill(Path(roundedRect: CGRect(x: c.x - T * 0.46, y: c.y - T * 0.5, width: T * 0.92, height: T * 0.55), cornerRadius: 4), with: .color(Color(0x9a6a3a)))
                ctx.fill(Path(roundedRect: CGRect(x: c.x - T * 0.5, y: c.y - T * 0.75, width: T, height: T * 0.25), cornerRadius: 3), with: .color(Color(0xc04a4a)))
            case "t":
                ctx.fill(Path(roundedRect: CGRect(x: c.x - T * 0.25, y: c.y - T * 0.7, width: T * 0.5, height: T * 0.75), cornerRadius: 6), with: .color(Color(0x9a9aa8)))
            case "s", "u":
                for k in 0..<3 { ctx.fill(Path(CGRect(x: r.minX + 4, y: r.minY + CGFloat(k) * r.height / 3 + 2, width: r.width - 8, height: r.height / 3 - 3)), with: .color(Color(0x5a5466).opacity(1 - Double(k) * 0.25))) }
            case "D":
                ctx.fill(Path(roundedRect: r.insetBy(dx: 4, dy: 2), cornerRadius: 4), with: .color(Color(0xf2c062).opacity(0.25)))
            default: break
            }
        } }
    }

    /// A sprite standing on a cell, feet on its centre.
    func spriteAt(_ ctx: inout GraphicsContext, _ name: String, _ p: CGPoint, scale: CGFloat = 1.3, lift: CGFloat = 0, alpha: Double = 1) {
        guard let meta = Art.meta[name], let ui = Art.uiImage(name + "_n") ?? Art.uiImage(name) else { return }
        let s = T / Art.pc * scale
        let g = ground(p)
        let rect = CGRect(x: g.x - meta.feet.x * s, y: g.y - meta.feet.y * s - lift * T, width: ui.size.width * s, height: ui.size.height * s)
        var c = ctx; c.opacity = alpha
        // a soft contact shadow
        c.fill(Path(ellipseIn: CGRect(x: g.x - T * 0.32, y: g.y - T * 0.1, width: T * 0.64, height: T * 0.22)), with: .color(.black.opacity(0.35)))
        c.draw(Image(uiImage: ui), in: rect)
        if let wimg = Art.image(name + "_w") {
            let l = warmth(p)
            if l > 0.02 { var cw = c; cw.opacity = min(1, l) * alpha; cw.draw(wimg, in: rect) }
        }
    }
    func sprite(_ ctx: inout GraphicsContext, _ name: String, _ p: Pt, bob: Bool = false, eased: Bool = false) {
        var at = CGPoint(x: p.x, y: p.y)
        if eased, w.walking { at = CGPoint(x: CGFloat(p.x) + (w.pos.x - CGFloat(w.me.x)), y: CGFloat(p.y) + (w.pos.y - CGFloat(w.me.y))) }
        let isFigure = name.hasPrefix("moss") || name.hasPrefix("otto") || name.hasPrefix("npc") || name.hasPrefix("mosto")
        spriteAt(&ctx, name, at, scale: isFigure ? 1.3 : 1.0, lift: bob ? CGFloat(abs(sin(t * 2 + Double(p.x)))) * 0.02 : 0)
    }

    func bead(_ ctx: inout GraphicsContext, _ sprite: String, _ p: CGPoint) {
        guard let meta = Art.meta[sprite], let b = meta.bead else { return }
        let g = ground(p), s = T / Art.pc * 1.3
        let c = CGPoint(x: g.x + (b.x - meta.feet.x) * s, y: g.y + (b.y - meta.feet.y) * s)
        var a = ctx; a.blendMode = .plusLighter
        let R = T * 0.55
        a.fill(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2)),
               with: .radialGradient(Gradient(colors: [Color(0xffd77a, 0.9), Color(0xffb04a, 0.25), Color(0xffb04a, 0)]), center: c, startRadius: 0, endRadius: R))
    }

    func chest(_ ctx: inout GraphicsContext, _ p: Pt, _ open: Bool) {
        if Art.meta[open ? "chest_open" : "chest"] != nil { sprite(&ctx, open ? "chest_open" : "chest", p); return }
        let g = gp(p)
        let r = CGRect(x: g.x - T * 0.32, y: g.y - T * 0.42, width: T * 0.64, height: T * 0.42)
        ctx.fill(Path(roundedRect: r, cornerRadius: 5), with: .color(Color(0x8a5a32)))
        ctx.fill(Path(roundedRect: CGRect(x: r.minX, y: r.minY - (open ? T * 0.12 : 0), width: r.width, height: T * 0.16), cornerRadius: 4), with: .color(Color(0xa86e3c)))
        ctx.fill(Path(CGRect(x: g.x - 3, y: r.minY + T * 0.1, width: 6, height: 8)), with: .color(Color(0xf2c062)))
        if !open {
            var a = ctx; a.blendMode = .plusLighter
            let k = 0.25 + 0.2 * sin(t * 3 + Double(p.x))
            a.fill(Path(ellipseIn: r.insetBy(dx: -8, dy: -8)), with: .radialGradient(Gradient(colors: [Color(0xffd77a, k), .clear]), center: CGPoint(x: r.midX, y: r.midY), startRadius: 0, endRadius: T * 0.5))
        }
    }

    func firefly(_ ctx: inout GraphicsContext, _ p: Pt) {
        let g = gp(p)
        var a = ctx; a.blendMode = .plusLighter
        for k in 0..<3 {
            let ph = t * (1.3 + Double(k) * 0.4) + Double(k * 2)
            let c = CGPoint(x: g.x + CGFloat(cos(ph)) * T * 0.2, y: g.y - T * 0.5 + CGFloat(sin(ph * 1.3)) * T * 0.15)
            a.fill(Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)), with: .radialGradient(Gradient(colors: [Color(0xeaffa0, 0.9), .clear]), center: c, startRadius: 0, endRadius: 9))
        }
    }

    func foe(_ ctx: inout GraphicsContext, _ kind: String, _ p: Pt, boss: Bool) {
        let name = Art.meta["foe_\(kind)"] != nil ? "foe_\(kind)" : "shadow"
        let wob = CGFloat(sin(t * 3 + Double(p.x * 7 + p.y))) * 0.03
        spriteAt(&ctx, name, CGPoint(x: CGFloat(p.x) + wob, y: CGFloat(p.y)), scale: boss ? 1.7 : 1.15)
        // a small red mark: this one will fight
        let g = gp(p)
        let k = 0.5 + 0.5 * sin(t * 4)
        ctx.stroke(Path(ellipseIn: CGRect(x: g.x - T * 0.4, y: g.y - T * 0.4 * K * 0.6, width: T * 0.8, height: T * 0.8 * K * 0.6)), with: .color(Color(0xe8503a, 0.35 + 0.35 * k)), lineWidth: 2)
    }

    func marker(_ ctx: inout GraphicsContext, _ n: RPGNPC, _ p: Pt) {
        var symbol: String? = nil
        switch n.id {
        case "moss": symbol = "exclamationmark"
        case "dora": symbol = w.quest("dora") == nil ? "exclamationmark" : w.quest("dora") == "back" ? "questionmark" : nil
        case "lynn": symbol = w.quest("net") == nil ? "exclamationmark" : w.quest("net") == "back" ? "questionmark" : nil
        case "hank": symbol = w.quest("main") == "home" ? "questionmark" : nil
        default: break
        }
        guard let sy = symbol else { return }
        let g = gp(p)
        let c = CGPoint(x: g.x, y: g.y - T * 1.55 - CGFloat(abs(sin(t * 3))) * 4)
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 11, y: c.y - 11, width: 22, height: 22)), with: .color(gold))
        var img = ctx.resolve(Image(systemName: sy))
        img.shading = .color(.black)
        ctx.draw(img, in: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14))
    }

    /// The main quest's next place: a gold pulse on it here, or an arrow at the screen edge pointing the way.
    func goalMark(_ ctx: inout GraphicsContext) {
        guard let gpt = w.goalHere, w.lines.isEmpty else { return }
        let g = gp(gpt)
        let k = (t * 0.8).truncatingRemainder(dividingBy: 1)
        if view.insetBy(dx: 30, dy: 80).contains(g) {
            ctx.stroke(Path(ellipseIn: CGRect(x: g.x - T * (0.3 + 0.3 * k), y: g.y - T * (0.3 + 0.3 * k) * K, width: T * (0.6 + 0.6 * k), height: T * (0.6 + 0.6 * k) * K)),
                       with: .color(gold.opacity(1 - k)), lineWidth: 3)
            return
        }
        // an arrow on the edge of the screen, toward it
        let centre = CGPoint(x: view.midX, y: view.midY)
        let dx = g.x - centre.x, dy = g.y - centre.y
        let len = max(1, hypot(dx, dy)), ux = dx / len, uy = dy / len
        let box = view.insetBy(dx: 34, dy: 120)
        let tx = ux > 0 ? (box.maxX - centre.x) / ux : ux < 0 ? (box.minX - centre.x) / ux : .infinity
        let ty = uy > 0 ? (box.maxY - centre.y) / uy : uy < 0 ? (box.minY - centre.y) / uy : .infinity
        let d = min(tx, ty)
        let tip = CGPoint(x: centre.x + ux * d, y: centre.y + uy * d)
        let s: CGFloat = 16 + 3 * CGFloat(sin(t * 4))
        var a = Path()
        a.move(to: CGPoint(x: tip.x + ux * s, y: tip.y + uy * s))
        a.addLine(to: CGPoint(x: tip.x - uy * s * 0.7, y: tip.y + ux * s * 0.7))
        a.addLine(to: CGPoint(x: tip.x + uy * s * 0.7, y: tip.y - ux * s * 0.7))
        a.closeSubpath()
        ctx.fill(a, with: .color(gold))
        ctx.stroke(a, with: .color(.black.opacity(0.5)), lineWidth: 1)
    }

    // MARK: light

    func lights() -> [(CGPoint, CGFloat, Double)] {
        var out: [(CGPoint, CGFloat, Double)] = [(w.pos, 3.3, 1)]
        for l in m.lamps where w.s.lit.contains(l.id) { out.append((CGPoint(x: l.at[0], y: l.at[1]), 3.2, 0.95)) }
        if w.s.map == "town", w.s.flags.contains("doraLit"), let d = m.npcs.first(where: { $0.id == "dora" }) { out.append((CGPoint(x: d.at[0], y: d.at[1]), 1.6, 0.8)) }
        for mo in m.motes where !w.s.opened.contains(mo.id) && w.quest("dora") != nil { out.append((CGPoint(x: mo.at[0], y: mo.at[1]), 1.0, 0.6)) }
        return out
    }
    func warmth(_ p: CGPoint) -> Double {
        var best = 0.0
        for (c, r, k) in lights() {
            let d = hypot(Double(p.x - c.x), Double(p.y - c.y))
            best = max(best, k * max(0, 1 - d / Double(r + 0.5)))
        }
        return min(1, best * 1.2)
    }

    func night(_ ctx: inout GraphicsContext) {
        let base = m.dark
        let ls = lights()
        ctx.drawLayer { layer in
            layer.fill(Path(view.insetBy(dx: -40, dy: -40)), with: .color(Color(0x03040c, base)))
            layer.blendMode = .destinationOut
            for (c, r, k) in ls {
                let g = ground(c), R = r * T
                layer.fill(Path(ellipseIn: CGRect(x: g.x - R, y: g.y - R * K, width: R * 2, height: R * 2 * K)),
                           with: .radialGradient(Gradient(stops: [.init(color: .white.opacity(0.95 * k), location: 0), .init(color: .white.opacity(0.6 * k), location: 0.5), .init(color: .white.opacity(0), location: 1)]),
                                                 center: g, startRadius: 0, endRadius: R))
            }
        }
        var a = ctx; a.blendMode = .plusLighter
        for (c, r, k) in ls {
            let g = ground(c), R = min(r, 2.5) * T
            a.fill(Path(ellipseIn: CGRect(x: g.x - R, y: g.y - R * K, width: R * 2, height: R * 2 * K)),
                   with: .radialGradient(Gradient(colors: [Color(0xffb45a, 0.16 * k), .clear]), center: g, startRadius: 0, endRadius: R))
        }
    }

    /// The cellar: black where no one has been; dim where you've been but no light reaches now.
    func fog(_ ctx: inout GraphicsContext) {
        let seen = Set(w.s.seen[w.s.map] ?? [])
        let ls = lights()
        for y in 0..<m.h { for x in 0..<m.w {
            let r = CGRect(x: CGFloat(x) * T - 1, y: CGFloat(y) * T * K - 1, width: T + 2, height: T * K + 2)
            if !seen.contains(y * m.w + x) { ctx.fill(Path(r), with: .color(.black)); continue }
            let p = CGPoint(x: x, y: y)
            let lit = ls.contains { hypot(Double(p.x - $0.0.x), Double(p.y - $0.0.y)) <= Double($0.1) - 0.3 }
            if !lit { ctx.fill(Path(r), with: .color(.black.opacity(0.5))) }
        } }
        // the black runs on past the map's edges
        let mapRect = CGRect(x: 0, y: 0, width: CGFloat(m.w) * T, height: CGFloat(m.h) * T * K)
        var outside = Path(view.insetBy(dx: -40, dy: -40)); outside.addRect(mapRect)
        ctx.fill(outside, with: .color(.black), style: FillStyle(eoFill: true))
    }
}
