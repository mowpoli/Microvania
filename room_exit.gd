extends Area2D

@export_file("*.tscn") var target_scene: String
@export var target_spawn := ""

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		GameState.next_spawn = target_spawn
		get_tree().change_scene_to_file(target_scene)
