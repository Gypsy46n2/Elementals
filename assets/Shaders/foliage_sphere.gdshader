shader_type spatial;
render_mode blend_premul_alpha, depth_draw_always;

// === COLOR CONTROLS ===
uniform vec3 foliage_color : source_color = vec3(0.2, 0.55, 0.15);
uniform float brightness : hint_range(0.3, 1.5) = 1.0;
uniform float color_variation : hint_range(0.0, 0.5) = 0.1;

// === LIGHTING CONTROLS ===
// Ambient light multiplier
uniform float ambient : hint_range(0.0, 1.0) = 0.4;
// Subsurface scattering strength (backlight glow)
uniform float sss_strength : hint_range(0.0, 1.0) = 0.35;
// SSS color (typically a slightly lighter/warmer green)
uniform vec3 sss_color : source_color = vec3(0.5, 0.85, 0.25);
// Rim light when backlit
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;

// === NOISE FOR VARIATION ===
float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

// === TRANSPARENCY CONTROLS ===
// Cutout threshold (0 = fully solid, 1 = mostly empty)
uniform float cutout_threshold : hint_range(0.0, 1.0) = 0.3;
// Noise scale for cutout pattern
uniform float cutout_scale : hint_range(1.0, 20.0) = 8.0;
// Size of leaf/foliage clusters. Higher = larger, fewer individual pieces
uniform float leaf_size : hint_range(0.5, 4.0) = 1.0;
// Current opacity for visibility transparency (0.0 = fully transparent, 1.0 = fully opaque)
uniform float current_opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// === SEED GENERATION ===
	// Use world position for variation (INSTANCE_ID not available for CSG nodes)
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float seed = fract(sin(dot(world_pos, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
	float seed2 = fract(sin(dot(world_pos, vec3(39.346, 11.135, 83.155))) * 12345.6789);
	
	// === CUTOUT ALPHA ===
	// Generate noise-based alpha for leaf-like transparency
	// Scale noise frequency by 1/leaf_size so higher values = larger foliage patches
	float noise_freq = cutout_scale / max(leaf_size, 0.1);
	float alpha_noise = hash3(normalize(NORMAL) * noise_freq + vec3(seed * 0.5, seed2, seed));
	
	// Scale alpha based on noise (1.0 at solid, lower at cutout areas)
	// Note: Not using discard so transparency blending works properly
	float base_alpha = smoothstep(cutout_threshold, cutout_threshold + 0.15, alpha_noise);
	
	// Apply visibility transparency from VisibilityManager
	ALPHA = base_alpha * current_opacity;
	
	// === COLOR VARIATION ===
	// Generate per-sphere and per-fragment variation
	float instance_seed = hash(seed);
	float variation = hash3(normalize(NORMAL) + vec3(seed2 * 0.1));
	
	// Color varies slightly per instance
	vec3 varied_color = foliage_color * mix(0.85, 1.15, instance_seed);
	
	// Add subtle fragment-level variation for organic look
	varied_color *= mix(0.9, 1.1, variation * color_variation * 2.0);
	
	// Apply brightness
	varied_color *= brightness;
	
	// === LIGHTING ===
	
	// Light direction (main sun)
	vec3 light_dir = normalize(vec3(0.5, 1.0, 0.3));
	vec3 view_dir = normalize(VIEW);
	
	// Standard diffuse (half-lambert for softer look)
	float NdotL = dot(NORMAL, light_dir);
	float diffuse = 0.5 + NdotL * 0.5;
	diffuse = max(diffuse, ambient); // Ensure minimum ambient
	
	// === SUBSURFACE SCATTERING APPROXIMATION ===
	// When light comes from behind relative to view, leaves glow
	float backlight = max(dot(NORMAL, -light_dir), 0.0);
	
	// SSS intensity based on backlight (light passing through leaf)
	float sss = pow(backlight, 2.0) * sss_strength;
	
	// Thin areas (edges of sphere) scatter more
	float edge_thinness = 1.0 - abs(dot(NORMAL, view_dir));
	sss *= mix(0.5, 1.0, edge_thinness);
	
	// === RIM LIGHT ===
	// Edge glow when looking toward light source
	float rim = pow(1.0 - max(dot(NORMAL, view_dir), 0.0), rim_power);
	rim *= backlight * rim_strength; // Only visible when backlit
	
	// === COMBINE ===
	vec3 final_color = varied_color * diffuse;
	
	// Add SSS contribution (light passing through)
	final_color += sss_color * sss * varied_color;
	
	// Add rim light
	final_color += sss_color * rim * varied_color * 0.5;
	
	// Slight darkening on very back-facing areas for depth
	float back_shade = 1.0 - pow(backlight, 3.0) * 0.2;
	final_color *= back_shade;
	
	ALBEDO = final_color;
	
	// Roughness varies slightly for organic feel
	float roughness_var = hash(seed2) * 0.2;
	ROUGHNESS = clamp(0.7 + roughness_var - edge_thinness * 0.2, 0.5, 0.95);
	
	// Subtle specular for wet/healthy look
	METALLIC = 0.0;
	SPECULAR = 0.5;
}