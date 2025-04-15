extends CharacterBody3D
class_name BallPlayer

@onready var meshi = $MeshInstance3D
@onready var coll : CollisionShape3D = $CollisionShape3D
@onready var blood_board = get_node("../Control/ProgressBar")
@onready var recover_inf: TextureProgressBar = get_node("../Control/Control2/SkillOfRecover/TextureProgressBar")
@onready var protect_inf: TextureProgressBar = get_node("../Control/Control2/SkillOfProtect/TextureProgressBar")
@onready var acc_inf: TextureProgressBar = get_node("../Control/Control2/SkillOfAcc/TextureProgressBar")
@onready var fixed_inf: TextureProgressBar = get_node("../Control/Control2/TextureRect/TextureProgressBar")
@onready var AtkAdd_inf: TextureProgressBar = get_node("../Control/Control2/SkillOfAtkAdd/TextureProgressBar")
@onready var cs_inf: TextureProgressBar = get_node("../Control/Control2/SkillOfAtkCs/TextureProgressBar")
@onready var ultimate_inf: TextureProgressBar = get_node("../CanvasLayer/Control/TextureProgressBar")
@onready var skill_e: skillofe = get_node("../skillofE")
@onready var skillofE: skillofe = get_node("../skillofE")
@onready var skillofEProcess: TextureProgressBar = get_node("../skillofE/Control/TextureProgressBar")

@onready var mesh: SphereMesh = meshi.mesh as SphereMesh
@onready var gravity = Gravity.new(9.8, mesh.radius, 0.5)
@onready var enemies = ($".." as Game).enemy_list

# Skill
var recover : Recover
var shield : Shield
var blink : BlinkSkill  # 修改点：替换Sprint为BlinkSkill
var confine : Confine
var atk : Atk
var cri : Cri

# 玩家属性
var acc: Vector3
var fric = 0.85
var hit_timer: float = 0.0
var is_hit: bool = false
var is_last_on_floor: bool = true
var blood: int = 100

# 技能相关
var skill_timer: float = 0.0
var is_skill: bool = false
var ultimate_ball: UltimateBall
var is_ultimate: bool = false

# 速度相关
var max_velocity = 10
var attack_damage = 2
var speed_multiplier: float = 1.0
var is_sprint: bool = false

# 摄像机相关
var camera_1 = 10
var camera_2 = 14.142
var camera_3 = 10
@onready var camera = $Camera3D as Node3D
var current_camera_view: int = 0
@onready var game: Game = $".."

# 暴击率/暴击伤害
var ATK: int = 20
var cri_ch: float = 50
var cri_hit: float = 150
var ulti_mult: float = 10
var skill_mult: float = 1.5

var timer: float = 0.0
const COUNT_INTERVAL: float = 15.0

func _ready() -> void:
	var material = meshi.material_override
	if not material:
		material = StandardMaterial3D.new()
		meshi.material_override = material
	material.albedo_color = Color(0, 1, 1)
	material.emission_enabled = true
	material.emission = Color(0, 1, 1)
	material.emission_energy_multiplier = 0
	
	recover = Recover.new(self)
	shield = Shield.new(self)
	blink = BlinkSkill.new(self)  # 修改点：初始化闪烁技能
	blink.game = game
	confine = Confine.new(self)
	atk = Atk.new(self)
	cri = Cri.new(self)
	
	add_child(shield)
	add_child(blink)    # 修改点：添加闪烁技能节点
	add_child(confine)
	add_child(atk)
	add_child(cri)

func camera_distance():
	return 15 * (log(2 * coll.shape.radius) + 1) / log(10)

func shake_camera():
	var d = camera_distance()
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
		camera.position = Vector3(d, sqrt(2) * d, d) + direc * d / (10 * (log(1) + 1) / log(10))
	camera.position = Vector3(d, sqrt(2) * d, d)

func update_camera_distance():
	var d = camera_distance()
	camera.position = Vector3(d, sqrt(2) * d, d)

func _input(event: InputEvent) -> void:
	if event.is_action_released("3") and blink.is_active:
		blink.deactivate()
		blink.is_active = false

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("KEY_L"):
		current_camera_view = (current_camera_view + 1) % 4
		rotation.y += PI / 2
		if rotation.y >= 2 * PI:
			rotation.y -= 2 * PI
		for enemy in enemies:
			enemy.health_bar.rotation = rotation + camera.rotation
			
	skillofEProcess.value += delta * 1000
	if skillofEProcess.value == skillofEProcess.max_value:
		if skillofE.count < 5:
			skillofE.count += 1
			skillofEProcess.value = 0

	var input_dir = Input.get_vector("KEY_A", "KEY_D", "KEY_W", "KEY_S")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	acc = direction.rotated(Vector3.UP, deg_to_rad(45 + rotation.y)) * \
			(-log(velocity.length() + 0.5) + 5)
	if is_sprint:
		acc *= speed_multiplier
	
	if Input.is_action_just_pressed("3") and acc_inf.value:
		blink.activate()
	
	if Input.is_action_pressed("3") and Input.is_action_just_released("Left_Button") \
		and blink.is_active and acc_inf.value:
		blink.perform_blink()
		blink.deactivate()
		acc_inf.value -= 1

	if Input.is_action_just_pressed("KEY_SHIFT"):
		gravity.charge()
	elif Input.is_action_just_released("KEY_SHIFT"):
		gravity.release()
	
	if Input.is_action_just_pressed("KEY_E") and skillofE.count > 0 and not is_skill:
		skillofE.count -= 1
		is_skill = true
		skill_timer = 0.2
		for enemy in enemies:
			enemy.is_attack_by_skill = false
		enable_glow(Color(0, 0.5019, 1), 0.5)
		skill_emitting()
	
	if Input.is_action_just_pressed("KEY_Q") and ultimate_inf.value == ultimate_inf.max_value:
		ultimate_inf.reset()
		is_ultimate = true
		ultimate_ball = UltimateBall.new()
		ultimate_ball.position = position
		ultimate_ball.player_position_y = position.y
		ultimate_ball.ultimate_ended.connect(_on_ultimate_ended)
		get_parent().add_child(ultimate_ball)
		bigger()
	
	if Input.is_action_just_pressed("1") and recover_inf.value:
		recover.heal(game)
		recover_inf.value -= 1
	if Input.is_action_just_pressed("2") and protect_inf.value:
		shield.activate_shield()
		protect_inf.value -= 1
	if Input.is_action_just_pressed("4") and fixed_inf.value:
		confine.activate_confine()
		fixed_inf.value -= 1
	if Input.is_action_just_pressed("5") and AtkAdd_inf.value:
		atk.benison()
		AtkAdd_inf.value -= 1
	if Input.is_action_just_pressed("6") and cs_inf.value:
		cri.benison()
		cs_inf.value -= 1

func bigger():
	for i in range(48):
		await get_tree().create_timer(0.016).timeout
		mesh.radius += 0.05
		mesh.height += 0.1
		(coll.shape as SphereShape3D).radius += 0.05

var internal_acc_will_release: bool = false

func _physics_process(delta: float) -> void:
	update_camera_distance()

	blood_board.value = blood
	velocity += acc
	if velocity.length() > max_velocity * (speed_multiplier if is_sprint else 1.0):
		velocity = velocity.normalized() * max_velocity * (speed_multiplier if is_sprint else 1.0)

	velocity -= (velocity.normalized() * fric * \
			sqrt(velocity.length() * 0.06)) if gravity.at_floor() else Vector3.ZERO
	gravity.update(delta)
	position.y = gravity.at()
	meshi.scale = gravity.zoom()

	var tmp_position = Vector3(position)
	var tmp_velocity = Vector3(velocity)

	var v = composited_velocity().length()
	if  v < 0.1 and $MeshInstance3D/GPUParticles3D.emitting:
		$MeshInstance3D/GPUParticles3D.emitting = false
	if not $MeshInstance3D/GPUParticles3D.emitting and v >= 0.1:
		$MeshInstance3D/GPUParticles3D.emitting = true
	if is_hit:
		hit_timer -= delta
		if hit_timer <= 0:
			is_hit = false
			$Hit.emitting = false
	if is_skill and is_hit:
		if skill_timer == 0.2:
			$Skill.emitting = true
			is_skill = false
		skill_timer -= delta
		if skill_timer <= 0:
			$Skill.emitting = false
		disable_glow()

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

func _on_ultimate_ended():
	is_ultimate = false
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

func enable_glow(color: Color, intensity: float) -> void:
	var material = meshi.material_override
	if material:
		material.emission = color
		material.emission_energy_multiplier = intensity

func disable_glow() -> void:
	var material = meshi.material_override
	if material:
		material.emission = Color(0, 0, 0)
		material.emission_energy_multiplier = 0.0
		
func balance_blood():
	if blood > 100:
		blood = 100
