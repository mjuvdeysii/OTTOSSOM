# App icon: Otto in the long night, his bulb the only light. Writes SVG variants; render.js turns them into PNGs.
import sys
def svg(variant):
    moss = variant in ('B','C')
    mosto = variant == 'C'
    ox, base = (470, 880) if variant=='A' else (420, 880)
    w, h = 430, 560
    top = base - h
    bx, by = ox + 250, top - 120
    stars = ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#dfe6ff" opacity="{o}"/>' for x,y,r,o in
        [(120,140,5,.7),(230,90,3,.5),(90,330,3.5,.45),(330,190,4,.55),(180,460,3,.35),(420,110,3,.4),(890,560,3,.3),(940,120,3.5,.35),(60,620,2.5,.3)])
    parts = [f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
 <radialGradient id="sky" cx="{bx}" cy="{by}" r="900" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#3a2c22"/><stop offset=".28" stop-color="#1a1f3c"/><stop offset=".7" stop-color="#0b1026"/><stop offset="1" stop-color="#05060c"/></radialGradient>
 <radialGradient id="halo" cx="{bx}" cy="{by}" r="330" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#ffd77a" stop-opacity=".95"/><stop offset=".18" stop-color="#f2c062" stop-opacity=".55"/><stop offset=".55" stop-color="#f2c062" stop-opacity=".12"/><stop offset="1" stop-color="#f2c062" stop-opacity="0"/></radialGradient>
 <linearGradient id="body" x1="{ox-w/2}" y1="0" x2="{ox+w/2}" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#22457f"/><stop offset=".6" stop-color="#2f5aa8"/><stop offset="1" stop-color="#4a74bf"/></linearGradient>
 <radialGradient id="pool" cx="{ox+60}" cy="{base}" r="420" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#f2c062" stop-opacity=".22"/><stop offset="1" stop-color="#f2c062" stop-opacity="0"/></radialGradient>
<linearGradient id="ground" x1="0" y1="{base-60}" x2="0" y2="1024" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#070913" stop-opacity="0"/><stop offset=".35" stop-color="#070913" stop-opacity=".7"/><stop offset="1" stop-color="#04050b" stop-opacity=".95"/></linearGradient>
</defs>
<rect width="1024" height="1024" fill="url(#sky)"/>
{stars}
<rect x="0" y="{base-60}" width="1024" height="{1024-base+60}" fill="url(#ground)"/>
<ellipse cx="{ox+60}" cy="{base}" rx="420" ry="70" fill="url(#pool)"/>
<ellipse cx="{ox}" cy="{base+4}" rx="{w*0.5}" ry="22" fill="#000" opacity=".45"/>
<g stroke="#0b0e19" stroke-width="34" stroke-linecap="round">
 <line x1="{ox-80}" y1="{base-60}" x2="{ox-80}" y2="{base}"/><line x1="{ox+80}" y1="{base-60}" x2="{ox+80}" y2="{base}"/></g>
<path d="M{ox-w/2},{base-55} L{ox-w/2},{top+w/2} A{w/2},{w/2} 0 0 1 {ox+w/2},{top+w/2} L{ox+w/2},{base-55} Q{ox},{base-10} {ox-w/2},{base-55} Z" fill="url(#body)"/>
<path d="M{ox+w/2-6},{top+w/2} A{w/2-6},{w/2-6} 0 0 0 {ox+40},{top+8}" stroke="#ffd77a" stroke-opacity=".35" stroke-width="10" fill="none" stroke-linecap="round"/>
<ellipse cx="{ox-w*0.3+30}" cy="{top+w*0.45}" rx="26" ry="80" fill="#fff" opacity=".07"/>
<path d="M{ox},{top+6} Q{ox+20},{top-150} {bx},{by}" stroke="#3b4672" stroke-width="18" fill="none" stroke-linecap="round"/>
<circle cx="{bx}" cy="{by}" r="330" fill="url(#halo)"/>
<circle cx="{bx}" cy="{by}" r="46" fill="#ffe39a"/>
<circle cx="{bx-14}" cy="{by-14}" r="14" fill="#fff8e0"/>''']
    ey, er = top + w*0.6, w*0.3
    ex = ox + 10
    parts.append(f'''<clipPath id="eyeclip"><ellipse cx="{ex}" cy="{ey}" rx="{er}" ry="{er*0.86}"/></clipPath>
<ellipse cx="{ex}" cy="{ey}" rx="{er}" ry="{er*0.86}" fill="#f4f1e8"/>
<g clip-path="url(#eyeclip)">
 <circle cx="{ex+er*0.32}" cy="{ey+er*0.02}" r="{er*0.46}" fill="#14182a"/>
 <circle cx="{ex+er*0.46}" cy="{ey-er*0.08}" r="{er*0.13}" fill="#fff"/>
 <rect x="{ex-er*1.1}" y="{ey-er*1.2}" width="{er*2.2}" height="{er*1.02}" fill="#244a92"/>
</g>
<path d="M{ex-er*0.97},{ey-er*0.18} Q{ex},{ey-er*0.1} {ex+er*0.97},{ey-er*0.18}" stroke="#15306a" stroke-width="12" fill="none" stroke-linecap="round"/>''')
    if moss:
        mx, mb = 790, base
        parts.append(f'''<ellipse cx="{mx}" cy="{mb+3}" rx="95" ry="14" fill="#000" opacity=".4"/>
<g stroke="#2a2f22" stroke-width="16" stroke-linecap="round"><line x1="{mx-34}" y1="{mb-30}" x2="{mx-34}" y2="{mb}"/><line x1="{mx+34}" y1="{mb-30}" x2="{mx+34}" y2="{mb}"/></g>
<ellipse cx="{mx}" cy="{mb-82}" rx="112" ry="64" fill="#6f8f58"/>
<ellipse cx="{mx+30}" cy="{mb-112}" rx="50" ry="18" fill="#ffd77a" opacity=".25"/>
<ellipse cx="{mx-26}" cy="{mb-86}" rx="13" ry="20" fill="#1d2318"/><ellipse cx="{mx+26}" cy="{mb-86}" rx="13" ry="20" fill="#1d2318"/>
<circle cx="{mx-23}" cy="{mb-97}" r="5" fill="#fff"/><circle cx="{mx+29}" cy="{mb-97}" r="5" fill="#fff"/>
<line x1="{mx}" y1="{mb-144}" x2="{mx}" y2="{mb-196}" stroke="#4c6a3e" stroke-width="8" stroke-linecap="round"/>
<ellipse cx="{mx-20}" cy="{mb-170}" rx="22" ry="11" fill="#9fd2a8" transform="rotate(-28 {mx-20} {mb-170})"/>
<ellipse cx="{mx+20}" cy="{mb-170}" rx="22" ry="11" fill="#9fd2a8" transform="rotate(28 {mx+20} {mb-170})"/>
<ellipse cx="{mx-18}" cy="{mb-194}" rx="18" ry="9" fill="#9fd2a8" transform="rotate(-28 {mx-18} {mb-194})"/>
<ellipse cx="{mx+18}" cy="{mb-194}" rx="18" ry="9" fill="#9fd2a8" transform="rotate(28 {mx+18} {mb-194})"/>''')
    parts.append('</svg>')
    return '\n'.join(parts)
for v in 'ABC':
    open(f'icon_{v}.svg','w').write(svg(v))
