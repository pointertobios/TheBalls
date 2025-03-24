shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0);  // 控制渐变进度

void fragment() {
	vec4 color = texture(TEXTURE, UV);  // 获取纹理颜色

	// 计算透明度：从下到上渐变
	float alpha = step(1.0 - progress, UV.y);  // 使用 step 函数实现硬边缘渐变
	// 或者使用 smoothstep 实现平滑渐变：
	// float alpha = smoothstep(1.0 - progress - 0.1, 1.0 - progress + 0.1, UV.y);

	COLOR = vec4(color.rgb, color.a * alpha);  // 应用透明度
}


