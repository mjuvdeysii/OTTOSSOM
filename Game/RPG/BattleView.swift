import SwiftUI

/// A fight: the foes above with what each will do next, the party below, the shared light between, and the
/// commands for whoever is choosing. Each round plays back as a short sequence of hits, heals and light.
struct BattleView: View {
    @ObservedObject var w: World
    @State private var chosen: [BattleAction] = []
    @State private var picking: SkillID?
    @State private var itemMenu = false
    @State private var playing = false
    @State private var caption = ""
    @State private var floats: [Floater] = []
    @State private var flash: [Int: Date] = [:]
    @State private var gone: Set<Int> = []
    @State private var lightShown = 3

    struct Floater: Identifiable, Equatable { let id = UUID(); var target: Int; var text: String; var color: Color; var at: Date }

    var b: BattleState? { w.battle }
    var levels: [Hero: Int] { Dictionary(uniqueKeysWithValues: w.s.members.map { ($0.hero, $0.level) }) }
    var tipLevels: [Hero: Int] {
        var l = levels
        if w.s.flags.contains("mineEarly") { l[.moss] = max(l[.moss] ?? 1, 4) }
        return l
    }
    /// Whoever chooses next: the living party members in order, one action each.
    var actor: Fighter? {
        guard let b else { return nil }
        let living = b.party.filter { $0.alive }
        return living.first { f in !chosen.contains { $0.actor == f.id } }
    }

    var body: some View {
        GeometryReader { g in
            ZStack {
                backdrop(g.size)
                VStack(spacing: 10) {
                    foes.frame(height: g.size.height * 0.36).padding(.top, 54)
                    lightMeter
                    Text(caption.isEmpty ? " " : caption).font(.callout.weight(.semibold)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 16)
                        .animation(.none, value: caption)
                    Spacer(minLength: 0)
                    partyRow
                    commands.frame(minHeight: 150)
                }
                .padding(.horizontal, 12).padding(.bottom, 10)
            }
        }
        .onAppear { lightShown = b?.light ?? 3; caption = opening }
    }

    private var opening: String {
        guard let b else { return "" }
        return b.boss ? "\(b.foes.first?.name ?? "") 挡住了去路！" : "\(b.foes.map { $0.name }.joined(separator: "、")) 扑过来了！"
    }

    // MARK: pieces

    private func backdrop(_ size: CGSize) -> some View {
        let theme = w.map.theme
        return ZStack {
            if let ui = Art.uiImage("battle_\(theme)", ext: "jpg") {
                Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill).frame(width: size.width, height: size.height).clipped()
            } else {
                LinearGradient(colors: theme == "cellar" ? [Color(0x0c0a14), Color(0x241c30)] : theme == "wilds" ? [Color(0x0c1a20), Color(0x2a3a2a)] : [Color(0x0c1028), Color(0x2a2a44)],
                               startPoint: .top, endPoint: .bottom)
            }
            LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    private var foes: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(b?.foes ?? []) { f in
                if !gone.contains(f.id) { foeCard(f).transition(.opacity.combined(with: .scale(scale: 0.6))) }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.35), value: gone)
    }

    private func foeCard(_ f: Fighter) -> some View {
        let targeting = picking != nil && (Skill.all[picking!]?.aim == .foe)
        let hit = flash[f.id].map { Date().timeIntervalSince($0) < 0.35 } ?? false
        let big = f.kind?.isBoss == true
        return VStack(spacing: 4) {
            intentBubble(f)
            ZStack {
                if targeting && f.alive {
                    Circle().stroke(gold, lineWidth: 2).frame(width: big ? 150 : 96).opacity(0.9)
                }
                FoeSprite(kind: f.kind ?? .shade, stolen: f.stolen)
                    .frame(width: big ? 190 : 116, height: big ? 190 : 116)
                    .offset(x: hit ? 6 : 0)
                    .colorMultiply(hit ? Color(0xffb0a0) : .white)
                    .opacity(f.alive ? 1 : 0.2)
                ForEach(floats.filter { $0.target == f.id }) { fl in FloatText(f: fl) }
            }
            Text(f.name).font(.caption.weight(.bold)).foregroundStyle(.white)
            Bar(value: Double(f.hp) / Double(max(1, f.maxHP)), tint: Color(0xe8503a)).frame(width: big ? 150 : 84)
            HStack(spacing: 4) {
                if f.stun > 0 { Image(systemName: "star.circle.fill").foregroundStyle(.yellow) }
                if f.slow { Image(systemName: "tortoise.fill").foregroundStyle(.cyan) }
                if f.shell { Image(systemName: "shield.fill").foregroundStyle(.gray) }
                if f.stolen > 0 { Label("\(f.stolen)", systemImage: "drop.halffull").foregroundStyle(gold) }
            }
            .font(.caption2)
            if f.revealed, let k = f.kind {
                Text(k.weakness).font(.caption2).foregroundStyle(Color(0xd8dcf0)).multilineTextAlignment(.center)
                    .frame(width: big ? 200 : 110).fixedSize(horizontal: false, vertical: true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if targeting && f.alive { choose(target: f.id) } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(f.name)，生命 \(f.hp)/\(f.maxHP)，下一步：\(f.intents.first?.label ?? "")")
    }

    private func intentBubble(_ f: Fighter) -> some View {
        let shownIntents = f.revealed ? Array(f.intents.prefix(2)) : Array(f.intents.prefix(1))
        return HStack(spacing: 6) {
            ForEach(Array(shownIntents.enumerated()), id: \.offset) { i, it in
                HStack(spacing: 3) {
                    Image(systemName: it.icon)
                    Text(intentText(f, it))
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(i == 0 ? Color.white : mutedText)
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background((i == 0 ? Color(0x5a2030) : Color.black).opacity(0.75), in: Capsule())
            }
        }
        .opacity(f.alive && f.stun == 0 ? 1 : 0)
    }

    private func intentText(_ f: Fighter, _ it: Intent) -> String {
        if it.power > 0 {
            let est = Int((Double(f.atk) * it.power - 3 * 0.5).rounded())
            return "\(it.label) \(est)"
        }
        return it.label
    }

    private var lightMeter: some View {
        HStack(spacing: 5) {
            Image(systemName: "light.max").foregroundStyle(gold).font(.caption)
            ForEach(0..<Battle.lightMax, id: \.self) { i in
                Circle().fill(i < lightShown ? gold : Color.white.opacity(0.12)).frame(width: 13, height: 13)
                    .shadow(color: i < lightShown ? gold.opacity(0.8) : .clear, radius: 4)
            }
            Text("\(lightShown)").font(.callout.monospacedDigit().weight(.bold)).foregroundStyle(gold).frame(width: 24)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.black.opacity(0.5), in: Capsule())
        .accessibilityLabel("光 \(lightShown)")
        .animation(.easeOut(duration: 0.25), value: lightShown)
    }

    private var partyRow: some View {
        HStack(spacing: 8) {
            ForEach(b?.party ?? []) { p in
                let on = actor?.id == p.id && !playing
                let picked = chosen.first { $0.actor == p.id }
                let hit = flash[p.id].map { Date().timeIntervalSince($0) < 0.35 } ?? false
                HStack(spacing: 8) {
                    Face(hero: p.hero).frame(width: 44, height: 44).opacity(p.alive ? 1 : 0.3)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(p.name).font(.caption.weight(.bold)).foregroundStyle(.white)
                            Spacer()
                            if let pk = picked, let sk = Skill.all[pk.skill] { Image(systemName: sk.icon).font(.caption2).foregroundStyle(gold) }
                        }
                        Bar(value: Double(p.hp) / Double(max(1, p.maxHP)), tint: p.hp * 3 < p.maxHP ? Color(0xe8a03a) : Color(0x7fd18b))
                        Text("\(p.hp)/\(p.maxHP)").font(.caption2.monospacedDigit()).foregroundStyle(mutedText)
                    }
                    .overlay(alignment: .top) { ForEach(floats.filter { $0.target == p.id }) { fl in FloatText(f: fl) } }
                }
                .padding(8)
                .background(on ? gold.opacity(0.22) : Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? gold : Color.clear, lineWidth: 1.5))
                .offset(x: hit ? -5 : 0)
                .onTapGesture { if picking == .item && p.alive { pickTea(p.id) } }
            }
        }
    }

    // MARK: commands

    @ViewBuilder private var commands: some View {
        if playing || b?.outcome != .ongoing {
            Color.clear.frame(height: 150)
        } else if itemMenu {
            itemList
        } else if let a = actor, let b {
            let skills = Battle.usable(b, a, level: 99).filter { w.learned(a.hero ?? .otto, levels[a.hero ?? .otto] ?? 1, $0.id) && !($0.id == .flee && b.boss) }
            let tip = Battle.suggest(b, levels: tipLevels, tea: w.s.bag["tea"] ?? 0).first { $0.actor == a.id }?.skill
            VStack(spacing: 8) {
                HStack {
                    Text(picking != nil ? "点一个敌人" : "\(a.name) 要做什么？").font(.footnote.weight(.semibold)).foregroundStyle(gold)
                    Spacer()
                    if picking != nil || !chosen.isEmpty {
                        Button { back() } label: { Label("返回", systemImage: "arrow.uturn.backward").font(.footnote) }.foregroundStyle(mutedText)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(skills, id: \.id) { sk in
                        let can = b.light >= sk.cost && (sk.id != .item || hasUsableItem)
                        Button { pick(sk, a) } label: { skillButton(sk, can: can, tip: sk.id == tip, on: picking == sk.id) }
                            .disabled(!can)
                    }
                }
            }
            .padding(10)
            .background(panelBG.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var hasUsableItem: Bool { ["tea", "oil", "jar"].contains { (w.s.bag[$0] ?? 0) > 0 } }

    private func skillButton(_ sk: Skill, can: Bool, tip: Bool, on: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: sk.icon).font(.system(size: 17, weight: .semibold)).frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(sk.name).font(.subheadline.weight(.bold))
                Text(sk.text).font(.system(size: 10)).foregroundStyle(mutedText).lineLimit(2).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if sk.cost > 0 {
                HStack(spacing: 1) { Image(systemName: "light.max").font(.system(size: 9)); Text("\(sk.cost)").font(.caption.monospacedDigit().weight(.bold)) }
                    .foregroundStyle(gold)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .background(on ? gold.opacity(0.3) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tip ? gold.opacity(0.85) : Color.white.opacity(0.08), lineWidth: tip ? 1.6 : 1))
        .opacity(can ? 1 : 0.35)
    }

    private var itemList: some View {
        VStack(spacing: 8) {
            HStack {
                Text("用什么？").font(.footnote.weight(.semibold)).foregroundStyle(gold)
                Spacer()
                Button { itemMenu = false } label: { Label("返回", systemImage: "arrow.uturn.backward").font(.footnote) }.foregroundStyle(mutedText)
            }
            ForEach(["tea", "oil", "jar"], id: \.self) { id in
                let n = w.s.bag[id] ?? 0
                if n > 0, let it = w.c.items[id] {
                    Button { useItem(id) } label: {
                        HStack {
                            Image(systemName: it.icon).frame(width: 24)
                            Text(it.name).font(.subheadline.weight(.bold))
                            Text(it.text).font(.caption).foregroundStyle(mutedText)
                            Spacer()
                            Text("×\(n)").font(.callout.monospacedDigit())
                        }
                        .foregroundStyle(.white).padding(10)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(10)
        .background(panelBG.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: choosing

    private func pick(_ sk: Skill, _ a: Fighter) {
        Haptic.light()
        switch sk.aim {
        case .foe:
            let living = b?.foes.filter { $0.alive } ?? []
            if living.count == 1 { commit(BattleAction(actor: a.id, skill: sk.id, target: living[0].id)) } else { picking = sk.id }
        default:
            if sk.id == .item { itemMenu = true; return }
            commit(BattleAction(actor: a.id, skill: sk.id))
        }
    }
    private func choose(target: Int) {
        guard let a = actor, let sk = picking else { return }
        picking = nil
        commit(BattleAction(actor: a.id, skill: sk, target: target))
    }
    private func useItem(_ id: String) {
        guard let a = actor else { return }
        itemMenu = false
        if id == "tea" {
            let low = b?.party.filter { $0.alive }.min { Double($0.hp) / Double($0.maxHP) < Double($1.hp) / Double($1.maxHP) }
            commit(BattleAction(actor: a.id, skill: .item, target: low?.id, item: id))
        } else {
            commit(BattleAction(actor: a.id, skill: .item, item: id))
        }
    }
    private func pickTea(_ target: Int) {}
    private func back() {
        if picking != nil { picking = nil; return }
        if !chosen.isEmpty { chosen.removeLast() }
    }
    private func commit(_ act: BattleAction) {
        chosen.append(act)
        if actor == nil { Task { await play() } }
    }

    // MARK: playing a round

    private func play() async {
        guard var st = w.battle else { return }
        playing = true
        let acts = chosen
        chosen = []
        // spend the items now
        for a in acts where a.skill == .item { if let i = a.item { w.s.bag[i, default: 0] -= 1; if w.s.bag[i] == 0 { w.s.bag[i] = nil } } }
        let before = st
        let events = Battle.resolve(&st, acts)
        // show it step by step, starting from the state before the round
        var shown = before
        lightShown = shown.light
        for e in events {
            apply(e, &shown, final: st)
            w.battle = shown
            try? await Task.sleep(for: .milliseconds(delay(e)))
        }
        w.battle = st
        lightShown = st.light
        playing = false
        switch st.outcome {
        case .won:
            caption = "赢了！"; Sound.shared.win(); Haptic.success()
            try? await Task.sleep(for: .milliseconds(900))
            w.endBattle()
        case .lost:
            caption = "眼前一黑……"; Haptic.warn()
            try? await Task.sleep(for: .milliseconds(1200))
            w.endBattle()
        case .fled:
            caption = "逃掉了。"
            try? await Task.sleep(for: .milliseconds(700))
            w.endBattle()
        case .ongoing:
            caption = "第 \(st.round) 回合"
        }
    }

    private func delay(_ e: BattleEvent) -> Int {
        switch e {
        case .act: return 420
        case .damage, .heal: return 380
        case .ko: return 300
        case .light: return 120
        default: return 260
        }
    }

    /// Mirrors one event onto the shown state (HP, light) and makes it seen and heard.
    private func apply(_ e: BattleEvent, _ s: inout BattleState, final: BattleState) {
        func name(_ id: Int) -> String { (s.fighter(id) ?? final.fighter(id))?.name ?? "" }
        switch e {
        case .act(let id, let what):
            caption = "\(name(id)) · \(what)"
        case .damage(let id, let n, let weak, let resisted):
            if let i = s.index(id) { s.fighters[i].hp = max(0, s.fighters[i].hp - n) }
            floats.append(Floater(target: id, text: "-\(n)\(weak ? " 弱点！" : resisted ? " 抵挡" : "")", color: weak ? gold : resisted ? mutedText : .white, at: Date()))
            flash[id] = Date()
            if final.fighter(id)?.isFoe == true { Sound.shared.push() } else { Sound.shared.dim(); Haptic.light() }
        case .heal(let id, let n):
            if let i = s.index(id) { s.fighters[i].hp = min(s.fighters[i].maxHP, s.fighters[i].hp + n) }
            if n > 0 { floats.append(Floater(target: id, text: "+\(n)", color: Color(0x7fd18b), at: Date())); Sound.shared.light() }
        case .light(let d):
            s.light = max(0, min(Battle.lightMax, s.light + d)); lightShown = s.light
        case .stolen(let id, let n):
            if let i = s.index(id) { s.fighters[i].stolen += n }
            floats.append(Floater(target: id, text: "偷走 \(n) 光", color: Color(0xb07af0), at: Date())); Sound.shared.motif(.mosto)
        case .regain(let id, let n):
            if let i = s.index(id) { s.fighters[i].stolen = 0 }
            floats.append(Floater(target: id, text: "抢回 \(n) 光", color: gold, at: Date())); Sound.shared.motif(.moss)
        case .stun(let id):
            if let i = s.index(id) { s.fighters[i].stun = 1 }
            floats.append(Floater(target: id, text: "晕了", color: .yellow, at: Date()))
        case .slow(let id):
            if let i = s.index(id) { s.fighters[i].slow = true }
            floats.append(Floater(target: id, text: "被推开", color: .cyan, at: Date()))
        case .reveal(let id):
            if let i = s.index(id), let f = final.fighter(id) { s.fighters[i].revealed = true; s.fighters[i].intents = f.intents }
            floats.append(Floater(target: id, text: "看穿了", color: gold, at: Date())); Sound.shared.touch()
        case .shell(let id):
            if let i = s.index(id) { s.fighters[i].shell = true }
        case .guard, .defend:
            break
        case .summon(let id):
            if let f = final.fighter(id) { s.fighters.append(f) }
        case .ko(let id):
            if final.fighter(id)?.isFoe == true { gone.insert(id) }
        case .fled(let ok):
            caption = ok ? "逃掉了。" : "逃不掉！"
        }
        // intents and statuses settle to what they'll be
        for f in final.fighters where f.isFoe { if let i = s.index(f.id) { s.fighters[i].intents = f.intents } }
        floats.removeAll { Date().timeIntervalSince($0.at) > 1.2 }
    }
}

struct FloatText: View {
    let f: BattleView.Floater
    @State private var up = false
    var body: some View {
        Text(f.text).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(f.color)
            .shadow(color: .black, radius: 2)
            .offset(y: up ? -46 : -10).opacity(up ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 1.0)) { up = true } }
            .allowsHitTesting(false)
    }
}

/// A foe in battle: its rendered sprite, breathing; the maw's belly glows with what it has stolen.
struct FoeSprite: View {
    let kind: FoeKind
    var stolen = 0
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let name = Art.meta["foe_\(kind.rawValue)"] != nil ? "foe_\(kind.rawValue)" : "shadow"
            ZStack {
                if stolen > 0 {
                    Circle().fill(RadialGradient(colors: [Color(0xffd27a).opacity(0.25 + 0.1 * Double(stolen)), .clear], center: .center, startRadius: 2, endRadius: 60))
                        .scaleEffect(0.8 + 0.1 * sin(t * 4))
                }
                if let ui = Art.uiImage(name + "_n") ?? Art.uiImage(name) {
                    Image(uiImage: ui).resizable().aspectRatio(contentMode: .fit)
                        .scaleEffect(x: 1 + 0.02 * sin(t * 2.4), y: 1 - 0.02 * sin(t * 2.4), anchor: .bottom)
                }
            }
        }
    }
}
