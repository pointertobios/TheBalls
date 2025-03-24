// skill_icon_shader.gdshader
shader_type canvas_item;

uniform float progress : hint_range(0, 1) = 1.0;  // 冷却进度（0.0 为完全冷却，1.0 为可用）
uniform vec4 gray_color = vec4(0.5, 0.5, 0.5, 0.5);  // 灰色颜色

void fragment() {
    vec4 color = texture(TEXTURE, UV);  // 获取原始颜色
    float mask = step(UV.y, progress);  // 根据 UV.y 和 progress 创建遮罩
    COLOR = mix(gray_color, color, mask);  // 混合灰色和原始颜色
}