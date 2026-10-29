"""Builds Game/Resources/rpg.json — the first region's maps, people, chests, foes, quests and lines — and checks it:
every row the same width, everything placed on open ground, every exit and goal reachable from where you arrive.

  python3 Tools/rpg/build.py

Map legend (terrain only; people, chests, foes and lamps are entities):
  #  cliff / wall        .  path          ,  grass          T  tree          R  rock
  H  house               ~  water         =  planks / bridge                F  fence
  i  dark street lamp    ^  lighthouse    B  market stall   D  doorway (an exit)
  t  stone tablet        s  stairs down   u  stairs up      x  cellar wall
"""
import json, os, collections

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLOCK = set("#TRH~Fi^Btx")

MAPS = {}

# ---------------------------------------------------------------- 灯塔城 (sea at the bottom, gate at the top)
MAPS["town"] = dict(name="灯塔城", theme="town", music=1, dark=0.35, map=[
    "#######D#######",
    "#TT,.......,TT#",
    "#T,..i...i..,T#",
    "#HH.........HH#",
    "#HH..,...,..HH#",
    "#.....HHH.....#",
    "#.i...HHH...i.#",
    "#.............#",
    "#HH.........HH#",
    "#HH..,...,..HH#",
    "#......B......#",
    "#.i.........i.#",
    "#HHH.......HHH#",
    "#HHH.,...,.HHH#",
    "#.............#",
    "#~~~~.....i...#",
    "#~~~==........#",
    "#~~~==....HH..#",
    "#~~~==........#",
    "#~~~~~~...^^^.#",
    "#~~~~~~...^^^.#",
    "###############",
])
# ---------------------------------------------------------------- 城外荒野 (town gate at the bottom, the cellar at the top)
MAPS["wilds"] = dict(name="城外荒野", theme="wilds", music=2, dark=0.45, map=[
    "###TTT#s#TTT###",
    "#TT,,,...,,,TT#",
    "#T,,R.....R,,T#",
    "#T,...,,,...,T#",
    "#,,..TT.TT..,,#",
    "#R...T...T...R#",
    "#....t.......,#",
    "#,,.......,,TT#",
    "#TT,,R....,,,T#",
    "#~~~~~~=~~~~~~#",
    "#~~~~~~=~~~~~~#",
    "#,,.........,,#",
    "#T,..R...R..,T#",
    "#T......,....T#",
    "#,,.TT...TT.,,#",
    "#....T...T....#",
    "#.R.........R.#",
    "#,,,...t...,,,#",
    "#TT,.......,TT#",
    "#T,,..R.R..,,T#",
    "#,,.........,,#",
    "#.....,,,.....#",
    "#TT.........TT#",
    "#TTT,..D..,TTT#",
])
# ---------------------------------------------------------------- 旧灯窖 一层 (dark; only Otto's bead and lit lamps show it)
MAPS["cellar1"] = dict(name="旧灯窖 · 一层", theme="cellar", music=3, dark=0.9, fog=True, map=[
    "xxxxxxxxxxxxx",
    "x.....s.....x",
    "x...........x",
    "x...........x",
    "xxxxxx.xxxxxx",
    "xxxx.....xxxx",
    "xxxx.....xxxx",
    "xxxx.....xxxx",
    "xxxx.xxx.xxxx",
    "x....xxx....x",
    "x....xxx....x",
    "x....xxx....x",
    "xt...xxx....x",
    "xx.xxxxxxx.xx",
    "xx.xxxxxxx.xx",
    "x...........x",
    "x...........x",
    "x.....u.....x",
    "xxxxxxxxxxxxx",
])
# ---------------------------------------------------------------- 旧灯窖 二层: the maw's room
MAPS["cellar2"] = dict(name="旧灯窖 · 二层", theme="cellar", music=4, dark=0.8, fog=True, map=[
    "xxxxxxxxxxx",
    "x.........x",
    "x.x.....x.x",
    "x.........x",
    "x.........x",
    "x.........x",
    "xx.x...x.xx",
    "x.........x",
    "x.x.....x.x",
    "x.........x",
    "xxxxxu.xxxx",
])

# ---------------------------------------------------------------- what's in them
ENT = {
    "town": dict(
        start=[11, 18],
        exits=[dict(at=[7, 0], to="wilds", arrive=[7, 22], need="moss")],
        lamps=[dict(id="square", at=[7, 7])],
        npcs=[
            dict(id="hank", sprite="npc_h", at=[9, 18], talk="hank"),
            dict(id="dora", sprite="npc_d", at=[4, 7], talk="dora"),
            dict(id="lynn", sprite="npc_n", at=[8, 10], talk="lynn", shop=["tea", "oil", "jar", "leafHard"]),
            dict(id="moss", sprite="moss_idle", at=[7, 4], talk="mossMeet", until="moss"),
        ],
        chests=[dict(id="t1", at=[1, 7], item="shadeOld"), dict(id="t2", at=[13, 14], item="tea", n=2)],
        foes=[
            dict(id="f_t1", at=[10, 13], party=["shade"], roam=2),
            dict(id="f_dock1", at=[6, 16], party=["shade"], roam=1, quest="net"),
            dict(id="f_dock2", at=[7, 18], party=["shade"], roam=1, quest="net"),
            dict(id="f_dock3", at=[5, 14], party=["shade", "shade"], roam=1, quest="net"),
        ],
        tablets=[],
        motes=[],
    ),
    "wilds": dict(
        exits=[dict(at=[7, 23], to="town", arrive=[7, 1]), dict(at=[7, 0], to="cellar1", arrive=[5, 17])],
        lamps=[dict(id="bridge", at=[6, 11]), dict(id="ridge", at=[8, 3])],
        npcs=[],
        chests=[dict(id="w1", at=[1, 11], item="leafSprout"), dict(id="w2", at=[13, 6], item="oil", n=2),
                dict(id="w3", at=[12, 20], item="motes", n=25), dict(id="w4", at=[2, 2], item="tea", n=2)],
        foes=[
            dict(id="f_w1", at=[7, 19], party=["shade"], roam=2),
            dict(id="f_w2", at=[3, 16], party=["shell"], roam=2),
            dict(id="f_w3", at=[11, 15], party=["moth", "shade"], roam=2),
            dict(id="f_w4", at=[7, 13], party=["fang"], roam=2),
            dict(id="f_w5", at=[3, 7], party=["shell", "moth"], roam=2),
            dict(id="f_w6", at=[11, 4], party=["shade", "shade"], roam=2),
            dict(id="f_w7", at=[7, 2], party=["fang", "shade"], roam=1),
        ],
        tablets=[dict(id="stone1", at=[5, 6], lore="stone1"), dict(id="stone2", at=[7, 17], lore="stone2")],
        motes=[dict(id="fly1", at=[13, 21]), dict(id="fly2", at=[2, 13]), dict(id="fly3", at=[11, 1])],
    ),
    "cellar1": dict(
        exits=[dict(at=[6, 17], to="wilds", arrive=[7, 1]), dict(at=[6, 1], to="cellar2", arrive=[5, 9], need="bigshade")],
        lamps=[dict(id="c1a", at=[1, 15]), dict(id="c1b", at=[11, 9]), dict(id="c1c", at=[10, 2])],
        npcs=[],
        chests=[dict(id="c1", at=[1, 9], item="shadeGlass"), dict(id="c2", at=[11, 12], item="leafDew"),
                dict(id="c3", at=[4, 5], item="tea", n=3), dict(id="c4", at=[1, 3], item="jar", n=1)],
        foes=[
            dict(id="f_c1", at=[10, 16], party=["fang", "shade"], roam=1),
            dict(id="f_c2", at=[3, 11], party=["shell", "shell"], roam=1),
            dict(id="f_c3", at=[9, 10], party=["moth", "moth", "shade"], roam=1),
            dict(id="f_c4", at=[6, 6], party=["fang"], roam=1),
            dict(id="f_mini", at=[6, 2], party=["bigshade"], roam=0, boss=True),
        ],
        tablets=[dict(id="stone3", at=[1, 12], lore="stone3")],
        motes=[],
    ),
    "cellar2": dict(
        exits=[dict(at=[5, 10], to="cellar1", arrive=[6, 2])],
        lamps=[dict(id="c2a", at=[5, 8])],
        npcs=[],
        chests=[],
        foes=[dict(id="f_boss", at=[5, 3], party=["maw"], roam=0, boss=True)],
        tablets=[],
        motes=[],
    ),
}

ITEMS = {
    "tea": dict(name="暖茶", kind="use", icon="cup.and.saucer.fill", price=8, text="回复 40 生命。"),
    "oil": dict(name="灯油", kind="use", icon="drop.fill", price=12, text="战斗中 +3 光。"),
    "jar": dict(name="萤火罐", kind="use", icon="sparkles", price=20, text="战斗中打开，所有敌人受 14 伤害。"),
    "shadeOld": dict(name="旧灯罩", kind="equip", hero="otto", icon="lamp.desk.fill", price=0, df=2, text="奥托 · 防御 +2"),
    "shadeCopper": dict(name="铜灯罩", kind="equip", hero="otto", icon="lamp.desk.fill", price=0, atk=3, text="奥托 · 攻击 +3"),
    "shadeGlass": dict(name="琉璃灯罩", kind="equip", hero="otto", icon="lamp.desk.fill", price=0, atk=2, light=1, text="奥托 · 攻击 +2，开战多 1 光"),
    "leafSprout": dict(name="嫩叶饰", kind="equip", hero="moss", icon="leaf.fill", price=0, hp=10, text="莫斯 · 生命 +10"),
    "leafHard": dict(name="硬叶饰", kind="equip", hero="moss", icon="leaf.fill", price=60, atk=3, text="莫斯 · 攻击 +3"),
    "leafDew": dict(name="露珠叶饰", kind="equip", hero="moss", icon="leaf.fill", price=0, spd=3, hp=6, text="莫斯 · 速度 +3，生命 +6"),
    "motes": dict(name="光屑", kind="money", icon="sparkle", price=0, text=""),
}

QUESTS = {
    "main": dict(name="主灯的光", steps=[
        dict(id="leave", text="走下灯塔，去广场看看", goal=["town", 7, 6]),
        dict(id="moss", text="跟着黑痕去广场，找那块会走路的苔石", goal=["town", 7, 4]),
        dict(id="gate", text="出城门，往荒野去", goal=["town", 7, 0]),
        dict(id="cellar", text="穿过荒野，找到旧灯窖", goal=["wilds", 7, 0]),
        dict(id="mini", text="灯窖一层：打倒堵在楼梯口的大影", goal=["cellar1", 6, 2]),
        dict(id="boss", text="下到二层，把主灯的光抢回来", goal=["cellar2", 5, 3]),
        dict(id="home", text="回灯塔，告诉汉克", goal=["town", 9, 18]),
        dict(id="done", text="主灯又亮了。莫斯托往影子国去了。", goal=None),
    ]),
    "dora": dict(name="朵拉的灯笼", steps=[
        dict(id="find", text="在荒野找到 3 团萤火", goal=None),
        dict(id="back", text="把萤火交给朵拉", goal=["town", 4, 7]),
        dict(id="done", text="朵拉的灯笼亮了", goal=None),
    ]),
    "net": dict(name="琳恩的渔网", steps=[
        dict(id="clear", text="赶走码头的冷影", goal=["town", 6, 16]),
        dict(id="back", text="告诉琳恩码头清了", goal=["town", 8, 10]),
        dict(id="done", text="琳恩又能补网了", goal=None),
    ]),
    "stones": dict(name="三块石碑", steps=[
        dict(id="read", text="让莫斯摸一摸三块石碑", goal=None),
        dict(id="done", text="石碑说完了太阳的事", goal=None),
    ]),
}

# lines: who (o otto, m moss, x mosto, h hank, d dora, n lynn, "" narration) and the line. Kept short.
LINES = {
    "intro": [["h", "又一盏。"], ["h", "主灯的光，昨晚被一团黑东西吞了，往城外去了。"], ["h", "再这么黑下去，冷影要爬进城了。"],
              ["o", "……我去看看。"]],
    "hank": [["h", "灯塔我看着。你去。"]],
    "hankHome": [["h", "主灯……亮了。"], ["h", "你肩上那个小东西是谁？"], ["m", "我的！"], ["o", "她说她是莫斯。"]],
    "mossMeet": [["", "一块苔石正踮着脚摸路灯，摸一盏，叹一口气。"], ["m", "冷的。冷的。这盏也冷的。"],
                 ["m", "你头上那个是热的！"], ["o", "……别摸。"],
                 ["m", "地上有黑黑的印子，我摸到了——那团光往城外的旧灯窖跑了。"], ["m", "那团光是我的！"],
                 ["o", "那是主灯的。"], ["m", "那就一起去拿。"]],
    "dora": [["d", "我的灯笼不亮了。"], ["d", "荒野里有萤火，能不能帮我抓三只？"]],
    "doraWait": [["d", "还差几只萤火……"]],
    "doraDone": [["d", "亮了！"], ["d", "这个给你们，打开它，萤火会帮你们。"]],
    "doraAfter": [["d", "我的灯笼现在是街上最亮的。"]],
    "lynn": [["n", "码头上挤满了冷影，我的网都没法补。"], ["n", "帮我赶走它们，我送你们一样好东西。"], ["n", "要买点什么吗？"]],
    "lynnWait": [["n", "码头那边还有冷影。要买点什么吗？"]],
    "lynnDone": [["n", "清干净了？谢谢。这个灯罩是我爷爷的，给你。"]],
    "lynnShop": [["n", "要买点什么吗？"]],
    "gateLocked": [["o", "……一个人去，太黑了。"]],
    "stone1": [["", "石碑上刻着：太阳从不闭眼。"], ["m", "它好累。"]],
    "stone2": [["", "石碑上刻着：人们在它下面点灯，灯是借太阳的火。"], ["m", "借的要还。"]],
    "stone3": [["", "石碑上刻着：有一天，一个戴歪王冠的小东西爬上了太阳。"], ["m", "……他偷了火。"], ["o", "所以太阳睡着了。"],
               ["", "莫斯学会了「我的！」"]],
    "lampFirst": [["o", "点亮它。歇一下。"]],
    "miniBefore": [["", "楼梯口蹲着一团特别大的影子。"], ["m", "它坐在我的路上。"]],
    "bossBefore": [["", "最底层，一团大影蹲在那里，肚子里有光在转。"], ["o", "主灯的光。"], ["m", "我的！"]],
    "bossAfter": [["", "灯吞散成一地黑烟，那团光飞了起来，往灯塔的方向去了。"],
                  ["x", "嘻嘻。"], ["", "窖顶趴着一个戴歪王冠的小家伙，长着犄角和蝙蝠翅膀，怀里抱着一团火。"],
                  ["x", "主灯那点光？零头而已。"], ["x", "太阳的火在我这儿。想要？来影子国拿。"],
                  ["", "他抱着火飞走了。莫斯的影子在灯下晃了一下，头上像是多了一顶小王冠。"],
                  ["m", "……那团火，是我的。"], ["o", "走吧。先回去告诉汉克。"]],
    "defeat": [["", "眼前一黑……醒来时，已经回到了最近点亮的灯旁边。"]],
    "netCleared": [["m", "码头干净了！"]],
    "fly": [["", "一团萤火落进了莫斯的叶子里。"]],
}

def check():
    for mid, m in MAPS.items():
        g = m["map"]; W = len(g[0])
        assert all(len(r) == W for r in g), (mid, [len(r) for r in g])
        e = ENT[mid]
        def tile(x, y): return g[y][x]
        def open_(x, y): return 0 <= y < len(g) and 0 <= x < W and tile(x, y) not in BLOCK
        placed = {}
        for kind in ("lamps", "npcs", "chests", "foes", "tablets", "motes"):
            for it in e[kind]:
                x, y = it["at"]
                if kind == "tablets": assert tile(x, y) == "t", (mid, it)
                else: assert open_(x, y), (mid, kind, it, tile(x, y))
                assert (x, y) not in placed, (mid, it, placed[(x, y)])
                placed[(x, y)] = it.get("id")
        for ex in e["exits"]:
            x, y = ex["at"]; assert tile(x, y) in "Dsu", (mid, ex, tile(x, y))
            to = ex["to"]; ax, ay = ex["arrive"]
            assert MAPS[to]["map"][ay][ax] not in BLOCK, (mid, ex)
        # everything reachable from the first exit's arrival (or the start), walking round chests/lamps/npcs/tablets
        solid = {tuple(it["at"]) for k in ("lamps", "npcs", "chests", "tablets") for it in e[k]}
        start = tuple(e.get("start") or next(ex2["arrive"] for m2 in ENT.values() for ex2 in m2["exits"] if ex2["to"] == mid))
        seen = {start}; q = collections.deque([start])
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n in seen: continue
                if 0 <= n[1] < len(g) and 0 <= n[0] < W and (tile(*n) not in BLOCK) and n not in solid:
                    seen.add(n); q.append(n)
        def near(p): return any((p[0] + dx, p[1] + dy) in seen for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        for k in ("lamps", "npcs", "chests", "tablets"):
            for it in e[k]: assert near(tuple(it["at"])), (mid, "unreachable", it)
        for it in e["foes"] + e["motes"]: assert tuple(it["at"]) in seen, (mid, "unreachable", it)
        for ex in e["exits"]: assert tuple(ex["at"]) in seen, (mid, "unreachable exit", ex)
    print("ok:", ", ".join(f"{k} {len(v['map'][0])}x{len(v['map'])}" for k, v in MAPS.items()))

if __name__ == "__main__":
    check()
    for q in QUESTS.values():
        for st in q["steps"]:
            g = st.pop("goal")
            if g: st["map"], st["x"], st["y"] = g
    out = dict(maps={k: dict(**MAPS[k], **ENT[k]) for k in MAPS}, items=ITEMS, quests=QUESTS, lines=LINES)
    json.dump(out, open(os.path.join(ROOT, "Game", "Resources", "rpg.json"), "w"), ensure_ascii=False, indent=1)
