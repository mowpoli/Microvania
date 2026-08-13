extends Node2D

@onready var player = $Player
@onready var camera = $Player/Camera2D
@onready var camera_top_left = $CameraTopLeft
@onready var camera_bottom_right = $CameraBottomRight

func _ready():
	camera.limit_left = int(camera_top_left.global_position.x)
	camera.limit_top = int(camera_top_left.global_position.y)
	camera.limit_right = int(camera_bottom_right.global_position.x)
	camera.limit_bottom = int(camera_bottom_right.global_position.y)

	if GameState.next_spawn != "":
		var spawn = get_node_or_null(GameState.next_spawn)

		if spawn != null:
			player.global_position = spawn.global_position
			player.spawn_position = spawn.global_position

		GameState.next_spawn = ""
