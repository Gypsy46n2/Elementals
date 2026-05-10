shader_type spatial;

// === TEXTURE CONTROLS ===
uniform sampler2D leaf_texture : source_color, filter_nearest_mipmap;
uniform float texture_repeat : hint_range(0.1, 10.0) = 1.0;

// === ALPHA CUTOUT CONTROLS ===
// Alpha threshold for the leaf shape (higher = more cutout, thinner leaves)
uniform float cutout_threshold : hint_range(0.0, 1.0) = 0.4;
// Edge softness for the cutout (slightly softer to avoid harsh pixel edges)
uniform float cutout_softness : hint_range(0.0, 0.3) = 0.05;

// === COLOR CONTROLS ===
uniform vec3 albedo_color : source_color = vec3(0.2, 0.6, 0.1);
uniform float color_variation : hint_range(0.0, 1.0) = 0.15;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;

// === WIND CONTROLS ===
// Overall wind strength
uniform float wind_strength : hint_range(0.0, 2.0) = 0.3;
// Wind speed multiplier
uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
// How much leaves sway independently (per-instance variation)
uniform float wind_turbulence : hint_range(0.0, 3.0) = 1.0;
// Primary wind direction (normalized)
uniform vec2 wind_direction : hint_range(-1.0, 1.0) = vec2(1.0, 0.0);

// === SUBSURFACE APPROXIMATION ===
// Backlight glow when looking toward light through leaves
uniform float sss_strength : hint_range(0.0, 1.0) = 0.2;
uniform vec3 sss_color : source_color = vec3(0.6, 0.9, 0.3);

// === RIM/BACKLIGHT ===
uniform float rim_strength : hint_range(0.0, 1.0) = 0.3;
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;

varying vec2 v_uv;
varying vec3 v_normal;
varying vec3 v_world_pos;
varying float v_instance_seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

vec2 hash2(vec2 p) {
	return vec2(
		fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453),
		fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453)
	);
}

// Simple smooth noise for wind
float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal brownian motion for more natural wind
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		value += amplitude * smooth_noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	v_uv = UV * texture_repeat;
	v_normal = NORMAL;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Instance seed for variation
	v_instance_seed = hash2(vec2(float(INSTANCE_ID), 0.0)).x;
	
	// === WIND ANIMATION ===
	// Height-based sway (leaves at top sway more)
	float height_factor = (VERTEX.y + 1.0) * 0.5;
	
	// Time with per-instance offset for variation
	float wind_time = TIME * wind_speed + v_instance_seed * 10.0;
	
	// Multi-frequency wind
	vec2 wind_dir = normalize(wind_direction);
	
	// Primary sway (slow, large movement)
	float primary_sway = sin(wind_time * 1.0 + v_world_pos.x * 0.5 + v_world_pos.z * 0.3) * 0.5 + 0.5;
	
	// Secondary flutter (faster, smaller)
	float flutter = sin(wind_time * 3.0 + v_world_pos.x * 2.0) * 0.3;
	
	// Turbulence from FBM
	float turbulence = fbm(v_world_pos.xz * 0.3 + wind_time * 0.5);
	turbulence = turbulence * 2.0 - 1.0;
	
	// Combine for final sway amount
	float sway_amount = primary_sway + flutter * 0.5 + turbulence * wind_turbulence;
	sway_amount *= wind_strength * height_factor;
	
	// Apply sway in world space, offsetting X and Z based on normal
	// This creates a natural bending motion
	VERTEX.x += wind_dir.x * sway_amount;
	VERTEX.z += wind_dir.y * sway_amount;
	
	// Slight upward arc during sway (leaves lift slightly when bending)
	VERTEX.y += abs(sway_amount) * 0.2;
	
	// Update world position for fragment calculations
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Sample leaf texture
	vec4 tex_col = texture(leaf_texture, v_uv);
	
	// Alpha cutout with softness
	float alpha = smoothstep(cutout_threshold - cutout_softness, cutout_threshold + cutout_softness, tex_col.a);
	
	// Discard fully transparent pixels
	if (alpha < 0.01) {
		discard;
	}
	
	// Color variation based on world position and instance
	float color_var = hash3(vec3(v_world_pos * 0.5 + v_instance_seed));
	vec3 var_albedo = albedo_color * mix(0.8, 1.2, color_var * color_variation * 2.0);
	
	// Apply base texture color
	vec3 final_albedo = tex_col.rgb * var_albedo;
	
	// Darken based on uniform
	final_albedo *= 1.0 - darkness;
	
	// === SIMPLE DIFFUSE ===
	vec3 light_dir = normalize(vec3(1.0, 1.0, 0.5));
	float NdotL = max(dot(v_normal, light_dir), 0.0);
	float diffuse = 0.5 + NdotL * 0.5; // Half-lambert for softer look
	
	// === SUBSURFACE SCATTERING APPROXIMATION ===
	// When light is behind the leaf (opposite of view), add glow
	float backlight = max(dot(v_normal, -light_dir), 0.0);
	float sss = pow(backlight, 2.0) * sss_strength;
	
	// Blend SSS color based on how thick the leaf appears at this point
	float thickness = 1.0 - tex_col.a * 0.5;
	vec3 sss_contribution = sss_color * sss * thickness;
	
	// === RIM LIGHT (backlight rim) ===
	// Creates a glowing edge effect when backlit
	float view_normal_dot = max(dot(normalize(-v_normal), vec3(0.0, 0.0, 1.0)), 0.0);
	float rim = pow(1.0 - view_normal_dot, rim_power) * backlight * rim_strength;
	
	// === COMBINE ===
	vec3 lit_color = final_albedo * diffuse;
	lit_color += sss_contribution;
	lit_color += final_albedo * rim * sss_color;
	
	ALBEDO = lit_color;
	
	// Slightly darker, less rough on top-facing areas
	ROUGHNESS = mix(0.8, 0.5, abs(v_normal.y));
	
	// Transparency for rendering order
	ALPHA = alpha;
}

// Optional: use this in the light() function for proper PBR lighting
// void light() {
//     DIFFUSE_LIGHT += albedo * clamp(dot(NORMAL, LIGHT_DIR), 0.0, 1.0) * ATTENUATION;
// }