// Searches where shadows / boulders start inside a hand-drawn frame. '?' cells may become S (shadow) or B (boulder).
// Keeps layouts that are solvable, that become unsolvable when a required ability is removed, with a long shortest
// solution. Usage: node mine.js <frame.json> ; frame: {map:[...], S:2, B:1, need:['bulb'|'otto'|'moss'|'mosto'], min:18, max:45, n:400, ...level opts}
const C=require('./core.js'); const fs=require('fs');
const F=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
let seed=F.seed||99; const rnd=()=>{ seed^=seed<<13; seed>>>=0; seed^=seed>>17; seed^=seed<<5; seed>>>=0; return seed/4294967296; };
const cells=[]; F.map.forEach((r,y)=>[...r].forEach((c,x)=>{ if(c==='?') cells.push([x,y]); }));
const out=[], seen=new Set();
for(let n=0;n<(F.n||400);n++){
  const g=F.map.map(r=>[...r].map(c=>c==='?'?'.':c)); const pick=[];
  const total=(F.S||0)+(F.B||0); if(total>cells.length) break;
  while(pick.length<total){ const c=cells[Math.floor(rnd()*cells.length)]; if(!pick.includes(c)) pick.push(c); }
  pick.forEach(([x,y],i)=>g[y][x]=i<(F.S||0)?'S':'B');
  const map=g.map(r=>r.join('')); const k=map.join('/'); if(seen.has(k)) continue; seen.add(k);
  const lv={...F,map}; delete lv.S; delete lv.B; delete lv.need;
  const s=C.solve(lv,{max:F.cap||250000}); if(!s.ok||s.path.length<(F.min||10)||s.path.length>(F.max||60)) continue;
  let needed=true; for(const nd of (F.need||[])){ const r=nd==='bulb'?C.solve(lv,{noBulb:true,max:F.cap||250000}):C.solve(lv,{ban:[nd],max:F.cap||250000}); if(r.ok){ needed=false; break; } }
  if(!needed) continue;
  const acts=s.path.map(a=>a[1]); const special=acts.filter(a=>!['up','down','left','right'].includes(a)).length;
  const switches=s.path.reduce((n,a,i)=>n+(i&&a[0]!==s.path[i-1][0]?1:0),0);
  out.push({map,len:s.path.length,special,switches,path:s.path});
}
out.sort((a,b)=>(b.special+b.switches)-(a.special+a.switches)||b.len-a.len);
console.log('found',out.length,'of',seen.size);
for(const o of out.slice(0,F.top||3)){ console.log('--- len',o.len,'special',o.special,'switches',o.switches); console.log(JSON.stringify(o.map,null,0)); }
