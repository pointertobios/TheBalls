extends GPUParticles3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# 设置径向加速度
func set_radial_acceleration(accel: float) -> void:
	var material = process_material as ParticleProcessMaterial
	if material:
		material.radial_accel_min = accel
		material.radial_accel_max = accel
		material.initial_velocity_min = 5
		material.initial_velocity_max = 10
		material.damping_min = 5
		material.damping_max = 5
		material.spread = 360
