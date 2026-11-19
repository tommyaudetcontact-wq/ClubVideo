shader_type spatial;
render_mode vertex_lighting;
uniform sampler2D paper_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
void vertex() { UV = UV / 16.0 + INSTANCE_CUSTOM.xy; }
void fragment() {
    ALBEDO = texture(paper_atlas, UV).rgb;
    ROUGHNESS = 0.65;
    SPECULAR = 0.12;
}
