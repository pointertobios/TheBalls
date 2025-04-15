class_name BlinkSkill
extends Node

const BLINK_DISTANCE := 12.0
const INDICATOR_COLOR := Color(1, 0.5, 0, 0.7)
const INDICATOR_SIZE := Vector3(0.3, 0.6, 0.3)
const AFTERIMAGE_FADE_TIME := 0.5  # 新增残影参数
const SCREEN_DISTORT_STRENGTH := 0.6  # 新增屏幕扭曲强度
const AFTERIMAGE_INTERVAL := 0.8  # 残影间隔距离
const MAX_AFTERIMAGES := 16       # 最大残影数量

var game: Game
var player: BallPlayer
var indicator: MeshInstance3D
var is_active := false
var screen_shader: ShaderMaterial
var afterimages := []

func _init(p: BallPlayer) -> void:
	player = p

func _ready():
	create_indicator()
	setup_screen_effect()

func setup_screen_effect():
	# 创建全屏着色器效果
	var post_process = ColorRect.new()
	post_process.material = ShaderMaterial.new()
	post_process.material.shader = preload("res://shader/screen_distortion.gdshader")
	post_process.size = Vector2(1920, 1080)
	post_process.material.set_shader_parameter("u_strength", 0.0)
	screen_shader = post_process.material

func create_indicator():
	indicator = MeshInstance3D.new()
	indicator.mesh = SphereMesh.new()
	indicator.mesh.radius = INDICATOR_SIZE.x
	indicator.mesh.height = INDICATOR_SIZE.y
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = INDICATOR_COLOR
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	
	indicator.material_override = mat
	indicator.visible = false
	player.add_child(indicator)

func activate():
	if is_active: return
	is_active = true
	indicator.visible = true
	player.set_process_input(true)

func deactivate():
	is_active = false
	indicator.visible = false
	player.set_process_input(false)

func perform_blink():
	var camera = player.camera
	var mouse_pos = player.get_viewport().get_mouse_position()
	var space_state = player.get_world_3d().direct_space_state
	
	# 计算目标点
	var from = player.position + camera.position
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	print("mouse ray: ", from, '-', to)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	
	var result = space_state.intersect_ray(query)
	print(result)
	if result.is_empty(): return
	
	var target_point = result.position
	var blink_direction = (target_point - player.global_position)
	blink_direction.y = 0
	var len = blink_direction.length()
	blink_direction = blink_direction.normalized()
	var target_position = player.position + (blink_direction * min(len, BLINK_DISTANCE))
	
	#trigger_effects()
	generate_path_afterimages(player.position, target_position)
	
	# 执行闪现
	player.global_position = target_position
	player.velocity = Vector3.ZERO  # 重置速度

## 新增路径残影生成方法
#func generate_path_afterimages(start_pos: Vector3, end_pos: Vector3):
	#var direction = (end_pos - start_pos).normalized()
	#var total_distance = start_pos.distance_to(end_pos)
	#var step_count = min(floor(total_distance / AFTERIMAGE_INTERVAL), MAX_AFTERIMAGES)
	#
	## 在路径上生成多个残影
	#for i in range(1, step_count + 1):
		#var spawn_pos = start_pos + direction * (AFTERIMAGE_INTERVAL * i)
		#create_afterimage(spawn_pos, float(i)/step_count)  # 传入位置和透明度系数
func generate_path_afterimages(start_pos: Vector3, end_pos: Vector3):
	var direction = (end_pos - start_pos).normalized()
	var total_distance = start_pos.distance_to(end_pos)
	var step_count = floor(total_distance / AFTERIMAGE_INTERVAL)  # 实际总间隔数
	
	# 计算起始索引（确保至少生成1个残影）
	var start_i = max(step_count - MAX_AFTERIMAGES + 1, 1)
	
	# 在路径末端生成残影
	for i in range(start_i, step_count + 1):
		var distance = AFTERIMAGE_INTERVAL * i
		var spawn_pos = start_pos + direction * min(distance, total_distance)
		var alpha_factor = float(i) / step_count  # 保持原有透明度渐变逻辑
		create_afterimage(start_pos, spawn_pos, end_pos, alpha_factor)

#func create_afterimage(spawn_pos: Vector3, target_pos: Vector3, alpha_factor: float = 1.0):
	## 生成半透明残影
	#var ghost = player.meshi.duplicate()
	#
	## 移除可能存在的子节点（如碰撞体等）
	#for n in ghost.get_children():
		#n.free()
	#
	#ghost.material_override = player.meshi.material_override.duplicate()
	#
	## 设置残影属性
	#var initial_alpha = lerp(0.3, 0.6, alpha_factor)  # 根据位置渐变初始透明度
	#print(ghost.material_override.transparency)
	#ghost.material_override.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	#ghost.material_override.albedo_color = Color(1, 1, 1, initial_alpha)
	## 添加到场景
	#game.add_child(ghost)
	#ghost.global_position = spawn_pos  # 使用传入的位置
	#
	#
	## 渐隐动画
	#var tween = ghost.create_tween()
	#tween.tween_property(ghost.material_override, "albedo_color:a", 0.0, AFTERIMAGE_FADE_TIME)
	#tween.tween_callback(ghost.queue_free)
	#
	#afterimages.append(ghost)
func create_afterimage(source_pos: Vector3, spawn_pos: Vector3, target_pos: Vector3, alpha_factor: float = 1.0):
	# 生成残影实例
	var ghost = player.meshi.duplicate()
	
	# 清理子节点
	for n in ghost.get_children():
		n.free()
	
	# 深度复制材质（防止材质实例冲突）
	ghost.material_override = player.meshi.material_override.duplicate()
	
	# 初始化材质属性
	var initial_alpha = lerp(0.3, 0.6, alpha_factor)
	ghost.material_override.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	ghost.material_override.albedo_color = Color(1, 1, 1, initial_alpha)
	ghost.material_override.blend_mode = StandardMaterial3D.BLEND_MODE_MIX  # 重要混合模式
	
	# 添加到场景
	game.add_child(ghost)
	ghost.global_position = spawn_pos
	
	# 创建并行动画
	var tween = ghost.create_tween().set_parallel(true)
	
	# 透明度渐变动画
	var mul = (spawn_pos - source_pos).length() / (target_pos - source_pos).length() * 0.6 + 0.4
	tween.tween_property(ghost.material_override, "albedo_color:a", 0.0, AFTERIMAGE_FADE_TIME * mul)
	
	# 位置移动动画（带缓动效果）
	tween.tween_property(ghost, "global_position", 
		target_pos, AFTERIMAGE_FADE_TIME * 2
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
	# 可选：添加缩放动画增强效果
	#ghost.scale = Vector3(1, 1, 1)
	#tween.tween_property(ghost, "scale", Vector3(0, 0, 0), AFTERIMAGE_FADE_TIME * 2)
	
	# 动画完成回调
	tween.chain().tween_callback(ghost.queue_free)
	
	# 实例管理
	afterimages.append(ghost)

func update_indicator():
	var camera = player.get_viewport().get_camera_3d()
	var mouse_pos = player.get_viewport().get_mouse_position()
	var space_state = player.get_world_3d().direct_space_state
	
	var from = player.position + camera.position
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	
	var result = space_state.intersect_ray(query)
	if result.is_empty(): return
	
	var target_point = result.position
	var blink_direction = (target_point - player.global_position)
	blink_direction.y = 0
	var len = blink_direction.length()
	blink_direction = blink_direction.normalized()
	indicator.global_position = player.position + (blink_direction * min(len, BLINK_DISTANCE))
	
	# 添加呼吸效果
	var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.2 + 0.8
	indicator.scale = Vector3.ONE * pulse

func _process(delta):
	if is_active:
		update_indicator()
