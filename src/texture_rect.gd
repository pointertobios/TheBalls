#SkillIcon.gd
extends TextureRect

@export var cooldown_time: float = 1.0  # 冷却时间
@onready var cooldown_label: Label = $Label  # 冷却倒计时标签

var is_cooldown: bool = false  # 是否在冷却中
var cooldown_timer: float = 0.0  # 冷却计时器
var skill_nums: int

func _ready():
	# 初始化 Shader
	material = ShaderMaterial.new()
	material.shader = load("res://shader/skill_icon_shader.gdshader")
	material.set_shader_parameter("progress", 1.0)  # 初始状态为可用

	# 检查 CooldownLabel 是否初始化成功
	if cooldown_label == null:
		print("CooldownLabel is null! Check the node path.")
	else:
		cooldown_label.visible = false  # 初始隐藏冷却倒计时

func _process(delta: float):
	# 检测是否按下 E 键
	#if Input.is_action_just_pressed("E"):  # 假设 "use_skill" 是 E 键的输入动作
		#if is_skill_ready():  # 检查技能是否可用
			#use_skill()  # 使用技能
			#start_cooldown()  # 开始冷却

	if is_cooldown:
		# 更新冷却计时器
		cooldown_timer -= delta
		cooldown_timer = max(cooldown_timer, 0.0)  # 确保计时器不小于 0

		# 更新冷却进度
		var progress = 1.0 - (cooldown_timer / cooldown_time)
		material.set_shader_parameter("progress", progress)

		# 更新冷却倒计时标签
		if cooldown_label != null:
			cooldown_label.text = "%0.1f" % cooldown_timer

		# 冷却结束后恢复技能
		if cooldown_timer <= 0.0:
			end_cooldown()

func get_progress_bar_value() -> int:
	# 获取子节点 TextureProgressBar
	var progress_bar = $TextureProgressBar
	# 返回 value 值
	return progress_bar.value

func use_skill():
	# 技能使用的逻辑

	# 减少 TextureProgressBar 的值
	var progress_bar = $TextureProgressBar
	progress_bar.value = max(progress_bar.value, 0)  # 确保值不小于 0

func start_cooldown():
	if is_cooldown:
		return  # 如果已经在冷却中，直接返回

	# 进入冷却状态
	is_cooldown = true
	cooldown_timer = cooldown_time
	if cooldown_label != null:
		cooldown_label.visible = true  # 显示冷却倒计时

func end_cooldown():
	# 结束冷却状态
	is_cooldown = false
	material.set_shader_parameter("progress", 1.0)  # 恢复为完全可用
	if cooldown_label != null:
		cooldown_label.visible = false  # 隐藏冷却倒计时

func is_skill_ready() -> bool:
	# 检查 TextureProgressBar 的值是否大于 0 且不在冷却中
	var progress_bar = $TextureProgressBar
	return progress_bar.value > 0 && !is_cooldown
