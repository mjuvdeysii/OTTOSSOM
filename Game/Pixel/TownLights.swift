import SwiftUI

/// The six windows belong to people, not to colors in an inventory.
struct TownResident: Identifiable {
    let id: String
    let windowX: Int
    let windowY: Int
    let request: String
    let response: String
    let returnThanks: String

    static let all: [TownResident] = [
        TownResident(id: "h", windowX: 152, windowY: 143,
                     request: "守灯室的灯也熄了。想补灯芯，得先看清线头。",
                     response: "线头看清了。你们下井时，我来替奥托看一会儿绳子。",
                     returnThanks: "守灯室换上新光了。绳结我也检查过，放心。"),
        TownResident(id: "n", windowX: 97, windowY: 140,
                     request: "小摊收了，还要在屋里分零件。黑着会把螺帽数错。",
                     response: "螺帽分好了。明晚来，我把爪子怎么保养再讲给你听。",
                     returnThanks: "还是你们配的光好。落在地上的小螺帽也看得见。"),
        TownResident(id: "d", windowX: 66, windowY: 152,
                     request: "窗边太黑了。我想在灯下缝好那只破掉的布偶。",
                     response: "布偶补好了。我给它留了一只手，等朋友来牵。",
                     returnThanks: "布偶坐在新灯旁边。这次我给它缝了一条小围巾。"),
        TownResident(id: "t1", windowX: 33, windowY: 147,
                     request: "还有三封信没分好。天黑后，信封上的字都挤在一起。",
                     response: "三封信都找到了主人。明天敲门时，终于不用先说抱歉了。",
                     returnThanks: "今天的信分好了。你们的灯，我一直留在桌边。"),
        TownResident(id: "t2", windowX: 12, windowY: 178,
                     request: "面团要等到后半夜。我想看着它，别又错过发好的时候。",
                     response: "今晚看清面团了。下一炉面包，能在大家出门前烤好。",
                     returnThanks: "新光照着案板，面粉也像小晶石。明早记得闻闻面包香。"),
        TownResident(id: "t3", windowX: 190, windowY: 184,
                     request: "旧海图还没看完。想找找那条年轻时走过的航线。",
                     response: "航线找到了。原来绕远的那一段，是为了送一个朋友回家。",
                     returnThanks: "海图又翻了一页。有些老地方，在新光下才看得清。"),
    ]

    static func find(_ id: String) -> TownResident? { all.first { $0.id == id } }
}

/// The same source coordinates are used in the full town and the closer street view.
private struct TownArtwork: View {
    let pixel: CGFloat
    let lamps: [String: TownLamp]

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelImage(name: "town", pt: pixel)
            ForEach(TownResident.all) { person in
                if let lamp = lamps[person.id] {
                    let color = Color(lamp.color.rgb)
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(color)
                            .shadow(color: color.opacity(0.8), radius: pixel * 5)
                        Rectangle().fill(pxInk).frame(width: pixel, height: pixel * 10).offset(x: pixel * 3)
                        Rectangle().fill(pxInk).frame(width: pixel * 7, height: pixel).offset(y: pixel * 5)
                    }
                    .frame(width: pixel * 7, height: pixel * 10)
                    .offset(x: CGFloat(person.windowX) * pixel, y: CGFloat(person.windowY) * pixel)
                }
            }
        }
        .frame(width: pixel * 200, height: pixel * 440, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

struct LitTownBackdrop: View {
    let save: DigSave
    let scale: PixelScale
    var body: some View {
        GeometryReader { g in
            TownArtwork(pixel: scale.pt, lamps: save.townLamps ?? [:])
                .position(x: g.size.width / 2, y: g.size.height - scale.pt * 220)
        }
        .background(Color(0x070a18))
        .ignoresSafeArea()
    }
}

struct TownLights: View {
    let save: DigSave
    let scale: PixelScale
    var close: () -> Void

    var body: some View {
        let pt = scale.pt, k = scale.k
        let count = TownResident.all.filter { save.townLamps?[$0.id] != nil }.count
        VStack(spacing: pt * 6) {
            Text("镇上的灯 · \(count)/6").font(PixelFont.font(1, k: k)).foregroundStyle(pxGold)
            GeometryReader { g in
                let pixel = max(1, floor(g.size.width * UIScreen.main.scale / 200)) / UIScreen.main.scale
                TownArtwork(pixel: pixel, lamps: save.townLamps ?? [:])
                    .offset(x: (g.size.width - pixel * 200) / 2, y: -pixel * 120)
            }
            .frame(height: pt * 80).clipped()
            Text(count == 0 ? "交出的灯，会亮在他们的窗边" : "往下看看，光照到了谁的生活")
                .font(PixelFont.font(1, k: k)).foregroundStyle(Color(0x9a94b8))
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: pt * 10) {
                    ForEach(TownResident.all) { person in
                        let lamp = save.townLamps?[person.id]
                        HStack(alignment: .top, spacing: pt * 5) {
                            PixelImage(name: LampShop.portrait(person.id), pt: pt)
                            VStack(alignment: .leading, spacing: pt * 3) {
                                Text(DigStory.name(person.id)).foregroundStyle(pxGold)
                                if let lamp {
                                    Text("\(lamp.color.name) · 第 \(lamp.day) 天送到")
                                        .foregroundStyle(Color(lamp.color.rgb))
                                    Text(lamp.deliveries > 1 ? person.returnThanks : person.response).foregroundStyle(pxCream)
                                } else {
                                    Text("还在等一盏灯").foregroundStyle(Color(0x9a94b8))
                                    Text(person.request).foregroundStyle(pxCream)
                                }
                            }
                            .font(PixelFont.font(1, k: k))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxHeight: pt * 150)
            PixelButton(title: "回到小摊", k: k) { close() }
        }
        .padding(pt * 8)
        .modifier(PixelPanel(pt: pt, fill: Color(0x141024)))
        .padding(.horizontal, pt * 6)
        .padding(.top, SafeArea.top + pt * 2)
        .padding(.bottom, SafeArea.bottom + pt * 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.75).ignoresSafeArea())
    }
}
