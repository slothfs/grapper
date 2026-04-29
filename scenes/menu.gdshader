shader_type canvas_item;

uniform float shake_strength : hint_range(0.0, 0.02) = 0.005;
uniform float glitch_strength : hint_range(0.0, 0.05) = 0.01;
uniform float speed = 2.0;

void fragment() {
    vec2 uv = UV;

    // Time
    float t = TIME * speed;

    // Smooth vertical bobbing (up/down)
    float bob = sin(t * 1.5) * 0.01;
    uv.y += bob;

    // Random glitch offset (horizontal jitter)
    float rand = fract(sin(dot(vec2(floor(t * 10.0), uv.y), vec2(12.9898,78.233))) * 43758.5453);
    float glitch = (rand - 0.5) * glitch_strength;

    // Apply glitch in small horizontal slices
    if (rand > 0.8) {
        uv.x += glitch;
    }

    // Small random shake (both axes)
    float shake_x = (fract(sin(t * 20.0) * 1000.0) - 0.5) * shake_strength;
    float shake_y = (fract(sin(t * 25.0) * 2000.0) - 0.5) * shake_strength;

    uv += vec2(shake_x, shake_y);

    COLOR = texture(TEXTURE, uv);
}