class_name MainCharacterInputAdapter
extends RefCounted

## The only production boundary that reads Godot's global Input singleton.
func capture() -> MainCharacterInputFrame:
	return MainCharacterInputFrame.new(
		Input.get_axis(&"character_left", &"character_right"),
		Input.is_action_just_pressed(&"character_jump"),
		Input.is_action_pressed(&"character_jump"),
		Input.is_action_just_released(&"character_jump"),
		Input.is_action_just_pressed(&"character_punch"),
		Input.is_action_just_pressed(&"character_special"),
		Input.is_action_just_pressed(&"character_rotation_kick"),
		Input.is_action_pressed(&"character_grab"),
		Input.is_action_pressed(&"character_climb_up"),
		Input.is_action_pressed(&"character_meditate"),
		Input.is_action_pressed(&"character_self_respawn")
	)
