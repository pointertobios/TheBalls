extends CharacterBody3D

class_name BallPlayer

@onready var meshi = $MeshInstance3D
@onready var coll : CollisionShape3D = $CollisionShape3D
@onready var blood_board = get_node("../Control/ProgressBar")
@onready var mesh = meshi.mesh as SphereMesh
@onready var gravity = Gravity.new(9.8, mesh.radius, 0.5)

@onready var enemies = ($".." as Game).enemy_list


var acc: Vector3
var fric = 0.9

var hit_timer: float = 0.0
var is_hit: bool = false
var is_last_on_floor: bool = true
var blood: int = 100

var skill_timer: float = 0.0
var is_skill: bool = false
var ultimate_ball: UltimateBall
var is_ultimate: bool = false

var max_velocity = 10
var attack_damage = 2

var camera_1 = 10
var camera_2 = 14.142
var camera_3 = 10

@onready var camera = $Camera3D as Node3D
@onready var camera_origin_position = camera.position

# 当前视角索引
var current_camera_view: int = 0

func _init() -> void:
	pass

func shake_camera():
	for i in range(50):
		await get_tree().create_timer(0.02).timeout
		var offset = sin(i * 0.2)
		var _direc = randf() * PI * 2
		var direc = Vector3(cos(_direc), 0, sin(_direc))
		direc = direc                            \
				.rotated(Vector3(0, 1, 0), 45)   \
				.rotated(Vector3(1, 0, 0), -45)  \
				.normalized()
		direc *= offset * 0.3
		camera.position = camera_origin_position + direc
	camera.position = camera_origin_position

func _process(delta: float) -> void:
	print(rotation)
	# 检测 L 键按下，切换摄像头视角
	if Input.is_action_just_pressed("KEY_L"):
		current_camera_view = (current_camera_view + 1) % 4  # 循环切换 0-3
		rotation.y += PI / 2
		if rotation.y >= 2 * PI:
			rotation.y -= 2 * PI
		for enemy in enemies:
			enemy.health_bar.rotation = rotation + camera.rotation
			

	# 获取输入方向
	var input_dir = Input.get_vector("KEY_A", "KEY_D", "KEY_W", "KEY_S")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	acc = direction.rotated(Vector3.UP, deg_to_rad(45 + rotation.y)) * \
			(-log(velocity.length() + 0.5) + 2)
	if Input.is_action_pressed("Right_Button"):
		acc *= 8
	if Input.is_action_just_pressed("KEY_SHIFT"):
		gravity.charge()
	elif Input.is_action_just_released("KEY_SHIFT"):
		gravity.release()
	# 技能释放
	if Input.is_action_just_pressed("KEY_E"):
		is_skill = true
		skill_timer = 0.2
		for enemy in enemies:
			enemy.is_attack_by_skill = false
		skill_emitting()
	if Input.is_action_just_pressed("KEY_Q"):  # 检测 Q 键按下
		is_ultimate = true
		ultimate_ball = UltimateBall.new()
		ultimate_ball.position = position  # 球体位置为玩家位置
		ultimate_ball.player_position_y = position.y
		ultimate_ball.ultimate_ended.connect(_on_ultimate_ended)
		get_parent().add_child(ultimate_ball)  # 将球体添加到场景中
		bigger()

func bigger():
	for i in range(48):
		await get_tree().create_timer(0.016).timeout
		mesh.radius += 0.05
		mesh.height += 0.1
		(coll.shape as SphereShape3D).radius += 0.05

var internal_acc_will_release: bool = false

func _physics_process(delta: float) -> void:
	blood_board.value = blood
	velocity += acc
	velocity -= velocity.normalized() * fric * \
			sqrt(velocity.length() * 0.06)
	gravity.update(delta)
	position.y = gravity.at()
	meshi.scale = gravity.zoom()

	var tmp_position = Vector3(position)
	var tmp_velocity = Vector3(velocity)

	var v = composited_velocity().length()
	if  v < 0.04 and $MeshInstance3D/GPUParticles3D.emitting:
		$MeshInstance3D/GPUParticles3D.emitting = false
	if not $MeshInstance3D/GPUParticles3D.emitting and v >= 0.04:
		$MeshInstance3D/GPUParticles3D.emitting = true
	if is_hit:
		hit_timer -= delta
		if hit_timer <= 0:
			is_hit = false
			$Hit.emitting = false
	# 技能检测
	if is_skill and is_hit:
		if skill_timer == 0.2:
			$Skill.emitting = true
		skill_timer -= delta
		if skill_timer <= 0:
			is_skill = false
			$Skill.emitting = false

	move_and_slide()

	if internal_acc_will_release:
		internal_acc_will_release = false 
		position = tmp_position
		velocity = tmp_velocity

	if get_slide_collision_count() > 0:
		internal_acc_will_release = true
	if gravity.charging and gravity.at_floor() and not is_last_on_floor :
		is_hit = true
		$Hit.set_radial_acceleration(10)
		hit_timer = 0.2
		$Hit.emitting = true
		is_last_on_floor = true
	if not gravity.at_floor():
		is_last_on_floor = false
	elif not is_last_on_floor:
		is_last_on_floor = true

func composited_velocity():
	return velocity + Vector3(0, gravity.v, 0)

func skill_emitting():
	$Skill.set_radial_acceleration(10)

func is_skill_emitting():
	return $Skill.emitting

# 大招结束时的回调
func _on_ultimate_ended():
	is_ultimate = false  # 大招结束，设置为 false
	for i in range(48):
		await get_tree().create_timer(0.016).timeout
		if i == 47:
			mesh.radius = 0.5
			mesh.height = 1
			(coll.shape as SphereShape3D).radius = 0.5
		else:
			mesh.radius -= 0.05
			mesh.height -= 0.1
			if (coll.shape as SphereShape3D).radius - 0.05 >= 0:
				(coll.shape as SphereShape3D).radius -= 0.05
