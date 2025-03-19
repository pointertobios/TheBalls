extends Sprite3D

class_name HealthBar

# 血条的最大长度
@export var max_length: float = 1.0
# 血条的颜色
@export var color: Color = Color(1, 0, 0, 1)  # 默认红色

# 材质实例
var material: StandardMaterial3D

func _ready() -> void:
	# 创建血条纹理
	var image = Image.create(256, 16, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.create_from_image(image)
	self.texture = texture
	self.scale = Vector3(max_length, 0.5, 0.5)  # 初始大小

	# 创建材质并设置纹理
	material = StandardMaterial3D.new()
	material.billboard_mode = StandardMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = texture  # 设置纹理
	self.material_override = material

# 更新血条
func update_health(health_ratio: float) -> void:
	print("Health Ratio: ", health_ratio)
	
	# 根据血量比例调整长度
	self.scale.x = max_length * health_ratio

	# 根据血量比例调整颜色
	material.albedo_color = Color(1 - health_ratio, health_ratio, 0)  # 血量越低，颜色越红

func reset_color():
	material.albedo_color = color
