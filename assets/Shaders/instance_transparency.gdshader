shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color;
instance uniform float instance_alpha : hint_range(0, 1) = 1.0;

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a * instance_alpha;
}
