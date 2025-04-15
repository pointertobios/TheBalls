shader_type canvas_item;

uniform float u_strength : hint_range(0, 1) = 0;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // 基础扭曲
    uv.x += sin(uv.y * 30.0 + TIME * 10.0) * u_strength * 0.02;
    uv.y += cos(uv.x * 25.0 + TIME * 8.0) * u_strength * 0.015;
    
    // 轻微色散
    COLOR.r = texture(SCREEN_TEXTURE, uv).r;
    COLOR.g = texture(SCREEN_TEXTURE, uv * 0.995).g;
    COLOR.b = texture(SCREEN_TEXTURE, uv * 1.005).b;
    COLOR.a = 1.0;
}
