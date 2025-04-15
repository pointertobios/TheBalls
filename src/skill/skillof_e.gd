extends CanvasLayer

class_name skillofe

@onready var control: Control = $Control
@onready var player_ball: TextureRect = $Control/PlayerBall
@onready var spikes: Array = [
	$Control/Spike1,
	$Control/Spike2,
	$Control/Spike3,
	$Control/Spike4,
	$Control/Spike5
]
@onready var SkillOfEProcessl: TextureProgressBar = $Control/TextureProgressBar


# 尖刺动画参数
var spike_move_distance: float = 100.0  # 尖刺移动的距离
var spike_move_duration: float = 0.5   # 尖刺移动的时长

# 球动画参数
var ball_move_distance: float = 100.0  # 球移动的距离
var ball_move_duration: float = 0.5    # 球移动的时长

var default_pos = Vector2(483, 70)  # 球的初始位置

# 尖刺数量
var count: int = 5

# 尖刺状态
enum SpikeState { IDLE, FALLING, RISING }
var spike_state: SpikeState = SpikeState.IDLE

func _ready() -> void:
	# 初始化尖刺的位置
	for spike in spikes:
		spike.position = Vector2(spike.position.x, 0)  # 初始位置

	# 设置 Control 节点的裁剪范围
	control.clip_contents = true
	control.size = Vector2(700, 200)  # 只显示上半部分

	# 根据 count 更新尖刺的显示状态
	update_spikes_visibility()

	# 初始化球
	player_ball.texture = create_circle_texture(64, Color(0, 1, 1))
	player_ball.z_index = 0  # 球在底层

	# 设置尖刺的 z_index，确保尖刺在球的上方
	for spike in spikes:
		spike.z_index = 1

	# 设置缩放基准点为底部中心
	var player_texture_size = player_ball.texture.get_size()
	player_ball.pivot_offset = Vector2(player_texture_size.x / 2, player_texture_size.y)

	align_player_ball()

func align_player_ball() -> void:
	# 重置球的位置到初始位置
	player_ball.position = default_pos

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

func _process(delta: float) -> void:
	# 检测 E 键是否被按下
	if Input.is_action_just_pressed("KEY_E") and spike_state == SpikeState.IDLE:
		start_falling_animation()
	update_spikes_visibility()

# 根据 count 更新尖刺的显示状态
func update_spikes_visibility() -> void:
	for i in range(spikes.size()):
		spikes[i].visible = (i < count)  # 如果 i < count，显示尖刺；否则隐藏

# 开始下降动画
func start_falling_animation() -> void:
	spike_state = SpikeState.FALLING

	# 尖刺下降动画（如果有尖刺）
	if count > 0:
		for i in range(count):
			var spike = spikes[i]
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(spike, "position", Vector2(spike.position.x, spike_move_distance), spike_move_duration).set_trans(Tween.TRANS_SINE)
			tween.tween_property(spike, "modulate", Color(1, 1, 1, 0), spike_move_duration).set_trans(Tween.TRANS_SINE)
			tween.connect("finished", self._on_falling_finished)

	# 球上升动画（无论是否有尖刺）
	var ball_tween = create_tween()
	ball_tween.tween_property(player_ball, "position", Vector2(player_ball.position.x, player_ball.position.y - ball_move_distance), ball_move_duration).set_trans(Tween.TRANS_SINE)
	ball_tween.connect("finished", self._on_ball_falling_finished)

# 下降动画完成
func _on_falling_finished() -> void:
	spike_state = SpikeState.RISING
	start_rising_animation()

# 球下降动画完成
func _on_ball_falling_finished() -> void:
	# 如果没有尖刺，直接让球回到初始位置
	if count == 0:
		var reset_tween = create_tween()
		reset_tween.tween_property(player_ball, "position", default_pos, ball_move_duration).set_trans(Tween.TRANS_SINE)
		reset_tween.connect("finished", self._on_rising_finished)
	else:
		start_ball_rising_animation()

# 开始上升动画
func start_rising_animation() -> void:
	# 尖刺上升动画（如果有尖刺）
	if count > 0:
		for i in range(count):
			var spike = spikes[i]
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(spike, "position", Vector2(spike.position.x, 0), spike_move_duration).set_trans(Tween.TRANS_SINE)
			tween.tween_property(spike, "modulate", Color(1, 1, 1, 1), spike_move_duration).set_trans(Tween.TRANS_SINE)
			tween.connect("finished", self._on_rising_finished)

	# 球下降动画（无论是否有尖刺）
	start_ball_rising_animation()

# 开始球下降动画
func start_ball_rising_animation() -> void:
	var ball_tween = create_tween()
	ball_tween.tween_property(player_ball, "position", Vector2(player_ball.position.x, player_ball.position.y + ball_move_distance), ball_move_duration).set_trans(Tween.TRANS_SINE)
	ball_tween.connect("finished", self._on_rising_finished)

# 上升动画完成
func _on_rising_finished() -> void:
	spike_state = SpikeState.IDLE
	# 如果count为0，确保球回到初始位置
	if count == 0:
		player_ball.position = default_pos

# 减少尖刺数量
func reduce_spike_count() -> void:
	if count > 0:
		count -= 1
		update_spikes_visibility()  # 更新尖刺的显示状态
		# 如果count变为0，让球回到初始位置
		if count == 0:
			var reset_tween = create_tween()
			reset_tween.tween_property(player_ball, "position", default_pos, ball_move_duration).set_trans(Tween.TRANS_SINE)

# 增加尖刺数量
func increase_spike_count() -> void:
	if count < spikes.size():
		count += 1
		update_spikes_visibility()  # 更新尖刺的显示状态
