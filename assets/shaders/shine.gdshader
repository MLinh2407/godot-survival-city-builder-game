shader_type canvas_item;
render_mode blend_premul_alpha;

// Visual controls
uniform float Angle_deg : hint_range(-90.0, 90.0) = 30.0;
uniform float Brightness : hint_range(0.0, 5.0) = 2.5;
uniform float Band_Soft : hint_range(0.0, 0.3) = 0.06;

// Staging controls
uniform int Stage_Count : hint_range(1, 3) = 2;
uniform float Stage1_Duration : hint_range(0.01, 10.0) = 1.0;
uniform float Stage2_Duration : hint_range(0.01, 10.0) = 1.5;
uniform float Stage3_Duration : hint_range(0.01, 10.0) = 1.0;
uniform float Stage1_Width : hint_range(0.0, 0.5) = 0.12;
uniform float Stage2_Width : hint_range(0.0, 0.5) = 0.12;
uniform float Stage3_Width : hint_range(0.0, 0.5) = 0.12;
uniform bool Stage1_LeftToRight = true;
uniform bool Stage2_LeftToRight = false;
uniform bool Stage3_LeftToRight = true;

// Animation mode
uniform bool One_Shot = false;
uniform float OneShot_Delay : hint_range(0.0, 10.0) = 0.0;
uniform float Phase_Offset : hint_range(0.0, 1.0) = 0.0;

// Angle wiggle
uniform bool Wiggle_Angle = false;
uniform float Wiggle_Amount_deg : hint_range(0.0, 45.0) = 15.0;

// Pause between shines
uniform float Shine_Pause : hint_range(0.0, 10.0) = 0.4;

vec2 rotate_uv(vec2 uv, vec2 center, float deg) {
    float a = radians(deg);
    mat2 r = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
    return r * (uv - center) + center;
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);

    int N = clamp(Stage_Count, 1, 3);
    float T1 = max(1e-4, Stage1_Duration);
    float T2 = (N >= 2) ? max(1e-4, Stage2_Duration) : 0.0;
    float T3 = (N >= 3) ? max(1e-4, Stage3_Duration) : 0.0;

    float P = max(0.0, Shine_Pause);
    float pause_count = One_Shot ? float(N - 1) : float(N);
    float Ttotal = max(T1 + T2 + T3 + P * pause_count, 1e-4);

    float t01;
    if (One_Shot) {
        float t = max(0.0, TIME - OneShot_Delay);
        t01 = clamp(t / Ttotal, 0.0, 1.0);
    } else {
        t01 = fract(Phase_Offset + TIME / Ttotal);
    }
    float tsec = t01 * Ttotal;
    bool finished_one_shot = (One_Shot && t01 >= 1.0);

    float s1_start = 0.0;
    float s1_end = s1_start + T1;
    float p1_end = s1_end + ((P > 0.0) ? P : 0.0);
    float s2_start = (N >= 2) ? p1_end : 0.0;
    float s2_end = (N >= 2) ? (s2_start + T2) : 0.0;
    float p2_end = (N >= 2) ? (s2_end + ((P > 0.0) ? P : 0.0)) : 0.0;
    float s3_start = (N >= 3) ? p2_end : 0.0;
    float s3_end = (N >= 3) ? (s3_start + T3) : 0.0;

    int stage = 0;
    float t_local = 0.0;
    float T_stage = 1.0;

    if (tsec >= s1_start && tsec < s1_end) {
        stage = 1; T_stage = T1; t_local = tsec - s1_start;
    } else if (N >= 2 && tsec >= s2_start && tsec < s2_end) {
        stage = 2; T_stage = T2; t_local = tsec - s2_start;
    } else if (N >= 3 && tsec >= s3_start && tsec < s3_end) {
        stage = 3; T_stage = T3; t_local = tsec - s3_start;
    }

    if (finished_one_shot || stage == 0) {
        COLOR = vec4(base.rgb * base.a, base.a);
    } else {
        float p = clamp(t_local / T_stage, 0.0, 1.0);
        float angle_eff_deg = Angle_deg;
        if (Wiggle_Angle) {
            float wig = sin(3.14159265 * (2.0 * p - 1.0));
            angle_eff_deg += Wiggle_Amount_deg * wig;
        }

        float a = radians(angle_eff_deg);
        vec2 ruv = rotate_uv(UV, vec2(0.5), angle_eff_deg);

        float c = abs(cos(a));
        float s = abs(sin(a));
        float min_x = 0.5 - 0.5 * (c + s);
        float max_x = 0.5 + 0.5 * (c + s);

        float width = Stage1_Width;
        bool dir_now = Stage1_LeftToRight;
        if (stage == 2) { width = Stage2_Width; dir_now = Stage2_LeftToRight; }
        else if (stage == 3) { width = Stage3_Width; dir_now = Stage3_LeftToRight; }

        float half_w = max(width * 0.5, 1e-4);
        float soft_raw = Band_Soft;
        float soft = max(Band_Soft, 1e-5);
        float pad = half_w + soft;

        float start_x = min_x - pad;
        float end_x = max_x + pad;
        float center = dir_now ? mix(start_x, end_x, p) : mix(end_x, start_x, p);
        float d = abs(ruv.x - center);

        float band = (soft_raw <= 0.0) ? step(d, half_w) : (1.0 - smoothstep(half_w, half_w + soft, d));
        band *= base.a;

        vec3 lit_rgb = base.rgb + vec3(1.0) * (band * Brightness);
        float out_a = base.a;
        vec3 out_rgb = lit_rgb * out_a;
        COLOR = vec4(out_rgb, out_a);
    }
}