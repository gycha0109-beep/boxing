shader_type canvas_item;

uniform float label_height = 1.0;
varying float height_ratio;

void vertex() {
    height_ratio = VERTEX.y / max(label_height, 1.0);
}

void fragment() {
    vec3 silver = vec3(0.99, 0.98, 0.95);
    vec3 bronze = vec3(0.57, 0.48, 0.33);
    float upper = smoothstep(0.31, 0.52, height_ratio) * (1.0 - smoothstep(0.54, 0.61, height_ratio));
    float taper = smoothstep(0.49, 0.83, height_ratio) * 0.87;
    vec3 metal = mix(silver, bronze, taper) * (1.0 - upper * 0.17);
    float face = smoothstep(0.23, 0.87, COLOR.r);
    COLOR.rgb = mix(COLOR.rgb, metal, face);
}
