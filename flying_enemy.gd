@tool
extends Node2D

const WAKE_RANGE_DEBUG_COLOR := Color(0.15, 0.85, 1.0, 0.9)
const AGGRO_RANGE_DEBUG_COLOR := Color(1.0, 0.35, 0.15, 0.9)
const DEBUG_CIRCLE_SEGMENTS := 96
const AGGRO_DASH_COUNT := 32
const AGGRO_DASH_RATIO := 0.6

enum State {
	SLEEPING,
	HOVERING,
	PREPARING,
	PECKING,
	RECOVERING,
}

@export_category("Stats")
@export var health := 3

@export_category("Activation")
@export_range(1.0, 2000.0, 1.0, "or_greater") var wake_range := 280.0:
	set(value):
		wake_range = value
		_queue_editor_redraw()
@export_range(1.0, 2000.0, 1.0, "or_greater") var aggro_range := 500.0:
	set(value):
		aggro_range = value
		_queue_editor_redraw()

@export_category("Hover")
@export_range(1.0, 1000.0, 1.0, "or_greater") var hover_radius_x := 150.0
@export_range(1.0, 1000.0, 1.0, "or_greater") var hover_radius_y := 70.0
@export_range(1.0, 1000.0, 1.0, "or_greater") var hover_speed := 90.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var approach_speed := 45.0
@export_range(1.0, 3000.0, 1.0, "or_greater") var hover_acceleration := 260.0
@export_range(0.0, 100.0, 0.5, "or_greater") var oscillation_amplitude := 8.0
@export_range(0.0, 10.0, 0.05, "or_greater") var oscillation_frequency := 1.0
@export_range(0.1, 10.0, 0.1, "or_greater") var hover_target_min_time := 0.8
@export_range(0.1, 10.0, 0.1, "or_greater") var hover_target_max_time := 1.8
@export_range(1.0, 100.0, 1.0, "or_greater") var hover_target_tolerance := 12.0
@export_range(0.0, 20.0, 0.1, "or_greater") var hover_turn_speed := 5.0

@export_category("Attack")
@export_range(1.0, 2000.0, 1.0, "or_greater") var attack_range := 220.0
@export_range(0.0, 5.0, 0.05, "or_greater") var preparation_duration := 0.35
@export_range(0.0, 30.0, 0.1, "or_greater") var preparation_turn_speed := 12.0
@export_range(1.0, 3000.0, 1.0, "or_greater") var peck_speed := 460.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var peck_distance := 190.0
@export_range(0.0, 20.0, 0.1, "or_greater") var attack_cooldown := 2.5
@export_range(0, 100, 1, "or_greater") var contact_damage := 1

var state := State.SLEEPING
var target: Node2D
var hover_center := Vector2.ZERO
var hover_target := Vector2.ZERO
var hover_target_timer := 0.0
var oscillation_time := 0.0
var oscillation_phase := 0.0
var preparation_timer := 0.0
var cooldown_timer := 0.0
var peck_direction := Vector2.RIGHT
var peck_start_position := Vector2.ZERO
var dealt_damage_this_peck := false
var facing_direction := 1.0
var obstacle_avoidance_side := 1.0

@onready var body: CharacterBody2D = $Body
@onready var visual: Node2D = $Body/Visual
@onready var wake_shape: CollisionShape2D = $WakeArea/CollisionShape2D
@onready var line_of_sight: RayCast2D = $LineOfSight


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	oscillation_phase = randf_range(0.0, TAU)
	_configure_wake_range()
	line_of_sight.add_exception(body)
	body.velocity = Vector2.ZERO
	body.rotation = 0.0
	visual.scale.x = facing_direction
	hover_center = body.position
	obstacle_avoidance_side = -1.0 if randf() < 0.5 else 1.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if state == State.SLEEPING:
		body.velocity = Vector2.ZERO
		return

	if not is_instance_valid(target):
		target = null

	if not _is_target_in_aggro_range() and state in [State.PREPARING, State.PECKING]:
		_return_to_hover()

	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	oscillation_time += delta

	match state:
		State.HOVERING:
			_process_hover(delta)
		State.PREPARING:
			_process_preparation(delta)
		State.PECKING:
			_process_peck()
		State.RECOVERING:
			_process_recovery(delta)

	var collision := body.move_and_collide(body.velocity * delta)
	_handle_motion_collision(collision)

	if state == State.PECKING:
		var traveled := body.global_position.distance_to(peck_start_position)
		if traveled >= peck_distance:
			_finish_peck()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	draw_arc(
		Vector2.ZERO,
		wake_range,
		0.0,
		TAU,
		DEBUG_CIRCLE_SEGMENTS,
		WAKE_RANGE_DEBUG_COLOR,
		2.0,
		true
	)

	var dash_angle := TAU / AGGRO_DASH_COUNT
	for dash_index in AGGRO_DASH_COUNT:
		var start_angle := dash_index * dash_angle
		draw_arc(
			Vector2.ZERO,
			aggro_range,
			start_angle,
			start_angle + dash_angle * AGGRO_DASH_RATIO,
			4,
			AGGRO_RANGE_DEBUG_COLOR,
			3.0,
			true
		)


func _queue_editor_redraw() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		queue_redraw()


func _process_hover(delta: float) -> void:
	_process_hover_motion(delta)
	body.rotation = 0.0
	_update_hover_facing()

	if _can_start_attack():
		_start_preparation()


func _process_hover_motion(delta: float) -> void:
	_update_hover_approach(delta)

	hover_target_timer -= delta
	var current_hover_target := hover_center + hover_target
	if (
		hover_target_timer <= 0.0
		or body.position.distance_to(current_hover_target) <= hover_target_tolerance
	):
		_choose_hover_target()
		current_hover_target = hover_center + hover_target

	var vertical_offset := sin(
		oscillation_time * TAU * oscillation_frequency + oscillation_phase
	) * oscillation_amplitude
	var desired_position := current_hover_target + Vector2(0.0, vertical_offset)
	var to_destination := desired_position - body.position
	var desired_velocity := to_destination * 2.5
	if desired_velocity.length() > hover_speed:
		desired_velocity = desired_velocity.normalized() * hover_speed

	body.velocity = body.velocity.move_toward(
		desired_velocity,
		hover_acceleration * delta
	)


func _update_hover_approach(delta: float) -> void:
	if approach_speed <= 0.0 or not _is_target_in_aggro_range():
		return

	var has_clear_line_of_sight := _has_clear_line_of_sight()
	if (
		body.global_position.distance_to(target.global_position) <= attack_range
		and has_clear_line_of_sight
	):
		return

	var target_local_position := to_local(target.global_position)
	var approach_direction := (target_local_position - body.position).normalized()
	if approach_direction == Vector2.ZERO:
		return

	if not has_clear_line_of_sight:
		var lateral_direction := Vector2(-approach_direction.y, approach_direction.x)
		approach_direction = (
			approach_direction + lateral_direction * obstacle_avoidance_side * 0.85
		).normalized()

	hover_center += approach_direction * approach_speed * delta


func _process_recovery(delta: float) -> void:
	_process_hover_motion(delta)
	body.rotation = rotate_toward(body.rotation, 0.0, hover_turn_speed * delta)

	if is_zero_approx(body.rotation):
		body.rotation = 0.0
		state = State.HOVERING
		_update_hover_facing()


func _process_preparation(delta: float) -> void:
	body.velocity = body.velocity.move_toward(
		Vector2.ZERO,
		hover_acceleration * delta
	)

	if not is_instance_valid(target):
		_return_to_hover()
		return

	var direction_to_player := target.global_position - body.global_position
	if direction_to_player.length_squared() > 0.001:
		body.rotation = rotate_toward(
			body.rotation,
			_body_rotation_for_direction(direction_to_player),
			preparation_turn_speed * delta
		)

	preparation_timer -= delta
	if preparation_timer <= 0.0:
		_begin_peck()


func _process_peck() -> void:
	# The direction is deliberately fixed when preparation ends.
	body.velocity = peck_direction * peck_speed


func _can_start_attack() -> bool:
	if cooldown_timer > 0.0 or not _is_target_in_aggro_range():
		return false
	if body.global_position.distance_to(target.global_position) > attack_range:
		return false
	return _has_clear_line_of_sight()


func _start_preparation() -> void:
	if not is_instance_valid(target):
		return

	_update_hover_facing()
	state = State.PREPARING
	preparation_timer = preparation_duration


func _begin_peck() -> void:
	if not is_instance_valid(target):
		_return_to_hover()
		return

	peck_direction = (target.global_position - body.global_position).normalized()
	if peck_direction == Vector2.ZERO:
		peck_direction = Vector2.from_angle(body.rotation)

	state = State.PECKING
	peck_start_position = body.global_position
	dealt_damage_this_peck = false
	body.rotation = _body_rotation_for_direction(peck_direction)
	body.velocity = peck_direction * peck_speed


func _finish_peck() -> void:
	cooldown_timer = attack_cooldown
	_return_to_hover()


func _return_to_hover() -> void:
	state = State.RECOVERING
	_choose_hover_target()


func _update_hover_facing() -> void:
	if not _is_target_in_aggro_range():
		return

	var horizontal_distance := target.global_position.x - body.global_position.x
	if not is_zero_approx(horizontal_distance):
		facing_direction = signf(horizontal_distance)
		visual.scale.x = facing_direction


func _body_rotation_for_direction(direction_to_target: Vector2) -> float:
	var desired_rotation := direction_to_target.angle()
	if facing_direction < 0.0:
		desired_rotation -= PI
	return wrapf(desired_rotation, -PI, PI)


func _has_clear_line_of_sight() -> bool:
	if not is_instance_valid(target):
		return false

	line_of_sight.global_position = body.global_position
	line_of_sight.target_position = line_of_sight.to_local(target.global_position)
	line_of_sight.force_raycast_update()

	if not line_of_sight.is_colliding():
		return true

	var collider := line_of_sight.get_collider() as Node
	return collider != null and _is_player(collider)


func _choose_hover_target() -> void:
	# sqrt() distributes destinations throughout the ellipse instead of
	# concentrating them around its center.
	var angle := randf_range(0.0, TAU)
	var radius_factor := sqrt(randf())
	hover_target = Vector2(
		cos(angle) * hover_radius_x,
		sin(angle) * hover_radius_y
	) * radius_factor

	var minimum_time := minf(hover_target_min_time, hover_target_max_time)
	var maximum_time := maxf(hover_target_min_time, hover_target_max_time)
	hover_target_timer = randf_range(minimum_time, maximum_time)


func _wake_up(player: Node2D) -> void:
	if state != State.SLEEPING:
		return

	target = player
	state = State.HOVERING
	cooldown_timer = attack_cooldown
	oscillation_time = 0.0
	_choose_hover_target()


func _is_target_in_aggro_range() -> bool:
	return (
		is_instance_valid(target)
		and body.global_position.distance_to(target.global_position) <= aggro_range
	)


func _configure_wake_range() -> void:
	var circle := wake_shape.shape as CircleShape2D
	if circle == null:
		return

	circle = circle.duplicate() as CircleShape2D
	circle.radius = wake_range
	wake_shape.shape = circle


func _handle_motion_collision(collision: KinematicCollision2D) -> void:
	if collision == null:
		return

	if state == State.PECKING:
		var collider := collision.get_collider() as Node
		if collider != null and _is_player(collider):
			_damage_player_once(collider)
		_finish_peck()
	else:
		body.velocity = Vector2.ZERO
		hover_center = body.position
		obstacle_avoidance_side *= -1.0
		_choose_hover_target()


func _damage_player_once(player: Node) -> void:
	if dealt_damage_this_peck or contact_damage <= 0:
		return
	if player.has_method("take_damage"):
		player.take_damage(contact_damage)
		dealt_damage_this_peck = true


func take_damage() -> void:
	if Engine.is_editor_hint():
		return

	health -= 1
	if health <= 0:
		queue_free()


func _is_player(candidate: Node) -> bool:
	return candidate.name == &"Player" or candidate.is_in_group(&"player")


func _on_wake_area_body_entered(detected_body: Node2D) -> void:
	if Engine.is_editor_hint():
		return

	if _is_player(detected_body):
		if state == State.SLEEPING:
			_wake_up(detected_body)
		elif not is_instance_valid(target):
			target = detected_body


func _on_damage_area_body_entered(detected_body: Node2D) -> void:
	if Engine.is_editor_hint():
		return

	if state == State.PECKING and _is_player(detected_body):
		_damage_player_once(detected_body)


# Keeps old scene overrides loadable while migrating from the previous script.
func _set(property: StringName, value: Variant) -> bool:
	if property == &"ideal_distance":
		attack_range = float(value)
		return true
	if property == &"activation_radius":
		wake_range = float(value)
		return true
	return false
