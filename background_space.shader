shader_type canvas_item;

const float PI = 3.14159265;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    float ab = mix(a, b, u.x);
    float cd = mix(c, d, u.x);
    return mix(ab, cd, u.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.6;
    float frequency = 1.0;
    for (int i = 0; i < 4; ++i) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

uniform vec3 ground_color : hint_color = vec3(0.176, 0.067, 0.019);
uniform vec3 twilight_color : hint_color = vec3(0.58, 0.313, 0.337);
uniform vec3 space_color : hint_color = vec3(0.035, 0.051, 0.185);
uniform vec3 aurora_color : hint_color = vec3(0.733, 0.349, 0.954);
uniform vec3 star_color : hint_color = vec3(0.94, 0.85, 0.7);
uniform float time_speed = 0.08;
uniform float aurora_strength = 0.35;

void fragment() {
    vec2 uv = UV;
    float height = clamp(pow(uv.y, 0.9), 0.0, 1.0);

    float warm_mid = smoothstep(0.0, 0.3, height);
    vec3 gradient = mix(ground_color, twilight_color, warm_mid);
    gradient = mix(gradient, space_color, smoothstep(0.35, 1.0, height));

    vec2 drift = uv * vec2(2.25, 0.65) + vec2(TIME * time_speed, TIME * time_speed * 0.6);
    float aurora = fbm(drift);
    float aurora_mask = smoothstep(0.18, 0.7, height) * (1.0 - smoothstep(0.6, 1.0, height));
    gradient += aurora_color * aurora * aurora_mask * aurora_strength;

    float star_noise = noise(uv * 70.0 + vec2(TIME * 0.4, 0.0));
    float stars = smoothstep(0.93, 1.0, star_noise);
    float twinkle = smoothstep(0.85, 1.0, noise(uv * 140.0 + vec2(0.0, TIME * 0.7)));
    gradient += star_color * stars * twinkle * pow(height, 1.4) * 0.6;

    float shimmer = sin((uv.x + TIME * 0.4) * PI * 1.4) * 0.02;
    gradient += vec3(shimmer) * (1.0 - height) * 0.25;

    vec3 result = clamp(gradient, 0.0, 1.0);
    COLOR = vec4(result, 1.0);
}
