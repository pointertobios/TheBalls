extends Node
class_name ServerAPI

signal ready_to_start

var connected_players = []
var player_callbacks = []

func register_player(uuid: String, nickname: String):
	connected_players.append({"uuid": uuid, "name": nickname})
	_notify_players("玩家加入: %s (%d/3)" % [nickname, connected_players.size()])
	_check_ready()

func playerevent(callback: Callable):
	player_callbacks.append(callback)
	# 改用SceneTree定时器确保安全
	get_tree().create_timer(4.0).timeout.connect(
		func(): 
			_simulate_other_players(), 
		CONNECT_ONE_SHOT
	)

func _notify_players(message: String):
	for cb in player_callbacks:
		cb.call(message)

func _simulate_other_players():
	# 模拟两个AI玩家加入
	if connected_players.size() < 3:
		register_player("ai_1", "AI玩家1")
		get_tree().create_timer(4).timeout.connect(
			func(): 
				if connected_players.size() < 3:
					register_player("ai_2", "AI玩家2"),
			CONNECT_ONE_SHOT
		)

func _check_ready():
	if connected_players.size() >= 3:
		ready_to_start.emit()
		_notify_players("所有玩家已就绪！")
