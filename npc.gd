extends Node2D

var player_nearby := false

@onready var interaction_prompt: Label = $InteractionPrompt
@onready var dialogue_box: PanelContainer = $DialogueBox


func _ready() -> void:
	set_process_unhandled_input(not GameState.has_dash)


func _unhandled_input(event: InputEvent) -> void:
	if not player_nearby or GameState.has_dash:
		return

	if event.is_action_pressed("interact"):
		interaction_prompt.visible = false
		dialogue_box.visible = true
		GameState.has_dash = true
		set_process_unhandled_input(false)
		get_viewport().set_input_as_handled()


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true
		interaction_prompt.visible = not GameState.has_dash


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		interaction_prompt.visible = false
		dialogue_box.visible = false
