extends Node2D

class_name Tests

var worker: TheBallsWorker = TheBallsWorker.connect("127.0.0.1:3000", "0")

func _init() -> void:
	worker.timeout(func ():
		print("timeout")
	)
	worker.connection_failed(func (e):
		print(e)
	)
	worker.started(func ():
		print("started")
	)
