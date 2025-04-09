extends CharacterBody3D

class_name Enemy

@onready var meshi = $MeshInstance3D
@onready var collshape = $CollisionShape3D
@onready var gpuparticles = $GPUParticles3D
@onready var death_sound_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var player: BallPlayer = get_node("../Player")
@onready var skill: Skill = get_node("../Player/Skill")
@onready var score: RichTextLabel = get_node("../Score_board/Score")
@onready var ultimate_inf: TextureProgressBar = get_node("../CanvasLayer/Control/TextureProgressBar")
@onready var progress_bar: ulti_bar = get_node("../CanvasLayer/Control/TextureProgressBar")
@onready var game: Game = get_node("..")

var health_bar: HealthBar

@onready var mesh
@onready var gravity

var uuid: String

var acc: Vector3
var fric = 0.9
var score_add = 10

var mutex = Mutex.new()

# 玩家血量
var player_blood: int

var ulti_recover = 4

# 敌人的移动速度
@export var speed: float = 3.0
# 敌人的转向速度
@export var rotation_speed: float = 5.0

# 用于控制隐藏和重新显示的计时器
var hide_timer: float = 0.0
var is_hidden: bool = false
var die_timer: float = 0.0
var is_die: bool = false

# 用于控制扣除玩家血量的冷却时间
var damage_cooldown: float = 0.0
var can_damage_player: bool = true

var random_inter: int = 100

# 新增：敌人血量
var health: float = 100.0
var max_health: float = 100.0
var is_attack_by_skill: float = false
var true_radiu: float = false
var radiu_v: float = 1

# 用于控制大招伤害的冷却时间
var is_ultimate_attack: bool = false

var dying_player_recover = 3

#受伤计时器
@onready var hit_timer = Timer.new() # 用于控制受伤时间

func set_hp():
	(gpuparticles as VisualInstance3D).visible = false
	var pos = randf_range(1, random_inter)
	if pos > 90 and pos <= 100:
		speed = 15
		max_health = 200.0 # 血量根据敌人大小调整
	elif pos > 80 and pos <= 90:
		speed = 12
		max_health = 150.0
	elif pos > 70 and pos <= 80:
		speed = 10
		max_health = 120.0
	elif pos > 60 and pos <= 70:
		speed = 8
		max_health = 100.0
	else:
		speed = 3
		max_health = 50.0

	health = max_health
	update_health_bar() # 更新血条

	#var true_radiu: float
	if pos > 90 and pos <= 100:
		true_radiu = 2
	elif pos > 80 and pos <= 90:
		true_radiu = 1.5
	elif pos > 70 and pos <= 80:
		true_radiu = 1
	elif pos > 60 and pos <= 70:
		true_radiu = 0.8
	else:
		true_radiu = 0.5
	(collshape.shape as SphereShape3D).radius = true_radiu
	mesh.radius = 0
	mesh.height = 0
	gravity.ballradius = 0

	if health_bar:
		health_bar.max_length = mesh.radius # 血条长度与敌人大小相关
		health_bar.position.y = mesh.radius + 0.2 # 血条位置在敌人头顶
		health_bar.reset()
		health_bar.rotation = player.rotation + player.camera.rotation
	set_random_color()

func _ready() -> void:
	meshi.mesh = meshi.mesh.duplicate()
	mesh = meshi.mesh as SphereMesh
	collshape.shape = collshape.shape.duplicate()
	gravity = Gravity.new(9.8, mesh.radius, 0.5)
	visible = true
	collshape.disabled = false
	## 加载 Shader 脚本
	var shader: Resource = load("res://shader/enemy.gdshader")

	## 创建 ShaderMaterial
	var material = ShaderMaterial.new()
	material.shader = shader

	## 应用到敌人节点
	meshi.material_override = material
	
	set_hp()
	
	# 初始化计时器
	add_child(hit_timer)
	hit_timer.timeout.connect(_on_hit_timeout)
	hit_timer.one_shot = true # 只触发一次

	# 动态创建血条
	health_bar = HealthBar.new()
	health_bar.max_length = mesh.radius # 血条长度与敌人大小相关
	health_bar.centered = true
	get_tree().root.add_child(health_bar) # 将血条添加到敌人节点

# 计时器结束时恢复颜色
func _on_hit_timeout():
	meshi.material_override.set_shader_parameter("hit_blend", 0.0) # 恢复原色

func _physics_process(delta: float) -> void:
	if mesh.radius < true_radiu:
		position.y = mesh.radius
		mesh.radius += radiu_v * delta
		mesh.height += radiu_v * 2 * delta
		gravity.ballradius += radiu_v
		meshi.material_override.set_shader_parameter("alpha", mesh.radius / true_radiu)
		if mesh.radius >= true_radiu:
			position.y = mesh.radius
			health_bar.max_length = true_radiu
			(gpuparticles as VisualInstance3D).visible = true
			update_health_bar()
		else:
			return
	if mesh.radius > true_radiu:
		mesh.radius = true_radiu
		mesh.height = true_radiu * 2
		gravity.ballradius = true_radiu
		
	if health_bar:
		health_bar.global_transform.origin = global_transform.origin + Vector3(0, mesh.radius + 0.5, 0) # 在敌人头顶显示
	if not player:
		return # 如果玩家不存在，直接返回
	# 更新扣除玩家血量的冷却时间
	if not can_damage_player:
		damage_cooldown -= delta
		if damage_cooldown <= 0:
			can_damage_player = true

	# 如果敌人处于隐藏状态，更新计时器
	if is_hidden:
		hide_timer -= delta
		if hide_timer <= 0:
			# 计时器结束，重新显示敌人并随机改变位置
			position.x = randf_range(-50, 50)
			position.z = randf_range(-50, 50)
			is_hidden = false
			meshi.visible = true
			gpuparticles.emitting = true
			collshape.disabled = false
		return

	if is_die:
		die_timer -= delta
		if die_timer <= 0:
			is_die = false
			$Die.emitting = false
			set_hp()
	if not player.confine.is_confine:
		# 获取玩家的水平位置（忽略 Y 轴）
		var player_position = Vector3(player.position.x, 0, player.position.z)
	
		# 获取敌人的水平位置（忽略 Y 轴）
		var enemy_position = Vector3(position.x, 0, position.z)
	
		# 计算敌人到玩家的方向
		var direction = (player_position - enemy_position).normalized()

		# 移动敌人
		velocity = direction * speed

		# 让敌人平滑转向玩家
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
		gpuparticles.rotation.y = - rotation.y

		# 更新重力
		gravity.update(delta)
		position.y = gravity.at()
		meshi.scale = gravity.zoom()

		# 更新粒子
		gpuparticles.set_emission_direction(-direction)

		# 应用移动并检测碰撞
		move_and_slide()

	# 检测敌人接触技能或玩家
	if not is_hidden and player.is_ultimate and (player.ultimate_ball.position - position).length() <= \
	mesh.radius + player.ultimate_ball.current_radius + 0.8 and (player.ultimate_ball.position - position).length() >= \
	mesh.radius + player.ultimate_ball.current_radius - 0.8:
		if !is_ultimate_attack:
			$Die.emitting = true
			$Die.set_radial_acceleration(10)
			take_ulti_damage(player.ATK * player.ulti_mult) # 开大时造成更高伤害
			is_ultimate_attack = true
	elif not is_hidden and player.is_skill_emitting() and (Vector3(player.position.x, 0, player.position.z) - position).length() <= \
	skill.collision_radius and not is_attack_by_skill:
		$Die.emitting = true
		$Die.set_radial_acceleration(10)
		player.skill_emitting()
		take_damage(player.ATK * player.skill_mult) # 技能造成伤害
		is_attack_by_skill = true
	elif not is_hidden and is_near():
		if player.gravity.charging and player.position.y > position.y:
			# 玩家压扁敌人
			start_squash_effect() # 调用压扁效果函数
			$Die.emitting = true
			$Die.set_radial_acceleration(10)
			await get_tree().create_timer(0.2).timeout # 等待压扁动画完成
			take_damage(player.ATK) # 普通撞击伤害
		elif can_damage_player and not collshape.disabled:
			# 扣除玩家血量
			if not player.shield.is_safe:
				player.blood -= 1 # 假设每次扣除1点血量
				can_damage_player = false
				damage_cooldown = 1.0 # 设置1秒的冷却时间

# 新增：敌人受到伤害
func take_damage(damage_val: float) -> void:
	var ran_num = randf_range(1, 100)
	var is_cri = false
	if ran_num <= player.cri_ch:
		is_cri = true
		damage_val *= (player.cri_hit / 100)
	var damage_digital = DamageText.new(damage_val, position, is_cri)
	game.add_child(damage_digital)
	health -= damage_val
	if health <= 0:
		die() # 调用 die 函数
	update_health_bar()
	meshi.material_override.set_shader_parameter("hit_blend", 0.5) # 变红
	hit_timer.start(0.4) # 0.4秒后恢复

func take_ulti_damage(damage_val: float) -> void:
	var ran_num = randf_range(1, 100)
	var is_cri = false
	if ran_num <= player.cri_ch:
		is_cri = true
		damage_val *= (player.cri_hit / 100)
	var damage_digital = DamageText.new(damage_val, position, is_cri)
	game.add_child(damage_digital)
	health -= damage_val
	if health <= 0:
		player.blood += dying_player_recover
		var recover = DamageText.new(-dying_player_recover, player.position, false)
		game.add_child(recover)
		player.balance_blood()
		die() # 调用 die 函数
	update_health_bar()
	meshi.material_override.set_shader_parameter("hit_blend", 0.5) # 变红
	# emit_signal("took_damage") # 发出受伤信号
	hit_timer.start(0.4) # 0.4秒后恢复

# 新增：敌人死亡
func die() -> void:
	# 播放死亡动画或效果
	$Die.emitting = true
	$Die.set_radial_acceleration(10)
	damage() # 调用原有的 damage 函数处理分数和隐藏逻辑
	if player.is_ultimate and player.ultimate_ball.last_prase_ult:
		player.shake_camera() # 触发玩家相机震动
	death_sound_player.play()

# 新增：更新血条
func update_health_bar() -> void:
	if health_bar:
		var health_ratio = health / max_health
		health_bar.update_health(health_ratio) # 调用血条的更新方法

# 压扁效果函数
func start_squash_effect() -> void:
	var tween = create_tween()

	# 压扁效果：Y 轴缩放减小，X 轴和 Z 轴缩放增大
	tween.tween_property(meshi, "scale", Vector3(1.1, 0.1, 1.1), 0.4) # 压扁
	#tween.tween_property(meshi, "scale", Vector3(1, 1, 1), 0.2)       # 恢复原状

	# 可选：播放音效
	if has_node("AudioStreamPlayer"):
		$AudioStreamPlayer.play()

# 检测玩家与敌人是否接近
func is_near() -> bool:
	return (player.position - position).length() <= mesh.radius + player.mesh.radius + 0.5

func damage():
	# 更新分数
	if is_die or is_hidden:
		return
	score.add(score_add)
	random_addtion()
	#progress_bar.value += 1
	progress_bar.smooth_set_value(300)
	

	# 禁用碰撞检测
	collshape.disabled = true
	gpuparticles.emitting = false

	# 延迟隐藏敌人
	meshi.visible = false

	# 碰撞发生，隐藏敌人并启动计时器
	is_hidden = true
	is_die = true
	die_timer = 0.01
	hide_timer = 3.0 # 隐藏3秒钟

@export var whiten_speed: float = 2.5 # 渐变速度（1 / 0.4 秒）
# 渐变到白色
func whiten():
	for i in range(24):
		await get_tree().create_timer(0.016).timeout
		(meshi.material_override as ShaderMaterial).set_shader_parameter("whiten_factor", float(i + 1) / 24)

# 渐变回原色
func unwhiten():
	for i in range(24):
		await get_tree().create_timer(0.016).timeout
		(meshi.material_override as ShaderMaterial).set_shader_parameter("whiten_factor", 1.0 - float(i + 1) / 24)

func random_addtion():
	var ran_num = randf_range(1, 100)
	if ran_num <= 5:
		player.recover_inf.value = min(player.recover_inf.max_value, player.recover_inf.value + 1)
	elif ran_num >= 15 and ran_num <= 20:
		player.protect_inf.value = min(player.protect_inf.max_value, player.protect_inf.value + 1)
	elif ran_num >= 25 and ran_num <= 30:
		player.acc_inf.value = min(player.acc_inf.max_value, player.acc_inf.value + 1)
	elif ran_num >= 35 and ran_num <= 40:
		player.fixed_inf.value = min(player.fixed_inf.max_value, player.fixed_inf.value + 1)
	elif ran_num >= 45 and ran_num <= 50:
		player.AtkAdd_inf.value = min(player.AtkAdd_inf.max_value, player.AtkAdd_inf.value + 1)
	elif ran_num >= 55 and ran_num <= 60:
		player.cs_inf.value = min(player.cs_inf.max_value, player.cs_inf.value + 1)
		
# 随机颜色函数
func set_random_color():
	var random_color = Color(randf(), randf(), randf()) # 完全随机 RGB
	set_enemy_color(random_color)
# 动态修改颜色的函数（可在外部调用）
func set_enemy_color(color: Color):
	var rgb_color = Vector3(color.r, color.g, color.b)
	meshi.material_override.set_shader_parameter("enemy_color", rgb_color)
