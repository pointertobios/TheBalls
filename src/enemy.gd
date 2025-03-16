extends CharacterBody3D

class_name Enemy

@onready var meshi = $MeshInstance3D
@onready var player: BallPlayer = get_node("../Player")
@onready var Particles = $GPUParticles3D

@onready var mesh = meshi.mesh as SphereMesh
@onready var score: RichTextLabel = get_node("../Score_board/Score")
@onready var gravity = Gravity.new(9.8, mesh.radius, 0.5)

var acc: Vector3
var fric = 0.9
var score_add = 10

# 玩家血量
var player_blood: int

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

func _init() -> void:
	var pos = randf_range(1, random_inter)
	if pos > 50 and pos <= 100:
		speed = 10
	else:
		speed = 3

func _physics_process(delta: float) -> void:
	if not player:
		return  # 如果玩家不存在，直接返回

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
			is_hidden = false
			meshi.visible = true
			Particles.emitting = true
			$CollisionShape3D.disabled = false
			position.x = randf_range(-50, 50)
			position.z = randf_range(-50, 50)
		return

	if is_die:
		die_timer -= delta
		if die_timer <= 0:
			is_die = false
			$Die.emitting = false
			_init()

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
	$GPUParticles3D.rotation.y = -rotation.y

	# 更新重力
	gravity.update(delta)
	position.y = gravity.at()
	meshi.scale = gravity.zoom()

	# 更新粒子
	Particles.set_emission_direction(-direction)

	# 应用移动并检测碰撞
	move_and_slide()

	# 检测玩家与敌人是否接触
	if is_near():
		if player.gravity.charging and player.position.y > position.y:
			# 玩家压扁敌人
			start_squash_effect()  # 调用压扁效果函数
			$Die.emitting = true
			$Die.set_radial_acceleration(10)

			# 更新分数
			var tmp = score.cur_score
			tmp += score_add
			score.cur_score = tmp
			score.clear()
			score.push_font_size(score.default_font)
			score.add_text(str(tmp))
			score.pop()

			# 禁用碰撞检测
			$CollisionShape3D.disabled = true
			Particles.emitting = false

			# 延迟隐藏敌人
			await get_tree().create_timer(0.4).timeout  # 等待压扁动画完成
			meshi.visible = false

			# 碰撞发生，隐藏敌人并启动计时器
			is_hidden = true
			is_die = true
			die_timer = 0.01
			hide_timer = 3.0  # 隐藏3秒钟
		elif can_damage_player and not $CollisionShape3D.disabled:
			# 扣除玩家血量
			player.blood -= 1  # 假设每次扣除1点血量
			print(player.blood)
			can_damage_player = false
			damage_cooldown = 1.0  # 设置1秒的冷却时间

# 压扁效果函数
func start_squash_effect() -> void:
	var tween = create_tween()

	# 压扁效果：Y 轴缩放减小，X 轴和 Z 轴缩放增大
	tween.tween_property(meshi, "scale", Vector3(1.1, 0.1, 1.1), 0.4)  # 压扁
	#tween.tween_property(meshi, "scale", Vector3(1, 1, 1), 0.2)       # 恢复原状

	# 可选：播放音效
	if has_node("AudioStreamPlayer"):
		$AudioStreamPlayer.play()

# 检测玩家与敌人是否接近
func is_near() -> bool:
	return (player.position - position).length() <= mesh.radius + player.mesh.radius + 0.5
