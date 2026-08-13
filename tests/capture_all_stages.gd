extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	for stage_number: int in range(1, 6):
		var game: MainGameView = GAME_SCENE.instantiate()
		game.set_meta("stage_number", stage_number)
		root.add_child(game)
		await process_frame
		await process_frame
		var controller: MainGameController = game.controller
		if stage_number >= 2:
			controller.active_piece_has_thorns = true
			controller.thorn_visible = stage_number != 3
		if stage_number == 4:
			game.character.apply_binding(2.0)
		if stage_number == 5:
			controller._spawn_boss_seeds()
		controller.game_changed.emit()
		game.queue_redraw()
		await process_frame
		await process_frame
		RenderingServer.force_draw(true)
		var image: Image = root.get_viewport().get_texture().get_image()
		if image == null or image.is_empty():
			push_error("스테이지 %d 캡처 이미지를 가져오지 못했습니다." % stage_number)
			quit(1)
			return
		var path: String = "res://build/stage_1_%d_review.png" % stage_number
		var error: Error = image.save_png(path)
		if error != OK:
			push_error("스테이지 %d 캡처 저장 실패: %s" % [stage_number, error_string(error)])
			quit(1)
			return
		print("스테이지 캡처: %s" % ProjectSettings.globalize_path(path))
		game.queue_free()
		await process_frame
	quit(0)
