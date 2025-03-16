extends GPUParticles3D

@onready var game: Game = $"../../"

@export var collision_radius: float = 5  # 碰撞检测半径


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
