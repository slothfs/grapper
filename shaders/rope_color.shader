shader_type canvas_item;

uniform vec4 rope_color : hint_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 sampled = texture(TEXTURE, UV);
    float alpha = sampled.a;
    if (alpha <= 0.0) {
        alpha = rope_color.a;
    }
    COLOR = vec4(rope_color.rgb, alpha * rope_color.a);
}
