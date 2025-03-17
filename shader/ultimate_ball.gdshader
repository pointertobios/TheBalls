shader_type spatial;

void vertex() {
	// Called for every vertex the material is visible on.
}

// 基础颜色
uniform vec4 albedo_color : source_color = vec4(0.0, 1.0, 1.0, 1.0); // 默认颜色为青色
uniform float alpha : hint_range(0.0, 1.0) = 1.0; // 透明度

// 发光效果
uniform bool emission_enabled = false; // 是否启用发光
uniform vec4 emission_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // 发光颜色

void fragment() {
    // 设置基础颜色和透明度
    ALBEDO = albedo_color.rgb;
    ALPHA = alpha;

    // 发光效果
    if (emission_enabled) {
        EMISSION = emission_color.rgb; // 设置发光颜色
    } else {
        EMISSION = vec3(0.0); // 关闭发光
    }
}
