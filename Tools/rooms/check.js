// CI: re-solves every room in Game/Resources/rooms.json with the reference rules and checks the stored par.
const C=require('./core.js'), fs=require('fs');
const f=JSON.parse(fs.readFileSync(__dirname+'/../../Game/Resources/rooms.json','utf8'));
let bad=0;
for(const [id,r] of Object.entries(f.rooms)){ const s=C.solve(r,{max:3000000});
  const ok=s.ok&&s.path.length===r.par&&s.explored===r.states; if(!ok) bad++;
  console.log(id.padEnd(8),'par',String(r.par).padStart(3),'js',s.ok?String(s.path.length).padStart(3):'  -','states',s.explored,ok?'ok':'MISMATCH'); }
for(const ch of f.chapters) for(const st of ch.steps) if(st.room&&!f.rooms[st.room]){ console.log('missing room',st.room); bad++; }
if(bad){ console.log(bad,'problems'); process.exit(1); }
