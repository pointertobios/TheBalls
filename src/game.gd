extends Node3D

@onready var enemy_scene = load("res://scene/enemy.tscn")

# 最大敌人数量
@export var max_enemies: int = 5

# 当前生成的敌人数量
var current_enemies: int = 0

# 生成敌人的计时器
var spawn_timer: float = 0.0

func _ready() -> void:
	# 初始化计时器
	spawn_timer = 3.0

func _process(delta: float) -> void:
	# 如果当前敌人数量小于最大数量，并且计时器小于等于0，生成敌人
	if current_enemies < max_enemies:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_enemy()
			spawn_timer = 3.0  # 重置计时器

func spawn_enemy() -> void:
	# 实例化敌人场景
	var enemy_instance = enemy_scene.instantiate()
	# 将敌人添加到场景中
	add_child(enemy_instance)
	
	# 设置敌人的初始位置（可以根据需要调整）
	enemy_instance.position = Vector3(randf_range(-50, 50), 0, randf_range(-50, 50))
	
	
	# 增加当前敌人数量
	current_enemies += 1
	
	# 连接敌人的死亡信号（假设敌人有一个信号在死亡时发出）
	#enemy_scene.connect("enemy_died", self, "_on_enemy_died")

func _on_enemy_died() -> void:
	# 当敌人死亡时，减少当前敌人数量
	current_enemies -= 1
