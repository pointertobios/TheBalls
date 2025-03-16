# UltimateBall.gd
extends Node3D

class_name UltimateBall

# 定义信号
signal ultimate_ended

@export var initial_radius: float = 1.0  # 初始半径
@export var expansion_rate: float = 2.0  # 每秒半径扩大 5 米
@export var duration: float = 5.0  # 大招持续时间
@export var fade_rate: float = 0.2  # 每秒透明度减少 0.2

var current_radius: float = initial_radius
var current_alpha: float = 1.0
var timer: float = 0.0
var player_position_y: float

# 球体材质
var material: StandardMaterial3D

func _ready() -> void:
	# 创建半球体
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = initial_radius
	sphere_mesh.height = initial_radius * 2
	mesh_instance.mesh = sphere_mesh
	# 设置半球体材质为紫色
	material = StandardMaterial3D.new()
	material.albedo_color = Color(0 / 255, 255 / 255, 255 / 255, current_alpha)  # 紫色，透明度为 1.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # 启用透明度
	mesh_instance.material_override = material
	
	# 将半球体添加到场景中
	add_child(mesh_instance)

func _process(delta: float) -> void:
	timer += delta
	# 更新半球体半径
	current_radius += expansion_rate * delta
	scale = Vector3(current_radius, current_radius, current_radius)
	
	# 更新半球体透明度
	current_alpha -= fade_rate * delta
	current_alpha = clamp(current_alpha, 0.0, 1.0)  # 确保透明度在 0 到 1 之间
	material.albedo_color.a = current_alpha  # 更新透明度
	
	# 大招结束后销毁半球体
	if timer >= duration:
		emit_signal("ultimate_ended")  # 发射信号
		queue_free()
