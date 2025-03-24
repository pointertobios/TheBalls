extends Control

# 尖刺相关参数
var spike_count: int = 4  # 尖刺数量
var spike_spacing: float = 20.0  # 尖刺间距
var spike_height: float = 40.0  # 尖刺高度
var spike_width: float = 20.0  # 尖刺宽度
var spike_offset: float = 20.0  # 尖刺下降的距离
var current_offset: float = 0.0  # 尖刺的当前偏移量

# 是否正在播放动画
var is_animating: bool = false

# 绘制尖刺
func _draw() -> void:
	for i in range(spike_count):
		# 计算尖刺的位置
		var x = i * spike_spacing
		var y = current_offset

		# 定义尖刺的顶点（三角形）
		var spike_points = [
			Vector2(x - spike_width / 2, y + spike_height),  # 左下角
			Vector2(x, y),                                   # 顶部
			Vector2(x + spike_width / 2, y + spike_height)   # 右下角
		]

		# 绘制尖刺（填充颜色为蓝色）
		draw_polygon(spike_points, [Color(0, 1, 1, 0.8)])

# 播放尖刺动画
func play_spike_animation(is_down: bool) -> void:
	var tween = create_tween()
	var target_offset = current_offset + (spike_offset if is_down else -spike_offset)
	tween.tween_property(self, "current_offset", target_offset, 0.5)

	# 等待动画完成
	await tween.finished

	# 如果播放的是下降动画，则播放升起动画
	if is_down:
		play_spike_animation(false)
	else:
		# 动画完成，重置状态
		is_animating = false
		#update()  # 调用 update() 触发 _draw()

# 触发尖刺动画
func trigger_spike_animation() -> void:
	if not is_animating:
		is_animating = true
		play_spike_animation(true)
