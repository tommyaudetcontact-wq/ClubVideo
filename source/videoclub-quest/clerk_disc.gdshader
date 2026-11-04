shader_type spatial;
render_mode cull_disabled;
uniform sampler2D label_texture : source_color, filter_linear_mipmap_anisotropic;
uniform bool has_label=false;
uniform bool scratched=false;
uniform vec4 label_rect=vec4(0.0,0.0,1.0,1.0);
void fragment() {
	vec2 p=UV-vec2(.5);
	float radius=length(p);
	float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
	float phase=atan(p.y,p.x)*.45+(1.0-facing)*7.0;
	vec3 rainbow=.5+.5*cos(vec3(0.0,2.1,4.2)+phase*3.0);
	float hub=1.0-smoothstep(.13,.16,radius);
	ALBEDO=mix(vec3(.62,.66,.68)+rainbow*.16,vec3(.60,.62,.64),hub);
	METALLIC=.82;
	ROUGHNESS=mix(.19,.35,hub);
	SPECULAR=.65;
	if (FRONT_FACING && scratched) {
		float marks=0.0;
		for (int i=0;i<9;i++) {
			float a=float(i)*2.399;
			vec2 q=mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)))*p;
			float line=abs(q.y-.025*sin(q.x*14.0+float(i))-.018*float(i-4));
			marks=max(marks,(1.0-smoothstep(.001,.0025,line))*step(abs(q.x),.28));
		}
		ALBEDO=mix(ALBEDO,vec3(.85),marks*.7);
		ROUGHNESS=mix(ROUGHNESS,.85,marks);
	}
	if (!FRONT_FACING && has_label) {
		ALBEDO=texture(label_texture,label_rect.xy+vec2(UV.x,1.0-UV.y)*label_rect.zw).rgb;
		METALLIC=.05;
		ROUGHNESS=.48;
	}
}
