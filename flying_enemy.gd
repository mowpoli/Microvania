extends Node2D

@export_range(0.0, 1000.0, 1.0, "or_greater") var patrol_speed := 80.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var horizontal_acceleration := 240.0
@export_range(0.0, 50.0, 0.5, "or_greater") var vertical_amplitude := 8.0
@export_range(0.0, 10.0, 0.05, "or_greater") var vertical_frequency := 1.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var approach_speed := 140.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var approach_acceleration := 300.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var ideal_distance := 120.0
@export_range(0.0, 5.0, 0.05, "or_greater") var preparation_duration := 0.35
@export_range(0.0, 2000.0, 1.0, "or_greater") var dive_speed := 420.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var reposition_speed := 120.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var vertical_recovery_speed := 160.0

enum AttackPhase {
	APPROACH,
	PREPARING,
	DIVING,
	REPOSITIONING
}

var direction := 1.0
var oscillation_time := 0.0
var oscillation_phase := 0.0
var base_height := 0.0
var target: Node2D = null
var attack_phase := AttackPhase.APPROACH
var preparation_timer := 0.0
var dive_direction := Vector2.ZERO
var dive_start_position := Vector2.ZERO

@onready var body: CharacterBody2D = $Body
@onready var left_limit: Marker2D = $PatrolPoints/LeftLimit
@onready var right_limit: Marker2D = $PatrolPoints/RightLimit


func _ready() -> void:
	direction = [-1.0, 1.0].pick_random()
	oscillation_phase = randf_range(0.0, TAU)
	base_height = body.position.y
	body.position.y = base_height + sin(oscillation_phase) * vertical_amplitude


func _physics_process(delta: float) -> void:
	var patrol_min_x: float = minf(left_limit.position.x, right_limit.position.x)
	var patrol_max_x: float = maxf(left_limit.position.x, right_limit.position.x)
	var has_target := is_instance_valid(target)
	var is_diving := false
	var started_inside_patrol := (
		body.position.x >= patrol_min_x and body.position.x <= patrol_max_x
	)

	if not has_target:
		target = null
		attack_phase = AttackPhase.APPROACH

	oscillation_time += delta

	if has_target:
		var hover_velocity := cos(
			oscillation_time * TAU * vertical_frequency + oscillation_phase
		) * vertical_amplitude * TAU * vertical_frequency

		match attack_phase:
			AttackPhase.APPROACH:
				var to_player := target.global_position - body.global_position
				var desired_velocity := Vector2(0.0, hover_velocity)

				if to_player.length() > ideal_distance:
					desired_velocity += to_player.normalized() * approach_speed
				else:
					attack_phase = AttackPhase.PREPARING
					preparation_timer = preparation_duration

				body.velocity = body.velocity.move_toward(
					desired_velocity,
					approach_acceleration * delta
				)

			AttackPhase.PREPARING:
				var desired_velocity := Vector2(0.0, hover_velocity)
				body.velocity = body.velocity.move_toward(
					desired_velocity,
					approach_acceleration * delta
				)
				preparation_timer -= delta

				if preparation_timer <= 0.0:
					dive_direction = (
						target.global_position - body.global_position
					).normalized()
					if dive_direction == Vector2.ZERO:
						dive_direction = Vector2(direction, 0.0)
					dive_start_position = body.global_position
					attack_phase = AttackPhase.DIVING

			AttackPhase.DIVING:
				body.velocity = dive_direction * dive_speed
				is_diving = true

			AttackPhase.REPOSITIONING:
				var to_player := target.global_position - body.global_position
				var distance_error := to_player.length() - ideal_distance
				var desired_height := target.global_position.y - ideal_distance
				var height_error := desired_height - body.global_position.y
				var desired_velocity := Vector2(
					clampf(
						to_player.x * 4.0,
						-reposition_speed,
						reposition_speed
					),
					clampf(
						height_error * 4.0,
						-vertical_recovery_speed,
						vertical_recovery_speed
					)
				)
				desired_velocity.y += hover_velocity

				var movement_without_hover := body.velocity - Vector2(0.0, hover_velocity)
				if (
					absf(distance_error) <= 8.0
					and absf(height_error) <= 8.0
					and movement_without_hover.length() <= 15.0
				):
					attack_phase = AttackPhase.PREPARING
					preparation_timer = preparation_duration

				body.velocity = body.velocity.move_toward(
					desired_velocity,
					approach_acceleration * delta
				)
	else:
		if is_equal_approx(patrol_min_x, patrol_max_x):
			body.velocity.x = move_toward(body.velocity.x, 0.0, horizontal_acceleration * delta)
		else:
			var stopping_distance := body.velocity.x * body.velocity.x / (2.0 * horizontal_acceleration)

			if body.position.x <= patrol_min_x:
				direction = 1.0
			elif body.position.x >= patrol_max_x:
				direction = -1.0
			elif direction > 0.0 and body.velocity.x > 0.0 and body.position.x >= patrol_max_x - stopping_distance:
				direction = -1.0
			elif direction < 0.0 and body.velocity.x < 0.0 and body.position.x <= patrol_min_x + stopping_distance:
				direction = 1.0

			body.velocity.x = move_toward(
				body.velocity.x,
				direction * patrol_speed,
				horizontal_acceleration * delta
			)

		var target_height := base_height + sin(
			oscillation_time * TAU * vertical_frequency + oscillation_phase
		) * vertical_amplitude
		body.velocity.y = (target_height - body.position.y) / delta

	body.move_and_slide()

	if is_diving:
		var dive_distance := body.global_position.distance_to(dive_start_position)
		if dive_distance >= maxf(ideal_distance * 2.0, 1.0) or body.get_slide_collision_count() > 0:
			attack_phase = AttackPhase.REPOSITIONING

	if has_target:
		base_height = body.position.y - sin(
			oscillation_time * TAU * vertical_frequency + oscillation_phase
		) * vertical_amplitude
	else:
		if started_inside_patrol:
			body.position.x = clampf(body.position.x, patrol_min_x, patrol_max_x)

		for collision_index in body.get_slide_collision_count():
			var collision := body.get_slide_collision(collision_index)
			if collision.get_normal().x > 0.5:
				direction = 1.0
				break
			if collision.get_normal().x < -0.5:
				direction = -1.0
				break


func _on_detection_area_body_entered(detected_body: Node2D) -> void:
	if detected_body.name == "Player":
		target = detected_body
		attack_phase = AttackPhase.APPROACH


func _on_detection_area_body_exited(detected_body: Node2D) -> void:
	if detected_body == target:
		target = null
		attack_phase = AttackPhase.APPROACH
