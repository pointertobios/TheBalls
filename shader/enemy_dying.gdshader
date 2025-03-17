shader_type spatial;

uniform vec4 base_color : source_color = vec4(0, 0, 0, 1.0); // 默认颜色
uniform float whiten_factor : hint_range(0.0, 1.0) = 0.0; // 变白系数
uniform float emission_intensity : hint_range(0.0, 10.0) = 1.0; // 发光强度

void fragment() {
    // 变白：混合颜色
    vec4 final_color = mix(base_color, vec4(1.0, 1.0, 1.0, 1.0), whiten_factor);

    // 输出颜色
    ALBEDO = final_color.rgb;

    // 发光：根据 whiten_factor 调整发光强度
    EMISSION = final_color.rgb * whiten_factor * emission_intensity;
}
