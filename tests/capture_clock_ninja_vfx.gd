extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: MainGameView = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var controller: MainGameController = game.controller
	var character: MainCharacterController = game.character
	character.position = Vector2(5.0 * MainLayout.CELL_SIZE, 14.0 * MainLayout.CELL_SIZE)

	character.set_character_id("clockmaker")
	character.play_special_animation()
	character._special_animation_remaining = 0.25
	controller.freeze_falling_blocks(3.0)
	await _save_frame(game, "res://design/character_vfx_sources/vfx_clockmaker_review.png")

	controller.clear_fall_freeze()
	character.set_character_id("ninja")
	character.play_special_animation()
	character._special_animation_remaining = 0.35
	character._ninja_special_result = {
		"success": true,
		"contact": MainGameController.SHURIKEN_CONTACT_ACTIVE,
		"travel_cells": 4,
		"impact_cell": Vector2i(9, 16),
		"direction": 1,
	}
	await _save_frame(game, "res://design/character_vfx_sources/vfx_ninja_success_review.png")

	character.play_special_animation()
	character._special_animation_remaining = 0.20
	character._ninja_special_result = {
		"success": false,
		"contact": MainGameController.SHURIKEN_CONTACT_FIXED,
		"travel_cells": 3,
		"impact_cell": Vector2i(8, 16),
		"direction": 1,
	}
	await _save_frame(game, "res://design/character_vfx_sources/vfx_ninja_failure_review.png")

	game.queue_free()
	await process_frame
	quit(0)


func _save_frame(game: MainGameView, path: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.is_empty():
		push_error("VFX 검토 viewport 이미지를 가져오지 못했습니다: %s" % path)
		quit(1)
		return
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("VFX 검토 이미지를 저장하지 못했습니다: %s" % path)
		quit(1)
