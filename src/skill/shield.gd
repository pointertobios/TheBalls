extends Node

class_name Shield

# 护盾颜色和透明度
@export var shield_color: Color = Color(1.0, 0.84, 0.0, 0.3)  # 金黄色，透明度 0.3

# 护盾持续时间
@export var duration: float = 10.0  # 持续 10 秒

# 玩家节点
var player: BallPlayer

# 护盾节点
var shield_mesh_instance: MeshInstance3D
var shield_collision_shape: CollisionShape3D

var is_safe: bool = false

# 初始化时传入玩家对象
func _init(player_node: BallPlayer) -> void:
	self.player = player_node

# 启用护盾
func activate_shield() -> void:
	if player:
		is_safe = true
		# 确保节点已经添加到场景树
		if not is_inside_tree():
			await ready  # 等待节点添加到场景树

		# 创建护盾
		create_shield()
		# 动态调整护盾大小
		adjust_shield_size()
		# 启动计时器，10 秒后禁用护盾
		start_shield_timer()
	else:
		print("错误：玩家节点未初始化！")

# 创建护盾
func create_shield() -> void:
	# 创建护盾的 MeshInstance3D
	shield_mesh_instance = MeshInstance3D.new()
	var shield_mesh = SphereMesh.new()
	shield_mesh.radius = player.mesh.radius + 0.2  # 护盾半径比玩家大 0.2m
	shield_mesh.height = (player.mesh.radius + 0.2) * 2  # 护盾高度
	shield_mesh_instance.mesh = shield_mesh

	# 设置护盾材质
	var shield_material = StandardMaterial3D.new()
	shield_material.albedo_color = shield_color
	shield_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # 启用透明度
	shield_mesh_instance.material_override = shield_material

	# 将护盾添加到玩家节点
	player.add_child(shield_mesh_instance)

	# 创建护盾的碰撞节点
	shield_collision_shape = CollisionShape3D.new()
	var shield_shape = SphereShape3D.new()
	shield_shape.radius = player.mesh.radius + 0.2  # 碰撞半径比玩家大 0.2m
	shield_collision_shape.shape = shield_shape

	# 将碰撞节点添加到玩家节点
	player.add_child(shield_collision_shape)

# 动态调整护盾大小
func adjust_shield_size() -> void:
	# 确保节点已经添加到场景树
	if not is_inside_tree():
		await ready  # 等待节点添加到场景树

	# 监听玩家半径变化
	while shield_mesh_instance and shield_collision_shape:
		# 更新护盾的 Mesh 和碰撞形状
		(shield_mesh_instance.mesh as SphereMesh).radius = player.mesh.radius + 0.2
		(shield_mesh_instance.mesh as SphereMesh).height = (player.mesh.radius + 0.2) * 2
		(shield_collision_shape.shape as SphereShape3D).radius = player.mesh.radius + 0.2
		await get_tree().process_frame  # 等待下一帧

# 启动护盾计时器
func start_shield_timer() -> void:
	# 确保节点已经添加到场景树
	if not is_inside_tree():
		await ready  # 等待节点添加到场景树

	await get_tree().create_timer(duration).timeout  # 等待 10 秒
	disable_shield()  # 10 秒后禁用护盾

# 禁用护盾
func disable_shield() -> void:
	if shield_mesh_instance and shield_collision_shape:
		shield_mesh_instance.queue_free()  # 移除护盾 Mesh
		shield_collision_shape.queue_free()  # 移除护盾碰撞节点
		is_safe = false
