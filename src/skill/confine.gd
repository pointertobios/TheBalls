extends Node

class_name Confine

#隐身盾持续时间
@export var duration: float = 10.0  # 持续 10 秒

var is_confine: bool = false

# 玩家节点
var player: BallPlayer


# 初始化时传入玩家对象
func _init(player_node: BallPlayer) -> void:
	self.player = player_node


# 启用隐藏
func activate_confine() -> void:
	if player:
		is_confine = true
		# 确保节点已经添加到场景树
		if not is_inside_tree():
			await ready  # 等待节点添加到场景树
		player.meshi.material_override.transparency = 0
		start_hind_timer()
	else:
		print("错误：玩家节点未初始化！")

func start_hind_timer() -> void:
	# 确保节点已经添加到场景树
	if not is_inside_tree():
		await ready  # 等待节点添加到场景树

	await get_tree().create_timer(duration).timeout  # 等待 10 秒
	is_confine = false
