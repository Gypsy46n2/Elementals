// TerrainBlendVisual.gdshader
// ----------------------------
// Safe spatial shader for the visual terrain layer.
// - Compatible with gl_compatibility renderer (no advanced render modes).
// - Two albedo textures (grass/ground + rock) tiled by world XZ.
// - Vertex COLOR channels carry blend weights:
//     R = grass, G = dirt/mud, B = rock, A = wet/special.
// - No animated shader tricks (no airborne waves), no time uniforms.
// - No depth/transparency hacks; opaque, depth_draw_opaque.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D ground_alb : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_alb   : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float ground_uv_scale : hint_range(0.02, 1.0) = 0.20;
uniform float rock_uv_scale   : hint_range(0.02, 1.0) = 0.10;

uniform vec3 grass_tint : source_color = vec3(0.42, 0.62, 0.30);
uniform vec3 dirt_tint  : source_color = vec3(0.58, 0.44, 0.30);
uniform vec3 rock_tint  : source_color = vec3(0.62, 0.60, 0.58);
uniform vec3 wet_tint   : source_color = vec3(0.30, 0.42, 0.55);

uniform float ambient_boost : hint_range(0.0, 1.0) = 0.20;

varying vec3 v_world;
varying vec4 v_color;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_color = COLOR;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv_g = v_world.xz * ground_uv_scale;
	vec2 uv_r = v_world.xz * rock_uv_scale;

	// Two-tap detune to break visible tiling without animating anything.
	vec3 g_a = texture(ground_alb, uv_g).rgb;
	vec3 g_b = texture(ground_alb, uv_g * 0.41 + vec2(13.7, 7.3)).rgb;
	vec3 ground_tex = mix(g_a, g_b, 0.35);

	vec3 r_a = texture(rock_alb, uv_r).rgb;
	vec3 r_b = texture(rock_alb, uv_r * 0.47 + vec2(5.3, 9.1)).rgb;
	vec3 rock_tex = mix(r_a, r_b, 0.35);

	float wg = max(v_color.r, 0.0);
	float wd = max(v_color.g, 0.0);
	float wr = max(v_color.b, 0.0);
	float ww = max(v_color.a, 0.0);
	float total = wg + wd + wr + ww + 0.0001;

	vec3 grass = ground_tex * grass_tint;
	vec3 dirt  = ground_tex * dirt_tint;
	vec3 rock  = rock_tex   * rock_tint;
	// Wet channel darkens and shifts the ground toward water/mud color.
	vec3 wet   = mix(ground_tex * vec3(0.45, 0.40, 0.35), wet_tint, 0.6);

	vec3 col = (grass * wg + dirt * wd + rock * wr + wet * ww) / total;

	// Subtle macro variation so identical tiles do not look identical.
	float macro = hash21(floor(v_world.xz * 0.5)) * 0.10 + 0.95;
	col *= macro;

	// Tiny ambient lift so deep shadow areas still read as terrain.
	col += col * ambient_boost * 0.25;

	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.65, wr);
	METALLIC = 0.0;
}
