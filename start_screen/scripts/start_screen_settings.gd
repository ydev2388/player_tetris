class_name StartScreenSettings
extends Node

signal bindings_changed
signal audio_changed
signal progress_changed
signal settings_error(message: String)

const DEFAULT_SETTINGS_PATH: String = "user://start_screen_settings.cfg"
const SETTINGS_SCHEMA_VERSION: int = 4
const MUSIC_BUS: StringName = BlockFighterAudioSettingsAdapter.MUSIC_BUS
const SFX_BUS: StringName = BlockFighterAudioSettingsAdapter.SFX_BUS
const INPUT_ACTIONS: Script = preload("res://scripts/input_actions.gd")
const LOCALIZATION: Script = preload("res://scripts/localization.gd")
const SETTINGS_CODEC: Script = preload("res://start_screen/scripts/settings_codec.gd")
const ACTION_DEFINITIONS: Array[Dictionary] = INPUT_ACTIONS.DEFINITIONS
const SELF_RESPAWN_ACTION: StringName = &"character_self_respawn"
const SELF_RESPAWN_MIGRATION_KEYS: Array[int] = [KEY_Q, KEY_K, KEY_BACKSPACE]
const STAGE_COUNT: int = BlockFighterProgressionService.STAGE_COUNT
const STAGE_NO_DAMAGE_COUNT: int = STAGE_COUNT
const MAX_STAGE_STARS: int = BlockFighterProgressionService.MAX_STAGE_STARS
const PASSIVE_IDS: Array[String] = BlockFighterProgressionService.PASSIVE_IDS
const PASSIVE_NAMES: Array[String] = ["공속", "이동", "점프", "스태미나", "특수스킬", "체력"]
const PASSIVE_DESCRIPTIONS: Array[String] = [
	"기본 공격과 회전킥의 재사용 대기시간이 줄어듭니다.",
	"좌우 이동 속도가 빨라집니다.",
	"점프 높이가 높아집니다.",
	"벽에 매달릴 때 스태미나 소모량이 줄어듭니다.",
	"특수 스킬의 재사용 대기시간이 줄어듭니다.",
	"레벨마다 캐릭터의 목숨이 1개 추가됩니다.",
]
const PASSIVE_NAMES_ENGLISH: Array[String] = ["Attack Speed", "Move", "Jump", "Stamina", "Special Skill", "Health"]
const PASSIVE_DESCRIPTIONS_ENGLISH: Array[String] = [
	"Reduces basic attack and block flip cooldowns.",
	"Increases left and right movement speed.",
	"Increases jump height.",
	"Reduces stamina use while hanging from a wall.",
	"Reduces special skill cooldowns.",
	"Adds one life per level.",
]
const MAX_PASSIVE_LEVEL: int = BlockFighterProgressionService.MAX_PASSIVE_LEVEL
const ENGLISH: String = "english"

var _progression_service := BlockFighterProgressionService.new()
var _audio_settings_adapter := BlockFighterAudioSettingsAdapter.new()
var _settings_repository: BlockFighterSettingsRepository
var _detached_settings_path: String = DEFAULT_SETTINGS_PATH

var settings_path: String:
	get:
		return (
			_settings_repository.settings_path
			if _settings_repository != null
			else _detached_settings_path
		)
	set(value):
		_detached_settings_path = value
		if _settings_repository != null:
			_settings_repository.settings_path = value
var master_percent: float:
	get:
		return _audio_settings_adapter.master_percent
	set(value):
		_audio_settings_adapter.master_percent = value
var music_percent: float:
	get:
		return _audio_settings_adapter.music_percent
	set(value):
		_audio_settings_adapter.music_percent = value
var sfx_percent: float:
	get:
		return _audio_settings_adapter.sfx_percent
	set(value):
		_audio_settings_adapter.sfx_percent = value
var language: String = ENGLISH
var stage_best_stars: Array[int]:
	get:
		return _progression_service.stage_best_stars
	set(value):
		_progression_service.stage_best_stars.assign(value)
var stage_no_damage_clears: Array[bool]:
	get:
		return _progression_service.stage_no_damage_clears
	set(value):
		_progression_service.stage_no_damage_clears.assign(value)
var star_currency: int:
	get:
		return _progression_service.star_currency
	set(value):
		_progression_service.star_currency = value
var passive_levels: Array[int]:
	get:
		return _progression_service.passive_levels
	set(value):
		_progression_service.passive_levels.assign(value)
var challenge_best_lines: int:
	get:
		return _progression_service.challenge_best_lines
	set(value):
		_progression_service.challenge_best_lines = value
var debug_all_characters_unlocked: bool:
	get:
		return _progression_service.debug_all_characters_unlocked
	set(value):
		_progression_service.debug_all_characters_unlocked = value

var _bindings: Dictionary = {}


func _init(custom_settings_path: String = DEFAULT_SETTINGS_PATH) -> void:
	_detached_settings_path = custom_settings_path
	_settings_repository = BlockFighterSettingsRepository.new(custom_settings_path)


func _ready() -> void:
	load_settings()
	apply_bindings()
	apply_audio()


func get_action_definitions() -> Array[Dictionary]:
	return INPUT_ACTIONS.get_definitions()


func get_action_label(action_name: StringName) -> String:
	var definition: Dictionary = _definition_for(action_name)
	return String(definition.get("label_english", String(action_name)))


func get_passive_name(index: int) -> String:
	return PASSIVE_NAMES_ENGLISH[index]


func get_passive_description(index: int) -> String:
	return PASSIVE_DESCRIPTIONS_ENGLISH[index]


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
		return "Unassigned"
	return keycode_to_text(keys[slot_index])


func set_binding(action_name: StringName, slot_index: int, key_code: int) -> Dictionary:
	var previous_state: Dictionary = _snapshot_state()
	var definition: Dictionary = _definition_for(action_name)
	if definition.is_empty():
		return _failure("알 수 없는 입력 동작입니다.")

	var slot_count: int = int(definition.get("slots", 1))
	if slot_index < 0 or slot_index >= slot_count:
		return _failure("변경할 수 없는 키 슬롯입니다.")
	if key_code == KEY_NONE:
		return _failure("주 키는 비워둘 수 없습니다.")
	if key_code == KEY_ESCAPE:
		return _failure("Esc는 메뉴 복귀 전용 키입니다.")

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
	if save_settings() != OK:
		_restore_state(previous_state)
		return _failure("키 설정을 저장하지 못했습니다.")
	bindings_changed.emit()
	return {
		"ok": true,
		"message": "%s key changed." % get_action_label(action_name),
	}


func clear_secondary_binding(action_name: StringName) -> Dictionary:
	var previous_state: Dictionary = _snapshot_state()
	var definition: Dictionary = _definition_for(action_name)
	if definition.is_empty() or int(definition.get("slots", 1)) < 2:
		return _failure("보조 키가 없는 동작입니다.")

	var keys: Array[int] = get_action_keys(action_name)
	while keys.size() < 2:
		keys.append(KEY_NONE)
	keys[1] = KEY_NONE
	_bindings[action_name] = keys
	apply_bindings()
	if save_settings() != OK:
		_restore_state(previous_state)
		return _failure("키 설정을 저장하지 못했습니다.")
	bindings_changed.emit()
	return {
		"ok": true,
		"message": "%s secondary key cleared." % get_action_label(action_name),
	}


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
				"label": get_action_label(action_name),
				}
	return {}


func reset_bindings_to_defaults() -> Dictionary:
	var previous_state: Dictionary = _snapshot_state()
	_load_default_bindings()
	apply_bindings()
	var save_error: Error = save_settings()
	if save_error != OK:
		_restore_state(previous_state)
		return _failure("기본 키 설정을 저장하지 못했습니다: %s" % error_string(save_error))
	bindings_changed.emit()
	return {"ok": true, "message": "All keys were restored to defaults."}


func apply_bindings() -> void:
	INPUT_ACTIONS.apply_bindings(_bindings)


func set_master_percent(value: float) -> Dictionary:
	var previous_state: Dictionary = _snapshot_state()
	_audio_settings_adapter.set_master_percent(value)
	var save_error: Error = save_settings()
	if save_error != OK:
		_restore_state(previous_state)
		return _failure("마스터 볼륨을 저장하지 못했습니다: %s" % error_string(save_error))
	audio_changed.emit()
	return {"ok": true, "percent": master_percent}


func set_music_percent(value: float) -> Dictionary:
	var previous_state: Dictionary = _snapshot_state()
	_audio_settings_adapter.set_music_percent(value)
	var save_error: Error = save_settings()
	if save_error != OK:
		_restore_state(previous_state)
		return _failure("음악 볼륨을 저장하지 못했습니다: %s" % error_string(save_error))
	audio_changed.emit()
	return {"ok": true, "percent": music_percent}


func set_sfx_percent(value: float) -> Dictionary:
	var previous_state: Dictionary = _snapshot_state()
	_audio_settings_adapter.set_sfx_percent(value)
	var save_error: Error = save_settings()
	if save_error != OK:
		_restore_state(previous_state)
		return _failure("효과음 볼륨을 저장하지 못했습니다: %s" % error_string(save_error))
	audio_changed.emit()
	return {"ok": true, "percent": sfx_percent}


func set_language(value: String) -> void:
	var previous_state: Dictionary = _snapshot_state()
	if language == ENGLISH:
		return
	language = ENGLISH
	LOCALIZATION.install(language)
	if save_settings() != OK:
		_restore_state(previous_state)
		LOCALIZATION.install(language)


func get_stage_best_stars(stage_number: int) -> int:
	return _progression_service.get_stage_best_stars(stage_number)


func is_stage_unlocked(stage_number: int) -> bool:
	return _progression_service.is_stage_unlocked(stage_number)


func is_challenge_unlocked() -> bool:
	return _progression_service.is_challenge_unlocked()


func get_total_best_stars() -> int:
	return _progression_service.get_total_best_stars()


func is_stage_cleared_without_damage(stage_number: int) -> bool:
	return _progression_service.is_stage_cleared_without_damage(stage_number)


func has_all_stage_no_damage_clears() -> bool:
	return _progression_service.has_all_stage_no_damage_clears()


## 캐릭터 해금은 현재 별 화폐가 아니라 저장된 스테이지별 최고 별의 합으로 계산한다.
## 상점에서 별을 사용하거나 게임을 재실행해도 이미 달성한 해금은 유지된다.
func is_character_unlocked(character_id: String) -> bool:
	return _progression_service.is_character_unlocked(character_id)


## 숫자 0 버그키에서 호출한다. 스테이지 진행과 재화는 바꾸지 않고 캐릭터 선택 제한만
## 해제하며, 재실행 뒤에도 유지되도록 즉시 저장한다.
func unlock_all_characters_for_debug() -> Error:
	var previous_progress: Dictionary = _progression_service.snapshot()
	if not _progression_service.unlock_all_characters_for_debug():
		return OK
	var save_error: Error = save_settings()
	if save_error != OK:
		_progression_service.restore(previous_progress)
		return save_error
	progress_changed.emit()
	return OK


func get_passive_level(passive_id: String) -> int:
	return _progression_service.get_passive_level(passive_id)


func get_passive_cost(passive_id: String) -> int:
	return _progression_service.get_passive_cost(passive_id)


func get_passive_levels() -> Array[int]:
	return _progression_service.get_passive_levels()


func upgrade_passive(passive_id: String) -> Dictionary:
	var previous_progress: Dictionary = _progression_service.snapshot()
	var result: Dictionary = _progression_service.upgrade_passive(passive_id)
	if not bool(result.get("ok", false)):
		return result
	var save_error: Error = save_settings()
	if save_error != OK:
		_progression_service.restore(previous_progress)
		return _failure("패시브 강화를 저장하지 못했습니다: %s" % error_string(save_error))
	progress_changed.emit()
	return result


func reset_passive_upgrades() -> Dictionary:
	var previous_progress: Dictionary = _progression_service.snapshot()
	var result: Dictionary = _progression_service.reset_passive_upgrades()
	var save_error: Error = save_settings()
	if save_error != OK:
		_progression_service.restore(previous_progress)
		return _failure("패시브 초기화를 저장하지 못했습니다: %s" % error_string(save_error))
	progress_changed.emit()
	return result


func complete_stage(
	stage_number: int,
	stars: int,
	remaining_lives: int = -1,
	cleared_without_damage: bool = false
) -> Dictionary:
	var previous_progress: Dictionary = _progression_service.snapshot()
	var result: Dictionary = _progression_service.complete_stage(
		stage_number, stars, remaining_lives, cleared_without_damage
	)
	if not bool(result.get("ok", false)):
		return result
	if bool(result.get("changed", false)):
		var save_error: Error = save_settings()
		if save_error != OK:
			_progression_service.restore(previous_progress)
			return _failure(
				"스테이지 결과를 저장하지 못했습니다: %s" % error_string(save_error)
			)
		progress_changed.emit()
	result.erase("changed")
	return result


func record_challenge_lines(lines: int) -> Error:
	var previous_progress: Dictionary = _progression_service.snapshot()
	if not _progression_service.record_challenge_lines(lines):
		return OK
	var save_error: Error = save_settings()
	if save_error != OK:
		_progression_service.restore(previous_progress)
		return save_error
	progress_changed.emit()
	return OK


func reset_stage_progress() -> Error:
	var previous_progress: Dictionary = _progression_service.snapshot()
	_progression_service.reset_stage_progress()
	var save_error: Error = save_settings()
	if save_error != OK:
		_progression_service.restore(previous_progress)
		return save_error
	progress_changed.emit()
	return OK


func ensure_audio_buses() -> void:
	_audio_settings_adapter.ensure_buses()


func apply_audio() -> void:
	_audio_settings_adapter.apply()


func load_settings() -> void:
	_reset_settings_to_defaults()
	LOCALIZATION.install(language)

	var loaded: Dictionary = _settings_repository.load_config()
	if not bool(loaded.get("ok", false)):
		var load_error: Error = loaded.get("error", FAILED)
		if not bool(loaded.get("missing", false)):
			settings_error.emit("설정 파일을 읽지 못했습니다: %s" % error_string(load_error))
		return
	var config: ConfigFile = loaded["config"] as ConfigFile

	var needs_save: bool = false
	if _load_bindings_from_config(config):
		needs_save = true
	if _restore_escape_bindings():
		needs_save = true
	if _migrate_rotation_kick_binding():
		needs_save = true
	if not SETTINGS_CODEC.has_binding(config, SELF_RESPAWN_ACTION):
		if _migrate_self_respawn_binding():
			needs_save = true
	if _load_audio_from_config(config):
		needs_save = true
	if _load_progress_from_config(config):
		needs_save = true
	if _restore_defaults_for_duplicate_keys():
		needs_save = true
	if SETTINGS_CODEC.version(config) != SETTINGS_SCHEMA_VERSION:
		needs_save = true
	# 언어를 설정 파일에서 읽은 뒤 TranslationServer locale을 다시 맞춘다.
	# (_reset_settings_to_defaults() 시점에는 기본값 ENGLISH가 설치되므로)
	LOCALIZATION.install(language)
	if needs_save:
		save_settings()


func _reset_settings_to_defaults() -> void:
	_load_default_bindings()
	_audio_settings_adapter.reset_defaults()
	language = ENGLISH
	_progression_service.reset_defaults()


func _load_bindings_from_config(config: ConfigFile) -> bool:
	var changed: bool = false
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = definition["action"]
		var slot_count: int = int(definition.get("slots", 1))
		if not SETTINGS_CODEC.has_binding(config, action_name):
			changed = true
			continue
		var stored_value: Variant = SETTINGS_CODEC.binding(
			config, action_name, _bindings[action_name]
		)
		var parsed: Array = _parse_key_array(
			stored_value,
			slot_count,
			action_name == SELF_RESPAWN_ACTION
		)
		if not parsed.is_empty():
			changed = changed or parsed != get_action_keys(action_name)
			_bindings[action_name] = parsed
		else:
			changed = true
	return changed


## 상황: Esc가 저장된 이전 키 설정을 불러올 때 호출한다.
## 결과: Esc만 제거하고 다른 유효 키는 유지하며, 남은 키가 없을 때만 기본값을 쓴다.
func _restore_escape_bindings() -> bool:
	var changed: bool = false
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = definition["action"]
		var keys: Array[int] = get_action_keys(action_name)
		if KEY_ESCAPE not in keys:
			continue
		changed = true
		var filtered_keys: Array[int] = []
		for key_code: int in keys:
			if key_code != KEY_ESCAPE:
				filtered_keys.append(key_code)
		var has_valid_key: bool = false
		for key_code: int in filtered_keys:
			if key_code != KEY_NONE:
				has_valid_key = true
				break
		_bindings[action_name] = (
			filtered_keys
			if has_valid_key
			else INPUT_ACTIONS.get_default_keys(action_name)
		)
	return changed


## 상황: 기존 설정 파일에 새 자력 재스폰 동작이 아직 없을 때 한 번 계산한다.
## 순서: Q→K→Backspace 중 다른 동작이 쓰지 않는 첫 키 선택, 모두 충돌하면 미지정.
## 결과: 기존 사용자 키 전체를 기본값으로 되돌리지 않고 새 동작만 안전하게 보충한다.
func _migrate_self_respawn_binding() -> bool:
	for key_code: int in SELF_RESPAWN_MIGRATION_KEYS:
		if find_conflict(key_code, SELF_RESPAWN_ACTION, 0).is_empty():
			_bindings[SELF_RESPAWN_ACTION] = [key_code]
			return true
	_bindings[SELF_RESPAWN_ACTION] = [KEY_NONE]
	return true


## 상황: 블록 플립의 기존 기본키 V를 새 기본키 S로 옮길 때 호출한다.
## 결과: 기존 기본값만 S로 옮기고, 사용자가 지정한 다른 키는 유지한다.
func _migrate_rotation_kick_binding() -> bool:
	var rotation_action: StringName = &"character_rotation_kick"
	var rotation_keys: Array[int] = get_action_keys(rotation_action)
	if rotation_keys.size() == 1 and rotation_keys[0] == KEY_V:
		_bindings[rotation_action] = [KEY_S]
		return true
	return false


func _load_audio_from_config(config: ConfigFile) -> bool:
	var changed: bool = false
	var master_value: Variant = SETTINGS_CODEC.audio(config, &"master")
	if not SETTINGS_CODEC.has_audio(config, &"master"):
		changed = true
	if _is_finite_number(master_value):
		master_percent = clampf(float(master_value), 0.0, 100.0)
		changed = changed or not is_equal_approx(float(master_value), master_percent)
	else:
		master_percent = 100.0
		changed = true
	var music_value: Variant = SETTINGS_CODEC.audio(config, &"music")
	if not SETTINGS_CODEC.has_audio(config, &"music"):
		changed = true
	if _is_finite_number(music_value):
		music_percent = clampf(float(music_value), 0.0, 100.0)
		changed = changed or not is_equal_approx(float(music_value), music_percent)
	else:
		music_percent = 100.0
		changed = true
	var sfx_value: Variant = SETTINGS_CODEC.audio(config, &"sfx")
	if not SETTINGS_CODEC.has_audio(config, &"sfx"):
		changed = true
	if _is_finite_number(sfx_value):
		sfx_percent = clampf(float(sfx_value), 0.0, 100.0)
		changed = changed or not is_equal_approx(float(sfx_value), sfx_percent)
	else:
		sfx_percent = 100.0
		changed = true
	var stored_language: Variant = SETTINGS_CODEC.language(config, ENGLISH)
	if not SETTINGS_CODEC.has_language(config):
		changed = true
	language = ENGLISH
	if String(stored_language) != ENGLISH:
		changed = true
	return changed


func _load_progress_from_config(config: ConfigFile) -> bool:
	var changed: bool = false
	var stored_debug_unlock: Variant = SETTINGS_CODEC.debug_unlock(config)
	if not SETTINGS_CODEC.has_debug_unlock(config):
		changed = true
	if stored_debug_unlock is bool:
		debug_all_characters_unlocked = bool(stored_debug_unlock)
	else:
		debug_all_characters_unlocked = false
		changed = true
	var stored_challenge_best: Variant = SETTINGS_CODEC.challenge_best(config)
	if not SETTINGS_CODEC.has_challenge_best(config):
		changed = true
	if _is_finite_number(stored_challenge_best):
		challenge_best_lines = maxi(int(stored_challenge_best), 0)
		changed = changed or not is_equal_approx(
			float(stored_challenge_best), float(challenge_best_lines)
		)
	else:
		challenge_best_lines = 0
		changed = true
	var stored_currency: Variant = SETTINGS_CODEC.star_currency(config)
	if not SETTINGS_CODEC.has_star_currency(config):
		changed = true
	if _is_finite_number(stored_currency):
		star_currency = maxi(int(stored_currency), 0)
		changed = changed or not is_equal_approx(float(stored_currency), float(star_currency))
	else:
		star_currency = 0
		changed = true
	for stage_number: int in range(1, STAGE_COUNT + 1):
		var stored_stars: Variant = SETTINGS_CODEC.stage_best(config, stage_number)
		if not SETTINGS_CODEC.has_stage_best(config, stage_number):
			changed = true
		if _is_finite_number(stored_stars):
			stage_best_stars[stage_number - 1] = clampi(
				int(stored_stars),
				0,
				MAX_STAGE_STARS
			)
			changed = changed or not is_equal_approx(
				float(stored_stars),
				float(stage_best_stars[stage_number - 1])
			)
		else:
			stage_best_stars[stage_number - 1] = 0
			changed = true
	# 구버전(5층까지) 세이브에서 5층을 클리어했으면 6층을 해금한다.
	# stage_6_best_stars 키가 없을 때만 1회 적용되어 이후 저장 시 재적용되지 않는다.
	if not SETTINGS_CODEC.has_stage_best(config, 6):
		if stage_best_stars[4] > 0 and stage_best_stars[5] == 0:
			stage_best_stars[5] = 1
			changed = true
	for stage_number: int in range(1, STAGE_NO_DAMAGE_COUNT + 1):
		var stored_no_damage: Variant = SETTINGS_CODEC.stage_no_damage(
			config, stage_number
		)
		if not SETTINGS_CODEC.has_stage_no_damage(config, stage_number):
			changed = true
		if stored_no_damage is bool:
			stage_no_damage_clears[stage_number - 1] = bool(stored_no_damage)
		else:
			stage_no_damage_clears[stage_number - 1] = false
			changed = true
	var stored_passive_levels: Variant = SETTINGS_CODEC.passive_levels(config)
	if not SETTINGS_CODEC.has_passive_levels(config):
		changed = true
	if stored_passive_levels is Array:
		var values: Array = stored_passive_levels as Array
		if values.size() != passive_levels.size():
			changed = true
		for index: int in range(passive_levels.size()):
			if index >= values.size():
				changed = true
				continue
			if _is_finite_number(values[index]):
				var normalized_level: int = clampi(
					int(values[index]),
					0,
					MAX_PASSIVE_LEVEL
				)
				passive_levels[index] = clampi(
					normalized_level,
					0,
					MAX_PASSIVE_LEVEL
				)
				changed = changed or not is_equal_approx(
					float(values[index]),
					float(passive_levels[index])
				)
			else:
				changed = true
	else:
		changed = true
	return changed


func _restore_defaults_for_duplicate_keys() -> bool:
	if _has_duplicate_keys():
		_load_default_bindings()
		settings_error.emit("저장된 키 설정에 중복이 있어 기본값으로 복원했습니다.")
		return true
	return false


func save_settings() -> Error:
	var save_error: Error = _settings_repository.save(
		SETTINGS_SCHEMA_VERSION,
		ACTION_DEFINITIONS,
		_bindings,
		language,
		_audio_settings_adapter.snapshot(),
		_progression_service.snapshot()
	)
	if save_error != OK:
		settings_error.emit("설정을 저장하지 못했습니다: %s" % error_string(save_error))
	return save_error


func _snapshot_state() -> Dictionary:
	return {
		"bindings": _bindings.duplicate(true),
		"language": language,
		"audio": _audio_settings_adapter.snapshot(),
		"progression": _progression_service.snapshot(),
	}


func _restore_state(snapshot: Dictionary) -> void:
	_bindings = (snapshot["bindings"] as Dictionary).duplicate(true)
	language = String(snapshot["language"])
	_audio_settings_adapter.restore(snapshot["audio"] as Dictionary, false)
	_progression_service.restore(snapshot["progression"] as Dictionary)
	apply_bindings()
	apply_audio()


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
		if not _is_finite_number(value):
			return []
		if value is float and not is_equal_approx(float(value), roundf(float(value))):
			return []
		parsed.append(int(value))
	if parsed.is_empty():
		return []
	for key_code: int in parsed:
		if key_code < KEY_NONE:
			return []
	if parsed[0] == KEY_NONE:
		return [KEY_NONE] if allow_unassigned_primary else []
	while parsed.size() < slot_count:
		parsed.append(KEY_NONE)
	if parsed.size() > slot_count:
		parsed.resize(slot_count)
	return parsed


func _is_finite_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value))


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


func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
