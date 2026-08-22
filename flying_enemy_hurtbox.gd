extends Area2D


func take_damage() -> void:
	if owner != null and owner.has_method("take_damage"):
		owner.take_damage()
