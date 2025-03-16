shader_type spatial;

void vertex() {
	// Called for every vertex the material is visible on.
	//COLOR.rgb = vec3(0, 255, 255); // 使用 UV 坐标作为颜
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec3 mixed_color = mix(COLOR.rgb, vec3(0,255,255), 0.5);
	ALBEDO = mixed_color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
