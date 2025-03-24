# UltimateBall.gd
extends Node3D

class_name UltimateBall

# 定义信号
signal ultimate_ended

@export var initial_radius: float = 1  # 初始半径
@export var expansion_rate: float = 10.0  # 每秒半径扩大 6 米
@export var shrink_rate: float = 10.0  # 每秒半径缩小 6 米
@export var duration: float = 5.0  # 大招第一阶段持续时间
@export var second_phase_duration: float = 5.0  # 大招第二阶段持续时间
@export var fade_rate: float = 0.2  # 每秒透明度减少 0.2
@export var darken_rate: float = 0.2  # 每秒颜色变深 0.2
@export var explosion_rate: float = 35.0  # 爆炸时半径扩大速度

@onready var ground: Ground = get_node("../Board")
@onready var game: Game = get_node("../")
@onready var player: BallPlayer = get_node("../Player")
@onready var ulti_pic: CanvasLayer = get_node("../CanvasLayer")

@onready var enemies = ($".." as Game).enemy_list

var current_radius: float = initial_radius
var current_alpha: float = 1.0
var current_color: Color = Color(0 / 255, 255 / 255, 255 / 255, current_alpha)  # 初始颜色
var timer: float = 0.0
var player_position_y: float
var down_brightness: float = 1.0
var one_prase_ult: bool = false
var second_prase_ult: bool = false
var last_prase_ult: bool = false

@onready var playmusic1: AudioStreamPlayer3D = $"../Player/FirstOfSkill"  # 第一阶段音乐
@onready var playmusic2: AudioStreamPlayer3D = $"../Player/SecondOfSkill"  # 第二阶段音乐
@onready var playmusic3: AudioStreamPlayer3D = $"../Player/ThirdOfSkill"  # 第三阶段音乐
#@onready var ultimate_inf: TextureProgressBar = get_node("../CanvasLayer/Control/TextureProgressBar")

# 球体材质
var material: ShaderMaterial

func _ready() -> void:
	# 创建半球体
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = initial_radius
	sphere_mesh.height = initial_radius * 2
	mesh_instance.mesh = sphere_mesh

	# 创建 ShaderMaterial 并加载 Shader 脚本
	material = ShaderMaterial.new()
	material.shader = load("res://shader/ultimate_ball.gdshader")  # 加载 Shader 脚本
	material.set_shader_parameter("albedo_color", current_color)  # 设置初始颜色
	material.set_shader_parameter("alpha", current_alpha)  # 设置初始透明度
	material.set_shader_parameter("emission_enabled", false)  # 初始关闭发光
	mesh_instance.material_override = material

	# 将半球体添加到场景中
	add_child(mesh_instance)
	# 重置地板 Shader 参数
	ground.reset_shader_parameters()
	ground.darken()  # 调用地面 Shader
	ulti_pic.set_ultimate_ready(true)
	


var re = true
var is_second_phase: bool = false
var is_exploding: bool = false  # 是否正在爆炸

func _process(delta: float) -> void:
	timer += delta
	position = player.position
	
	if is_exploding:
		return
	if !is_second_phase:
		# 第一阶段：球体扩大
		if not one_prase_ult:
			reset_time()
			playmusic1.play()  # 播放第一阶段音乐
		one_prase_ult = true
			
		current_radius += expansion_rate * delta
		current_alpha -= fade_rate * delta
		current_alpha = clamp(current_alpha, 0.0, 1.0)  # 确保透明度在 0 到 1 之间
		# 更新球体大小和透明度
		scale = Vector3(current_radius, current_radius, current_radius)
		material.set_shader_parameter("alpha", current_alpha)

		# 大招开始时触发颜色变化
		if timer >= 0.0 and timer < 0.4:
			for enemy in game.enemy_list:
				enemy.whiten()  # 调用敌人 Shader

		# 第一阶段结束后进入第二阶段
		if timer >= duration:
			is_second_phase = true
			timer = 0.0  # 重置计时器
			# 进入第二阶段后，设置球体颜色为浅灰色并启用发光
			current_color = Color(0.8, 0.8, 0.8, current_alpha)  # 浅灰色
			material.set_shader_parameter("albedo_color", current_color)
			material.set_shader_parameter("emission_enabled", true)  # 启用发光
			material.set_shader_parameter("emission_color", Color(1.0, 1.0, 1.0))  # 设置发光颜色为白色
	else:
		# 第二阶段：球体缩小
		if not second_prase_ult:
			reset_time()
			playmusic2.play()  # 播放第二阶段音乐
			ulti_pic.set_ultimate_ready(false)
		second_prase_ult = true
		current_radius -= shrink_rate * delta
		current_radius = max(current_radius, initial_radius)  # 确保半径不小于初始值
		current_alpha += fade_rate * delta
		current_alpha = clamp(current_alpha, 0.0, 1.0)  # 确保透明度在 0 到 1 之间

		# 更新球体大小和透明度
		scale = Vector3(current_radius, current_radius, current_radius)
		material.set_shader_parameter("alpha", current_alpha)
		# 更新地板颜色（从黑色渐变到红色）
		ground.set_red_factor(min(timer / second_phase_duration, 1.0))
		#更新球的亮度
		down_brightness -= 0.5 * get_process_delta_time()
		down_brightness = clamp(down_brightness, 0.0, 1.0)
		material.set_shader_parameter("brightness", down_brightness)

		# 大招结束后恢复颜色
		if timer >= second_phase_duration and timer < second_phase_duration + 2.0:
			if re:
				ground.lighten()
				re = false
			for enemy in game.enemy_list:
				enemy.unwhiten()  # 调用敌人 Shader

			# 爆炸效果
			if !is_exploding:
				is_exploding = true
				start_explosion()

		# 第二阶段结束后销毁球体
		elif timer >= second_phase_duration + 4.0:
			emit_signal("ultimate_ended")  # 发射信号
			queue_free()

# 爆炸效果
func start_explosion() -> void:
	reset_time()
	last_prase_ult = true
	playmusic3.play()  # 播放第三阶段音乐
	var explosion_timer: float = 0.0
	var slow_expansion_timer: float = 0.0
	var target_radius: float = 8.0  # 爆炸前的目标半径
	var is_exploding_fast: bool = false  # 是否进入快速爆炸阶段
	var brightness: float = 0.0  # 初始亮度值
	var max_brightness: float = 1.0  # 最大亮度值
	material.set_shader_parameter("emission_enabled", true)  # 启用发光
	ulti_pic.pause_ultimate_animation()
	while explosion_timer < 6.0:
		# 缓慢增大半径（爆炸前）
		if current_radius < target_radius and !is_exploding_fast:
			current_radius += 7 * get_process_delta_time()  # 缓慢增大半径
			#current_radius = min(current_radius, target_radius)  # 确保半径不超过目标值

			# 逐渐增加亮度
			brightness += 0.5 * get_process_delta_time()  # 亮度逐渐增大
			brightness = clamp(brightness, 0.0, max_brightness)  # 确保亮度不超过最大值
			scale = Vector3(current_radius, current_radius, current_radius)

			# 设置亮度
			material.set_shader_parameter("albedo_color", Vector4(brightness, brightness, brightness, 1))
			
		# 快速爆炸（当半径达到目标值后）
		elif current_radius >= target_radius or is_exploding_fast:
			is_exploding_fast = true
			current_radius += explosion_rate * get_process_delta_time()  # 快速增大半径
			current_alpha -= fade_rate * get_process_delta_time() * 7  # 快速减小透明度
			current_alpha = clamp(current_alpha, 0.0, 1.0)  # 确保透明度在 0 到 1 之间

			# 更新球体大小和透明度
			scale = Vector3(current_radius, current_radius, current_radius)
			material.set_shader_parameter("alpha", current_alpha)

		# 更新计时器
		explosion_timer += get_process_delta_time()
		slow_expansion_timer += get_process_delta_time()
		await get_tree().process_frame  # 等待下一帧
	is_exploding = false
	reset_time()

func reset_time():
	for enemy in enemies:
		enemy.is_ultimate_attack = false
