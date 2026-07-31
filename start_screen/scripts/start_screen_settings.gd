class_name StartScreenSettings
extends Node

signal bindings_changed
signal audio_changed
signal settings_error(message: String)

const DEFAULT_SETTINGS_PATH: String = "user://start_screen_settings.cfg"
const MUSIC_BUS: StringName = &"BGM"
const SFX_BUS: StringName = &"SFX"
const INPUT_ACTIONS: Script = preload("res://scripts/input_actions.gd")
const ACTION_DEFINITIONS: Array[Dictionary] = INPUT_ACTIONS.DEFINITIONS
const SELF_RESPAWN_ACTION: StringName = &"character_self_respawn"
const SELF_RESPAWN_MIGRATION_KEYS: Array[int] = [KEY_Q, KEY_K, KEY_BACKSPACE]

var settings_path: String = DEFAULT_SETTINGS_PATH
var music_percent: float = 100.0
var sfx_percent: float = 100.0

var _bindings: Dictionary = {}


func _init(custom_settings_path: String = DEFAULT_SETTINGS_PATH) -> void:
	settings_path = custom_settings_path


func _ready() -> void:
	load_settings()
	ensure_audio_buses()
	apply_bindings()
	apply_audio()


func get_action_definitions() -> Array[Dictionary]:
	return INPUT_ACTIONS.get_definitions()


func get_action_label(action_name: StringName) -> String:
	var definition: Dictionary = _definition_for(action_name)
	return String(definition.get("label", String(action_name)))


func get_action_keys(action_name: StringName) -> Array[int]:
	var result: Array[int] = []
	var values: Array = _bindings.get(action_name, [])
	for value: Variant in values:
		result.append(int(value))
	return result


func get_binding_text(action_name: StringName) -> String:
	var parts: PackedStringArray = []
	for key_code: int in get_action_keys(action_name):
		if key_code != KEY_NONE:
			parts.append(keycode_to_text(key_code))
	return " / ".join(parts)


func get_slot_text(action_name: StringName, slot_index: int) -> String:
	var keys: Array[int] = get_action_keys(action_name)
	if slot_index < 0 or slot_index >= keys.size() or keys[slot_index] == KEY_NONE:
		return "미지정"
	return keycode_to_text(keys[slot_index])


func set_binding(action_name: StringName, slot_index: int, key_code: int) -> Dictionary:
	var definition: Dictionary = _definition_for(action_name)
	if definition.is_empty():
		return _failure("알 수 없는 입력 동작입니다.")

	var slot_count: int = int(definition.get("slots", 1))
	if slot_index < 0 or slot_index >= slot_count:
		return _failure("변경할 수 없는 키 슬롯입니다.")
	if key_code == KEY_NONE:
		return _failure("주 키는 비워둘 수 없습니다.")

	var conflict: Dictionary = find_conflict(key_code, action_name, slot_index)
	if not conflict.is_empty():
		return _failure(
			"%s 키는 이미 '%s'에 사용 중입니다."
			% [keycode_to_text(key_code), String(conflict.get("label", ""))]
		)

	var keys: Array[int] = get_action_keys(action_name)
	while keys.size() < slot_count:
		keys.append(KEY_NONE)
	keys[slot_index] = key_code
	_bindings[action_name] = keys
	apply_bindings()
	save_settings()
	bindings_changed.emit()
	return {"ok": true, "message": "%s 키가 변경되었습니다." % get_action_label(action_name)}


func clear_secondary_binding(action_name: StringName) -> Dictionary:
	var definition: Dictionary = _definition_for(action_name)
	if definition.is_empty() or int(definition.get("slots", 1)) < 2:
		return _failure("보조 키가 없는 동작입니다.")

	var keys: Array[int] = get_action_keys(action_name)
	while keys.size() < 2:
		keys.append(KEY_NONE)
	keys[1] = KEY_NONE
	_bindings[action_name] = keys
	apply_bindings()
	save_settings()
	bindings_changed.emit()
	return {"ok": true, "message": "%s 보조 키를 지웠습니다." % get_action_label(action_name)}


func find_conflict(
	key_code: int,
	ignored_action: StringName = &"",
	ignored_slot: int = -1
) -> Dictionary:
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = definition["action"]
		var keys: Array[int] = get_action_keys(action_name)
		for slot_index: int in range(keys.size()):
			if action_name == ignored_action and slot_index == ignored_slot:
				continue
			if keys[slot_index] == key_code:
				return {
					"action": action_name,
					"slot": slot_index,
					"label": definition["label"],
				}
	return {}


func reset_bindings_to_defaults() -> void:
	_load_default_bindings()
	apply_bindings()
	save_settings()
	bindings_changed.emit()


func apply_bindings() -> void:
	INPUT_ACTIONS.apply_bindings(_bindings)


func set_music_percent(value: float) -> void:
	music_percent = clampf(value, 0.0, 100.0)
	_apply_bus_volume(MUSIC_BUS, music_percent)
	save_settings()
	audio_changed.emit()


func set_sfx_percent(value: float) -> void:
	sfx_percent = clampf(value, 0.0, 100.0)
	_apply_bus_volume(SFX_BUS, sfx_percent)
	save_settings()
	audio_changed.emit()


func ensure_audio_buses() -> void:
	_ensure_audio_bus(MUSIC_BUS)
	_ensure_audio_bus(SFX_BUS)


func apply_audio() -> void:
	ensure_audio_buses()
	_apply_bus_volume(MUSIC_BUS, music_percent)
	_apply_bus_volume(SFX_BUS, sfx_percent)


func load_settings() -> void:
	_reset_settings_to_defaults()

	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(settings_path)
	if load_error != OK:
		if load_error != ERR_FILE_NOT_FOUND:
			settings_error.emit("설정 파일을 읽지 못했습니다: %s" % error_string(load_error))
		return

	_load_bindings_from_config(config)
	if not config.has_section_key("input", String(SELF_RESPAWN_ACTION)):
		_migrate_self_respawn_binding()
	_load_audio_from_config(config)
	_restore_defaults_for_duplicate_keys()


func _reset_settings_to_defaults() -> void:
	_load_default_bindings()
	music_percent = 100.0
	sfx_percent = 100.0


func _load_bindings_from_config(config: ConfigFile) -> void:
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = definition["action"]
		var slot_count: int = int(definition.get("slots", 1))
		var stored_value: Variant = config.get_value(
			"input",
			String(action_name),
			_bindings[action_name]
		)
		var parsed: Array[int] = _parse_key_array(
			stored_value,
			slot_count,
			action_name == SELF_RESPAWN_ACTION
		)
		if not parsed.is_empty():
			_bindings[action_name] = parsed


## 상황: 기존 설정 파일에 새 자력 재스폰 동작이 아직 없을 때 한 번 계산한다.
## 순서: Q→K→Backspace 중 다른 동작이 쓰지 않는 첫 키 선택, 모두 충돌하면 미지정.
## 결과: 기존 사용자 키 전체를 기본값으로 되돌리지 않고 새 동작만 안전하게 보충한다.
func _migrate_self_respawn_binding() -> void:
	for key_code: int in SELF_RESPAWN_MIGRATION_KEYS:
		if find_conflict(key_code, SELF_RESPAWN_ACTION, 0).is_empty():
			_bindings[SELF_RESPAWN_ACTION] = [key_code]
			return
	_bindings[SELF_RESPAWN_ACTION] = [KEY_NONE]


func _load_audio_from_config(config: ConfigFile) -> void:
	music_percent = clampf(
		float(config.get_value("audio", "music_percent", 100.0)),
		0.0,
		100.0
	)
	sfx_percent = clampf(
		float(config.get_value("audio", "sfx_percent", 100.0)),
		0.0,
		100.0
	)


func _restore_defaults_for_duplicate_keys() -> void:
	if _has_duplicate_keys():
		_load_default_bindings()
		settings_error.emit("저장된 키 설정에 중복이 있어 기본값으로 복원했습니다.")


func save_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = definition["action"]
		config.set_value("input", String(action_name), get_action_keys(action_name))
	config.set_value("audio", "music_percent", music_percent)
	config.set_value("audio", "sfx_percent", sfx_percent)
	var save_error: Error = config.save(settings_path)
	if save_error != OK:
		settings_error.emit("설정을 저장하지 못했습니다: %s" % error_string(save_error))
	return save_error


static func keycode_to_text(key_code: int) -> String:
	match key_code:
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_SPACE:
			return "Space"
		KEY_ESCAPE:
			return "Esc"
		_:
			var text_value: String = OS.get_keycode_string(key_code)
			return text_value if not text_value.is_empty() else "Key %d" % key_code


func _definition_for(action_name: StringName) -> Dictionary:
	return INPUT_ACTIONS.get_definition(action_name)


func _load_default_bindings() -> void:
	_bindings.clear()
	for definition: Dictionary in ACTION_DEFINITIONS:
		_bindings[definition["action"]] = INPUT_ACTIONS.get_default_keys(
			definition["action"]
		)


func _parse_key_array(
	stored_value: Variant,
	slot_count: int,
	allow_unassigned_primary: bool = false
) -> Array[int]:
	var parsed: Array[int] = []
	if not (stored_value is Array):
		return parsed
	for value: Variant in stored_value:
		if not (value is int or value is float):
			return []
		parsed.append(int(value))
	if parsed.is_empty():
		return []
	if parsed[0] == KEY_NONE:
		return [KEY_NONE] if allow_unassigned_primary else []
	while parsed.size() < slot_count:
		parsed.append(KEY_NONE)
	if parsed.size() > slot_count:
		parsed.resize(slot_count)
	return parsed


func _has_duplicate_keys() -> bool:
	var used: Dictionary = {}
	for definition: Dictionary in ACTION_DEFINITIONS:
		for key_code: int in get_action_keys(definition["action"]):
			if key_code == KEY_NONE:
				continue
			if used.has(key_code):
				return true
			used[key_code] = true
	return false


func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_bus_volume(bus_name: StringName, percent: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var muted: bool = percent <= 0.0
	AudioServer.set_bus_mute(bus_index, muted)
	AudioServer.set_bus_volume_db(
		bus_index,
		-80.0 if muted else linear_to_db(percent / 100.0)
	)


func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
