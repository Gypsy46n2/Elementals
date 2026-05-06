shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform vec4 color : source_color = vec4(1.0, 0.2, 0.2, 0.6);
uniform float angle_degrees : hint_range(0.0, 360.0) = 90.0;

void fragment() {
    // Center is (0.5, 0.5)
    vec2 pos = UV - vec2(0.5);
    float dist = length(pos);
    
    // Outer circle
    if (dist > 0.5) discard;
    
    // Angle check (pointing towards +Y in UV space which is "down" in 2D, but +Z in local space)
    float phi = degrees(atan(pos.x, pos.y)); 
    if (abs(phi) > angle_degrees / 2.0) discard;
    
    ALBEDO = color.rgb;
    // Fade out at edges and center for a nicer look
    float edge_fade = smoothstep(0.5, 0.4, dist);
    float center_fade = smoothstep(0.0, 0.1, dist);
    ALPHA = color.a * edge_fade * center_fade;
}
