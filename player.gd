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

@onready var camera := $Camera2D

func _physics_process(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
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

	move_and_slide()
