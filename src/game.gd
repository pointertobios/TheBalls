extends Node3D

class_name Game

var enemy_scene: Resource = load("res://scene/enemy.tscn")

var player_scene: Resource = load("res://scene/player.tscn")


# 最大敌人数量
@export var max_enemies: int = 5
@export var max_value: float = 100.0  #// 最大值
@export var current_value: float = 0.0  #// 当前值
var player_list = {}



var enemy_list = []

# 当前生成的敌人数量
var current_enemies: int = 0

# 生成敌人的计时器
var spawn_timer: float = 0.0

var worker: TheBallsWorker

#游戏是否开始
var is_running: bool = false

func set_status(status: bool):
	is_running = status

var menu_exited = false

func start_get_player_enter(call: Callable):
	worker.recv_player_enter(func (uuid: String, name: String):
		player_list[uuid] = player_scene.instantiate()
		if not menu_exited:
			call.call(uuid, name)
	)


func game_start():
	is_running = true
	worker.recv_scene_sync(func (objs: Array):
		for obj in objs:
			var uuid = obj[0]
			var cur_player: BallPlayer = player_list[uuid]
			cur_player.mesh.radius = obj[1]
			cur_player.position = obj[2]
			cur_player.velocity = obj[3]
			cur_player.velocity.y = 0
			cur_player.gravity.v = obj[3].y
			cur_player.acc = obj[4]
			cur_player.acc.y = 0
			cur_player.gravity.fast_jump = obj[5]
			cur_player.gravity.charging = obj[6]
			cur_player.gravity.charging_keep = obj[7]
	)



func _ready() -> void:
	# 初始化计时器
	spawn_timer = 3.0

func _process(delta: float) -> void:
	pass
	# 如果当前敌人数量小于最大数量，并且计时器小于等于0，生成敌人
	#if current_enemies < max_enemies:
		#spawn_timer -= delta
		#if spawn_timer <= 0:
			#spawn_enemy()
			#spawn_timer = 3.0  # 重置计时器

func spawn_enemy() -> void:
	# 实例化敌人场景
	var enemy_instance = enemy_scene.instantiate()
	enemy_list.append(enemy_instance)
	enemy_instance.add_to_group("enemies")
	# 将敌人添加到场景中
	add_child(enemy_instance)
	
	
	# 增加当前敌人数量
	current_enemies += 1
	
	# 连接敌人的死亡信号（假设敌人有一个信号在死亡时发出）
	#enemy_scene.connect("enemy_died", self, "_on_enemy_died")

func _on_enemy_died() -> void:
	# 当敌人死亡时，减少当前敌人数量
	current_enemies -= 1
