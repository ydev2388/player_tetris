extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const ANIMATION_DATA: Script = preload("res://scripts/character_animation_data.gd")
const CHARACTER_DATA: Script = preload("res://scripts/character_data.gd")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: MainGameView = GAME_SCENE.instantiate()
	game.set_meta("stage_number", 1)
	root.add_child(game)
	await process_frame
	await process_frame
	game.controller.state = MainGameController.GameState.PAUSED
	game.character.position = Vector2(5.5 * MainLayout.CELL_SIZE, 17.5 * MainLayout.CELL_SIZE)
	game.character.velocity = Vector2.ZERO

	for character_id: String in CHARACTER_DATA.CHARACTER_ORDER:
		game.character.set_character_id(character_id)
		game.character._animation_state = ANIMATION_DATA.IDLE
		game.character._animation_time = 0.001
		game.character.sprite.flip_h = false
		game.character._apply_animation_frame()
		game.queue_redraw()
		await process_frame
		await process_frame
		RenderingServer.force_draw(true)
		var image: Image = root.get_viewport().get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Failed to capture skin: %s" % character_id)
			quit(1)
			return
		var path: String = "res://build/character_skin_%s.png" % character_id
		var error: Error = image.save_png(path)
		if error != OK:
			push_error("Failed to save %s: %s" % [path, error_string(error)])
			quit(1)
			return
		print("Character skin capture: %s" % ProjectSettings.globalize_path(path))

	game.queue_free()
	await process_frame
	quit(0)
