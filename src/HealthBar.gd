extends Sprite3D

class_name HealthBar

# 血条的最大长度
@export var max_length: float = 1.0
# 血条的颜色
@export var color: Color = Color(1, 0, 0, 1)  # 默认红色

# 材质实例
var material: StandardMaterial3D
# 摄像机引用
@onready var camera: Camera3D = get_node("/root/Node3D/Player/Camera3D")
# 敌人引用
@export var enemy: Node3D  # 通过 Inspector 设置敌人的引用

func _ready() -> void:
	# 创建血条纹理
	position = Vector3(-10000, -10000, -10000)
	var image = Image.create(256, 16, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.create_from_image(image)
	self.texture = texture
	self.scale = Vector3(max_length, 0.5, 0.5)  # 初始大小

	# 创建材质并设置纹理
	material = StandardMaterial3D.new()
	material.albedo_texture = texture  # 设置纹理
	material.emission_enabled = true  # 启用发光
	material.emission = Color(1, 0, 0, 1)  # 设置发光颜色为红色
	material.emission_energy_multiplier = 1.0  # 发光强度
	self.material_override = material

	self.rotation = camera.rotation
	
	self.centered = true

	# 初始化颜色
	reset_color()

# 更新血条
func update_health(health_ratio: float) -> void:
	# 确保 health_ratio 在 0 到 1 之间
	health_ratio = clamp(health_ratio, 0.0, 1.0)

	# 根据血量比例调整长度
	self.scale.x = max_length * health_ratio

	# 根据血量比例调整颜色
	material.albedo_color = Color(1 - health_ratio, health_ratio, 0)  # 血量越低，颜色越红

	# 动态调整发光强度
	material.emission_energy_multiplier = 1.0 + (1.0 - health_ratio) * 2.0  # 血量越低，发光越强


# 重置血条
func reset_color() -> void:
	# 重置长度
	self.scale.x = max_length

	# 重置颜色为初始颜色
	material.albedo_color = color

	# 重置发光强度
	material.emission_energy_multiplier = 1.0

func reset():
	self.scale = Vector3(max_length, 0.5, 0.5)  # 初始大小

	# 初始化颜色
	reset_color()
