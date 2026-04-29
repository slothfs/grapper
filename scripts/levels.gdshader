shader_type canvas_item;

uniform float speed : hint_range(0.1, 10.0) = 3.5;
uniform float strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
    vec2 uv = UV;

    // Strong motion waves
    float wave_x = sin((uv.x * 18.0) + TIME * speed);
    float wave_y = cos((uv.y * 14.0) + TIME * speed * 1.3);

    float wave = (wave_x + wave_y) * 0.5;

    // MAIN COLOR (#000020) — dominant
    vec3 base_color = vec3(0.0, 0.0, 0.125);

    // VERY CLOSE shades (so base stays visible)
    vec3 shade1 = vec3(0.0, 0.0, 0.16);
    vec3 shade2 = vec3(0.05, 0.05, 0.22);

    // Smooth blend
    float t = wave * 0.5 + 0.5;
    vec3 animated = mix(shade1, shade2, t);

    // Mix but keep base dominant
    vec3 final_color = mix(base_color, animated, strength);

    COLOR = vec4(final_color, 1.0);
}