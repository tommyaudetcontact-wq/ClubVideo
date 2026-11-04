shader_type sky;

// Cloud photograph is low-frequency color. Stars and moon are evaluated at
// the eye framebuffer resolution rather than enlarging raster star pixels.
uniform sampler2D cloud_panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 horizon_color : source_color = vec4(0.1451,0.1882,0.2667,1.0);

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx)*0.1031);
	q += dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}

void sky() {
	vec3 color = textureLod(cloud_panorama,SKY_COORDS,3.5).rgb;
	if (!AT_CUBEMAP_PASS) {
		vec2 grid = SKY_COORDS*vec2(4096.0,2048.0);
		vec2 cell = floor(grid);
		float seed = hash21(cell);
		float latitude_weight = sqrt(max(0.0,1.0-EYEDIR.y*EYEDIR.y));
		float star = step(1.0-0.0012*latitude_weight,seed)*step(0.025,EYEDIR.y);
		vec2 center = vec2(hash21(cell+17.1),hash21(cell+41.3))*0.6+0.2;
		vec2 delta = fract(grid)-center;
		float footprint = length(fwidth(grid));
		float variance = 0.018+footprint*footprint*0.12;
		float intensity = exp(-dot(delta,delta)/variance)/(1.0+footprint*footprint*0.45);
		color += vec3(0.78,0.86,1.0)*star*intensity*0.65;
	}
	// A smooth horizon joins fully fogged distant ground without a hard edge.
	float horizon = 1.0-smoothstep(0.0,0.075,abs(EYEDIR.y));
	COLOR = mix(color,horizon_color.rgb,horizon*0.96);
}
