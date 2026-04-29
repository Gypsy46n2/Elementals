shader_type spatial;

uniform sampler2D top_texture : source_color, filter_nearest;
uniform sampler2D side_texture : source_color, filter_nearest;
uniform vec3 albedo_color : source_color = vec3(1.0);
uniform float top_texture_scale : hint_range(0.01, 10.0) = 0.25;
uniform float side_scale : hint_range(0.1, 10.0) = 1.0;
uniform float height_darkening : hint_range(0.0, 1.0) = 0.3;
uniform float rim_highlight : hint_range(0.0, 1.0) = 0.2;
uniform float rim_size : hint_range(0.0, 0.5) = 0.05;
uniform float side_animation_speed : hint_range(-10.0, 10.0) = 0.0;
uniform sampler2D overlay_texture : source_color, hint_default_transparent, filter_nearest;
uniform float overlay_animation_speed : hint_range(-10.0, 10.0) = 0.0;

// Top UV distortion for organic flow
uniform float top_noise_scale : hint_range(0.0, 2.0) = 0.15;
uniform float top_noise_strength : hint_range(0.0, 2.0) = 0.4;

// NEW: Top edge blending parameters
uniform float top_edge_darkening : hint_range(0.0, 1.0) = 0.15;
uniform float top_edge_softness : hint_range(0.0, 0.5) = 0.1;
uniform float texture_tiling_noise : hint_range(0.0, 1.0) = 0.05;

// Edge perturbation parameters
uniform float edge_noise_amplitude : hint_range(0.0, 0.4) = 0.1;
uniform float edge_noise_frequency : hint_range(0.0, 50.0) = 10.0;
uniform float edge_noise_bias : hint_range(-0.5, 0.5) = 0.0;

varying float v_y;
varying vec3 v_normal;
varying vec3 v_vertex;
varying float v_scale_y;
varying vec3 v_world_pos;

void vertex() {
	v_y = VERTEX.y;
	v_normal = NORMAL;
	v_vertex = VERTEX;
	v_scale_y = length(MODEL_MATRIX[1].xyz);
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise1d(float x) {
	float i = floor(x);
	float f = fract(x);
	float a = hash(vec2(i, 0.0));
	float b = hash(vec2(i + 1.0, 0.0));
	return mix(a, b, smoothstep(0.0, 1.0, f));
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm2d(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise2d(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	// Organic world-space noise distortion to break the square grid
	vec2 noise_pos = v_world_pos.xz * top_noise_scale;
	float n_x = fbm2d(noise_pos);
	float n_z = fbm2d(noise_pos + vec2(31.7, 12.3));
	vec2 distortion = (vec2(n_x, n_z) - vec2(0.5)) * top_noise_strength;
	
	// Add subtle tiling noise to break up repetitions
	float noise = hash(v_world_pos.xz * 1.5) * texture_tiling_noise;
	
	// Top color from world-space coordinates for consistency and zero corner stretch
	vec2 top_uv = (v_world_pos.xz + distortion) * top_texture_scale + vec2(noise * 0.05);
	vec4 top_col = texture(top_texture, top_uv);
	
	// Multi-scale sampling to destroy visible tiling patterns
	vec4 top_col2 = texture(top_texture, top_uv * 2.7 + vec2(0.3, 0.7));
	float detail_blend = fbm2d(v_world_pos.xz * 0.08 + vec2(17.0, 43.0));
	top_col = mix(top_col, top_col2, 0.25 + detail_blend * 0.35);
	
	// Hexagonal distance for accurate edge effects (Normalized to 1.0 at edges)
	// Points are rotated 30 degrees to match Arena.gd mesh rotation
	vec2 p_hex = v_vertex.xz;
	float dist_h = max(abs(p_hex.y), abs(p_hex.y) * 0.5 + abs(p_hex.x) * 0.86602540) * 1.1547005;
	
	// Side mapping: Cylindrical mapping but with vertical scale from world space
	float angle = atan(v_vertex.x, v_vertex.z);
	
	// Edge noise for broken seam/overhang
	// Use multiple frequencies for more organic look
	float e_noise = noise1d(angle * edge_noise_frequency) * 0.7;
	e_noise += noise1d(angle * edge_noise_frequency * 2.1) * 0.2;
	e_noise += noise1d(angle * edge_noise_frequency * 0.47) * 0.1;
	e_noise = (e_noise - 0.5 + edge_noise_bias) * edge_noise_amplitude;
	
	// Top edge vignette (darkening)
	float top_vignette = smoothstep(1.0, 1.0 - top_edge_softness, dist_h + e_noise);
	vec3 top_final_rgb = top_col.rgb * mix(1.0 - top_edge_darkening, 1.0, top_vignette);
	
	vec2 side_uv = vec2(angle * 3.0 / 3.14159265, (v_vertex.y * v_scale_y) * side_scale * 0.5 + TIME * side_animation_speed);
	vec4 side_col = texture(side_texture, side_uv);
	
	vec2 overlay_uv = vec2(angle * 3.0 / 3.14159265, (v_vertex.y * v_scale_y) * side_scale * 0.5 + TIME * overlay_animation_speed);
	vec4 overlay_col = texture(overlay_texture, overlay_uv);
	side_col.rgb = mix(side_col.rgb, overlay_col.rgb, overlay_col.a);
	
	// --- BLENDING LOGIC ---
	float is_top = step(0.5, v_normal.y);
	
	// Wrap the top texture slightly over the side edge for a "rounded" feel
	float edge_blend_width = 0.15; // Increased blend width for more pronounced overhang
	float transition_blend = is_top;
	
	float edge_lip = 0.0;
	
	if (is_top < 0.5) {
		// Use noise to pull top texture down (overhang)
		float noisy_edge = 1.0 - (edge_blend_width + e_noise) / v_scale_y;
		float top_side_fade = smoothstep(noisy_edge, 1.0, v_y);
		transition_blend = top_side_fade;
		
		// Create a "lip" shadow right under the overhang
		edge_lip = smoothstep(noisy_edge - 0.05, noisy_edge, v_y) * (1.0 - top_side_fade);
	} else {
		// Even on top, pull side texture up slightly with noise
		float top_edge_noise = smoothstep(1.0, 1.0 - (edge_blend_width * 0.5), dist_h + e_noise);
		transition_blend = mix(0.7, 1.0, top_edge_noise);
	}
	
	vec3 final_albedo = mix(side_col.rgb, top_final_rgb, transition_blend) * albedo_color;
	
	// Darken the lip to make it look like a physical overhang/shadow
	final_albedo *= mix(1.0, 0.35, edge_lip * (top_edge_darkening + 0.5));
	
	// --- SHADING LOGIC ---
	float height_factor = clamp((v_y + 1.0) * 0.5, 0.0, 1.0);
	final_albedo *= mix(1.0 - height_darkening, 1.0, pow(height_factor, 0.5));
	
	// Improved Rim highlight / Bevel / Edge Shadow
	if (is_top < 0.5) {
		float shadow_factor = smoothstep(1.0 - (rim_size + e_noise) / v_scale_y, 1.0, v_y);
		final_albedo *= mix(1.0, 0.8, shadow_factor);
	}
	
	if (is_top > 0.5) {
		float edge_dist = smoothstep(1.0 - rim_size, 1.0, dist_h + e_noise);
		final_albedo = mix(final_albedo, final_albedo + rim_highlight * 0.5, edge_dist);
	}
	
	ALBEDO = final_albedo;
	ROUGHNESS = mix(0.8, 0.5, is_top);
}
