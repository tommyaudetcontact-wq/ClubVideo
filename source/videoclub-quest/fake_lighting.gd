extends Node3D

# Two instanced draws, no shadow maps, no full-screen bloom pass.
func _ready() -> void:
	name = "SimulatedLightGlow"
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0,0.82,0.56,0.12);
void fragment() {
	vec2 p = UV*2.0-1.0;
	float falloff = max(0.0,1.0-dot(p,p));
	ALBEDO = tint.rgb;
	ALPHA = tint.a*falloff*falloff*falloff;
}
"""
	for floor_pool in [false,true]:
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("tint",Color(1.0,0.82,0.56,0.055 if floor_pool else 0.16))
		var quad := QuadMesh.new()
		quad.size = Vector2(2.1,3.0) if floor_pool else Vector2(1.50,2.15)
		quad.material = material
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = quad
		instances.instance_count = 9
		var index := 0
		for z in [-4.5,0.3,4.5]:
			for x in [-3.9,0.0,3.9]:
				instances.set_instance_transform(index,Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(x,0.005 if floor_pool else 3.145,z)))
				index += 1
		var node := MultiMeshInstance3D.new()
		node.name = "SoftFloorLight" if floor_pool else "FluorescentHalos"
		node.multimesh = instances
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
