extends RichTextLabel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	push_font_size(40)
	add_text("Score: ")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
