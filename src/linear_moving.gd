class_name LinearMoving

var formular: Callable
var timer: float = 0

func _init(formular: Callable) -> void:
	self.formular = formular

func update(delta: float):
	timer += delta

func gen():
	return formular.call(timer)

func reset():
	timer = 0
