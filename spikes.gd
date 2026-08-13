extends Area2D

@export var damage := 1

@onready var return_point: Marker2D = $ReturnPoint

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var died = body.take_damage(damage)

		if not died:
			body.global_position = return_point.global_position
			body.velocity = Vector2.ZERO
