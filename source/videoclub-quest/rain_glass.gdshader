shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_disabled;
uniform sampler2D condensation : filter_linear_mipmap,repeat_disable;
uniform float preview_time = -1.0;
float hash(float p){return fract(sin(p*127.1)*43758.5453);}
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 uv=UV;
 uv.y=(2.98-world_position.y)/2.6;
 bool side=abs(world_position.x+5.755)<.008;
 if(side){uv.x=(world_position.z+1.58)/2.12;}
 float pane=floor((world_position.x+5.75)/2.30);
 if(abs(world_position.x+5.76)<.03)pane=floor((world_position.z+1.56)/2.12)+7.0;
 vec2 sample_uv=uv;
 float mirror=step(.5,hash(pane+25.0));
 sample_uv.x=mix(uv.x,1.0-uv.x,mirror);
 // Mirrored continuous coordinates meet at identical edge texels. Do not
 // restart droplets or change the texture randomly at an imaginary pane seam.
 if(side){
  sample_uv.x=1.0-abs(mod(uv.x,2.0)-1.0);
  mirror=step(1.0,mod(uv.x,2.0));
 }
 vec4 packed=texture(condensation,sample_uv);
 packed.r=mix(packed.r,1.0-packed.r,mirror);
 float t=preview_time<0.0?TIME:preview_time;
 float lane=floor(uv.x*18.0);
 float seed=hash(lane+3.0);
 float bead=0.0;
 float trail=0.0;
 vec2 bead_bend=vec2(0.0);
 float cx=(lane+.20+.60*hash(lane+12.0))/18.0;
 float cy=-.14+mod(t*(.035+seed*.045)+hash(lane+33.0)*1.6,1.5);
 float wiggle=sin(uv.y*24.0+seed*12.0)*.0013;
 vec2 q=(uv-vec2(cx+wiggle,cy))/vec2(.0032,.0075);
 float radius=dot(q,q);
 // Derivatives remain outside the lane branch, identical across lane edges.
 float radius_width=fwidth(radius);
 // Inactive lanes have always contributed zero. Skip their moving-water
 // arithmetic, preserving condensation, static beads and all active trails.
 if(seed>=.65){
  bead=1.0-smoothstep(.25,1.0+radius_width,radius);
  float dx=(uv.x-cx-wiggle)*950.0;
  trail=exp(-dx*dx)*smoothstep(cy-.13,cy-.03,uv.y)*(1.0-smoothstep(cy-.015,cy,uv.y));
  bead_bend=vec2(q.x,-q.y)*bead*.18;
 }
 float fog=packed.a*packed.a*.42*(1.0-trail*.65);
 float water=max(packed.b,bead);
 vec2 bend=(packed.rg-.5)*1.5+bead_bend;
 ALBEDO=mix(vec3(.39,.48,.53),vec3(.65,.69,.70),fog);
 ROUGHNESS=mix(.25,.84,smoothstep(.015,.30,fog));
 METALLIC=.025;
 NORMAL_MAP=vec3(clamp(.5+bend,vec2(.02),vec2(.98)),1.0);
 NORMAL_MAP_DEPTH=.35;
 ALPHA=clamp(.025+fog*.70+water*.11+trail*.045,.025,.78);
 float rim=1.0-abs(dot(NORMAL,VIEW));
 rim*=rim;
 rim*=rim;
 EMISSION=vec3(.22,.28,.32)*fog*.20+vec3(.12,.16,.18)*water*.08+vec3(.06,.075,.085)*rim*(.25+fog);
}
