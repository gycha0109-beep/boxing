shader_type canvas_item;

uniform float shine_intensity : hint_range(0.0, 1.5) = 0.0;
uniform vec4 shine_color : source_color = vec4(1.0, 0.82, 0.48, 1.0);

void fragment() {
    vec4 base = COLOR;
    float travel = fract(TIME * 0.075 + 0.12);
    float distance_to_band = abs(UV.x - travel);
    float band = exp(-pow(distance_to_band / 0.040, 2.0));
    float shoulder = exp(-pow((UV.x - travel) / 0.105, 2.0));
    float metal_mask = smoothstep(0.16, 0.48, dot(base.rgb, vec3(0.299, 0.587, 0.114)));
    float plate_focus = 0.72 + 0.28 * sin(UV.y * 18.0 + 0.5);
    float sweep = (band * 0.72 + shoulder * 0.16) * metal_mask * plate_focus;
    float ambient = (0.018 + 0.012 * sin(TIME * 0.55)) * metal_mask;
    base.rgb += shine_color.rgb * (sweep * shine_intensity + ambient);
    COLOR = base;
}