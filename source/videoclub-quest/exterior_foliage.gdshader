shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaves:source_color,filter_linear_mipmap_anisotropic;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec4 leaf=texture(leaves,UV);
 float haze=smoothstep(4.0,22.0,length(world_pos.xz-CAMERA_POSITION_WORLD.xz));
 ALBEDO=leaf.rgb*1.5*(1.0-haze);
 EMISSION=vec3(.018,.026,.041)*haze;
 ROUGHNESS=.9;
 ALPHA=leaf.a;
 ALPHA_SCISSOR_THRESHOLD=.4;
}
