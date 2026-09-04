class_name BlockFighterSettingsCodec
extends RefCounted

## ConfigFile의 section/key schema를 한 곳에서 소유한다.
## Settings는 값 검증·migration을, Repository는 파일 I/O만 담당한다.


static func encode(
	schema_version: int,
	action_definitions: Array[Dictionary],
	bindings: Dictionary,
	language: String,
	audio: Dictionary,
	progress: Dictionary
) -> ConfigFile:
	var config := ConfigFile.new()
	config.set_value("meta", "version", schema_version)
	for definition: Dictionary in action_definitions:
		var action_name: StringName = definition["action"]
		config.set_value(
			"input", String(action_name),
			(bindings.get(action_name, []) as Array).duplicate()
		)
	config.set_value("audio", "master_percent", audio["master_percent"])
	config.set_value("audio", "music_percent", audio["music_percent"])
	config.set_value("audio", "sfx_percent", audio["sfx_percent"])
	config.set_value("options", "language", language)
	config.set_value("progress", "star_currency", progress["star_currency"])
	config.set_value("progress", "passive_levels", progress["passive_levels"])
	config.set_value("progress", "challenge_best_lines", progress["challenge_best_lines"])
	config.set_value(
		"progress", "debug_all_characters_unlocked",
		progress["debug_all_characters_unlocked"]
	)
	var stars: Array = progress["stage_best_stars"]
	var no_damage: Array = progress["stage_no_damage_clears"]
	for stage_number: int in range(1, stars.size() + 1):
		config.set_value(
			"progress", _stage_best_key(stage_number), stars[stage_number - 1]
		)
		config.set_value(
			"progress", _stage_no_damage_key(stage_number), no_damage[stage_number - 1]
		)
	return config


static func version(config: ConfigFile) -> int:
	return int(config.get_value("meta", "version", 0))


static func has_binding(config: ConfigFile, action_name: StringName) -> bool:
	return config.has_section_key("input", String(action_name))


static func binding(config: ConfigFile, action_name: StringName, fallback: Array) -> Variant:
	return config.get_value("input", String(action_name), fallback)


static func has_audio(config: ConfigFile, channel: StringName) -> bool:
	return config.has_section_key("audio", _audio_key(channel))


static func audio(config: ConfigFile, channel: StringName, fallback: float = 100.0) -> Variant:
	return config.get_value("audio", _audio_key(channel), fallback)


static func has_language(config: ConfigFile) -> bool:
	return config.has_section_key("options", "language")


static func language(config: ConfigFile, fallback: String) -> Variant:
	return config.get_value("options", "language", fallback)


static func has_debug_unlock(config: ConfigFile) -> bool:
	return config.has_section_key("progress", "debug_all_characters_unlocked")


static func debug_unlock(config: ConfigFile) -> Variant:
	return config.get_value("progress", "debug_all_characters_unlocked", false)


static func has_challenge_best(config: ConfigFile) -> bool:
	return config.has_section_key("progress", "challenge_best_lines")


static func challenge_best(config: ConfigFile) -> Variant:
	return config.get_value("progress", "challenge_best_lines", 0)


static func has_star_currency(config: ConfigFile) -> bool:
	return config.has_section_key("progress", "star_currency")


static func star_currency(config: ConfigFile) -> Variant:
	return config.get_value("progress", "star_currency", 0)


static func has_stage_best(config: ConfigFile, stage_number: int) -> bool:
	return config.has_section_key("progress", _stage_best_key(stage_number))


static func stage_best(config: ConfigFile, stage_number: int) -> Variant:
	return config.get_value("progress", _stage_best_key(stage_number), 0)


static func has_stage_no_damage(config: ConfigFile, stage_number: int) -> bool:
	return config.has_section_key("progress", _stage_no_damage_key(stage_number))


static func stage_no_damage(config: ConfigFile, stage_number: int) -> Variant:
	return config.get_value("progress", _stage_no_damage_key(stage_number), false)


static func has_passive_levels(config: ConfigFile) -> bool:
	return config.has_section_key("progress", "passive_levels")


static func passive_levels(config: ConfigFile) -> Variant:
	return config.get_value("progress", "passive_levels", [])


static func _audio_key(channel: StringName) -> String:
	match channel:
		&"master": return "master_percent"
		&"music": return "music_percent"
		&"sfx": return "sfx_percent"
		_: return ""


static func _stage_best_key(stage_number: int) -> String:
	return "stage_%d_best_stars" % stage_number


static func _stage_no_damage_key(stage_number: int) -> String:
	return "stage_%d_no_damage" % stage_number
