extends Node

class_name Recover

# 默认回血量
@export var heal_amount: float = 8.0

# 玩家节点
var player: BallPlayer

func _init(player):
	self.player = player

# 回血函数
func heal(game: Game) -> void:
	# 调用玩家的回血方法
	player.blood += heal_amount
	player.balance_blood()
	var recover = DamageText.new(-heal_amount, player.position, false)
	game.add_child(recover)
