shader_type spatial;

void vertex() {
	// Called for every vertex the material is visible on.
}
// Gamma 值（通常为 2.2）
uniform float gamma : hint_range(0.1, 5.0) = 2.2;
// Gamma 编码函数
vec3 gamma_encode(vec3 color) {
    return pow(color, vec3(1.0 / gamma));
}

uniform vec4 base_color : source_color = vec4(0.4, 0.77254, 0.53725, 1.0); // 默认颜色
uniform float darken_factor : hint_range(0.0, 1.0) = 0.0; // 变暗系数
uniform float red_factor : hint_range(0.0, 1.0) = 0.0; // 红色系数
uniform float reverse_red_factor : hint_range(0.0, 1.0) = 0.0; // 红色渐变回默认颜色的系数
void fragment() {
    vec4 dark_color = mix(base_color, vec4(0.0, 0.0, 0.0, 1.0), darken_factor);
    vec4 red_color = mix(dark_color, vec4(1.0, 0.0, 0.0, 1.0), red_factor);
	vec4 final_color = mix(red_color, base_color, reverse_red_factor);
    ALBEDO = gamma_encode(final_color.rgb);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
