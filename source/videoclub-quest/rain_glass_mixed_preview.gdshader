shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_disabled;
uniform sampler2D condensation : filter_linear_mipmap,repeat_disable;
uniform float preview_time = -1.0;
float hash(float p){return fract(sin(p*127.1)*43758.5453);}
void fragment(){
 vec2 uv=UV;
 vec4 packed=texture(condensation,uv);
 float t=preview_time<0.0?TIME:preview_time;
 float lane=floor(uv.x*18.0);
 float seed=hash(lane+3.0);
 float active=step(.65,seed);
 float cx=(lane+.20+.60*hash(lane+12.0))/18.0;
 float cy=1.14-mod(t*(.035+seed*.045)+hash(lane+33.0)*1.6,1.5);
 float wiggle=sin(uv.y*24.0+seed*12.0)*.0013;
 vec2 q=(uv-vec2(cx+wiggle,cy))/vec2(.0032,.0075);
 float bead=max(0.0,1.0-dot(q,q))*active;
 float trail=exp(-pow((uv.x-cx-wiggle)*950.0,2.0));
 trail*=smoothstep(cy,cy+.015,uv.y)*(1.0-smoothstep(cy+.03,cy+.13,uv.y))*active;
 float fog=packed.a*(1.0-trail*.65);
 float water=max(packed.b,bead);
 vec2 bend=(packed.rg-.5)*1.5+vec2(q.x,-q.y)*bead*.18;
 ALBEDO=mix(vec3(.39,.48,.53),vec3(.65,.69,.70),fog);
 ROUGHNESS=mix(.09,.90,smoothstep(.025,.50,fog));
 METALLIC=.025;
 NORMAL_MAP=vec3(clamp(.5+bend,vec2(.02),vec2(.98)),1.0);
 NORMAL_MAP_DEPTH=.35;
 ALPHA=clamp(.025+fog*.94+water*.17+trail*.045,.025,.78);
 float rim=pow(1.0-abs(dot(NORMAL,VIEW)),4.0);
 EMISSION=vec3(.22,.28,.32)*fog*.33+vec3(.12,.16,.18)*water*.16+vec3(.06,.075,.085)*rim*(.25+fog);
}
