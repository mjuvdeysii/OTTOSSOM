const C=require('./core.js');
const rooms=JSON.parse(require('fs').readFileSync(process.argv[2],'utf8'));
for(const [id,lv] of Object.entries(rooms)){ const t0=Date.now(); const s=C.solve(lv,{max:1500000}); let need='';
  const L=C.parse(lv); if(L.who.includes('otto')&&s.ok&&!C.solve(lv,{noBulb:true,max:1500000}).ok) need+=' needsBulb';
  console.log(id.padEnd(9),s.ok?'len '+s.path.length:'UNSOLVABLE','states',s.explored,need,(Date.now()-t0)+'ms', process.env.SHOW&&s.ok?'\n   '+s.path.map(a=>(L.who.length>1?L.who[a[0]]+':':'')+a[1]).join(' '):''); }
