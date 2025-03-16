extends RichTextLabel

var default_font = 40
var cur_score
var mutex = Mutex.new()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	push_font_size(default_font)
	add_text("0")
	cur_score = 0
	pop()

func add(score):
	mutex.lock()
	cur_score += score
	clear()
	push_font_size(default_font)
	add_text(str(cur_score))
	pop()
	mutex.unlock()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
