shader_type canvas_item;

uniform vec2 portrait_size = vec2(1.0);
uniform bool mirror_fade = false;
uniform bool fade_outer = false;
uniform float spotlight : hint_range(0.0, 1.0) = 0.5;
varying vec2 position_in_portrait;

void vertex() {
    position_in_portrait = VERTEX / max(portrait_size, vec2(1.0));
}

void fragment() {
    vec4 portrait = COLOR;
    vec2 p = position_in_portrait;
    float x = mirror_fade ? 1.0 - p.x : p.x;
    float edge = 1.0 - smoothstep(0.71, 1.0, x);
    if (fade_outer) {
        edge *= smoothstep(0.0, 0.15, x);
    }
    float top = smoothstep(0.0, 0.12, p.y);
    float bottom = 1.0 - smoothstep(0.78, 1.0, p.y);
    float luminance = dot(portrait.rgb, vec3(0.299, 0.587, 0.114));
    vec3 shadow = mix(vec3(luminance) * vec3(0.78, 0.85, 0.96), portrait.rgb, 0.58) * 0.78;
    vec3 lit = portrait.rgb * vec3(1.14, 1.035, 0.92);
    COLOR = vec4(mix(shadow, lit, spotlight), portrait.a * top * bottom * edge);
}
