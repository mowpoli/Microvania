extends Node2D

@onready var player = $Player

func _ready():
	if GameState.next_spawn != "":
		var spawn = get_node_or_null(GameState.next_spawn)

		if spawn != null:
			player.global_position = spawn.global_position
			player.spawn_position = spawn.global_position

		GameState.next_spawn = ""
