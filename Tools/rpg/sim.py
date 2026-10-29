"""Balance model for the RPG battles — the same rules as Game/RPG/Battle.swift, used to tune the numbers.

  python3 Tools/rpg/sim.py          # win rate, rounds and HP left for every encounter at the level it's met

A plain-but-sensible policy plays the party: Moss touches unknown foes once, Otto shines weak-to-light foes, heals
when someone is low, flares when 3+ foes; Moss bumps shells, shoves charging fangs, takes the light back from the maw.
"""
import random, statistics

LEVELS = [0, 20, 50, 95, 155, 230, 320, 430]
BASE = {"otto": dict(hp=46, atk=9, df=4, spd=4.0), "moss": dict(hp=36, atk=8, df=3, spd=7.0)}
GROW = {"otto": dict(hp=7, atk=2, df=1, spd=0.5), "moss": dict(hp=5, atk=2, df=1, spd=1.0)}
FOES = {
    "shade": dict(hp=30, atk=16, df=1, spd=5, light=1.5, phys=1.0, xp=6, motes=3),
    "shell": dict(hp=44, atk=17, df=6, spd=3, light=0.5, phys=1.5, xp=9, motes=5),
    "moth": dict(hp=20, atk=13, df=0, spd=9, light=1.25, phys=1.0, xp=7, motes=4),
    "fang": dict(hp=40, atk=16, df=2, spd=6, light=1.0, phys=1.0, xp=10, motes=5),
    "bigshade": dict(hp=150, atk=19, df=3, spd=4, light=1.25, phys=1.0, xp=40, motes=30),
    "maw": dict(hp=280, atk=17, df=4, spd=5, light=1.0, phys=1.0, xp=0, motes=0),
}

def stats(who, lv):
    b, g = BASE[who], GROW[who]
    return dict(hp=b["hp"] + g["hp"] * (lv - 1), atk=b["atk"] + g["atk"] * (lv - 1), df=b["df"] + g["df"] * (lv - 1), spd=b["spd"] + g["spd"] * (lv - 1))

class F:
    def __init__(s, kind, rng):
        d = FOES[kind]; s.kind = kind; s.hp = s.max = d["hp"]; s.atk = d["atk"]; s.df = d["df"]; s.spd = d["spd"]
        s.light = d["light"]; s.phys = d["phys"]; s.stun = 0; s.stolen = 0; s.revealed = False; s.shell = False; s.charged = False
        s.slow = False; s.rng = rng; s.intents = [s.pick(), None]; s.intents[1] = s.pick()
    def pick(s):
        r = s.rng.random(); k = s.kind
        if k == "shade": return "drain1" if r < 0.4 else "hit"
        if k == "shell": return "shell" if r < 0.4 else "hit"
        if k == "moth": return "drain2" if r < 0.5 else "flutter"
        if k == "fang": return "charge" if r < 0.45 else "hit"
        if k == "bigshade": return "summon" if r < 0.3 else ("drain2" if r < 0.5 else "slam")
        if k == "maw": return "drain2" if r < 0.5 else "bite"

def dmg(atk, power, mult, df, rng):
    return max(1, round(atk * power * mult - df * 0.5) + rng.randint(-1, 1))

def fight(foes, lv, seed, items=None, naive=False):
    rng = random.Random(seed)
    P = {w: dict(stats(w, lv)) for w in ("otto", "moss")}
    for w in P: P[w]["cur"] = P[w]["hp"]
    E = [F(k, rng) for k in foes]
    light = 3; rounds = 0; items = dict(items or {"tea": 2})
    while True:
        rounds += 1
        if rounds > 40: return False, rounds, P
        light = min(10, light + 1)
        alive = [e for e in E if e.hp > 0]
        if not alive: return True, rounds, P
        # ---- the party's choices ----
        acts = {}
        for w in ("otto", "moss"):
            if P[w]["cur"] <= 0: continue
            if naive:
                acts[w] = ("bump" if w == "moss" else ("shine" if light >= 1 else "defend"), alive[0]); continue
            if w == "moss":
                maw = next((e for e in alive if e.kind == "maw"), None)
                charging = next((e for e in alive if e.intents[0] == "charge"), None)
                unknown = next((e for e in alive if not e.revealed and e.kind in ("maw", "bigshade", "shell", "fang")), None)
                if maw and maw.stolen >= 3 and lv >= 4: acts[w] = ("mine", maw)
                elif charging: acts[w] = ("shove", charging)
                elif unknown and light < 4: acts[w] = ("touch", unknown)
                else:
                    tgt = max(alive, key=lambda e: (e.phys, -e.hp)); acts[w] = ("bump", tgt)
            else:
                low = [x for x in P if 0 < P[x]["cur"] < P[x]["hp"] * 0.45]
                if low and light >= 2: acts[w] = ("warm", None)
                elif low and items.get("tea", 0) > 0: acts[w] = ("tea", min(low, key=lambda x: P[x]["cur"]))
                elif len(alive) >= 3 and light >= 4 and lv >= 3: acts[w] = ("flare", None)
                elif light >= 1:
                    tgt = max(alive, key=lambda e: (e.light, -e.hp)); acts[w] = ("shine", tgt)
                else: acts[w] = ("defend", None)
        order = [("p", w) for w in acts] + [("e", e) for e in alive]
        order.sort(key=lambda t: -(P[t[1]]["spd"] if t[0] == "p" else t[1].spd))
        guard = acts.get("otto", ("",))[0] == "vigil"
        defending = {w for w, a in acts.items() if a[0] == "defend"}
        for side, who in order:
            if side == "p":
                if P[who]["cur"] <= 0: continue
                a, t = acts[who]
                if t is not None and not isinstance(t, str) and t.hp <= 0:
                    alive2 = [e for e in E if e.hp > 0]
                    if not alive2: break
                    t = alive2[0]
                atk = P[who]["atk"]
                if a == "shine" and light >= 1:
                    light -= 1; t.hp -= dmg(atk, 1.0, t.light * (2.0 if t.kind == "maw" and t.stolen >= 3 else 1), t.df, rng) // (2 if t.shell else 1)
                elif a == "warm" and light >= 2:
                    light -= 2
                    for x in P:
                        if P[x]["cur"] > 0: P[x]["cur"] = min(P[x]["hp"], P[x]["cur"] + round(P[x]["hp"] * 0.35))
                elif a == "flare" and light >= 4:
                    light -= 4
                    for e in E:
                        if e.hp > 0:
                            e.hp -= dmg(atk, 0.9, e.light * (2.0 if e.kind == "maw" and e.stolen >= 3 else 1), e.df, rng) // (2 if e.shell else 1)
                            if e.kind == "moth": e.stun = 1
                elif a == "tea":
                    items["tea"] -= 1; P[t]["cur"] = min(P[t]["hp"], P[t]["cur"] + 40)
                elif a == "defend": light = min(10, light + 1)
                elif a == "bump": t.hp -= dmg(atk, 1.0, t.phys, t.df, rng) // (2 if t.shell else 1)
                elif a == "touch": t.revealed = True; light = min(10, light + 2)
                elif a == "shove": t.hp -= dmg(atk, 0.6, t.phys, t.df, rng); t.slow = True
                elif a == "mine": t.hp -= dmg(atk, 1.2, t.phys, t.df, rng); light = min(10, light + t.stolen); t.stolen = 0
            else:
                e = who
                if e.hp <= 0: continue
                if e.stun > 0: e.stun -= 1; continue
                if e.slow: e.slow = False; continue      # its intent waits a round
                it = e.intents.pop(0); e.intents.append(e.pick()); e.shell = False
                targets = [x for x in P if P[x]["cur"] > 0]
                if not targets: break
                def hit(x, power):
                    d = dmg(e.atk, power, 1.0, P[x]["df"], rng)
                    if x in defending: d = d // 2
                    P[x]["cur"] -= d
                if it == "hit": hit(rng.choice(targets), 1.0)
                elif it == "shell": e.shell = True
                elif it == "charge": e.intents.insert(0, "bite"); e.intents.pop()
                elif it == "bite": hit(rng.choice(targets), 2.2)
                elif it == "flutter":
                    for x in targets: hit(x, 0.6)
                elif it in ("drain1", "drain2"):
                    n = 1 if it == "drain1" else 2
                    got = min(light, n); light -= got; e.stolen += got
                    if got < n:      # nothing left to take: it bites the light out of someone instead
                        hit(rng.choice(targets), 0.5 * (n - got))
                        if e.kind == "maw": e.stolen += n - got
                    if e.kind == "shade": e.hp = min(e.max, e.hp + 4)
                    if e.kind == "maw" and e.stolen >= 5:
                        e.intents[0] = "spew"
                elif it == "spew":
                    for x in targets: hit(x, 1.8)
                    e.stolen = 0
                elif it == "slam": hit(rng.choice(targets), 1.3)
                elif it == "summon":
                    if sum(1 for q in E if q.hp > 0) < 3: E.append(F("shade", rng))
        if all(P[x]["cur"] <= 0 for x in P): return False, rounds, P

ENC = [
    ("town: shade", ["shade"], 1), ("town: 2 shades", ["shade", "shade"], 1),
    ("wilds: shell", ["shell"], 2), ("wilds: moth+shade", ["moth", "shade"], 2), ("wilds: fang", ["fang"], 2),
    ("wilds: shell+moth", ["shell", "moth"], 3), ("wilds: 3 shades", ["shade", "shade", "shade"], 2),
    ("cellar: fang+shade", ["fang", "shade"], 3), ("cellar: 2 shells", ["shell", "shell"], 3),
    ("cellar: 2 moths+shade", ["moth", "moth", "shade"], 3),
    ("miniboss: big shade", ["bigshade"], 4), ("boss: maw", ["maw"], 5), ("boss: maw @6", ["maw"], 6),
]
if __name__ == "__main__":
    for name, foes, lv in ENC:
        res = [fight(foes, lv, s) for s in range(400)]
        wins = [r for r in res if r[0]]
        rounds = statistics.mean(r[1] for r in wins) if wins else 0
        left = statistics.mean((r[2]["otto"]["cur"] / r[2]["otto"]["hp"] + r[2]["moss"]["cur"] / r[2]["moss"]["hp"]) / 2 for r in wins) if wins else 0
        nres = [fight(foes, lv, s_, naive=True) for s_ in range(400)]
        nw = [r for r in nres if r[0]]
        nleft = statistics.mean((r[2]["otto"]["cur"] / r[2]["otto"]["hp"] + r[2]["moss"]["cur"] / r[2]["moss"]["hp"]) / 2 for r in nw) if nw else 0
        print(f"{name:26s} Lv{lv}  win {len(wins) / 4:5.1f}%  rounds {rounds:4.1f}  hp left {left * 100:4.0f}%   naive win {len(nw) / 4:5.1f}% left {nleft * 100:3.0f}%")
