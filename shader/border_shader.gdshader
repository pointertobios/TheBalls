// border_shader.gdshader
shader_type canvas_item;

uniform vec4 border_color  = vec4(1.0, 1.0, 1.0, 1.0);  // 边框颜色
uniform float border_width : hint_range(0.0, 0.5) = 0.05;  // 边框宽度（相对于整体大小的比例）

void fragment() {
    // 计算 UV 坐标
    vec2 uv = UV;

    // 判断当前像素是否在边框范围内
    if (uv.x < border_width || uv.x > 1.0 - border_width || 
        uv.y < border_width || uv.y > 1.0 - border_width) {
        COLOR = border_color;  // 绘制边框
    } else {
        COLOR = vec4(0.0);  // 中间部分透明
    }
}

