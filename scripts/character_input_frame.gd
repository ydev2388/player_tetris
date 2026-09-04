class_name MainCharacterInputFrame
extends RefCounted

## Immutable input snapshot captured once per physics frame.
var horizontal: float
var jump_pressed: bool
var jump_held: bool
var jump_released: bool
var punch_pressed: bool
var special_pressed: bool
var rotation_pressed: bool
var grab_held: bool
var climb_up_held: bool
var meditate_held: bool
var self_respawn_held: bool


func _init(
	p_horizontal: float = 0.0,
	p_jump_pressed: bool = false,
	p_jump_held: bool = false,
	p_jump_released: bool = false,
	p_punch_pressed: bool = false,
	p_special_pressed: bool = false,
	p_rotation_pressed: bool = false,
	p_grab_held: bool = false,
	p_climb_up_held: bool = false,
	p_meditate_held: bool = false,
	p_self_respawn_held: bool = false
) -> void:
	horizontal = clampf(p_horizontal, -1.0, 1.0)
	jump_pressed = p_jump_pressed
	jump_held = p_jump_held
	jump_released = p_jump_released
	punch_pressed = p_punch_pressed
	special_pressed = p_special_pressed
	rotation_pressed = p_rotation_pressed
	grab_held = p_grab_held
	climb_up_held = p_climb_up_held
	meditate_held = p_meditate_held
	self_respawn_held = p_self_respawn_held
