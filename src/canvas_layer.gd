extends CanvasLayer

@onready var player_ball: TextureRect = $Control/PlayerBall
@onready var ultimate_ball: TextureRect = $Control/UltimateBall

var is_ultimate_ready: bool = false
var is_ultimate_active: bool = false
var ultimate_tween: Tween  # 保存 Tween 引用

func _ready() -> void:
	player_ball.texture = create_circle_texture(32, Color(0, 1, 1))
	ultimate_ball.texture = create_circle_texture(96, Color(1, 1, 1, 0.3))

	player_ball.z_index = 1

	# 设置缩放基准点为底部中心
	var ultimate_texture_size = ultimate_ball.texture.get_size()
	ultimate_ball.pivot_offset = Vector2(ultimate_texture_size.x / 2, ultimate_texture_size.y)
	
	var player_texture_size = player_ball.texture.get_size()
	player_ball.pivot_offset = Vector2(player_texture_size.x / 2, player_texture_size.y)

	align_player_ball()

func align_player_ball() -> void:
	var player_texture_size = player_ball.texture.get_size()
	var ultimate_texture_size = ultimate_ball.texture.get_size()

	# 补偿抗锯齿导致的底部透明边缘
	var edge_compensation = 1
	var player_pos = Vector2(
		30,
		56
	)
	player_ball.position = player_pos

func _process(delta: float) -> void:
	update_ultimate_ball()

func update_ultimate_ball() -> void:
	if is_ultimate_ready and not is_ultimate_active:
		start_ultimate_animation()
	elif not is_ultimate_ready and is_ultimate_active:
		stop_ultimate_animation()

func start_ultimate_animation() -> void:
	is_ultimate_active = true
	ultimate_ball.modulate = Color(0, 1, 1)
	animate_ultimate_ball()

func stop_ultimate_animation() -> void:
	is_ultimate_active = false
	ultimate_ball.modulate = Color(1, 1, 1)
	ultimate_ball.scale = Vector2.ONE

func animate_ultimate_ball() -> void:
	ultimate_tween = create_tween().set_loops()
	ultimate_tween.tween_property(ultimate_ball, "scale", Vector2(1.5, 1.5), 0.5).set_trans(Tween.TRANS_SINE)
	ultimate_tween.tween_property(ultimate_ball, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)

# 暂停大招动画
func pause_ultimate_animation() -> void:
	if ultimate_tween:
		ultimate_tween.pause()

# 恢复大招动画
func resume_ultimate_animation() -> void:
	if ultimate_tween:
		ultimate_tween.play()

func create_circle_texture(size: int, color: Color) -> Texture2D:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var center = Vector2(size / 2, size / 2)
	var radius = size / 2

	for x in range(size):
		for y in range(size):
			var distance = center.distance_to(Vector2(x, y))
			var alpha = 1.0 - smoothstep(radius - 1.5, radius + 0.5, distance)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))

	return ImageTexture.create_from_image(image)

func set_ultimate_ready(ready: bool) -> void:
	is_ultimate_ready = ready
