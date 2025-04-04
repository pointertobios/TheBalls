extends Node2D

class_name Tests

var worker: TheBallsWorker = TheBallsWorker.connect("127.0.0.1:3000", "0") #

func _init() -> void:
	worker.timeout(func():
		print("timeout")
	)
	worker.connection_failed(func(e):
		print(e)
	)
	worker.started(func():
		print("started")
	)
	worker.player_enter("player1")
	worker.player_enter("player2")
	worker.recv_player_enter(func(name):
		print("player ", name, " entered")
	)

func _exit_tree() -> void:
	worker.exit()
