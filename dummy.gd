extends Area2D

@export var health := 3

func take_damage():
	health -= 1
	print("Dummy HP: ", health)

	if health <= 0:
		queue_free()
