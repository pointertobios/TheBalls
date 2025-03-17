# Ground.gd
extends MeshInstance3D

class_name Ground

@export var darken_speed: float = 2.5  # 渐变速度（1 / 0.4 秒）
var tween: Tween

func _ready():
	# 加载 Shader 脚本
	var shader = load("res://shader/board.gdshader")
	
	# 创建 ShaderMaterial
	var material = ShaderMaterial.new()
	material.shader = shader
	
	# 应用到地面节点
	material_override = material

# 渐变到黑色
func darken():
	for i in range(24):
		await get_tree().create_timer(0.016).timeout
		(material_override as ShaderMaterial).set_shader_parameter("darken_factor", float(i + 1) / 24)
		#print((material_override as ShaderMaterial).get_shader_parameter("darken_factor"))
		
	#var tween = self.create_tween()
	#tween.tween_property(material_override, "shader_param/darken_factor", 1.0, 1.0 / darken_speed)
# 渐变回原色
func lighten():
	for i in range(24):
		await get_tree().create_timer(0.016).timeout
		(material_override as ShaderMaterial).set_shader_parameter("darken_factor", 1.0 - float(i + 1) / 24)
		(material_override as ShaderMaterial).set_shader_parameter("reverse_red_factor", float(i + 1) / 24)  # 新增：渐变回默认颜色


# 设置红色系数
func set_red_factor(factor: float) -> void:
	(material_override as ShaderMaterial).set_shader_parameter("red_factor", factor)

func reset_shader_parameters() -> void:
	(material_override as ShaderMaterial).set_shader_parameter("darken_factor", 0.0)
	(material_override as ShaderMaterial).set_shader_parameter("red_factor", 0.0)
	(material_override as ShaderMaterial).set_shader_parameter("reverse_red_factor", 0.0)
