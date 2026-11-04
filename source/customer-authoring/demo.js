const V=(x=0,y=0,z=0)=>new Vector3(x,y,z);
const scene=new Scene();
scene.background=new Color(0xbeb2a8);
scene.add(new HemisphereLight(0xdce8ff,0x675047,1.57));
for(const [ink,power,p] of [[0xffecd0,2.7,[-3,5,5]],[0xbcd2ff,.80,[3,4,-4]]]){
 const light=new DirectionalLight(ink,power);light.position.set(...p);scene.add(light);
}
const material=(color)=>new MeshStandardMaterial({color,roughness:.85});
function panel(parent,size,pos,ink){
 const item=new Mesh(new BoxGeometry(...size),material(ink));
 item.position.set(...pos);parent.add(item);return item;
}
const stage=new Group();scene.add(stage);
panel(stage,[14,.05,14],[0,-.025,0],0xa09990);
const shelf=new Group();stage.add(shelf);
panel(shelf,[.91,1.65,.3],[.21,.825,.89],0x27354c);
for(const y of [.29,.70,1.08,1.48]){
 panel(shelf,[.94,.04,.47],[.21,y,.69],0x334e6d);
 for(let i=0;i<9;i++){
  if((y===1.08||y===.70)&&i===3)continue;
  panel(shelf,[.034,.135,.12],[-.18+i*.094,y+.088,.64],[0x8a5253,0xa0936e,0x586579,0x515749][i%4]);
 }
}
const counter=new Group();stage.add(counter);
panel(counter,[1.22,.84,.40],[.16,.42,.76],0x263c5c);
panel(counter,[1.29,.066,.54],[.16,.866,.72],0x736052);
panel(counter,[.25,.23,.16],[.48,1.014,.83],0xb9ad97);
panel(counter,[.19,.14,.015],[.48,1.021,.743],0x272d32);
const box=new Group();stage.add(box);
const caseShell=panel(box,[.132,.186,.017],[0,0,0],0x282b30);
panel(box,[.121,.169,.002],[0,0,.009],0x293950);
const caseStripe=panel(box,[.104,.036,.002],[0,.055,.011],0xd5ac6d);
panel(box,[.061,.064,.002],[.014,-.015,.011],0x789cb0);
const people=outfits.map(createCustomer);
for(const p of people)stage.add(p.mesh);
const shadow=new Mesh(new CircleGeometry(.33,32),new MeshBasicMaterial({color:0x3d3434,transparent:true,opacity:.18,depthWrite:false}));
shadow.rotation.x=-Math.PI/2;stage.add(shadow);
const renderer=new WebGLRenderer({antialias:true,preserveDrawingBuffer:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));
renderer.toneMapping=ACESFilmicToneMapping;
document.querySelector("main").append(renderer.domElement);
const camera=new PerspectiveCamera(35,1,.03,50);
const picker=document.querySelector("select");
outfits.forEach((o,i)=>picker.add(new Option(o.name,i)));
const params=new URLSearchParams(location.search);
let actor=Number(params.get("client")??6),action=Number(params.get("action")??0),playing=!params.has("still"),time=0,view=.80;
picker.value=String(actor);
const names=["Marche","Marche avec boîtier","Prise en rayon","Remise au comptoir"];
const durations=[3.5,3.5,3.3,3.5];
const ease=(v)=>MathUtils.smoothstep(v,0,1);

function setWorld(bone,q){
 const parent=bone.parent.getWorldQuaternion(new Quaternion()).invert();
 bone.quaternion.copy(parent.multiply(q));
 bone.updateWorldMatrix(false,true);
}
function solveChain(rig,first,second,end,target,pole,keepEnd=false){
 const a=rig.joints[first],b=rig.joints[second],c=rig.joints[end];
 const start=a.bone.getWorldPosition(V());
 const d=target.clone().sub(start), L1=b.rest.distanceTo(a.rest),L2=c.rest.distanceTo(b.rest);
 const range=MathUtils.clamp(d.length(),Math.abs(L1-L2)+.001,L1+L2-.0005);
 d.normalize();
 const bend=pole.clone().addScaledVector(d,-pole.dot(d)).normalize();
 const along=(L1*L1-L2*L2+range*range)/(2*range);
 const mid=start.clone().addScaledVector(d,along).addScaledVector(bend,Math.sqrt(Math.max(0,L1*L1-along*along)));
 const dest=start.clone().addScaledVector(d,range);
 setWorld(a.bone,new Quaternion().setFromUnitVectors(b.rest.clone().sub(a.rest).normalize(),mid.clone().sub(start).normalize()));
 setWorld(b.bone,new Quaternion().setFromUnitVectors(c.rest.clone().sub(b.rest).normalize(),dest.sub(mid).normalize()));
 if(keepEnd)setWorld(c.bone,new Quaternion());
}
function gait(t,side,stride){
 const f=(t/1.08+(side>0?.5:0))%1;
 if(f<.61)return {z:stride*(.5-f/.61),lift:0};
 const u=(f-.61)/.39;
 return {z:stride*(-.5+ease(u)),lift:.088*Math.sin(Math.PI*u)};
}

function frame(seconds){
 const rig=people[actor],{mesh,joints,limbs,h,W,pelvis,chestBone,headBone}=rig;
 const t=Math.max(0,seconds)%durations[action];
 for(const p of people)p.mesh.visible=p===rig;
 const walking=action<2, carry=action===1;
 const progress=walking?t:0;
 // The root advances at the same speed as the stance foot retreats.
 const stride=h*.25;
 const z=progress*stride/(1.08*.61)-.73;
 const rootZ=walking?z:(action>=2?.13:0);
 const feet=limbs.map(l=>walking?gait(t,l.s,stride):{z:l.s*.035,lift:0});
 const phase=t*Math.PI*2/1.08;
 const reach=action===2?ease((t-.35)/.88)*(1-ease((t-1.53)/.92)):action===3?ease((t-.39)/.92)*(1-ease((t-1.77)/.78)):0;
 const lean=walking?.045:.07*reach;
 const shelfY=h<1.4?.815:1.195;
 const shelfCase=V(.103,shelfY,.512);
 const counterCase=V(.103,.903,.511);
 const grip=V(0,-.028,.042);
 mesh.position.set(walking?.025*Math.sin(phase):0,0,rootZ);
 for(const j of joints)j.bone.quaternion.identity();
 joints[pelvis].bone.position.copy(joints[pelvis].rest);
 joints[pelvis].bone.position.y+=walking?-.048+.015*Math.cos(phase*2):-.022*reach;
 for(const [i,l] of limbs.entries()){
  const a=joints[l.hipBone].rest,b=joints[l.knee].rest,c=joints[l.ankle].rest;
  const length=a.distanceTo(b)+b.distanceTo(c)-.002;
  const horizontal=feet[i].z**2+mesh.position.x**2;
  const ceiling=c.y+feet[i].lift+Math.sqrt(Math.max(.001,length*length-horizontal));
  joints[pelvis].bone.position.y=Math.min(joints[pelvis].bone.position.y,ceiling);
 }
 joints[chestBone].bone.rotation.set(lean,walking?.075*Math.sin(phase):.11*reach,walking?.032*Math.cos(phase):-.034*reach);
 joints[headBone].bone.rotation.set(walking?-.027:-.045*reach,walking?-.08*Math.sin(phase):.09*reach,0);
 mesh.updateMatrixWorld(true);
 for(const [i,l] of limbs.entries()){
  const step=feet[i];
  solveChain(rig,l.hipBone,l.knee,l.ankle,V(l.s*.096*W,joints[l.ankle].rest.y+step.lift,rootZ+step.z),V(0,0,1),true);
  const wrist=joints[l.wrist].rest;
  const swing=walking?.17*Math.cos(phase+(l.s>0?0:Math.PI)):0;
  let hand=V(wrist.x,wrist.y+Math.abs(swing)*.16,rootZ+swing);
  if(l.s>0){
   const hold=V(.175*W,h*.60,.218+rootZ);
   if(carry)hand=hold;
   if(action===2){
    const shelfWrist=shelfCase.clone().sub(grip);
    if(t<1.42)hand.lerp(shelfWrist,reach);
    else hand.copy(hold).lerp(shelfWrist,reach);
   }
   if(action===3)hand.copy(hold).lerp(counterCase.clone().sub(V(0,-.055,.042)),reach);
  }
  solveChain(rig,l.upper,l.elbow,l.wrist,hand,V(l.s*.75,-.6,-.39),true);
 }
 const right=limbs.find(l=>l.s>0);
 const wrist=joints[right.wrist].bone.getWorldPosition(V());
 box.visible=action!==0;
 shelf.visible=action===2;
 counter.visible=action===3;
 // At the two contacts the case is stationary on the shelf/counter.
 if(action===2&&t<1.42){box.position.copy(shelfCase);box.rotation.set(0,0,0);}
 else if(action===3&&t>=1.70){box.position.copy(counterCase);box.rotation.set(-Math.PI/2,0,0);}
 else{
  box.position.copy(wrist).add(V(0,action===3?MathUtils.lerp(grip.y,-.055,reach):grip.y,grip.z));
  box.rotation.set(action===3?-Math.PI*.5*reach:-.11*(1-reach),0,-.11*(1-reach));
 }
 shadow.position.set(mesh.position.x,.003,rootZ);
 const portrait=params.has("portrait");
 const look=portrait?V(mesh.position.x,h-.16,rootZ):V(action>=2?.11:0,h*.53,walking?rootZ:.22);
 const cameraDistance=portrait?.64:2.85;
 camera.position.copy(look).add(V(Math.sin(view)*cameraDistance,portrait?.022:.45,Math.cos(view)*cameraDistance));
 camera.lookAt(look);
 const canvas=renderer.domElement,w=canvas.clientWidth,ht=canvas.clientHeight;
 renderer.setSize(w,ht,false);
 camera.aspect=w/ht;camera.updateProjectionMatrix();
 renderer.render(scene,camera);
 document.querySelector("#caption").textContent=names[action];
 document.documentElement.dataset.ready="true";
 return {right:wrist.toArray(),feet:limbs.map(l=>joints[l.ankle].bone.getWorldPosition(V()).toArray()),case:box.position.toArray(),root:rootZ};
}
window.previewFrame=(clip,who,t,angle=.80)=>{action=clip;actor=who;view=angle;playing=false;return frame(t);};
window.previewCase=(game)=>{document.querySelector("#case-type").value=game?"game":"dvd";document.querySelector("#case-type").dispatchEvent(new Event("change"));};
function choose(id){action=id;time=0;view=id===2?1.72:id===3?1.34:.80;document.querySelectorAll("[data-action]").forEach((b,i)=>b.classList.toggle("active",i===id));frame(time);}
document.querySelectorAll("[data-action]").forEach((b,i)=>b.onclick=()=>choose(i));
document.querySelector("#case-type").onchange=e=>{
 const game=e.target.value==="game";
 caseShell.material.color.setHex(game?0x438345:0x282b30);
 caseStripe.material.color.setHex(game?0x9ad36e:0xd5ac6d);
 frame(time);
};
picker.onchange=()=>{actor=Number(picker.value);time=0;frame(time);};
document.querySelector("#pause").onclick=(event)=>{playing=!playing;event.currentTarget.textContent=playing?"Pause":"Lire";};
let drag=null;
const canvas=renderer.domElement;
canvas.onpointerdown=e=>{drag=e.clientX;canvas.setPointerCapture(e.pointerId);};
canvas.onpointermove=e=>{if(drag!==null){view+=(drag-e.clientX)*.013;drag=e.clientX;frame(time);}};
canvas.onpointerup=canvas.onpointercancel=()=>{drag=null;};
let last=performance.now();
function tick(now){if(playing){time+=Math.min(.034,(now-last)/1000);frame(time);}last=now;requestAnimationFrame(tick);}
choose(action);
requestAnimationFrame(tick);
