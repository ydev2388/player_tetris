extends SceneTree

const START_SCREEN_SCENE: PackedScene = preload(
	"res://start_screen/scenes/start_screen.tscn"
)


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var screen: KungFuTetrisStartScreen = START_SCREEN_SCENE.instantiate()
	root.add_child(screen)
	await process_frame
	screen.show_character_select()
	await process_frame
	await process_frame
	if not _save_viewport("res://build/character_select_preview.png"):
		quit(1)
		return
	for _step: int in range(5):
		screen._shift_character_window(1)
	screen._select_character("clockmaker")
	await process_frame
	await process_frame
	if not _save_viewport("res://build/character_select_clock_ninja_preview.png"):
		quit(1)
		return
	quit(0)


func _save_viewport(resource_path: String) -> bool:
	RenderingServer.force_draw(true)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("캐릭터 선택 화면 viewport 이미지를 가져오지 못했습니다.")
		return false
	var output_path: String = ProjectSettings.globalize_path(resource_path)
	var error: Error = image.save_png(output_path)
	if error != OK:
		push_error("캐릭터 선택 화면 캡처 실패: %s" % error_string(error))
		return false
	print("캐릭터 선택 화면 캡처: %s" % output_path)
	return true
