class_name BlockFighterSettingsRepository
extends RefCounted

const SETTINGS_CODEC: Script = preload("res://start_screen/scripts/settings_codec.gd")

var settings_path: String


func _init(path: String) -> void:
	settings_path = path


func load_config() -> Dictionary:
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	return {
		"ok": error == OK,
		"missing": error == ERR_FILE_NOT_FOUND,
		"error": error,
		"config": config,
	}


func save(
	schema_version: int,
	action_definitions: Array[Dictionary],
	bindings: Dictionary,
	language: String,
	audio: Dictionary,
	progress: Dictionary
) -> Error:
	var config: ConfigFile = SETTINGS_CODEC.encode(
		schema_version,
		action_definitions,
		bindings,
		language,
		audio,
		progress
	)
	return config.save(settings_path)
