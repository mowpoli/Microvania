extends CharacterBody2D

@export var max_speed := 200.0
@export var acceleration := 900.0
@export var friction := 1200.0
@export var gravity := 1400.0
@export var jump_force := -550.0
@export var jump_cut := 0.5
@export var coyote_time := 0.12
var coyote_timer := 0.0
@export var jump_buffer_time := 0.12
var jump_buffer_timer := 0.0
@export var camera_look_ahead := 10.0
@export var camera_look_speed := 50.0
var facing_direction := 1.0

@onready var camera := $Camera2D
@onready var attack_hitbox := $AttackArea/CollisionShape2D
@onready var attack_visual := $AttackArea/AttackVisual
@onready var attack_area := $AttackArea

var is_attacking := false
@export var death_y := 650.0
var spawn_position: Vector2
@export var health := 3


func _ready():
	spawn_position = global_position
	attack_hitbox.disabled = true
	attack_area.position.x = 45 * facing_direction

func _physics_process(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		facing_direction = direction
		attack_area.position.x = 45 * facing_direction
	var target_camera_x = direction * camera_look_ahead

	camera.offset.x = move_toward(
		camera.offset.x,
		target_camera_x,
		camera_look_speed * delta
)

	if direction != 0:
		velocity.x = move_toward(
			velocity.x,
			direction * max_speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(
			velocity.x,
			0,
			friction * delta
		)

	if not is_on_floor():
		velocity.y += gravity * delta

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_force
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	if Input.is_action_just_released("ui_accept") and velocity.y < 0:
		velocity.y *= jump_cut

	if global_position.y > death_y:
		global_position = spawn_position
		velocity = Vector2.ZERO

	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()

	move_and_slide()

func attack():
	is_attacking = true
	attack_hitbox.set_deferred("disabled", false)
	attack_visual.visible = true

	await get_tree().create_timer(0.12).timeout

	attack_hitbox.set_deferred("disabled", true)
	attack_visual.visible = false
	is_attacking = false


func _on_checkpoint_body_entered(body: Node2D) -> void:
	if body == self:
		spawn_position = global_position


func _on_attack_area_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage()

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body == self:
		return

	if body.has_method("take_damage"):
		body.take_damage()

func take_damage():
	health -= 1
	print("Player HP: ", health)

	if health <= 0:
		global_position = spawn_position
		velocity = Vector2.ZERO
		health = 3
