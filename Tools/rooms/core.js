// 《长夜》 rules — one grid engine for all four chapters. Pure and deterministic: the page, the solver and the
// iOS self-test all run this same file.
//
// Map legend
//   #  wall          .  floor        ~  water (only Mosto can fly over it)
//   L  dark lamp     l  lit lamp     N  dark nest (a lamp only Mosto can fill)   n... see NPC note below
//   S  lost shadow   B  boulder (Moss pushes it)   P  plate   D  door (open while every plate is weighed down)
//   T  stone tablet (Moss can read it; story only)  E  exit
//   O  Otto   M  Moss   X  Mosto       lowercase letters other than l: people (see NPC table in story)
//   W  Mosto as the thief (chapter 4): not played; he moves on his own after every action
// Rules
//   · Lost shadows are cold. After every action each shadow drifts one tile toward the nearest light within reach:
//     Otto's bulb (rOtto), the light Mosto carries (rCarry), lit lamps and nests (rLamp).
//   · A lit lamp with two shadows next to it is crowded and goes out. A lamp with a shadow next to it can't be lit.
//   · Otto: bulb on/off; lights a dark lamp next to him.  Moss: pushes boulders.  Mosto: takes the light out of a lit
//     lamp next to him (one at a time) and puts it into a dark lamp or nest; flies over water; walks through shadows.
//   · Doors are open while every plate has a boulder or a character on it.
//   · A room is cleared when every character present stands on an exit and the room's lamp goal is met.
//   · The thief (W): after the shadows drift, if a lit lamp is next to him he takes its light; otherwise he takes one
//     step along a shortest path toward the nearest cell next to a lit lamp (ties: lamp order, then up, right, down,
//     left). He flies over water and through shadows; walls, lamps, boulders, characters and closed doors stop him.
//     Goal 'trap': he is caught when walls, lamps, boulders and closed doors close him in on all four sides.
(function(root){
const DIRS={up:[0,-1],down:[0,1],left:[-1,0],right:[1,0]};
const CH=['otto','moss','mosto'];
function parse(level){
  const rows=level.map, H=rows.length, W=Math.max(...rows.map(r=>r.length));
  const grid=[], lamps=[], shadows=[], boulders=[], plates=[], exits=[], npcs={}, tablets={}; const chars={}; let thief=null;
  for(let y=0;y<H;y++){ grid.push([]); for(let x=0;x<W;x++){ const c=rows[y][x]||'~'; let t='floor';
    if(c==='#') t='wall'; else if(c==='~') t='water';
    else if(c==='L'||c==='l'){ t='lamp'; lamps.push({x,y,lit:c==='l',nest:false}); }
    else if(c==='N'){ t='lamp'; lamps.push({x,y,lit:false,nest:true}); }
    else if(c==='S') shadows.push([x,y]);
    else if(c==='B') boulders.push([x,y]);
    else if(c==='P') t='plate';
    else if(c==='D') t='door';
    else if(c==='T'){ t='tablet'; tablets[x+','+y]=1; }
    else if(c==='E'){ t='exit'; exits.push([x,y]); }
    else if(c==='W') thief=[x,y];
    else if(c==='O') chars.otto=[x,y]; else if(c==='M') chars.moss=[x,y]; else if(c==='X') chars.mosto=[x,y];
    else if(/[a-z]/.test(c)){ t='npc'; npcs[x+','+y]=c; }
    if(c==='P') plates.push([x,y]);
    grid[y].push(t); } }
  const who=CH.filter(k=>chars[k]);
  return {W,H,grid,npcs,tablets,exits,plates,who,lampPos:lamps.map(l=>[l.x,l.y]),nest:lamps.map(l=>l.nest),
    rOtto:level.rOtto||3,rCarry:level.rCarry||2,rLamp:level.rLamp||2,goal:level.goal||'allLamps',lockBulb:!!level.lockBulb,
    needKey:!!level.needKey,keyGiven:false,
    start:{c:who.map(k=>chars[k].slice()),bulb:!!level.bulbOn,carry:!!level.carry,shadows,boulders,lit:lamps.map(l=>l.lit),steps:0,thief}};
}
const clone=s=>({c:s.c.map(p=>p.slice()),bulb:s.bulb,carry:s.carry,shadows:s.shadows.map(p=>p.slice()),boulders:s.boulders.map(p=>p.slice()),lit:s.lit.slice(),steps:s.steps,thief:s.thief?s.thief.slice():null});
const key=s=>s.c.map(p=>p.join(',')).join(';')+'|'+(s.bulb?1:0)+(s.carry?1:0)+'|'+s.shadows.map(p=>p.join(',')).sort().join(';')+'|'+s.boulders.map(p=>p.join(',')).sort().join(';')+'|'+s.lit.map(b=>b?1:0).join('')+(s.thief?'|'+s.thief.join(','):'');
const man=(a,b)=>Math.abs(a[0]-b[0])+Math.abs(a[1]-b[1]);
const at=(list,x,y)=>list.findIndex(p=>p[0]===x&&p[1]===y);
function tileAt(L,x,y){ if(y<0||y>=L.H||x<0||x>=L.W) return 'wall'; return L.grid[y][x]; }
function platesDown(L,s){ return L.plates.every(([x,y])=>at(s.boulders,x,y)>=0||at(s.c,x,y)>=0); }
function charIdx(L,name){ return L.who.indexOf(name); }
function lampsOk(L,s){ if(L.goal==='none'||L.goal==='trap') return true; if(L.goal==='carry') return s.carry; if(L.goal==='nests') return s.lit.every((b,i)=>!L.nest[i]||b); return s.lit.every(Boolean); }
// can character ci stand on (x,y)?
function canEnter(L,s,ci,x,y){
  const t=tileAt(L,x,y), who=L.who[ci];
  if(t==='wall'||t==='lamp'||t==='npc'||t==='tablet') return false;
  if(t==='water'&&who!=='mosto') return false;
  if(t==='door'&&!platesDown(L,s)) return false;
  if(t==='exit'&&(!lampsOk(L,s)||(L.needKey&&!L.keyGiven))) return false;
  if(at(s.c,x,y)>=0) return false;
  if(s.thief&&s.thief[0]===x&&s.thief[1]===y) return false;
  if(at(s.boulders,x,y)>=0) return false;
  if(at(s.shadows,x,y)>=0&&who!=='mosto') return false;
  return true;
}
function shadowFree(L,s,x,y){ const t=tileAt(L,x,y); return (t==='floor'||t==='plate'||t==='exit'||(t==='door'&&platesDown(L,s)))&&at(s.shadows,x,y)<0&&at(s.boulders,x,y)<0&&at(s.c,x,y)<0&&!(s.thief&&s.thief[0]===x&&s.thief[1]===y); }
// where the thief may stand
function thiefFree(L,s,x,y){ const t=tileAt(L,x,y);
  if(!(t==='floor'||t==='plate'||t==='exit'||t==='water'||(t==='door'&&platesDown(L,s)))) return false;
  return at(s.boulders,x,y)<0&&at(s.c,x,y)<0; }
// a side that holds him for good: not a character, who can always step away
function thiefWall(L,s,x,y){ const t=tileAt(L,x,y);
  return t==='wall'||t==='lamp'||t==='npc'||t==='tablet'||(t==='door'&&!platesDown(L,s))||at(s.boulders,x,y)>=0; }
function trapped(L,s){ if(!s.thief) return false; const [x,y]=s.thief; return [[0,-1],[1,0],[0,1],[-1,0]].every(([dx,dy])=>thiefWall(L,s,x+dx,y+dy)); }
const TDIRS=[[0,-1],[1,0],[0,1],[-1,0]];
function thiefMove(L,s,ev){
  if(!s.thief||trapped(L,s)) return;
  const [tx,ty]=s.thief;
  const near=L.lampPos.findIndex((lp,i)=>s.lit[i]&&!L.nest[i]&&man(lp,s.thief)===1);
  if(near>=0){ s.lit[near]=false; ev&&ev.push({k:'steal',i:near}); return; }
  // breadth-first from every cell next to a lit lamp (lamp order), so each cell knows its distance to the nearest target
  const dist=new Map(), q=[]; const K=(x,y)=>x+','+y;
  L.lampPos.forEach((lp,i)=>{ if(!s.lit[i]||L.nest[i]) return;
    for(const [dx,dy] of TDIRS){ const x=lp[0]+dx, y=lp[1]+dy; if(!dist.has(K(x,y))&&(thiefFree(L,s,x,y)||(x===tx&&y===ty))){ dist.set(K(x,y),0); q.push([x,y]); } } });
  for(let h=0;h<q.length;h++){ const [x,y]=q[h], d=dist.get(K(x,y));
    for(const [dx,dy] of TDIRS){ const nx=x+dx, ny=y+dy; if(dist.has(K(nx,ny))) continue;
      if(!(thiefFree(L,s,nx,ny)||(nx===tx&&ny===ty))) continue; dist.set(K(nx,ny),d+1); q.push([nx,ny]); } }
  const here=dist.get(K(tx,ty)); if(here===undefined) return;
  for(const [dx,dy] of TDIRS){ const nx=tx+dx, ny=ty+dy; const d=dist.get(K(nx,ny));
    if(d!==undefined&&d<here&&thiefFree(L,s,nx,ny)){ s.thief=[nx,ny]; ev&&ev.push({k:'thief'}); return; } }
}
function drift(L,s,ev){
  const att=[]; const oi=charIdx(L,'otto'), xi=charIdx(L,'mosto');
  if(oi>=0&&s.bulb) att.push({p:s.c[oi],r:L.rOtto});
  if(xi>=0&&s.carry) att.push({p:s.c[xi],r:L.rCarry});
  L.lampPos.forEach((p,i)=>{ if(s.lit[i]) att.push({p,r:L.rLamp}); });
  const order=s.shadows.map((p,i)=>i).sort((a,b)=>s.shadows[a][1]-s.shadows[b][1]||s.shadows[a][0]-s.shadows[b][0]);
  for(const i of order){ const p=s.shadows[i]; let best=null;
    for(const a of att){ const d=man(p,a.p); if(d<=a.r&&(!best||d<best.d)) best={...a,d}; }
    if(!best||best.d<=1) continue;
    const dx=best.p[0]-p[0], dy=best.p[1]-p[1];
    const tries=Math.abs(dx)>=Math.abs(dy)?[[Math.sign(dx),0],[0,Math.sign(dy)]]:[[0,Math.sign(dy)],[Math.sign(dx),0]];
    for(const [mx,my] of tries){ if(!mx&&!my) continue; const nx=p[0]+mx, ny=p[1]+my; if(shadowFree(L,s,nx,ny)){ p[0]=nx; p[1]=ny; ev&&ev.push({k:'drift',i}); break; } } }
  L.lampPos.forEach((lp,i)=>{ if(s.lit[i]&&s.shadows.filter(p=>man(p,lp)===1).length>=2){ s.lit[i]=false; ev&&ev.push({k:'dim',i}); } });
}
// action: [ci, verb] — verb is a direction, 'bulb', 'light' (Otto), 'take' / 'give' (Mosto)
function step(L,s0,ci,v,ev){
  const s=clone(s0), who=L.who[ci], p=s.c[ci];
  if(DIRS[v]){ const [dx,dy]=DIRS[v], nx=p[0]+dx, ny=p[1]+dy;
    const bi=at(s.boulders,nx,ny);
    if(bi>=0){ if(who!=='moss') return null; const bx=nx+dx, by=ny+dy; const t=tileAt(L,bx,by);
      if(!(t==='floor'||t==='plate'||(t==='door'&&platesDown(L,s)))||at(s.boulders,bx,by)>=0||at(s.c,bx,by)>=0||at(s.shadows,bx,by)>=0||(s.thief&&s.thief[0]===bx&&s.thief[1]===by)) return null;
      s.boulders[bi]=[bx,by]; ev&&ev.push({k:'push'}); s.c[ci]=[nx,ny];
      // a door can't close on someone: if the push lifted a plate while a character or boulder stands in a doorway, undo
      if(!platesDown(L,s)&&(s.c.some(([x,y])=>tileAt(L,x,y)==='door')||s.boulders.some(([x,y])=>tileAt(L,x,y)==='door'))) return null; }
    else { if(!canEnter(L,s,ci,nx,ny)) return null; s.c[ci]=[nx,ny];
      if(!platesDown(L,s)&&(s.c.some(([x,y])=>tileAt(L,x,y)==='door')||s.boulders.some(([x,y])=>tileAt(L,x,y)==='door'))) return null; }
  } else if(v==='bulb'){ if(who!=='otto'||L.lockBulb) return null; s.bulb=!s.bulb; ev&&ev.push({k:'bulb',on:s.bulb}); }
  else if(v==='light'){ if(who!=='otto') return null; let any=false;
    L.lampPos.forEach((lp,i)=>{ if(!s.lit[i]&&!L.nest[i]&&man(lp,p)===1&&!s.shadows.some(q=>man(q,lp)===1)){ s.lit[i]=true; any=true; ev&&ev.push({k:'light',i}); } });
    if(!any) return null; }
  else if(v==='take'){ if(who!=='mosto'||s.carry) return null; const i=L.lampPos.findIndex((lp,k)=>s.lit[k]&&man(lp,p)===1); if(i<0) return null; s.lit[i]=false; s.carry=true; ev&&ev.push({k:'take',i}); }
  else if(v==='give'){ if(who!=='mosto'||!s.carry) return null; const i=L.lampPos.findIndex((lp,k)=>!s.lit[k]&&man(lp,p)===1&&!s.shadows.some(q=>man(q,lp)===1)); if(i<0) return null; s.lit[i]=true; s.carry=false; ev&&ev.push({k:'give',i,nest:L.nest[i]}); }
  else return null;
  s.steps++; drift(L,s,ev); thiefMove(L,s,ev);
  // a door can't close on the thief either
  if(s.thief&&!platesDown(L,s)&&tileAt(L,s.thief[0],s.thief[1])==='door') return null;
  return s;
}
function won(L,s){ if(L.goal==='trap') return trapped(L,s); return lampsOk(L,s)&&s.c.every(([x,y])=>tileAt(L,x,y)==='exit'); }
function verbs(who){ return who==='otto'?['bulb','light']:who==='mosto'?['take','give']:[]; }
function solve(level,opts={}){
  const L=parse(level); L.keyGiven=true; const start=L.start;
  const acts=[]; L.who.forEach((w,ci)=>{ if(opts.ban&&opts.ban.includes(w)) return; ['up','down','left','right',...verbs(w)].forEach(v=>{ if(opts.noBulb&&v==='bulb') return; acts.push([ci,v]); }); });
  const seen=new Map([[key(start),null]]), q=[start]; let head=0; const max=opts.max||600000;
  if(won(L,start)) return {ok:true,path:[],explored:1};
  while(head<q.length&&seen.size<max){ const s=q[head++], ks=key(s);
    for(const [ci,v] of acts){ const n=step(L,s,ci,v); if(!n) continue; const k=key(n); if(seen.has(k)) continue; seen.set(k,[ks,ci,v]);
      if(won(L,n)){ const path=[]; let cur=k; while(seen.get(cur)){ const [pk,pc,pv]=seen.get(cur); path.unshift([pc,pv]); cur=pk; } return {ok:true,path,explored:seen.size}; }
      q.push(n); } }
  return {ok:false,explored:seen.size,capped:seen.size>=max};
}
function lightBlock(L,s,ci){ const p=s.c[ci]; for(let i=0;i<L.lampPos.length;i++){ const lp=L.lampPos[i]; if(!s.lit[i]&&man(lp,p)===1&&s.shadows.some(q=>man(q,lp)===1)) return 'crowded'; } return null; }
const API={DIRS,CH,parse,clone,step,drift,won,solve,trapped,thiefMove,tileAt,canEnter,platesDown,lampsOk,lightBlock,man,at,charIdx,verbs};
if(typeof module!=='undefined') module.exports=API; else root.Core=API;
})(typeof window!=='undefined'?window:globalThis);
