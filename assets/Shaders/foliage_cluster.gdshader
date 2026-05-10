shader_type spatial;

// === TEXTURE CONTROLS ===
uniform sampler2D foliage_texture : source_color, filter_nearest_mipmap;
uniform float texture_repeat : hint_range(0.1, 10.0) = 2.0;

// === ALPHA CONTROLS ===
// Soft alpha for semi-transparent foliage clusters
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.2;

// === COLOR CONTROLS ===
uniform vec3 color_tint : source_color = vec3(0.3, 0.7, 0.15);
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;

// === DENSITY CONTROLS ===
// Randomize visibility to create density variation
uniform float density : hint_range(0.0, 1.0) = 0.85;
// Size of density patches
uniform float density_scale : hint_range(1.0, 20.0) = 8.0;

// === WIND CONTROLS ===
// How much the entire bush/grass sways
uniform float sway_strength : hint_range(0.0, 1.0) = 0.15;
// Speed of swaying
uniform float sway_speed : hint_range(0.0, 3.0) = 0.8;
// Direction of primary sway
uniform vec2 sway_direction : hint_range(-1.0, 1.0) = vec2(1.0, 0.3);
// Secondary flutter intensity
uniform float flutter : hint_range(0.0, 1.0) = 0.5;

varying vec2 v_uv;
varying vec3 v_world_pos;
varying vec3 v_normal;
varying float v_height;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	v_uv = UV * texture_repeat;
	v_normal = NORMAL;
	v_height = (VERTEX.y + 1.0) * 0.5;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// === GENTLE WIND SWAY ===
	vec2 wind_dir = normalize(sway_direction);
	float time = TIME * sway_speed;
	
	// Height-based sway (top moves more)
	float height_sway = v_height * v_height;
	
	// Primary sway
	float primary = sin(time + v_world_pos.x * 0.8 + v_world_pos.z * 0.6) * 0.5 + 0.5;
	
	// Secondary flutter (faster)
	float secondary = sin(time * 3.0 + v_world_pos.x * 2.5) * flutter;
	
	// Combine
	float sway = (primary + secondary) * sway_strength * height_sway;
	
	// Apply in XZ based on normal (sways in wind direction + perpendicular)
	vec3 sway_offset = vec3(
		wind_dir.x * sway,
		sway * sway * 0.3, // Slight upward arc
		wind_dir.y * sway
	);
	
	VERTEX += sway_offset;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Sample base texture
	vec4 tex = texture(foliage_texture, v_uv);
	
	// === DENSITY MASK ===
	// Create patchy density using noise
	float density_noise = noise2d(v_world_pos.xz * 0.3 + v_world_pos.y * 0.5);
	float density_mask = step(1.0 - density, density_noise);
	
	// Instance-based variation
	float instance_var = hash(vec2(float(INSTANCE_ID), 0.0));
	density_mask *= step(1.0 - density * 0.3, instance_var);
	
	if (density_mask < 0.5) {
		discard;
	}
	
	// === COLOR PROCESSING ===
	vec3 color = tex.rgb * color_tint * brightness;
	
	// Saturation adjustment
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(gray), color, saturation);
	
	// Slight variation per-fragment
	float variation = hash3(v_world_pos * 0.3);
	color *= mix(0.85, 1.15, variation);
	
	// === SIMPLE LIGHTING ===
	// Up-facing areas are slightly lighter
	float up_light = mix(0.7, 1.0, v_normal.y * 0.5 + 0.5);
	
	// Rim lighting from backlight
	vec3 light_dir = normalize(vec3(1.0, 0.5, 0.5));
	float backlight = max(dot(v_normal, -light_dir), 0.0);
	float rim = pow(backlight, 2.0) * 0.2;
	
	ALBEDO = color * up_light + color * rim * 0.3;
	ROUGHNESS = mix(0.9, 0.6, v_normal.y * 0.5 + 0.5);
	ALPHA = tex.a * alpha * density_mask;
}

// === ALTERNATIVE: Simple grass ground cover shader ===
// For flat grass planes, use this simpler version:
// 
// shader_type spatial;
// uniform sampler2D grass_texture : source_color;
// uniform float wind_strength = 0.1;
// uniform float wind_speed = 1.0;
// uniform vec2 wind_dir = vec2(1.0, 0.0);
// 
// void fragment() {
//     vec2 wind_offset = wind_dir * sin(TIME * wind_speed + UV.x * 10.0) * wind_strength;
//     vec2 uv = UV + wind_offset * UV.y;
//     ALBEDO = texture(grass_texture, uv).rgb;
// }