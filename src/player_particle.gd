extends GPUParticles3D

@onready var player: BallPlayer = $"../.."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var material = process_material as ParticleProcessMaterial
	if material:
		material.direction = -player.velocity.normalized() + Vector3(0, player.gravity.v, 0)
		material.initial_velocity_min = 5
		material.initial_velocity_max = 5
		material.spread = 15
