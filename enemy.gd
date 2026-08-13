extends CharacterBody2D

@export var patrol_speed := 50.0
@export var chase_speed := 140.0
@export var gravity := 1400.0
@export var health := 3

var direction := 1.0
var target: Node2D = null
@onready var floor_check: RayCast2D = $FloorCheck

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	var current_speed = patrol_speed

	if target != null:
		direction = sign(target.global_position.x - global_position.x)
		current_speed = chase_speed

	# Coloca o FloorCheck na frente do inimigo
	floor_check.position.x = abs(floor_check.position.x) * direction
	floor_check.force_raycast_update()

	# Se não houver chão na frente
	if is_on_floor() and not floor_check.is_colliding():
		if target == null:
			# Patrulhando: vira na borda
			direction *= -1
		else:
			# Perseguindo: não se joga da plataforma
			current_speed = 0.0

	velocity.x = direction * current_speed

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


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		target = body


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		target = null

func _ready():
	direction = [-1.0, 1.0].pick_random()
