extends TextureProgressBar

class_name ulti_bar

# 剩余需要增加的能量值
var remaining_value: float = 0.0

var add_velocity: float = 300

var mutex = Mutex.new()

# 平滑增加能量的函数
func smooth_set_value(target_value: float) -> void:
	# 将目标值累加到 remaining_value
	remaining_value += target_value

# 在 _process 中处理剩余能量
func _process(delta: float) -> void:
	if value < remaining_value:
		value += add_velocity * delta
	if value > max_value:
		value = max_value
	#print(value, ":", remaining_value)

func reset() -> void:
	remaining_value = 0
	value = 0
