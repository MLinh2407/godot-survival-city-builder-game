shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec4 outline_color : source_color = vec4(0.65, 0.96, 1.0, 1.0);
uniform float outline_size : hint_range(0.0, 6.0) = 1.25;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float a = base.a;

	vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_size;
	float edge = 0.0;
	edge = max(edge, texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(-step_uv.x, 0.0)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(0.0, -step_uv.y)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(step_uv.x, step_uv.y)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(-step_uv.x, -step_uv.y)).a);

	float outline = step(0.01, edge) * (1.0 - step(0.01, a)) * outline_strength;
	vec4 out_color = base;
	if (outline > 0.0) {
		out_color = vec4(outline_color.rgb * outline_color.a, outline_color.a * outline);
	}

	COLOR = out_color;
}