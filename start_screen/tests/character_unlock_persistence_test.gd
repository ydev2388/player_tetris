extends SceneTree

const TEST_SETTINGS_PATH: String = "res://build/character_unlock_persistence_test.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	var settings := StartScreenSettings.new(TEST_SETTINGS_PATH)
	settings.load_settings()
	_expect(settings.is_character_unlocked("normal"), "normal starts unlocked")
	_expect(not settings.is_character_unlocked("boxer"), "boxer starts locked")

	var first_result: Dictionary = settings.complete_stage(1, 3, 3, true)
	_expect(bool(first_result.get("ok", false)), "three-star debug clear saves")
	_expect(settings.is_character_unlocked("boxer"), "three stars unlock boxer")
	_expect(not settings.is_character_unlocked("shield_guard"), "six-star character stays locked")

	var reloaded := StartScreenSettings.new(TEST_SETTINGS_PATH)
	reloaded.load_settings()
	_expect(reloaded.get_total_best_stars() == 3, "best-star total reloads")
	_expect(reloaded.is_character_unlocked("boxer"), "boxer unlock reapplies after restart")
	_expect(reloaded.is_stage_cleared_without_damage(1), "no-damage clear reloads")

	for stage_number: int in range(2, StartScreenSettings.STAGE_COUNT + 1):
		var result: Dictionary = reloaded.complete_stage(stage_number, 3, 3, true)
		_expect(bool(result.get("ok", false)), "stage %d progress saves" % stage_number)
	_expect(reloaded.is_character_unlocked("clockmaker"), "fifteen stars unlock clockmaker")
	_expect(reloaded.is_character_unlocked("ninja"), "all no-damage clears unlock ninja")

	var final_reload := StartScreenSettings.new(TEST_SETTINGS_PATH)
	final_reload.load_settings()
	for character_id: String in MainCharacterData.CHARACTER_ORDER:
		_expect(
			final_reload.is_character_unlocked(character_id),
			"%s unlock survives restart" % character_id
		)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	settings.free()
	reloaded.free()
	final_reload.free()
	print("CHARACTER_UNLOCK_PERSISTENCE_RESULT failures=", _failures)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
