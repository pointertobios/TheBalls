extends Node

class_name Sprint

# 疾跑速度倍数
@export var speed_multiplier: float = 6.0

# 疾跑持续时间
@export var duration: float = 10.0  # 持续 10 秒

# 玩家节点
var player: BallPlayer

# 玩家原始速度
var original_speed: float

var is_sprint: bool = false


# 初始化时传入玩家对象
func _init(player_node: BallPlayer) -> void:
	self.player = player_node

# 启用疾跑技能
func activate_sprint() -> void:
	if player:
		# 确保节点已经添加到场景树
		if not is_inside_tree():
			await ready  # 等待节点添加到场景树

		# 设置疾跑状态
		player.is_sprint = true
		player.speed_multiplier = 10.0  # 速度变为 5 倍

		# 启动计时器，10 秒后恢复原始速度
		start_sprint_timer()
	else:
		print("错误：玩家节点未初始化！")

# 启动疾跑计时器
func start_sprint_timer() -> void:
	# 确保节点已经添加到场景树
	if not is_inside_tree():
		await ready  # 等待节点添加到场景树

	await get_tree().create_timer(duration).timeout  # 等待 10 秒
	disable_sprint()  # 10 秒后禁用疾跑

# 禁用疾跑技能
func disable_sprint() -> void:
	if player:
		# 恢复玩家原始速度
		player.is_sprint = false
		player.speed_multiplier = 1.0  # 恢复原始速度
