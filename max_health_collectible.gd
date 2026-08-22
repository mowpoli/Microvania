extends Area2D

@export var collection_state := &"sala11_health_upgrade_collected"
@export_range(0.0, 50.0, 0.5, "or_greater") var hover_amplitude := 6.0
@export_range(0.0, 10.0, 0.05, "or_greater") var hover_frequency := 1.25

var collected := false
var hover_time := 0.0
var visual_start_position := Vector2.ZERO

@onready var visual: Node2D = $Visual


func _ready() -> void:
	if bool(GameState.get(collection_state)):
		queue_free()
		return

	visual_start_position = visual.position


func _process(delta: float) -> void:
	hover_time += delta
	visual.position = visual_start_position + Vector2(
		0.0,
		sin(hover_time * TAU * hover_frequency) * hover_amplitude
	)


func _on_body_entered(body: Node2D) -> void:
	if collected or not _is_player(body):
		return

	collected = true
	monitoring = false
	GameState.set(collection_state, true)
	GameState.max_health += 1
	GameState.current_health = GameState.max_health
	body.set(&"health", GameState.max_health)
	if body.has_method("update_health_label"):
		body.update_health_label()
	queue_free()


func _is_player(candidate: Node) -> bool:
	return candidate.name == &"Player" or candidate.is_in_group(&"player")
