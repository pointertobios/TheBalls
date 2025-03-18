extends GPUParticles3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	local_coords = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_emission_direction(direction: Vector3) -> void:
	# 获取 process_material
	var material = self.process_material
	if material:
		# 设置粒子的发射方向
		material.direction = direction.normalized()
		material.spread = 5
		# 设置粒子的初始速度
		material.initial_velocity_min = 15  # 最小初始速度
		material.initial_velocity_max = 15  # 最大初始速度
