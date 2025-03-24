extends RichTextLabel

@onready var player: BallPlayer = get_node("../../Player")

var default_font = 24  # 调小字体大小
var cur_score = 0
var mutex = Mutex.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 设置幼圆字体
	var font = FontFile.new()
	add_theme_font_override("normal_font", font)
	
	update_display()

func add(score):
	mutex.lock()
	cur_score += score
	update_display()
	mutex.unlock()

# 更新属性显示
func update_display():
	clear()
	push_font_size(default_font)
	
	# 显示分数
	add_text("分数: " + str(cur_score) + "\n")
	
	# 显示攻击力
	add_text("攻击力: " + str(int(player.ATK)) + "\n")
	
	# 显示暴击率 (转换为百分比)
	add_text("暴击率: " + str(int(player.cri_ch)) + "%\n")  # 修正了百分比计算
	
	# 显示暴击伤害 (转换为百分比)
	add_text("暴击伤害: " + str(int(player.cri_hit)) + "%")
	
	pop()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_display()  # 每帧更新显示，确保属性变化实时显示
