shader_type spatial;
render_mode cull_back;
uniform sampler2D base_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D grain_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D grain_roughness : filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 vec3 base=texture(base_texture,p/6.0).rgb;
 float pores=texture(grain_roughness,p*.9).r;
 float puddle=smoothstep(.55,.76,sin(p.x*.41+sin(p.y*.22))*sin(p.y*.37)*.5+.5);
 ALBEDO=base*mix(.82,.61,puddle);
 NORMAL_MAP=texture(grain_normal,p*.9).rgb;
 NORMAL_MAP_DEPTH=mix(.48,.08,puddle);
 ROUGHNESS=mix(.47,.16,puddle)*(.8+.2*pores);
 METALLIC=.13;
 // Soft fixed reflections of storefront lighting, retained with baked lighting.
 float blue=exp(-abs(p.x+5.6)*.9)*exp(-abs(p.y-9.0)*.24);
 float gold=exp(-abs(p.x-1.0)*.55)*exp(-abs(p.y-9.0)*.22);
 EMISSION=(vec3(.025,.075,.19)*blue+vec3(.13,.072,.018)*gold)*(.38+.62*pores);
 // Pools are centred underneath the four modelled lamp heads.
 vec2 lamps[4]=vec2[4](vec2(-10.48,20.0),vec2(11.82,22.5),vec2(-18.88,32.0),vec2(23.12,33.0));
 float lamp_pool=0.0;
 for(int i=0;i<4;i++){vec2 delta=p-lamps[i];lamp_pool+=exp(-dot(delta,delta)/12.0);}
 EMISSION+=vec3(.11,.085,.052)*lamp_pool*(.75+.25*pores);
 float outside=max(step(7.21,world_pos.z),step(5.81,abs(world_pos.x)));
 float haze=smoothstep(4.0,22.0,length(world_pos.xz-CAMERA_POSITION_WORLD.xz))*outside;
 ALBEDO*=1.0-haze;
 EMISSION=mix(EMISSION,vec3(.018,.026,.041),haze);
}
