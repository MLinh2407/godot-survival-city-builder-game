shader_type canvas_item;

uniform float blur_radius = 1.6;
uniform vec4 tint : source_color = vec4(0.55, 0.88, 1.0, 0.9);

void fragment() {
    vec2 t = TEXTURE_PIXEL_SIZE * blur_radius;
    float a = 0.0;
    a += texture(TEXTURE, UV).a * 0.24;
    a += texture(TEXTURE, UV + vec2(t.x, 0.0)).a * 0.12;
    a += texture(TEXTURE, UV + vec2(-t.x, 0.0)).a * 0.12;
    a += texture(TEXTURE, UV + vec2(0.0, t.y)).a * 0.12;
    a += texture(TEXTURE, UV + vec2(0.0, -t.y)).a * 0.12;
    a += texture(TEXTURE, UV + vec2(t.x, t.y)).a * 0.07;
    a += texture(TEXTURE, UV + vec2(-t.x, t.y)).a * 0.07;
    a += texture(TEXTURE, UV + vec2(t.x, -t.y)).a * 0.07;
    a += texture(TEXTURE, UV + vec2(-t.x, -t.y)).a * 0.07;
    COLOR = vec4(tint.rgb, tint.a * a);
}