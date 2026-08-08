extends CharacterBody2D

@export var speed := 80.0
@export var gravity := 1400.0
@export var health := 3

var direction := 1.0

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	velocity.x = direction * speed

	move_and_slide()

	if is_on_wall():
		direction *= -1

func take_damage():
	health -= 1
	print("Enemy HP: ", health)

	if health <= 0:
		queue_free()


func _on_damage_area_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage()
