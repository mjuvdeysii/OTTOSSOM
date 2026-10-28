// Builds Game/Resources/rooms.json: chapters + rooms with the reference shortest solution (par) from core.js.
const C=require('./core.js'), fs=require('fs');
const src=JSON.parse(fs.readFileSync(__dirname+'/rooms.src.json','utf8'));
const report=[];
for(const [id,r] of Object.entries(src.rooms)){
  r.id=id; const s=C.solve(r,{max:3000000});
  if(!s.ok){ console.error('UNSOLVABLE',id); process.exit(1); }
  r.par=s.path.length; r.solution=s.path.map(([c,v])=>c+':'+v); r.states=s.explored;
  report.push(id.padEnd(8)+' par '+String(r.par).padStart(3)+'  states '+s.explored);
}
fs.writeFileSync(__dirname+'/../../Game/Resources/rooms.json',JSON.stringify(src,null,1));
console.log(report.join('\n'));
