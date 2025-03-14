extends CharacterBody3D

@onready var meshi = $MeshInstance3D
@onready var mesh = meshi.mesh as SphereMesh
@onready var gravity = Gravity.new(9.8, mesh.radius, 0.5)

var acc: Vector3
var fric = 0.9

func _init() -> void:
	pass

func _process(_delta: float) -> void:
	var input_dir = Input.get_vector("KEY_A", "KEY_D", "KEY_W", "KEY_S")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	acc = direction.rotated(Vector3.UP, deg_to_rad(45)) * \
			(-log(velocity.length() + 0.5) + 2)
	if Input.is_action_pressed("KEY_SHIFT"):
		acc *= 8

	if Input.is_action_pressed("KEY_CTRL"):
		gravity.charge()
	elif Input.is_action_just_released("KEY_CTRL"):
		gravity.release()

func _physics_process(delta: float) -> void:
	velocity += acc
	velocity -= velocity.normalized() * fric * \
			sqrt(velocity.length() * 0.06)

	gravity.update(delta)
	position.y = gravity.at()
	meshi.scale = gravity.zoom()

	move_and_slide()
