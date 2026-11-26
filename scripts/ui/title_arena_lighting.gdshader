shader_type canvas_item;

uniform float light_intensity : hint_range(0.0, 1.5) = 0.0;
uniform vec4 beam_tint : source_color = vec4(0.72, 0.80, 0.94, 1.0);

float beam(vec2 uv, float origin_x, float drift, float width) {
    float axis = origin_x + (uv.y - 0.04) * drift;
    float spread = mix(width * 0.45, width, uv.y);
    float core = 1.0 - smoothstep(spread, spread + 0.085, abs(uv.x - axis));
    return core * smoothstep(0.02, 0.20, uv.y) * (1.0 - smoothstep(0.68, 0.96, uv.y));
}

void fragment() {
    vec4 base = COLOR;
    float left_beam = beam(UV, 0.20 + sin(TIME * 0.19) * 0.018, 0.20, 0.045);
    float right_beam = beam(UV, 0.80 + sin(TIME * 0.16 + 1.8) * 0.016, -0.18, 0.040);
    float center_beam = beam(UV, 0.51 + sin(TIME * 0.11 + 0.8) * 0.012, 0.025, 0.025) * 0.48;
    vec2 left_delta = (UV - vec2(0.23, 0.70)) * vec2(2.1, 1.5);
    vec2 right_delta = (UV - vec2(0.77, 0.70)) * vec2(2.1, 1.5);
    float pools = exp(-dot(left_delta, left_delta) * 5.0) + exp(-dot(right_delta, right_delta) * 5.0);
    float flicker = 0.96 + 0.04 * sin(TIME * 2.1);
    float light = (left_beam * 0.34 + right_beam * 0.31 + center_beam * 0.20 + pools * 0.10) * flicker;
    base.rgb += beam_tint.rgb * light * light_intensity;
    COLOR = base;
}