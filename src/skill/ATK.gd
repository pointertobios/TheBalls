extends Node

class_name Atk

# 攻击力增加
@export var atk_add: float = 30

#技能持续时间
@export var duration: float = 30.0  # 持续 10 秒

# 玩家节点
var player: BallPlayer


# 初始化时传入玩家对象
func _init(player_node: BallPlayer) -> void:
	self.player = player_node

# 暴击爆伤增益
func benison() -> void:
	if player:
		# 确保节点已经添加到场景树
		if not is_inside_tree():
			await ready  # 等待节点添加到场景树
		player.ATK += atk_add
		# 启动计时器，10 秒后恢复
		benison_begin()
	else:
		print("错误：玩家节点未初始化！")

# 启动疾跑计时器
func benison_begin() -> void:
	# 确保节点已经添加到场景树
	if not is_inside_tree():
		await ready  # 等待节点添加到场景树

	await get_tree().create_timer(duration).timeout  # 等待 10 秒
	benison_end()  # 10 秒后禁用疾跑

# 禁用疾跑技能
func benison_end() -> void:
	if player:
		player.ATK -= atk_add
		# 恢复玩家原始速度
