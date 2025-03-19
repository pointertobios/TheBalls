extends GPUParticles3D

class_name Skill

@onready var game: Game = $"../../"
@onready var player: BallPlayer = $"../"

@export var collision_radius: float = 4  # 碰撞检测半径

var default_collision_radius = 5

var default_player_radius = 0.5
var default_player_height = 1.0

@export var base_damage: float = 20.0
@export var ultimate_damage_multiplier: float = 2.0

func get_damage() -> float:
	if player.is_ultimate:
		return base_damage * ultimate_damage_multiplier
	return base_damage



func _ready() -> void:
	position.y -= 5


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# 设置径向加速度
func set_radial_acceleration(accel: float) -> void:
	var material = process_material as ParticleProcessMaterial
	if material:
		#material.radial_accel_min = accel
		#material.radial_accel_max = accel
		material.initial_velocity_min = 10
		material.initial_velocity_max = 10
		material.damping_min = 10
		material.damping_max = 10
		material.spread = 0
		material.gravity = Vector3(0, -80, 0)
		material.direction = Vector3(0, 1, 0)
		var sphere_radiu = ($"../MeshInstance3D".mesh as SphereMesh).radius
		material.emission_sphere_radius = sphere_radiu * 5
		if sphere_radiu == 0.5:
			amount = 200
		else:
			amount = int(200 * sphere_radiu * sphere_radiu)
		collision_radius = sphere_radiu * 5
