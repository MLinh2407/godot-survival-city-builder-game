shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_size : hint_range(0.0, 4.0) = 1.0;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.85;
uniform float text_lum_thresh : hint_range(0.0, 1.0) = 0.25;

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    float a = base.a;

    float lum = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
    float is_text = step(lum, text_lum_thresh) * step(0.01, a);

    vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_size;
    float neighbor_count = 0.0;

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            if (x == 0 && y == 0) { continue; }
            vec2 off = UV + vec2(float(x) * step_uv.x, float(y) * step_uv.y);
            vec4 s = texture(TEXTURE, off);
            float s_lum = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));
            float s_is_text = step(s_lum, text_lum_thresh) * step(0.01, s.a);
            neighbor_count += s_is_text;
        }
    }

    float outline_mask = step(0.5, neighbor_count) * (1.0 - is_text);
    float outline = outline_mask * outline_strength;

    if (outline > 0.0) {
        COLOR = vec4(outline_color.rgb, outline_color.a * outline);
    } else {
        COLOR = vec4(0.0);
    }
}
