extends GPUParticles3D

var default_radius = 0.07
var default_Height = 0.14

var default_player_radius = 0.5
var default_player_height = 1.0



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
		material.damping_min = 0
		material.damping_max = 0
		material.spread = 360
		var sphere_radiu = ($"../MeshInstance3D".mesh as SphereMesh).radius
		amount = int(200 * sphere_radiu * sphere_radiu * 4)
		set_particle_scale(sphere_radiu)  # 调整粒子大小
		

# 动态调整粒子大小
func set_particle_scale(sphere_radius: float) -> void:
	var material = process_material as ParticleProcessMaterial
	if material:
		# 根据球的半径调整粒子大小
		var scale_factor = (default_radius / default_player_radius) * sphere_radius  # 计算缩放比例
		material.emission_ring_radius = scale_factor  # 最小粒子大小
		material.emission_ring_height = scale_factor * 2 # 最大粒子大小
