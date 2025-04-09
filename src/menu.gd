# menu.gd
extends Node2D

@onready var ui = $UI
@onready var start_button = $UI/Background/StartButton
@onready var nickname_input = $UI/Background/NicknameInput
@onready var waiting_panel = $UI/WaitingPanel
@onready var waiting_label = $UI/WaitingPanel/Label
@onready var title = $UI/Background/Label

@onready var game: Game = load("res://scene/game.tscn").instantiate()

var uuid_to_name = {}

signal game_start

func _ready():
	# 初始化UI状态
	start_button.visible = true
	nickname_input.visible = false
	waiting_panel.visible = false
	
	# 连接信号
	start_button.pressed.connect(_on_start_pressed)
	nickname_input.text_submitted.connect(_on_nickname_submitted)
	
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
	
	game.player_uuid = (nickname + str(Time.get_unix_time_from_system())).md5_text()
	print(game.player_uuid)

	game.worker = TheBallsWorker.connect("127.0.0.1:3000", game.player_uuid)
	game.worker.connection_failed(func(e):
		print(e)
	)
	game.worker.timeout(func():
		print("connection timeout")
		#
	)
	game.worker.started(func():
		print("connectiong started")
	)
	game.worker.player_enter(game.player_uuid, nickname)
	game.start_get_player_list(func(ids, names):
		for i in range(len(ids)):
			uuid_to_name[ids[i]] = names[i]
		waiting_label.text = "等待玩家加入 (" + str(len(uuid_to_name)) + "/3)..."
		print("player_list: ", uuid_to_name)
		if len(uuid_to_name) >= 3:
			game_start.emit()
	)
	game.start_get_player_enter(func(uuid, player_name):
		print(player_name, " enter")
		uuid_to_name[uuid] = player_name
		waiting_label.text = "等待玩家加入 (" + str(len(uuid_to_name)) + "/3)..."
		if len(uuid_to_name) >= 3:
			game_start.emit()
	)
	game.start_get_player_exit(func(uuid):
		print(uuid_to_name[uuid], " exit")
		uuid_to_name.erase(uuid)
		waiting_label.text = "等待玩家加入 (" + str(len(uuid_to_name)) + "/3)..."
	)
	
	nickname_input.visible = false
	waiting_panel.visible = true
	waiting_label.text = "等待玩家加入 (" + str(len(uuid_to_name)) + "/3)..."
	
	await _start_game()

func _update_waiting_ui(msg: String):
	waiting_label.text = msg
	
func _start_game():
	await game_start
	game.game_start()
	get_tree().root.add_child(game)
	game.menu_exited = true
	queue_free()

func _exit_tree() -> void:
	if not game.menu_exited and game.worker:
		game.worker.exit()
