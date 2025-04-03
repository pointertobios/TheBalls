# menu.gd
extends Node2D

@onready var ui = $UI
@onready var start_button = $UI/Background/StartButton
@onready var nickname_input = $UI/Background/NicknameInput
@onready var waiting_panel = $UI/WaitingPanel
@onready var waiting_label = $UI/WaitingPanel/Label
@onready var title = $UI/Background/Label

var server_api: ServerAPI
var player_uuid: String = ""

func _ready():
	server_api = ServerAPI.new()
	add_child(server_api)
	server_api.ready_to_start.connect(_start_game)
	# 初始化UI状态
	start_button.visible = true
	nickname_input.visible = false
	waiting_panel.visible = false
	
	# 连接信号
	start_button.pressed.connect(_on_start_pressed)
	nickname_input.text_submitted.connect(_on_nickname_submitted)
	server_api.playerevent(_update_waiting_ui)
	
	# 设置UI样式
	_setup_ui_style()

func _setup_ui_style():
	# 开始按钮样式
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#4a6fa5")
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_bottom_right = 10
	start_button.add_theme_stylebox_override("normal", btn_style)
	
	# 输入框样式
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color("#2e3440")
	input_style.border_color = Color("#4a6fa5")
	input_style.border_width_left = 2
	input_style.border_width_right = 2
	nickname_input.add_theme_stylebox_override("normal", input_style)
	
	# 等待面板样式
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#2e3440", 0.8)
	panel_style.corner_radius_top_left = 15
	panel_style.corner_radius_bottom_right = 15
	waiting_panel.add_theme_stylebox_override("panel", panel_style)

func _on_start_pressed():
	start_button.visible = false
	title.visible = false
	nickname_input.visible = true
	nickname_input.grab_focus()

func _on_nickname_submitted(nickname: String):
	if nickname.strip_edges().is_empty():
		nickname_input.placeholder_text = "昵称不能为空！"
		return
	
	player_uuid = nickname.md5_text()
	print(player_uuid)
	server_api.register_player(player_uuid, nickname)
	
	nickname_input.visible = false
	waiting_panel.visible = true
	waiting_label.text = "等待玩家加入 (1/3)..."

func _update_waiting_ui(msg: String):
	waiting_label.text = msg
	
func _start_game():
	var game = load("res://scene/game.tscn").instantiate()
	get_tree().root.add_child(game)
	queue_free()
