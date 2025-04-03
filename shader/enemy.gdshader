shader_type spatial;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec3 enemy_color : source_color = vec3(1.0, 1.0, 1.0);  // 基础颜色

// 新增受伤效果参数
uniform vec3 hit_color = vec3(1.0, 0.0, 0.0);  // 受伤红色
uniform float hit_blend = 0.0;  // 混合强度（0=无效果，1=完全红色）

void fragment() {
    // 混合基础颜色和受伤红色
    vec3 final_color = mix(enemy_color, hit_color, hit_blend);
    ALBEDO = final_color;
    ALPHA = alpha;
}
