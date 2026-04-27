shader_type canvas_item;

uniform vec3 ground_color : hint_color = vec3(0.11, 0.06, 0.04);
uniform vec3 horizon_color : hint_color = vec3(0.85, 0.42, 0.26);
uniform vec3 twilight_color : hint_color = vec3(0.5, 0.2, 0.55);
uniform vec3 space_color : hint_color = vec3(0.02, 0.04, 0.18);
uniform float cosmic_speed : hint_range(0.05, 1.0) = 0.22;
uniform float star_intensity : hint_range(0.0, 1.0) = 0.35;

float pseudo_rand(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    float anim = TIME * cosmic_speed;
    float wave = sin((uv.x * 5.0 + anim)) * 0.02;
    float vertical = clamp(uv.y + wave + sin(uv.x * 2.0 + anim * 0.6) * 0.015, 0.0, 1.0);

    float horizon_layer = smoothstep(0.15, 0.45, vertical);
    float twilight_layer = smoothstep(0.4, 0.75, vertical);
    float space_layer = smoothstep(0.7, 1.0, vertical);

    vec3 color = mix(ground_color, horizon_color, horizon_layer);
    color = mix(color, twilight_color, twilight_layer);
    color = mix(color, space_color, space_layer);

    float haze = sin((uv.y + anim * 0.3) * 3.6 + uv.x * 1.5) * 0.1 + 0.15;
    color += haze * vec3(0.5, 0.28, 0.6) * (1.0 - vertical) * 0.2;
    color += haze * vec3(0.15, 0.2, 0.35) * vertical * 0.15;

    float star_noise = pseudo_rand(vec2(uv.x * 300.0, uv.y * 300.0 + anim * 40.0));
    float star_mask = smoothstep(0.995, 1.0, star_noise + sin(anim * 0.8) * 0.03);
    vec3 stars = vec3(1.0, 0.9, 0.7) * star_mask * (1.0 - vertical) * star_intensity;
    color += stars;

    COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
