extends Node3D

class_name Game

var enemy_scene: Resource = load("res://scene/enemy.tscn")

var player_scene: Resource = load("res://scene/player.tscn")


# 最大敌人数量
@export var max_enemies: int = 5
@export var max_value: float = 100.0 # // 最大值
@export var current_value: float = 0.0 # // 当前值
var player_list: Dictionary = {}
var enemy_list = {}

var player_uuid: String = ""


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

func spawn_player(uuid, player_name, pos):
	player_list[uuid] = player_scene.instantiate()
	player_list[uuid].uuid = uuid
	player_list[uuid].player_name = player_name
	player_list[uuid].position = pos
	if uuid != player_uuid:
		for node in player_list[uuid].get_children():
			if node.name == "Camera3D":
				node.queue_free()
	add_child(player_list[uuid])

func start_get_player_list(callback: Callable):
	worker.recv_player_list(func(uuids, names):
		for i in range(len(uuids)):
			if len(names[i]) == 0:
				continue
			spawn_player(uuids[i], names[i], Vector3(0, 0, 0))
		if not menu_exited:
			callback.call(uuids, names)
	)

func start_get_player_enter(callback: Callable):
	worker.recv_player_enter(func(uuid: String, player_name: String, pos):
		spawn_player(uuid, player_name, Vector3(pos[0], pos[1], pos[2]))
		if not menu_exited:
			callback.call(uuid, player_name)
	)

func start_get_player_exit(callback: Callable):
	worker.recv_player_exit(func(uuid: String):
		remove_child(player_list[uuid])
		player_list.erase(uuid)
		if not menu_exited:
			callback.call(uuid)
	)

func game_start():
	is_running = true
	worker.recv_scene_sync(func(objs: Array):
		for obj in objs:
			var uuid = obj[0]
			if obj[1]: # is_player
				if uuid == player_uuid:
					continue
				if !player_list.has(uuid):
					return
				var cur_player: BallPlayer = player_list[uuid]
				cur_player.mesh.radius = obj[2]
				cur_player.position = Vector3(obj[3][0], obj[3][1], obj[3][2])
				cur_player.gravity.y = obj[3][1]
				cur_player.velocity = Vector3(obj[4][0], obj[4][1], obj[4][2])
				cur_player.velocity.y = 0
				cur_player.gravity.v = obj[4][1]
				cur_player.acc = Vector3(obj[5][0], obj[5][1], obj[5][2])
				cur_player.acc.y = 0
				cur_player.gravity.fast_jump = obj[6]
				cur_player.gravity.charging = obj[7]
				cur_player.gravity.charging_keep = obj[8]
			else: # is_enemy
				if !enemy_list.has(uuid):
					return
				var ene: Enemy = enemy_list[uuid]
				ene.mesh.radius = obj[2]
				ene.position = Vector3(obj[3][0], obj[3][1], obj[3][2])
				ene.gravity.y = obj[3][1]
				ene.velocity = Vector3(obj[4][0], obj[4][1], obj[4][2])
				ene.velocity.y = 0
				ene.gravity.v = obj[4][1]
				ene.acc = Vector3(obj[5][0], obj[5][1], obj[5][2])
				ene.acc.y = 0
				ene.gravity.fast_jump = obj[6]
				ene.gravity.charging = obj[7]
				ene.gravity.charging_keep = obj[8]
	)
	worker.recv_enemy_spawn(func(uuid, pos, hp, color):
		spawn_enemy(
			uuid,
			Vector3(pos[0], pos[1], pos[2]),
			hp,
			Color(color[0], color[1], color[2]))
	)
	worker.recv_enemy_took_damage(func(uuid, damage, source_uuid, ulti):
		if ulti:
			enemy_list[uuid].take_ulti_damage(damage, player_list[source_uuid])
		else:
			enemy_list[uuid].take_damage(damage, player_list[source_uuid])
	)
	worker.recv_enemy_die(func(uuid):
		enemy_list[uuid].die()
		enemy_list[uuid].queue_free()
		enemy_list.erase(uuid)
	)

func _ready() -> void:
	# 初始化计时器
	spawn_timer = 3.0

func _process(_delta: float) -> void:
	pass

func spawn_enemy(uuid, pos, hp, color) -> void:
	# 实例化敌人场景
	var enemy_instance = enemy_scene.instantiate()
	enemy_list[uuid] = enemy_instance
	enemy_instance.add_to_group("enemies")
	enemy_instance.uuid = uuid
	enemy_instance.position = pos
	enemy_instance.max_health = hp
	# 将敌人添加到场景中
	add_child(enemy_instance)
	enemy_instance.set_enemy_color(color)
	
	# 增加当前敌人数量
	current_enemies += 1

func _on_enemy_died() -> void:
	# 当敌人死亡时，减少当前敌人数量
	current_enemies -= 1

func _exit_tree() -> void:
	if worker:
		worker.exit()

func get_local_player() -> BallPlayer:
	return player_list[player_uuid]

func any_player_confined() -> bool:
	for player in player_list.values():
		if player.confine.is_confine:
			return true
	return false
