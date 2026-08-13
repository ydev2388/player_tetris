extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const ANIMATION_DATA: Script = preload("res://scripts/character_animation_data.gd")

const CAPTURES: Array[Dictionary] = [
	{"name": "idle_right", "state": "idle", "frame": 0, "flip": false},
	{"name": "idle_left", "state": "idle", "frame": 0, "flip": true},
	{"name": "attack", "state": "attack", "frame": 2, "flip": false},
	{"name": "hang", "state": "hang", "frame": 1, "flip": false},
	{"name": "jump", "state": "jump", "frame": 2, "flip": false},
	{"name": "fall", "state": "jump", "frame": 5, "flip": false},
	{"name": "rotation", "state": "rotation_kick", "frame": 3, "flip": false},
	{"name": "special", "state": "special", "frame": 3, "flip": false},
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: MainGameView = GAME_SCENE.instantiate()
	game.set_meta("stage_number", 1)
	root.add_child(game)
	await process_frame
	await process_frame
	game.controller.state = MainGameController.GameState.PAUSED
	game.character.set_character_id("normal")
	game.character.position = Vector2(5.5 * MainLayout.CELL_SIZE, 17.5 * MainLayout.CELL_SIZE)
	game.character.velocity = Vector2.ZERO

	for capture: Dictionary in CAPTURES:
		var state: String = str(capture["state"])
		var frame: int = int(capture["frame"])
		game.character._animation_state = state
		game.character._animation_time = (
			float(frame) * float(ANIMATION_DATA.FRAME_DURATIONS[state]) + 0.001
		)
		game.character.sprite.flip_h = bool(capture["flip"])
		game.character._apply_animation_frame()
		game.queue_redraw()
		await process_frame
		await process_frame
		RenderingServer.force_draw(true)
		var image: Image = root.get_viewport().get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Failed to capture normal reference state: %s" % str(capture["name"]))
			quit(1)
			return
		var path: String = "res://build/normal_reference_%s.png" % str(capture["name"])
		var error: Error = image.save_png(path)
		if error != OK:
			push_error("Failed to save %s: %s" % [path, error_string(error)])
			quit(1)
			return
		print("Normal reference capture: %s" % ProjectSettings.globalize_path(path))

	game.queue_free()
	await process_frame
	quit(0)
