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
	screen.show_stage_select()
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("스테이지 선택 화면 이미지를 가져오지 못했습니다.")
		quit(1)
		return
	var output_path: String = ProjectSettings.globalize_path(
		"res://build/stage_select_preview.png"
	)
	var error: Error = image.save_png(output_path)
	if error != OK:
		push_error("스테이지 선택 화면 캡처 실패: %s" % error_string(error))
		quit(1)
		return
	print("스테이지 선택 화면 캡처: %s" % output_path)
	quit(0)
