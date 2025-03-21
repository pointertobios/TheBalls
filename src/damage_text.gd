extends Label3D

class_name DamageText

var origin_pos
var upmoving_vel
var horizontal_move
var t = 0.0  # 时间变量
var fade_duration = 1.2  # 总淡出时间
var fade_in_duration = 0.3  # 由 0 到 1 的时间
var fade_out_duration = fade_duration - fade_in_duration  # 由 1 到 0 的时间
var is_cri: bool = false

var moving = LinearMoving.new(func(t):
	return origin_pos.y + log(t + 1) * upmoving_vel
)

# 大于0红色，小于0绿色
func _init(value, pos, is_cri):
	if value >= 0:
		modulate = Color.CRIMSON
	else:
		modulate = Color.CHARTREUSE
		value = -value
	self.is_cri = is_cri
	text = str(int(value)) + ("!!" if is_cri else "")
	#if is_cri:
		#text += "!!"
	#text = str(is_cri) + ("!!" if is_cri else "")
	position = pos
	origin_pos = pos
	no_depth_test = true
	font_size = 5 * log(value * 10) / log(1.2)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	upmoving_vel = randf_range(2, 15)
	if is_cri:
		outline_size = 30
	else:
		outline_size = 0
	outline_modulate = Color.CRIMSON
	var x = randf_range(0, 2 * PI)
	horizontal_move = Vector3(cos(x), 0, sin(x))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	t += delta  # 更新时间变量

	# 计算透明度
	var alpha = 0.0
	if t < fade_in_duration:
		# 由 0 到 1，快速变化
		alpha = t / fade_in_duration
	else:
		# 由 1 到 0，缓慢变化
		alpha = 1.0 - (t - fade_in_duration) / fade_out_duration

	# 设置透明度
	modulate.a = alpha
	outline_modulate.a = alpha

	# 如果时间超过总淡出时间，销毁节点
	if t >= fade_duration:
		queue_free()

func _physics_process(delta: float) -> void:
	moving.update(delta)
	position.y = moving.gen()
	position += horizontal_move * delta
