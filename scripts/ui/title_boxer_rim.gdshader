shader_type canvas_item;

uniform float rim_strength : hint_range(0.0, 1.5) = 0.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.66, 0.28, 1.0);

void fragment() {
    vec4 base = COLOR;
    vec2 px = TEXTURE_PIXEL_SIZE;
    float texture_alpha = texture(TEXTURE, UV).a;
    float visibility = clamp(base.a / max(texture_alpha, 0.001), 0.0, 1.0);
    float a = base.a;
    float near_alpha = 0.0;
    near_alpha = max(near_alpha, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
    near_alpha = max(near_alpha, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
    near_alpha = max(near_alpha, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
    near_alpha = max(near_alpha, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
    near_alpha = max(near_alpha, texture(TEXTURE, UV + px).a);
    near_alpha = max(near_alpha, texture(TEXTURE, UV - px).a);
    float edge = max(near_alpha - a, 0.0) * (1.0 - a);
    float rim = edge * 0.94;
    float shoulder_focus = smoothstep(0.08, 0.38, UV.y) * (1.0 - smoothstep(0.80, 0.98, UV.y));
    float breathing = 0.90 + 0.10 * sin(TIME * 1.1);
    float glow = rim * rim_strength * shoulder_focus * breathing * visibility;
    vec3 lit = base.rgb + rim_color.rgb * glow * 0.72;
    float out_alpha = max(a, glow * rim_color.a * 0.52);
    COLOR = vec4(lit, out_alpha);
}