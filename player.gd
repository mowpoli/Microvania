extends CharacterBody2D

@export var max_speed := 200.0
@export var acceleration := 900.0
@export var turn_acceleration := 1800.0
@export var friction := 1200.0
@export var gravity := 1400.0
@export var fall_gravity := 1800.0
@export var max_fall_speed := 900.0
@export var jump_force := -600.0
@export var jump_cut := 0.5
@export var coyote_time := 0.12
var coyote_timer := 0.0
@export var jump_buffer_time := 0.12
var jump_buffer_timer := 0.0
@export var dash_speed := 1000.0
@export var dash_duration := 0.22
@export var dash_cooldown := 1.00

var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var air_dash_available := true
@export var camera_look_ahead := 10.0
@export var camera_look_speed := 50.0
var facing_direction := 1.0

@onready var camera := $Camera2D
@onready var attack_hitbox := $AttackArea/CollisionShape2D
@onready var attack_visual := $AttackArea/AttackVisual
@onready var attack_area := $AttackArea
@onready var health_label = $CanvasLayer/HealthLabel
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var is_attacking := false
@export var health := 3


func _ready():
	health = GameState.current_health
	attack_hitbox.disabled = true
	attack_area.position.x = 45 * facing_direction
	update_health_label()

func _physics_process(delta):
	var direction = Input.get_axis("ui_left", "ui_right")

	if direction != 0:
		facing_direction = direction
		attack_area.position.x = 45 * facing_direction
		anim.flip_h = facing_direction < 0

	var target_camera_x = direction * camera_look_ahead

	camera.offset.x = move_toward(
		camera.offset.x,
		target_camera_x,
		camera_look_speed * delta
	)

	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)

	if is_on_floor():
		air_dash_available = true

	if GameState.has_dash and Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_dashing:
		if is_on_floor() or air_dash_available:
			is_dashing = true
			dash_timer = dash_duration
			dash_cooldown_timer = dash_cooldown

			if not is_on_floor():
				air_dash_available = false

	if is_dashing:
		velocity.x = facing_direction * dash_speed
		velocity.y = 0.0

		dash_timer -= delta

		move_and_slide()

		if dash_timer <= 0.0:
			is_dashing = false
			velocity.x = 0.0

		return

	if direction != 0:
		var current_acceleration = acceleration

		if velocity.x != 0 and sign(velocity.x) != direction:
			current_acceleration = turn_acceleration

		velocity.x = move_toward(
			velocity.x,
			direction * max_speed,
			current_acceleration * delta
		)
	else:
		velocity.x = move_toward(
			velocity.x,
			0,
			friction * delta
		)

	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += fall_gravity * delta
		else:
			velocity.y += gravity * delta

		velocity.y = min(velocity.y, max_fall_speed)

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

	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()

	if not is_attacking:
		if abs(velocity.x) > 5:
			anim.play("walk")
		else:
			anim.play("idle")

	move_and_slide()

func attack():
	is_attacking = true
	anim.play("bite")
	attack_hitbox.set_deferred("disabled", false)
	attack_visual.visible = true

	await get_tree().create_timer(0.12).timeout

	attack_hitbox.set_deferred("disabled", true)
	attack_visual.visible = false

	if anim.is_playing():
		await anim.animation_finished

	is_attacking = false


func _on_checkpoint_body_entered(body: Node2D, marker_path := "Checkpoint") -> void:
	if body != self:
		return

	var current_scene := get_tree().current_scene
	if current_scene != null:
		GameState.respawn_scene = current_scene.scene_file_path
		GameState.respawn_marker = marker_path


func _on_attack_area_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage()

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body == self:
		return

	if body.has_method("take_damage"):
		body.take_damage()

func take_damage(amount := 1) -> bool:
	health -= amount
	GameState.current_health = health
	update_health_label()
	print("Player HP: ", health)

	if health <= 0:
		velocity = Vector2.ZERO
		health = GameState.max_health
		GameState.current_health = GameState.max_health
		GameState.next_spawn = GameState.respawn_marker
		update_health_label()
		get_tree().change_scene_to_file(GameState.respawn_scene)
		return true

	return false

func update_health_label():
	health_label.text = "HP: " + str(health)
