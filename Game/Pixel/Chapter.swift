import Foundation

// Chapter one: the lighthouse town, five nights. Each night has a place, a dawn, the waves of shadows that come, and
// a few lines before and after. Names are the cast's Chinese names: 奥托 Otto, 莫斯 Moss, 莫斯托 Mosto, 汉克 Hank,
// 朵拉 Dora, 琳恩 Lynn.

struct Say: Equatable { var who: String; var text: String }

enum ChapterOne {
    static func w(_ t: Double, _ type: FoeType, _ n: Int) -> Wave { Wave(t: t, type: type, n: n) }

    static let nights: [NightSpec] = [
        NightSpec(id: 1, name: "第一夜 · 灯塔顶", place: "top", dawn: 60, drain: 0.5, waves: [
            w(1.5, .shade, 1), w(6, .shade, 1), w(10, .shade, 2), w(16, .shade, 2), w(23, .shade, 3),
            w(31, .shade, 3), w(39, .shade, 4), w(47, .shade, 4), w(54, .shade, 3)], thiefAt: nil, boss: nil, teach: "drag"),
        NightSpec(id: 2, name: "第二夜 · 北街", place: "street", dawn: 80, drain: 0.85, waves: [
            w(2, .shade, 2), w(7, .shell, 1), w(13, .shade, 4), w(20, .shell, 1), w(20, .shade, 3), w(28, .shell, 2),
            w(36, .shade, 4), w(44, .shell, 2), w(44, .shade, 2), w(55, .shade, 5), w(64, .shell, 3), w(72, .shade, 4)],
                  thiefAt: nil, boss: nil, teach: "loop"),
        NightSpec(id: 3, name: "第三夜 · 码头", place: "dock", dawn: 90, drain: 1.05, waves: [
            w(2, .shade, 4), w(8, .moth, 3), w(15, .shade, 4), w(16, .moth, 2), w(24, .shell, 2), w(25, .moth, 3),
            w(34, .shade, 6), w(44, .moth, 4), w(45, .shell, 1), w(56, .shade, 5), w(57, .moth, 3), w(68, .shell, 2),
            w(69, .shade, 4), w(78, .moth, 4), w(80, .shade, 5)], thiefAt: nil, boss: nil, teach: "wake"),
        NightSpec(id: 4, name: "第四夜 · 广场", place: "square", dawn: 100, drain: 1.2, waves: [
            w(3, .shade, 4), w(10, .fang, 1), w(18, .shade, 4), w(19, .fang, 1), w(28, .shell, 2), w(29, .moth, 3),
            w(50, .shade, 6), w(51, .shell, 1), w(62, .fang, 2), w(63, .moth, 3), w(76, .shade, 6), w(77, .fang, 1),
            w(88, .shell, 2), w(89, .shade, 4)], thiefAt: 38, boss: nil, teach: "fang"),
        NightSpec(id: 5, name: "第五夜 · 旧灯窖", place: "cellar", dawn: 0, drain: 0.6, waves: [
            w(2, .shade, 2), w(18, .moth, 2), w(36, .shell, 2), w(60, .moth, 3), w(80, .shell, 2)],
                  thiefAt: nil, boss: true, teach: "boss"),
    ]

    static func s(_ who: String, _ text: String) -> Say { Say(who: who, text: text) }

    static let before: [Int: [Say]] = [
        1: [s("h", "主灯的光，昨晚被一团黑东西吞了。"), s("h", "今晚只剩你头上那一点光了，奥托。"), s("o", "……我守着。")],
        2: [s("m", "我叫莫斯。你的光，能借我摸一下吗？"), s("o", "……摸吧。"), s("h", "北街的冷影越来越多，有的还背着石头壳。"),
            s("m", "那我绕着它们跑一圈！")],
        3: [s("n", "码头上的灯蛾在抢地上的光屑。"), s("n", "要是奥托又打瞌睡，就点他一下。"), s("o", "我没睡。"), s("m", "他睡了。")],
        4: [s("d", "我的灯笼被偷了！"), s("d", "屋顶上有个戴歪王冠的小影子，抱着光跑了。"), s("m", "那光是我的！"),
            s("o", "……那是朵拉的。")],
        5: [s("h", "城外旧灯窖里，有一团大影子吃了主灯的光。"), s("m", "它肚子亮的时候，我们就套它。"), s("o", "走吧。")],
    ]

    static let after: [Int: [Say]] = [
        1: [s("", "天边泛白，冷影缩回了墙根。"), s("", "一块长着薄荷叶的小石头，从黑暗里走过来，摸了摸奥托的灯珠。"), s("m", "热的。")],
        2: [s("h", "北街守住了。"), s("m", "我绕的圈最圆！"), s("o", "……还行。")],
        3: [s("n", "灯蛾都散了。谢谢你们。"), s("n", "拿着，这些光屑够换一截灯芯。")],
        4: [s("x", "嘻嘻。"), s("", "戴王冠的小家伙从屋顶上探出头，怀里抱着一团火——比朵拉的灯笼亮得多。"),
            s("x", "灯塔城的光，我都要了。"), s("m", "……那团火是太阳的。")],
        5: [s("", "灯吞散成一地黑烟，主灯的光飞回了灯塔。"), s("x", "主灯那点光？零头而已。"),
            s("x", "太阳的火在我这儿。想要？来影子国拿。"), s("", "莫斯托抱着火，飞进了更深的夜里。"), s("m", "那是我的。"), s("o", "走吧。")],
    ]

    /// The first time something new appears in a night, a short line says what to do with it.
    static func teach(_ key: String) -> String {
        switch key {
        case "drag": return "按住屏幕拖着莫斯跑，用光丝扫碎影子"
        case "loop": return "绕一圈把轨迹接上，圈里的都会被套住——石壳影只能这样打"
        case "wake": return "灯快灭了就点一下奥托，叫醒他"
        case "fang": return "尖影闪「！」后会直冲奥托：在它冲刺的路上横一根光丝"
        case "thief": return "莫斯托偷了光要逃：把他圈住，光就回来"
        case "boss": return "灯吞吃了光屑，肚子会发亮：那时套住它，伤害翻倍"
        default: return ""
        }
    }
}
