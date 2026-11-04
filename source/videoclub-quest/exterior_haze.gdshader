shader_type spatial;
render_mode cull_disabled;
uniform sampler2D base_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform bool textured=false;
uniform bool vertex_color=false;
uniform vec4 tint:source_color=vec4(1.0);
uniform vec3 uv_scale=vec3(1.0);
uniform vec3 uv_offset=vec3(0.0);
uniform float surface_roughness=.75;
uniform float surface_metallic=0.0;
uniform vec3 glow:source_color=vec3(0.0);
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec4 color=tint;
 if(textured)color*=texture(base_texture,UV*uv_scale.xy+uv_offset.xy);
 if(vertex_color)color*=COLOR;
 ALBEDO=color.rgb;
 ROUGHNESS=surface_roughness;
 METALLIC=surface_metallic;
 EMISSION=glow;
 float outside=max(step(7.21,world_pos.z),step(5.81,abs(world_pos.x)));
 float haze=smoothstep(4.0,22.0,length(world_pos.xz-CAMERA_POSITION_WORLD.xz))*outside;
 ALBEDO*=1.0-haze;
 EMISSION=mix(EMISSION,vec3(.018,.026,.041),haze);
}
