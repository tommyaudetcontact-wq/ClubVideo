const outfits = [
 {name:"Polair bourgogne", h:1.69, hu:6.55,w:1.025,skin:0xd99d75,hair:0x4a2b1c,top:0x752f42,pants:0x687890,shoe:0x4a362d,style:"fleece",cut:"bob"},
 {name:"Coupe-vent turquoise", h:1.77,hu:6.45,w:1.03,skin:0xd49b70,hair:0x35271d,top:0x2e5e5c,pants:0x879098,shoe:0x777571,style:"wind",cut:"spike"},
 {name:"Manteau et foulard", h:1.64,hu:5.95,w:1.06,skin:0xe3aa79,hair:0x48301e,top:0xb88e5f,pants:0x53433e,shoe:0x332823,style:"coat",cut:"curl"},
 {name:"Capuchon et cargo", h:1.83,hu:6.7,w:1.06,skin:0xd6a172,hair:0x3b281f,top:0x38363c,pants:0x656049,shoe:0x514c46,style:"hood",cut:"cap"},
 {name:"Surchemise à carreaux", h:1.79,hu:6.75,w:1.16,skin:0xcc9066,hair:0x503224,top:0x696778,pants:0x6d7385,shoe:0x66442d,style:"plaid",cut:"wave"},
 {name:"Veste matelassée", h:1.57,hu:5.6,w:1.01,skin:0xd99c78,hair:0x372922,top:0x475579,pants:0x44434e,shoe:0x61646e,style:"vest",cut:"fringe"},
 {name:"Fille · veste framboise",h:1.21,hu:5.0,w:.71,skin:0xe0a47d,hair:0x63412a,top:0x934d60,pants:0x5c7696,shoe:0xb9b6aa,style:"fleece",cut:"pigtails"},
 {name:"Garçon · chandail moutarde",h:1.24,hu:5.1,w:.72,skin:0xd9a17a,hair:0x3e2b22,top:0xb28641,pants:0x62634c,shoe:0x474850,style:"sweater",cut:"spike"},
];

const color = new Color();
// One shared diffuse atlas, without a normal map or per-character materials.
const atlasCanvas=document.createElement("canvas");
atlasCanvas.width=atlasCanvas.height=512;
const atlasContext=atlasCanvas.getContext("2d");
const pixels=atlasContext.createImageData(512,512);
const TAU=Math.PI*2;
const clamp8=v=>Math.max(0,Math.min(255,Math.round(v)));
for(let y=0;y<512;y++)for(let x=0;x<512;x++){
 const tile=(x>>7)+4*(y>>8);
 const u=(x%128)/128,v=(y%256)/256;
 const noise=(Math.sin(x*37.23+y*91.17)*43758.5453)%1;
 let value=250, warmth=0;
 if(tile===0){ // fleece / cotton: dense weave, shallow wear in creases
  value=232+5*Math.sin(TAU*(u*43+v*7))+4*Math.sin(TAU*v*104)+4*noise;
 }else if(tile===1){ // denim: indigo twill and faded warp
  value=229+7*Math.sin(TAU*(u*49+v*112))+7*Math.sin(TAU*(u*17-v*2))+5*noise;
  warmth=-2;
 }else if(tile===2){ // satin nylon: low contrast, broad ripstop
  value=239+5*Math.sin(TAU*(u*21+v*22))+3*Math.sin(TAU*v*56)+2*noise;
 }else if(tile===3){ // warm skin tint, no relief or gloss map
  value=246+3*Math.cos(TAU*(u*.83-v*.69))+2*noise;
  warmth=3;
 }else if(tile===4){ // hair: narrow, irregular streaks rather than geometry strands
  value=229+10*Math.sin(TAU*(u*34+.3*Math.sin(v*16)))+5*Math.sin(TAU*u*11)+4*noise;
  warmth=2;
 }else if(tile===5){ // worn leather and rubber
  value=231+6*Math.cos(TAU*(u*6+v*8))+7*noise;
 }else if(tile===6){ // raised rib knit
  value=230+10*Math.sin(TAU*u*51)+3*Math.cos(TAU*v*75)+3*noise;
 }
 const i=(y*512+x)*4;
 pixels.data.set([clamp8(value+warmth),clamp8(value),clamp8(value-warmth),255],i);
}
atlasContext.putImageData(pixels,0,0);
const wardrobeAtlas=new CanvasTexture(atlasCanvas);
wardrobeAtlas.colorSpace=SRGBColorSpace;
wardrobeAtlas.anisotropy=2;
const mat = new MeshStandardMaterial({vertexColors:true,map:wardrobeAtlas,roughness:.79,metalness:0});

const sphere = new SphereGeometry(1,8,5);
const detailSphere = new SphereGeometry(1,6,4);
const cube = new BoxGeometry(1,1,1);
const sourceMeshes = new Map();
function sampleGeometry(geometry){
 if(sourceMeshes.has(geometry))return sourceMeshes.get(geometry);
 const mesh=geometry.index?geometry.toNonIndexed():geometry;
 const arr=mesh.getAttribute("position").array;
 sourceMeshes.set(geometry,arr);
 return arr;
}
function createCustomer(o){
 const positions=[], colors=[], uv=[], surfaceGroups=[], skinIndices=[], skinWeights=[];
 let surface=0;
 const joints=[], children=[];
 let influence=()=>[[0,1]];
 let shadeId=0;
 const h=o.h, hh=h/o.hu, W=o.w, headY=h-hh*.54;
 function joint(name,parent,x,y,z){
  const bone=new Bone();bone.name=name;
  const rest=new Vector3(x,y,z);
  const index=joints.length;
  bone.position.copy(parent<0?rest:rest.clone().sub(joints[parent].rest));
  joints.push({bone,rest,parent});children.push(index);
  if(parent>=0)joints[parent].bone.add(bone);
  return index;
 }
 const blend=(upper,lower,y,width)=>(p)=>{
  const q=MathUtils.smoothstep(p[1],y-width,y+width);
  return [[upper,q],[lower,1-q]];
 };
 const zFace=.097*W, headWidth=.101*W, top=o.top;
 const tone = (base,f)=>new Color(base).multiplyScalar(f);
 const palette = (base,index)=>tone(base,1+Math.sin((index+shadeId)*18.21)*.015);
 function triangle(a,b,c,base){
  positions.push(...a,...b,...c);
  const t=typeof base==="number"?palette(base,positions.length):base;
  for(const vertex of [a,b,c]){
   const [x,y,z]=vertex;
   const grain=surface===3?1:1-.035*Math.cos((y/h)*15+x*11);
   colors.push(t.r*grain,t.g*grain,t.b*grain);
   const u=MathUtils.clamp(.5+x*.95+z*.73,.02,.98);
   const v=MathUtils.clamp(y/h,.02,.98);
   uv.push(((surface%4)*128+8+u*112)/512,1-((surface>>2)*256+12+(1-v)*232)/512);
   surfaceGroups.push(shadeId);
   const weights=influence(vertex);
   for(let i=0;i<4;i++){skinIndices.push(weights[i]?.[0]??0);skinWeights.push(weights[i]?.[1]??0);}
  }
 }
 function solid(g,x,y,z,sx,sy,sz,base,rz=0,ry=0){
  const pos=sampleGeometry(g), q=new Quaternion().setFromEuler(new Euler(0,ry,rz)), v=new Vector3();
  const pt=(i)=>v.set(pos[i]*sx,pos[i+1]*sy,pos[i+2]*sz).applyQuaternion(q).add(new Vector3(x,y,z)).toArray();
  shadeId++;
  for(let i=0;i<pos.length;i+=9)triangle(pt(i),pt(i+3),pt(i+6),base);
 }
 const oval=(x,y,z,sx,sy,sz,c,rz=0,ry=0)=>solid(Math.max(sx,sy,sz)<.041?detailSphere:sphere,x,y,z,sx,sy,sz,c,rz,ry);
 const box=(x,y,z,sx,sy,sz,c,rz=0,ry=0)=>solid(cube,x,y,z,sx,sy,sz,c,rz,ry);
 function loft(rings,n,c,selector){
  shadeId++;
  const grid=rings.map(([y,x,z,rx,rz],r)=>Array.from({length:n},(_,i)=>{
   const a=(i/n)*Math.PI*2;
   const fold=(r>0&&r<rings.length-1&&y<h-hh*1.12)?Math.sin(i*2.2+r*1.7)*.008*W:0;
   return [x+(rx+fold)*Math.sin(a),y+fold*.85,z+(rz+fold)*Math.cos(a)];
  }));
  for(let r=0;r<grid.length-1;r++)for(let i=0;i<n;i++){
   const j=(i+1)%n, ink=selector?selector(r,i):c;
   triangle(grid[r][i],grid[r][j],grid[r+1][i],ink);
   triangle(grid[r][j],grid[r+1][j],grid[r+1][i],ink);
  }
  for(let i=0;i<n;i++){
   const j=(i+1)%n, bottom=rings[0],upper=rings.at(-1);
   triangle([bottom[1],bottom[0],bottom[2]],grid[0][j],grid[0][i],c);
   triangle([upper[1],upper[0],upper[2]],grid.at(-1)[i],grid.at(-1)[j],c);
  }
 }
 const hip=h*(o.hu<5.3?.47:.50), shoulders=h-hh*1.17, hem=hip-h*.015;
 const waist=hem+h*.11, sleeveTop=shoulders-.020;
 const pelvis=joint("Bassin",-1,0,hip,0);
 const chestBone=joint("Torse",pelvis,0,hip+.035,0);
 const headBone=joint("Tête",chestBone,0,shoulders+.025,0);
 const limbs=[];
 influence=blend(chestBone,pelvis,hip+.09*W,.072*W);
 const neckBase=shoulders+.022, neckTop=headY-hh*.30;
 surface=3;
 loft([[neckBase,0,0,.052*W,.045*W],[neckTop,0,.008,.055*W,.053*W]],8,o.skin);
 surface=["wind","vest"].includes(o.style)?2:o.style==="sweater"?6:0;
 const over=o.style==="coat", plaid=o.style==="plaid", wind=o.style==="wind", vest=o.style==="vest", hoodie=o.style==="hood";
 const lower=over?hem-.20:hem;
 const chest=.185*W;
 const rows=[[lower,0,0,chest*(over?1.21:1.01),(over?.163:.108)*W],[hem+.025,0,0,chest*(over?1.18:.98),(over?.163:.110)*W],
  [waist,0,-.006,chest*(over?1.06:.88),(over?.147:.106)*W],[shoulders-.098,0,-.005,chest,.117*W],
  [shoulders-.021,0,-.004,chest*.95,.093*W],[shoulders+.018,0,0,.076*W,.067*W]];
 if(vest){
  const bands=Array.from({length:9},(_,r)=>[hem+(shoulders-.065-hem)*r/8,0,0,(r%2?.174:.162)*W,(r%2?.119:.107)*W]);
  rows.splice(0,rows.length,...bands,[shoulders-.02,0,0,.166*W,.095*W],[shoulders+.02,0,0,.074*W,.066*W]);
 }
 if(plaid){
  rows.splice(0,rows.length,...Array.from({length:11},(_,i)=>[lower+(shoulders+.015-lower)*i/10,0,0,(i===10?.074:.175+(i%3)*.003)*W,(i===10?.066:.106)*W]));
 }
 loft(rows,plaid?16:12,top,(r,i)=>{
  if(plaid){
   if(i===0||i===15)return 0xc8b8a5;
   return [0x867e74,0xb49f89,0x545871,0x3c3e53][(i%2)+2*(Math.floor(r/2)%2)];
  }
  if(wind && (r===2||r===3) && [0,1,2,9,10,11].includes(i))return r===3?0xc6b99e:0x283955;
  if(vest&&r%2===0)return tone(top,.87);
  return top;
 });
 if(["fleece","wind","vest"].includes(o.style)){
  for(let r=0;r<rows.length-2;r++){
   const a=rows[r],b=rows[r+1],za=a[2]+a[4],zb=b[2]+b[4];
   // A narrow zipper strip follows the loft profile instead of floating above it.
   const ink=0x4b3a42, w=.004*W;
   triangle([-w,a[0],za+.002],[w,a[0],za+.002],[-w,b[0],zb+.002],ink);
   triangle([w,a[0],za+.002],[w,b[0],zb+.002],[-w,b[0],zb+.002],ink);
  }
  box(0,shoulders-.075,.117*W,.018,.030,.009,0x91877a);
  for(const s of [-1,1])box(s*.064*W,hem+.069,.107*W,.067*W,.012,.007,tone(top,.72),s*.18);
 }
 if(wind)oval(0,shoulders+.015,-.057,.105*W,.055,.067,0x384457);
 if(hoodie){
  oval(0,shoulders+.032,-.059,.115*W,.059,.070,0x302f36);
  for(const s of [-1,1])box(s*.034*W,shoulders-.078,.109,.009,.138,.007,0xb5aaa0,s*.04);
  oval(0,hem+.069,.096,.111*W,.055,.022,0x414047);
 }
 if(over){
  oval(0,shoulders+.027,.022,.134*W,.050,.088,0x714560,-.10);
  box(.021,shoulders-.118,.109,.074*W,.246,.015,0x70425c,.03);
  for(let i=0;i<4;i++)oval(.081,hem-.112+i*.083,.106,.012,.011,.008,0x9d744f);
 }
 if(plaid){
  box(0,hem-.024,.105,.217*W,.032,.01,0x564435);
  box(.018,hem-.024,.113,.039,.025,.010,0xad884c);
  for(const s of [-1,1])box(s*.115*W,shoulders-.12,.105,.078,.061,.013,0x777282);
 }
 for(const s of [-1,1]){
  const x=.096*W, thigh=.092*W, legEnd=.081*W;
  const hipBone=joint("Hanche "+s,pelvis,x*s,hip,0);
  const knee=joint("Genou "+s,hipBone,x*s,h*.265,.012);
  const ankle=joint("Cheville "+s,knee,x*s,.077*W,0);
  surface=1;
  influence=blend(hipBone,knee,h*.265,.065*W);
  loft([[legEnd,x*s,0,thigh*(o.style==="fleece"?1.05:.83),.071*W],
   [h*.11,x*s,.004,thigh*.94,.077*W],[h*.22,x*s,-.020,thigh*.79,.072*W],[h*.30,x*s,.013,thigh*.84,.085*W],
   [hip-.099,x*s,0,thigh,.098*W],[hip+.014,x*s*.89,0,thigh*.93,.091*W]],8,o.pants,(r,i)=>r===2&&[0,7].includes(i)?tone(o.pants,1.13):o.pants);
  surface=5;
  influence=()=>[[ankle,1]];
  oval(x*s,.059*W,.043,.087*W,.049*W,.134*W,o.shoe);
  oval(x*s,.022*W,.042,.090*W,.021*W,.136*W,[1,3,5,6,7].includes(outfits.indexOf(o))?0xc1b7a4:0x332b2a);
  surface=1;
  influence=()=>[[hipBone,1]];
  if(["fleece","wind","plaid","sweater"].includes(o.style))box(x*s,hip-.055,-.099*W,.085*W,.060*W,.008,tone(o.pants,.79),s*.12);
  if(hoodie)box(x*s+s*.074*W,hip-.152,.015,.036,.125,.114,0x776e52,s*.03);
  const arm=s*chest;
  const wristY=hem-.043, ax=arm+s*.050*W;
  const elbowY=(wristY+sleeveTop)*.5;
  const upper=joint("Épaule "+s,chestBone,arm-s*.014*W,sleeveTop-.032,-.004);
  const elbow=joint("Coude "+s,upper,arm+s*.035*W,elbowY,-.009);
  const wrist=joint("Main "+s,elbow,ax,wristY,0);
  limbs.push({s,hipBone,knee,ankle,upper,elbow,wrist});
  surface=wind?2:o.style==="sweater"?6:0;
  influence=blend(upper,elbow,elbowY,.065*W);
  const armColor=vest?0x9a9593:top;
  loft([[wristY,ax,0,.044*W,.042*W],[wristY+.055,ax+s*.008,0,.053*W,.048*W],
   [(wristY+sleeveTop)*.5,arm+s*.036*W,-.009,.061*W,.055*W],
   [sleeveTop-.075,arm+s*.019*W,-.01,.066*W,.066*W],
   [sleeveTop-.026,arm-s*.018*W,-.007,.062*W,.059*W],
   [sleeveTop+.016,arm-s*.048*W,-.003,.041*W,.045*W]],8,armColor,(r,i)=>wind&&r===2?0x33425b:wind&&r===3?0xc1b49a:plaid&&r%2?0x9d8f85:armColor);
  surface=3;
  influence=()=>[[wrist,1]];
  oval(ax,wristY-.030,.007,.036*W,.054*W,.026*W,o.skin,s*.12);
  oval(ax-s*.028*W,wristY-.021,.016,.014*W,.032*W,.019*W,o.skin,-s*.23);
 }
 surface=3;
 influence=()=>[[headBone,1]];
 // Tapered jaw, cheek planes and ear overlap.
 loft([[headY-hh*.37,0,.021,headWidth*.48,zFace*.57],
  [headY-hh*.28,0,.016,headWidth*.77,zFace*.79],
  [headY-hh*.035,0,0,headWidth,zFace],
  [headY+hh*.21,0,-.008,headWidth*.96,zFace*.96],
  [headY+hh*.35,0,-.013,headWidth*.71,zFace*.79],
  [headY+hh*.405,0,-.016,headWidth*.42,zFace*.52]],12,o.skin);
 for(const s of [-1,1]){
  oval(s*headWidth*.93,headY-hh*.045,0,.020*W,.033*W,.018*W,o.skin,s*.09);
  const ex=s*headWidth*.39;
  oval(ex,headY+hh*.043,zFace*.88,.021*W,.013*W,.012*W,0xf6dec5,0,s*.19);
  oval(ex,headY+hh*.041,zFace*.977,.010*W,.011*W,.006*W,0x493027);
  oval(ex-.002,headY+hh*.046,zFace*1.032,.0031*W,.0031*W,.002*W,0xf8e7cc);
  box(ex,headY+hh*.128,zFace*.89,.038*W,.009*W,.009*W,o.hair,-s*.13,s*.15);
 }
 oval(0,headY-hh*.029,zFace*.99,.018*W,.036*W,.024*W,o.skin);
 // Smile hugs the face plane and the corners rise visibly.
 surface=7;
 const child=o.hu<5.3;
 function smilePoint(t,edge){
  return [t*.040*W,headY+hh*(-.213+.064*t*t)+edge*(child?.011:.008)*W*(1-t*t),MathUtils.lerp(.016+zFace*.79,zFace,.29+.26*t*t)-.010*W*t*t+.004];
 }
 for(let j=0;j<10;j++){
  const a=j/5-1,b=(j+1)/5-1;
  triangle(smilePoint(a,-.68),smilePoint(b,-.68),smilePoint(a,.55),0x652e29);
  triangle(smilePoint(b,-.68),smilePoint(b,.55),smilePoint(a,.55),0x652e29);
  if(j>1&&j<8){
   const front=(t,e)=>{const v=smilePoint(t,e);v[2]+=.0015;return v;};
   triangle(front(a,.13),front(b,.13),front(a,.48),0xffe3c8);
   triangle(front(b,.13),front(b,.48),front(a,.48),0xffe3c8);
  }
 }
 if(o.style==="wind")box(0,headY-hh*.309,zFace*.66,.035*W,.027*W,.012*W,0x48342a);
 if(plaid)for(const s of [-1,1])oval(s*.018,headY-hh*.145,zFace*.91,.025,.012,.012,0x543526,-s*.19);
 // Hair cap and coarse clumps preserve silhouettes without alpha cards.
 surface=o.cut==="cap"?0:4;
 const long=["bob","curl","fringe","pigtails"].includes(o.cut);
 // Continuous crown and nape under the clumps. The hairline descends at the temples and rear.
 const capPoint=(u,row)=>{
  const angle=2*Math.PI*u;
  const rear=(1-Math.cos(angle))*.5;
  const length=1.25+1.12*rear+(long?.18:0);
  const polar=length*row/5;
  const ripple=1+.014*Math.sin(angle*7+row*.9);
  return [Math.sin(angle)*Math.sin(polar)*headWidth*1.16*ripple,
   headY+hh*(.055+.472*Math.cos(polar)),
   -.012+Math.cos(angle)*Math.sin(polar)*zFace*(1.18+.09*rear)*ripple];
 };
 for(let row=0;row<5;row++)for(let i=0;i<14;i++){
  const a=capPoint(i/14,row),b=capPoint((i+1)/14,row),c=capPoint(i/14,row+1),d=capPoint((i+1)/14,row+1);
  if(row>0)triangle(a,c,b,o.hair);
  triangle(b,c,d,o.hair);
 }
 if(o.cut==="cap"){
  oval(0,headY+hh*.275,-.022,headWidth*1.10,hh*.24,zFace*1.16,0x353646);
  oval(0,headY+hh*.184,-.113,headWidth*.94,.011,zFace*.84,0x2b2e3b);
 }else{
  const waves=o.cut==="bob"||o.cut==="pigtails"||o.cut==="wave";
  if(waves){
   const sweep=o.cut==="wave"?.018:0;
   oval(-headWidth*.27+sweep,headY+hh*.319,zFace*.48,headWidth*.60,hh*.177,zFace*.63,o.hair,-.33);
   oval(headWidth*.34+sweep,headY+hh*.303,zFace*.48,headWidth*.48,hh*.17,zFace*.63,o.hair,.39);
   oval(-headWidth*.72,headY+hh*.166,zFace*.47,headWidth*.28,hh*.205,zFace*.46,o.hair,-.41);
   oval(headWidth*.72,headY+hh*.160,zFace*.43,headWidth*.27,hh*.185,zFace*.42,o.hair,.33);
  }else{
   for(let i=0;i<6;i++){
    const x=(i-2.5)*headWidth*.32;
    const y=headY+hh*(.295+Math.sin(i*2.1)*.052-(o.cut==="fringe"?.035:0));
    oval(x,y,zFace*.48,headWidth*.34,hh*(long?.19:.16),zFace*.59,o.hair,(i-2.5)*-.15);
   }
  }
  for(const s of [-1,1]){
   oval(s*headWidth*.86,headY+(long?-hh*.035:hh*.12),-.027,headWidth*.34,hh*(long?.28:.19),zFace*.74,o.hair,s*.14);
   if(o.cut==="curl"||o.cut==="bob"||o.cut==="fringe")oval(s*headWidth*.79,headY-hh*.22,-.043,headWidth*.39,hh*.19,zFace*.65,o.hair,s*.27);
   if(o.cut==="pigtails"){
    oval(s*headWidth*1.43,headY-hh*.10,-.051,headWidth*.42,hh*.25,zFace*.57,o.hair,s*-.47);
    oval(s*headWidth*1.05,headY+hh*.025,-.05,headWidth*.16,hh*.09,zFace*.30,0x935778);
   }
  }
 }
 const geo=new BufferGeometry();
 geo.setAttribute("position",new Float32BufferAttribute(positions,3));
 geo.setAttribute("color",new Float32BufferAttribute(colors,3));
 geo.setAttribute("uv",new Float32BufferAttribute(uv,2));
 geo.computeVertexNormals();
 // Blend normals only within the same sewn panel or sculpted part.
 const normals=geo.getAttribute("normal");
 const grouped=new Map();
 const keys=surfaceGroups.map((part,i)=>{
  const key=part+":"+positions.slice(i*3,i*3+3).map(v=>Math.round(v*100000)).join(",");
  if(!grouped.has(key))grouped.set(key,new Vector3());
  grouped.get(key).add(new Vector3().fromBufferAttribute(normals,i));
  return key;
 });
 keys.forEach((key,i)=>{
  const face=new Vector3().fromBufferAttribute(normals,i);
  const rounded=face.lerp(grouped.get(key).clone().normalize(),.72).normalize();
  normals.setXYZ(i,rounded.x,rounded.y,rounded.z);
 });
 geo.setAttribute("skinIndex",new Uint16BufferAttribute(skinIndices,4));
 geo.setAttribute("skinWeight",new Float32BufferAttribute(skinWeights,4));
 const mesh=new SkinnedMesh(geo,mat);
 mesh.name=o.name;
 mesh.add(joints[0].bone);
 mesh.updateMatrixWorld(true);
 mesh.bind(new Skeleton(joints.map(j=>j.bone)),new Matrix4());
 mesh.frustumCulled=false;
 return {mesh,joints,limbs,pelvis,chestBone,headBone,h,W,hip};

}

