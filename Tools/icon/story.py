# App icon as a silent story: the tired sun sleeps on the horizon; Mosto hugs the spark he took from it,
# half asleep himself; Moss reaches out to touch it; Otto leans over them with his bulb turned low.
import math, sys
W = 1024
def P(*pts): return ' '.join(f'{x:.1f},{y:.1f}' for x, y in pts)

def icon():
    o = []
    add = o.append
    # ---- defs
    add(f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">
<defs>
 <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#060918"/><stop offset=".55" stop-color="#121a3a"/><stop offset=".72" stop-color="#2a2238"/><stop offset="1" stop-color="#3a2618"/></linearGradient>
 <radialGradient id="sun" cx="560" cy="1270" r="720" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#a65a26"/><stop offset=".8" stop-color="#7a3e1c"/><stop offset=".94" stop-color="#9a5428"/><stop offset="1" stop-color="#d88a48"/></radialGradient>
 <radialGradient id="sunrim" cx="560" cy="1270" r="820" gradientUnits="userSpaceOnUse">
  <stop offset=".84" stop-color="#ffb36b" stop-opacity="0"/><stop offset=".89" stop-color="#ffb36b" stop-opacity=".42"/><stop offset="1" stop-color="#ffb36b" stop-opacity="0"/></radialGradient>
 <radialGradient id="spark" cx="700" cy="800" r="330" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#fff2c4" stop-opacity="1"/><stop offset=".12" stop-color="#ffd77a" stop-opacity=".85"/><stop offset=".4" stop-color="#f2a050" stop-opacity=".3"/><stop offset="1" stop-color="#f2a050" stop-opacity="0"/></radialGradient>
 <radialGradient id="bulbglow" cx="470" cy="300" r="170" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#ffd77a" stop-opacity=".7"/><stop offset=".35" stop-color="#f2c062" stop-opacity=".22"/><stop offset="1" stop-color="#f2c062" stop-opacity="0"/></radialGradient>
 <linearGradient id="otto" x1="120" y1="0" x2="460" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#1f3f78"/><stop offset=".55" stop-color="#2f5aa8"/><stop offset="1" stop-color="#5a82c8"/></linearGradient>
 <linearGradient id="mosto" x1="590" y1="0" x2="860" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#9a6ad0"/><stop offset=".5" stop-color="#7b4bb3"/><stop offset="1" stop-color="#5a3290"/></linearGradient>
 <linearGradient id="moss" x1="360" y1="0" x2="600" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#5c7a48"/><stop offset=".7" stop-color="#7a9a60"/><stop offset="1" stop-color="#9ab878"/></linearGradient>
 <linearGradient id="ground" x1="0" y1="880" x2="0" y2="1024" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#140d0a"/><stop offset="1" stop-color="#07050a"/></linearGradient>
</defs>
<rect width="{W}" height="{W}" fill="url(#sky)"/>''')
    # stars, sparse, only high up
    for x, y, r, a in [(92,120,4.5,.75),(210,70,3,.5),(330,170,3.5,.55),(150,300,3,.4),(560,90,3,.45),(700,150,4,.6),(860,80,3.5,.5),(960,230,3,.4),(820,300,2.5,.35),(60,440,2.5,.3),(980,420,2.5,.3),(420,60,2.5,.4)]:
        add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#dfe6ff" opacity="{a}"/>')
    # ---- the sleeping sun on the horizon: a huge tired dome with a closed eye and Otto's eye bags
    add('<circle cx="560" cy="1270" r="820" fill="url(#sunrim)"/>')
    add('<circle cx="560" cy="1270" r="720" fill="url(#sun)"/>')
    ex0, ey0 = 590, 600
    add(f'<path d="M{ex0-78},{ey0} Q{ex0},{ey0+40} {ex0+78},{ey0}" stroke="#2a1309" stroke-width="12" fill="none" stroke-linecap="round"/>')   # closed lid
    for dx in (-52, -18, 18, 52):   # lashes
        x = ex0 + dx; y = ey0 + 40 * (1 - (dx / 78) ** 2) * 0.5 + 2
        add(f'<line x1="{x}" y1="{y:.0f}" x2="{x + dx*0.15:.0f}" y2="{y+17:.0f}" stroke="#2a1309" stroke-width="7" stroke-linecap="round"/>')
    add(f'<path d="M{ex0-60},{ey0+46} Q{ex0},{ey0+68} {ex0+60},{ey0+46}" stroke="#4a2410" stroke-width="7" fill="none" stroke-linecap="round" opacity=".85"/>')   # eye bag, like Otto's
    add(f'<path d="M{ex0-44},{ey0+64} Q{ex0},{ey0+80} {ex0+44},{ey0+64}" stroke="#4a2410" stroke-width="6" fill="none" stroke-linecap="round" opacity=".6"/>')
    add('<text x="0" y="0"/>')
    # ---- ground ledge they sit on
    add('<path d="M0,900 Q512,862 1024,900 L1024,1024 L0,1024 Z" fill="url(#ground)"/>')
    # ---- spark light pooling on the ground and on everyone
    add('<ellipse cx="640" cy="905" rx="380" ry="46" fill="#f2a050" opacity=".16"/>')

    # ---- Otto: left, leaning toward the others, bulb turned low over them
    ox, base, w, h = 270, 905, 330, 470
    top = base - h
    add(f'<ellipse cx="{ox}" cy="{base+4}" rx="{w*0.5}" ry="18" fill="#000" opacity=".45"/>')
    add(f'<g stroke="#0b0e19" stroke-width="30" stroke-linecap="round"><line x1="{ox-62}" y1="{base-50}" x2="{ox-62}" y2="{base}"/><line x1="{ox+62}" y1="{base-50}" x2="{ox+62}" y2="{base}"/></g>')
    add(f'<g transform="rotate(8 {ox} {base})">')
    add(f'<path d="M{ox-w/2},{base-45} L{ox-w/2},{top+w/2} A{w/2},{w/2} 0 0 1 {ox+w/2},{top+w/2} L{ox+w/2},{base-45} Q{ox},{base-8} {ox-w/2},{base-45} Z" fill="url(#otto)"/>')
    add(f'<path d="M{ox+w/2-8},{top+w/2+120} L{ox+w/2-8},{top+w/2} A{w/2-8},{w/2-8} 0 0 0 {ox+50},{top+10}" stroke="#ffcf8a" stroke-opacity=".38" stroke-width="10" fill="none" stroke-linecap="round"/>')
    add(f'<ellipse cx="{ox-w*0.28}" cy="{top+w*0.48}" rx="20" ry="70" fill="#fff" opacity=".07"/>')
    # stem forward over the group, bulb low
    bx, by = ox + 230, top - 70
    add(f'<path d="M{ox},{top+6} Q{ox+30},{top-150} {bx},{by}" stroke="#3b4672" stroke-width="16" fill="none" stroke-linecap="round"/>')
    # eye: tired, looking down-right at the spark
    ey, er = top + w*0.6, w*0.3; ex = ox + 12
    add(f'<clipPath id="oe"><ellipse cx="{ex}" cy="{ey}" rx="{er}" ry="{er*0.86}"/></clipPath>')
    add(f'<ellipse cx="{ex}" cy="{ey}" rx="{er}" ry="{er*0.86}" fill="#f4f1e8"/>')
    add(f'<g clip-path="url(#oe)"><circle cx="{ex+er*0.38}" cy="{ey+er*0.22}" r="{er*0.44}" fill="#14182a"/>'
        f'<circle cx="{ex+er*0.5}" cy="{ey+er*0.08}" r="{er*0.12}" fill="#fff"/>'
        f'<rect x="{ex-er*1.1}" y="{ey-er*1.2}" width="{er*2.2}" height="{er*1.12}" fill="#244a92"/></g>')
    add(f'<path d="M{ex-er*0.97},{ey-er*0.1} Q{ex},{ey-er*0.0} {ex+er*0.97},{ey-er*0.1}" stroke="#15306a" stroke-width="11" fill="none" stroke-linecap="round"/>')
    # one-sided smile: only the corner, as in the bible's arc
    add(f'<path d="M{ex+er*0.25},{ey+er*1.25} Q{ex+er*0.62},{ey+er*1.32} {ex+er*0.8},{ey+er*1.08}" stroke="#16306a" stroke-width="8" fill="none" stroke-linecap="round"/>')
    add('</g>')
    # bulb (outside the rotation so its glow position is exact)
    import math as _m
    a = _m.radians(8)
    rbx = ox + (bx-ox)*_m.cos(a) - (by-base)*_m.sin(a); rby = base + (bx-ox)*_m.sin(a) + (by-base)*_m.cos(a)
    add(f'<circle cx="{rbx:.0f}" cy="{rby:.0f}" r="170" fill="url(#bulbglow)" transform="translate({rbx-470:.0f} {rby-300:.0f})"/>' if False else
        f'<radialGradient id="bg2" cx="{rbx:.0f}" cy="{rby:.0f}" r="170" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#ffd77a" stop-opacity=".6"/><stop offset=".35" stop-color="#f2c062" stop-opacity=".18"/><stop offset="1" stop-color="#f2c062" stop-opacity="0"/></radialGradient>'
        f'<circle cx="{rbx:.0f}" cy="{rby:.0f}" r="170" fill="url(#bg2)"/>'
        f'<circle cx="{rbx:.0f}" cy="{rby:.0f}" r="30" fill="#ffd98a"/><circle cx="{rbx-9:.0f}" cy="{rby-9:.0f}" r="9" fill="#fff6dc"/>')

    # ---- Mosto: right, sitting, hugging the spark, half asleep
    mx, mb, r = 715, 900, 128
    cy = mb - r*0.95
    add(f'<ellipse cx="{mx}" cy="{mb+4}" rx="{r*0.95}" ry="16" fill="#000" opacity=".4"/>')
    for s in (-1, 1):   # wings, folded a little
        add(f'<polygon points="{P((mx+s*r*0.55, cy-r*0.25),(mx+s*r*1.62, cy-r*1.0),(mx+s*r*1.38, cy-r*0.25),(mx+s*r*1.62, cy+r*0.25),(mx+s*r*0.6, cy+r*0.15))}" fill="#4b2a73"/>')
    # tail curling out to the right, heart tip turning gold
    add(f'<path d="M{mx+r*0.8},{cy+r*0.62} Q{mx+r*1.75},{cy+r*0.95} {mx+r*1.55},{cy+r*0.15}" stroke="#7b4bb3" stroke-width="16" fill="none" stroke-linecap="round"/>')
    tx, ty = mx + r*1.55, cy + r*0.08
    add(f'<path d="M{tx},{ty+14} C{tx-26},{ty-6} {tx-12},{ty-28} {tx},{ty-12} C{tx+12},{ty-28} {tx+26},{ty-6} {tx},{ty+14} Z" fill="#ffcf6a"/>')
    add(f'<ellipse cx="{mx}" cy="{cy}" rx="{r}" ry="{r*0.95}" fill="url(#mosto)"/>')
    add(f'<ellipse cx="{mx-r*0.42}" cy="{cy-r*0.45}" rx="{r*0.22}" ry="{r*0.13}" fill="#fff" opacity=".18"/>')
    # horns
    for s in (-1, 1):
        hx, hy = mx + s*r*0.72, cy - r*0.72
        add(f'<path d="M{hx-s*8},{hy+22} Q{hx+s*34},{hy-6} {hx+s*14},{hy-42} Q{hx-s*2},{hy-30} {hx+s*10},{hy-18}" stroke="#efe3c8" stroke-width="15" fill="none" stroke-linecap="round"/>')
    # crown, always crooked
    cx0, cy0 = mx + r*0.12, cy - r*0.92
    add(f'<g transform="translate({cx0} {cy0}) rotate(17)"><polygon points="{P((-52,0),(-52,-44),(-26,-20),(0,-56),(26,-20),(52,-44),(52,0))}" fill="#f2c062"/><rect x="-52" y="-8" width="104" height="10" fill="#c9963e"/></g>')
    # brows pressed in, sleepy half-closed eyes (Otto's half), the fang
    for s in (-1, 1):
        ex2 = mx + s*r*0.34
        add(f'<line x1="{mx+s*r*0.6}" y1="{cy-r*0.36}" x2="{mx+s*r*0.18}" y2="{cy-r*0.22}" stroke="#2a1640" stroke-width="10" stroke-linecap="round"/>')
        add(f'<path d="M{ex2-20},{cy-r*0.05} Q{ex2},{cy+r*0.09} {ex2+20},{cy-r*0.05}" stroke="#160b26" stroke-width="10" fill="none" stroke-linecap="round"/>')
    add(f'<path d="M{mx-r*0.2},{cy+r*0.3} Q{mx},{cy+r*0.4} {mx+r*0.2},{cy+r*0.3}" stroke="#2a1640" stroke-width="7" fill="none" stroke-linecap="round"/>')
    add(f'<polygon points="{P((mx+r*0.04, cy+r*0.33),(mx+r*0.12, cy+r*0.5),(mx+r*0.2, cy+r*0.33))}" fill="#fff"/>')

    # ---- the spark, held to his chest
    sx, sy = mx - 24, mb - 50
    add(f'<radialGradient id="sg" cx="{sx}" cy="{sy}" r="300" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff2c4"/><stop offset=".1" stop-color="#ffd77a" stop-opacity=".9"/><stop offset=".36" stop-color="#f2a050" stop-opacity=".28"/><stop offset="1" stop-color="#f2a050" stop-opacity="0"/></radialGradient>')
    add(f'<circle cx="{sx}" cy="{sy}" r="300" fill="url(#sg)"/>')
    add(f'<circle cx="{sx}" cy="{sy}" r="40" fill="#ffe7a8"/><circle cx="{sx}" cy="{sy}" r="24" fill="#fffaf0"/>')
    # Mosto's little hands cupping it from both sides
    add(f'<ellipse cx="{sx-40}" cy="{sy+16}" rx="20" ry="26" fill="#8a58c4" transform="rotate(-20 {sx-40} {sy+16})"/>')
    add(f'<ellipse cx="{sx+40}" cy="{sy+16}" rx="20" ry="26" fill="#6a3c9e" transform="rotate(20 {sx+40} {sy+16})"/>')
    # ---- Moss: middle, reaching one small hand toward the spark
    gx, gb, gw, gh = 470, 905, 240, 136
    gcy = gb - 34 - gh/2
    add(f'<ellipse cx="{gx}" cy="{gb+3}" rx="{gw*0.45}" ry="13" fill="#000" opacity=".4"/>')
    add(f'<g stroke="#2a2f22" stroke-width="15" stroke-linecap="round"><line x1="{gx-40}" y1="{gb-34}" x2="{gx-40}" y2="{gb}"/><line x1="{gx+40}" y1="{gb-34}" x2="{gx+40}" y2="{gb}"/></g>')
    add(f'<ellipse cx="{gx}" cy="{gcy}" rx="{gw/2}" ry="{gh/2}" fill="url(#moss)"/>')
    add(f'<ellipse cx="{gx+52}" cy="{gcy-36}" rx="44" ry="15" fill="#ffd77a" opacity=".22"/>')
    # reaching arm and hand toward the spark
    add(f'<path d="M{gx+gw*0.44},{gcy+10} Q{gx+gw*0.66},{gcy-30} {sx-58},{sy-30}" stroke="#7a9a60" stroke-width="16" fill="none" stroke-linecap="round"/>')
    add(f'<circle cx="{sx-56}" cy="{sy-30}" r="15" fill="#8aaa6c"/>')
    add(f'<circle cx="{gx-gw*0.5-6}" cy="{gcy+18}" r="14" fill="#6f8f58"/>')
    # eyes on the spark
    for s in (-1, 1):
        ex3 = gx + s*36 + 10
        add(f'<ellipse cx="{ex3}" cy="{gcy-2}" rx="14" ry="21" fill="#1d2318"/><circle cx="{ex3+6}" cy="{gcy-10}" r="5.5" fill="#fff"/>')
    # stem and two pairs of mint leaves, the upper pair opening
    add(f'<line x1="{gx}" y1="{gcy-gh/2+2}" x2="{gx}" y2="{gcy-gh/2-58}" stroke="#4c6a3e" stroke-width="8" stroke-linecap="round"/>')
    for dy, rx, ry, ang in ((-24, 24, 12, 26), (-50, 20, 10, 40)):
        for s in (-1, 1):
            lx, ly = gx + s*20, gcy - gh/2 + dy
            add(f'<ellipse cx="{lx}" cy="{ly}" rx="{rx}" ry="{ry}" fill="#9fd2a8" transform="rotate({s*ang} {lx} {ly})"/>')

    # soft vignette
    add('<radialGradient id="vg" cx="512" cy="600" r="760" gradientUnits="userSpaceOnUse"><stop offset=".6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".45"/></radialGradient>')
    add(f'<rect width="{W}" height="{W}" fill="url(#vg)"/>')
    add('</svg>')
    return '\n'.join(o)

open('icon_story.svg', 'w').write(icon())
