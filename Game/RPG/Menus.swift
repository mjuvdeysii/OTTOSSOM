import SwiftUI

/// The party, the bag and the quests, in one sheet.
struct PartyMenu: View {
    @ObservedObject var w: World
    @Environment(\.dismiss) var dismiss
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("", selection: $tab) {
                    Text("队伍").tag(0)
                    Text("背包").tag(1)
                    Text("任务").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                ScrollView {
                    VStack(spacing: 12) {
                        switch tab {
                        case 0: party
                        case 1: bag
                        default: quests
                        }
                    }
                    .padding(16)
                }
            }
            .padding(.top, 8)
            .background(nightBG.ignoresSafeArea())
            .navigationTitle(tab == 0 ? "队伍" : tab == 1 ? "背包" : "任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("好") { dismiss() } }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: party

    private var party: some View {
        ForEach(w.s.members, id: \.hero) { m in
            let st = Stats.of(m)
            let next = Stats.levels[min(m.level, Stats.levels.count - 1)]
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Face(hero: m.hero).frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(Stats.name(m.hero)).font(.headline).foregroundStyle(.white)
                            Text("Lv\(m.level)").font(.subheadline.monospacedDigit()).foregroundStyle(gold)
                        }
                        Bar(value: Double(m.hp) / Double(max(1, st.maxHP)), tint: Color(0x7fd18b))
                        Text("生命 \(m.hp)/\(st.maxHP) · 经验 \(m.xp)/\(next)").font(.caption.monospacedDigit()).foregroundStyle(mutedText)
                    }
                }
                HStack(spacing: 14) {
                    stat("攻击", "\(st.atk)")
                    stat("防御", "\(st.def)")
                    stat("速度", String(format: "%.0f", st.spd))
                }
                HStack(spacing: 8) {
                    Image(systemName: m.hero == .otto ? "lamp.desk.fill" : "leaf.fill").foregroundStyle(gold)
                    Text(m.equip.flatMap { w.c.items[$0]?.name } ?? "没有装备").font(.subheadline).foregroundStyle(.white)
                    Spacer()
                    if let e = m.equip, let it = w.c.items[e] { Text(it.text).font(.caption).foregroundStyle(mutedText) }
                }
                .padding(10)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(skills(m), id: \.id) { sk in
                        let has = w.learned(m.hero, m.level, sk.id)
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: sk.icon).frame(width: 22).foregroundStyle(has ? gold : mutedText)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(sk.name + (sk.cost > 0 ? " · \(sk.cost) 光" : "") + (has ? "" : " · Lv\(sk.level) 学会")).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(has ? .white : mutedText)
                                Text(sk.text).font(.caption).foregroundStyle(mutedText).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(panelBG, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func skills(_ m: Member) -> [Skill] {
        let ids: [SkillID] = m.hero == .otto ? [.shine, .warm, .flare, .vigil] : [.bump, .touch, .shove, .mine]
        return ids.compactMap { Skill.all[$0] }
    }

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.headline.monospacedDigit()).foregroundStyle(.white)
            Text(k).font(.caption2).foregroundStyle(mutedText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: bag

    private var bag: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "sparkle").foregroundStyle(gold)
                Text("光屑 \(w.s.motes)").font(.headline.monospacedDigit()).foregroundStyle(.white)
                Spacer()
            }
            let ids = w.s.bag.keys.sorted { (w.c.items[$0]?.kind ?? "") > (w.c.items[$1]?.kind ?? "") }
            if ids.isEmpty { Text("背包是空的。").foregroundStyle(mutedText).padding(.top, 20) }
            ForEach(ids, id: \.self) { id in
                if let it = w.c.items[id], let n = w.s.bag[id], n > 0 {
                    HStack(spacing: 10) {
                        Image(systemName: it.icon).font(.title3).foregroundStyle(gold).frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(it.name) ×\(n)").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text(it.text).font(.caption).foregroundStyle(mutedText).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        if it.kind == "equip", let h = it.hero.flatMap({ Hero(rawValue: $0) }), w.s.members.contains(where: { $0.hero == h }) {
                            Button("装备") { w.equip(id, on: h) }.buttonStyle(.borderedProminent).tint(gold).foregroundStyle(.black)
                        } else if id == "tea" {
                            Menu("喝") {
                                ForEach(w.s.members, id: \.hero) { m in Button(Stats.name(m.hero)) { w.useOutside(id, on: m.hero) } }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(12)
                    .background(panelBG, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: quests

    private var quests: some View {
        VStack(spacing: 10) {
            ForEach(["main", "dora", "net", "stones"], id: \.self) { q in
                if let i = w.s.quests[q], let quest = w.c.quests[q] {
                    let done = i >= quest.steps.count - 1
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: q == "main" ? "flag.fill" : done ? "checkmark.circle.fill" : "circle.dotted").foregroundStyle(gold)
                            Text(quest.name).font(.headline).foregroundStyle(.white)
                            Spacer()
                            if q == "main" { Text("主线").font(.caption2).foregroundStyle(gold) }
                        }
                        Text(quest.steps[min(i, quest.steps.count - 1)].text + progress(q)).font(.subheadline).foregroundStyle(done ? mutedText : Color(0xd8dcf0))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(panelBG, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func progress(_ q: String) -> String {
        switch q {
        case "dora" where w.quest("dora") == "find": return "（\(["fly1", "fly2", "fly3"].filter { w.s.opened.contains($0) }.count)/3）"
        case "net" where w.quest("net") == "clear": return "（\(["f_dock1", "f_dock2", "f_dock3"].filter { w.s.beaten.contains($0) }.count)/3）"
        case "stones" where w.quest("stones") == "read": return "（\(["stone1", "stone2", "stone3"].filter { w.s.opened.contains($0) }.count)/3）"
        default: return ""
        }
    }
}

struct ShopSheet: View {
    @ObservedObject var w: World
    let items: [String]
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    HStack {
                        Face(hero: nil, sprite: "npc_n_n").frame(width: 44, height: 44)
                        Text("琳恩的小摊").font(.headline).foregroundStyle(.white)
                        Spacer()
                        Label("\(w.s.motes)", systemImage: "sparkle").font(.headline.monospacedDigit()).foregroundStyle(gold)
                    }
                    ForEach(items, id: \.self) { id in
                        if let it = w.c.items[id] {
                            HStack(spacing: 10) {
                                Image(systemName: it.icon).font(.title3).foregroundStyle(gold).frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(it.name + ((w.s.bag[id] ?? 0) > 0 ? "（有 \(w.s.bag[id]!)）" : "")).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                    Text(it.text).font(.caption).foregroundStyle(mutedText).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                Button { w.buy(id) } label: { Label("\(it.price)", systemImage: "sparkle").font(.subheadline.monospacedDigit()) }
                                    .buttonStyle(.borderedProminent).tint(gold).foregroundStyle(.black)
                                    .disabled(w.s.motes < it.price)
                            }
                            .padding(12)
                            .background(panelBG, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(16)
            }
            .background(nightBG.ignoresSafeArea())
            .navigationTitle("买东西")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("好") { w.shop = nil; dismiss() } }
        }
        .preferredColorScheme(.dark)
    }
}
