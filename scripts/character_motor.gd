class_name MainCharacterMotor
extends RefCounted

## Owns kinematic/hang runtime state and is the only component that invokes move_and_slide.
var is_hanging: bool = false
var hang_body: Node2D
var hang_last_global_position: Vector2 = Vector2.ZERO
var hang_active_origin: Vector2i = Vector2i.ZERO
var hang_top_global_y: float = 0.0
var hang_bottom_global_y: float = 0.0
var hang_face_global_x: float = 0.0
var hang_animation_direction: float = 0.0
var hang_corner_climb_active: bool = false
var hang_corner_climb_start_global: Vector2 = Vector2.ZERO
var hang_corner_climb_target_global: Vector2 = Vector2.ZERO
var hang_corner_climb_progress: float = 0.0
var hang_corner_climb_duration: float = 0.0


func is_grounded(body: CharacterBody2D) -> bool:
	return body.is_on_floor()


func move(body: CharacterBody2D) -> void:
	body.move_and_slide()


func approach_horizontal_velocity(
	body: CharacterBody2D,
	target_speed: float,
	acceleration: float,
	delta: float
) -> void:
	body.velocity.x = move_toward(body.velocity.x, target_speed, acceleration * maxf(delta, 0.0))


func apply_gravity(
	body: CharacterBody2D,
	grounded: bool,
	gravity: float,
	fall_multiplier: float,
	maximum_fall_speed: float,
	delta: float
) -> void:
	if grounded:
		return
	var multiplier := fall_multiplier if body.velocity.y > 0.0 else 1.0
	body.velocity.y = minf(
		body.velocity.y + gravity * multiplier * maxf(delta, 0.0),
		maximum_fall_speed
	)


func clamp_position(
	body: CharacterBody2D,
	minimum_x: float,
	maximum_x: float,
	minimum_y: float,
	maximum_y: float
) -> void:
	body.position.x = clampf(body.position.x, minimum_x, maximum_x)
	body.position.y = clampf(body.position.y, minimum_y, maximum_y)


func reset_hang() -> void:
	is_hanging = false
	hang_body = null
	hang_last_global_position = Vector2.ZERO
	hang_active_origin = Vector2i.ZERO
	hang_top_global_y = 0.0
	hang_bottom_global_y = 0.0
	hang_face_global_x = 0.0
	hang_animation_direction = 0.0
	hang_corner_climb_active = false
	hang_corner_climb_start_global = Vector2.ZERO
	hang_corner_climb_target_global = Vector2.ZERO
	hang_corner_climb_progress = 0.0
	hang_corner_climb_duration = 0.0
