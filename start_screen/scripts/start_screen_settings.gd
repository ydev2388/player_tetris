class_name StartScreenSettings
extends Node

signal bindings_changed
signal audio_changed
signal progress_changed
signal settings_error(message: String)

const DEFAULT_SETTINGS_PATH: String = "user://start_screen_settings.cfg"
const SETTINGS_SCHEMA_VERSION: int = 2
const MUSIC_BUS: StringName = &"BGM"
const SFX_BUS: StringName = &"SFX"
const INPUT_ACTIONS: Script = preload("res://scripts/input_actions.gd")
const LOCALIZATION: Script = preload("res://scripts/localization.gd")
const CHARACTER_DATA: Script = preload("res://scripts/character_data.gd")
const ACTION_DEFINITIONS: Array[Dictionary] = INPUT_ACTIONS.DEFINITIONS
const SELF_RESPAWN_ACTION: StringName = &"character_self_respawn"
const SELF_RESPAWN_MIGRATION_KEYS: Array[int] = [KEY_Q, KEY_K, KEY_BACKSPACE]
const STAGE_COUNT: int = 10
const STAGE_NO_DAMAGE_COUNT: int = 5
const MAX_STAGE_STARS: int = 3
const PASSIVE_IDS: Array[String] = [
	"attack_speed",
	"move",
	"jump",
	"stamina",
	"special_skill",
	"health",
]
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
const PASSIVE_NAMES_CHINESE: Array[String] = ["攻击速度", "移动", "跳跃", "体力", "特殊技能", "生命"]
const PASSIVE_DESCRIPTIONS_CHINESE: Array[String] = [
	"缩短普通攻击和方块翻转的冷却时间。",
	"提高左右移动速度。",
	"提高跳跃高度。",
	"减少攀墙时的体力消耗。",
	"缩短特殊技能的冷却时间。",
	"每级增加一条生命。",
]
const MAX_PASSIVE_LEVEL: int = 3
const ENGLISH: String = "english"
const KOREAN: String = "kor"
const CHINESE: String = "zh_cn"

var settings_path: String = DEFAULT_SETTINGS_PATH
var music_percent: float = 100.0
var sfx_percent: float = 100.0
var language: String = ENGLISH
var stage_best_stars: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var stage_no_damage_clears: Array[bool] = [false, false, false, false, false]
var star_currency: int = 0
var passive_levels: Array[int] = [0, 0, 0, 0, 0, 0]
var challenge_best_lines: int = 0

var _bindings: Dictionary = {}


func _init(custom_settings_path: String = DEFAULT_SETTINGS_PATH) -> void:
	settings_path = custom_settings_path


func _ready() -> void:
	load_settings()
	apply_bindings()
	apply_audio()


func get_action_definitions() -> Array[Dictionary]:
	return INPUT_ACTIONS.get_definitions()


func get_action_label(action_name: StringName) -> String:
	var definition: Dictionary = _definition_for(action_name)
	var label_key: String = (
		"label" if language == KOREAN else "label_chinese" if language == CHINESE else "label_english"
	)
	return String(definition.get(label_key, String(action_name)))


func get_passive_name(index: int) -> String:
	var names: Array[String] = (
		PASSIVE_NAMES if language == KOREAN else PASSIVE_NAMES_CHINESE if language == CHINESE else PASSIVE_NAMES_ENGLISH
	)
	return names[index]


func get_passive_description(index: int) -> String:
	var descriptions: Array[String] = (
		PASSIVE_DESCRIPTIONS if language == KOREAN else PASSIVE_DESCRIPTIONS_CHINESE if language == CHINESE else PASSIVE_DESCRIPTIONS_ENGLISH
	)
	return descriptions[index]


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
		return "未设置" if language == CHINESE else "미지정" if language == KOREAN else "Unassigned"
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
		"message": "%s 키가 변경되었습니다." % get_action_label(action_name)
		if language == KOREAN
		else "%s key changed." % get_action_label(action_name),
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
		"message": "%s 보조 키를 지웠습니다." % get_action_label(action_name)
		if language == KOREAN
		else "%s secondary key cleared." % get_action_label(action_name),
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


func reset_bindings_to_defaults() -> void:
	var previous_state: Dictionary = _snapshot_state()
	_load_default_bindings()
	apply_bindings()
	if save_settings() != OK:
		_restore_state(previous_state)
		return
	bindings_changed.emit()


func apply_bindings() -> void:
	INPUT_ACTIONS.apply_bindings(_bindings)


func set_music_percent(value: float) -> void:
	var previous_state: Dictionary = _snapshot_state()
	music_percent = clampf(value, 0.0, 100.0)
	_apply_bus_volume(MUSIC_BUS, music_percent)
	if save_settings() != OK:
		_restore_state(previous_state)
		return
	audio_changed.emit()


func set_sfx_percent(value: float) -> void:
	var previous_state: Dictionary = _snapshot_state()
	sfx_percent = clampf(value, 0.0, 100.0)
	_apply_bus_volume(SFX_BUS, sfx_percent)
	if save_settings() != OK:
		_restore_state(previous_state)
		return
	audio_changed.emit()


func set_language(value: String) -> void:
	var previous_state: Dictionary = _snapshot_state()
	var next_language: String = value if value in [KOREAN, CHINESE] else ENGLISH
	if language == next_language:
		return
	language = next_language
	LOCALIZATION.install(language)
	if save_settings() != OK:
		_restore_state(previous_state)
		LOCALIZATION.install(language)


func get_stage_best_stars(stage_number: int) -> int:
	if stage_number < 1 or stage_number > STAGE_COUNT:
		return 0
	return stage_best_stars[stage_number - 1]


func is_stage_unlocked(stage_number: int) -> bool:
	if stage_number < 1 or stage_number > STAGE_COUNT:
		return false
	if stage_number == 1:
		return true
	return get_stage_best_stars(stage_number - 1) > 0


func is_challenge_unlocked() -> bool:
	return get_stage_best_stars(STAGE_COUNT) > 0


func get_total_best_stars() -> int:
	var total: int = 0
	for stars: int in stage_best_stars:
		total += stars
	return total


func is_stage_cleared_without_damage(stage_number: int) -> bool:
	if stage_number < 1 or stage_number > STAGE_NO_DAMAGE_COUNT:
		return false
	return stage_no_damage_clears[stage_number - 1]


func has_all_stage_no_damage_clears() -> bool:
	for cleared_without_damage: bool in stage_no_damage_clears:
		if not cleared_without_damage:
			return false
	return true


## 캐릭터 해금은 현재 별 화폐가 아니라 저장된 스테이지별 최고 별의 합으로 계산한다.
## 상점에서 별을 사용하거나 게임을 재실행해도 이미 달성한 해금은 유지된다.
func is_character_unlocked(character_id: String) -> bool:
	if not CHARACTER_DATA.has_character(character_id):
		return false
	var profile: Dictionary = CHARACTER_DATA.profile_for(character_id)
	if bool(profile.get("unlock_all_no_damage", false)):
		return has_all_stage_no_damage_clears()
	return get_total_best_stars() >= int(profile.get("unlock_stars", 0))


func get_passive_level(passive_id: String) -> int:
	var index: int = PASSIVE_IDS.find(passive_id)
	if index < 0:
		return 0
	return passive_levels[index]


func get_passive_cost(passive_id: String) -> int:
	if not PASSIVE_IDS.has(passive_id):
		return 0
	var level: int = get_passive_level(passive_id)
	return 0 if level >= MAX_PASSIVE_LEVEL else level + 1


func get_passive_levels() -> Array[int]:
	return passive_levels.duplicate()


func upgrade_passive(passive_id: String) -> Dictionary:
	var index: int = PASSIVE_IDS.find(passive_id)
	if index < 0:
		return _failure("알 수 없는 패시브입니다.")
	var current_level: int = passive_levels[index]
	if current_level >= MAX_PASSIVE_LEVEL:
		return _failure("이미 최대 레벨입니다.")
	var cost: int = current_level + 1
	if star_currency < cost:
		return _failure("별이 부족합니다. 필요한 별: %d개" % cost)

	var previous_currency: int = star_currency
	passive_levels[index] = current_level + 1
	star_currency -= cost
	var save_error: Error = save_settings()
	if save_error != OK:
		passive_levels[index] = current_level
		star_currency = previous_currency
		return _failure("패시브 강화를 저장하지 못했습니다: %s" % error_string(save_error))
	progress_changed.emit()
	return {
		"ok": true,
		"passive_id": passive_id,
		"level": passive_levels[index],
		"cost": cost,
		"star_currency": star_currency,
	}


func reset_passive_upgrades() -> Dictionary:
	var previous_levels: Array[int] = passive_levels.duplicate()
	var previous_currency: int = star_currency
	var refund: int = 0
	for level: int in passive_levels:
		for spent_level: int in range(1, level + 1):
			refund += spent_level
	passive_levels.fill(0)
	star_currency += refund
	var save_error: Error = save_settings()
	if save_error != OK:
		passive_levels = previous_levels
		star_currency = previous_currency
		return _failure("패시브 초기화를 저장하지 못했습니다: %s" % error_string(save_error))
	progress_changed.emit()
	return {
		"ok": true,
		"refund": refund,
		"star_currency": star_currency,
	}


func complete_stage(
	stage_number: int,
	stars: int,
	remaining_lives: int = -1,
	cleared_without_damage: bool = false
) -> Dictionary:
	if stage_number < 1 or stage_number > STAGE_COUNT:
		return _failure("알 수 없는 스테이지입니다.")
	if stars < 1:
		return _failure("스테이지 클리어 별은 1개 이상이어야 합니다.")

	var awarded_stars: int = clampi(stars, 1, MAX_STAGE_STARS)
	var previous_stars: int = get_stage_best_stars(stage_number)
	var reward: int = maxi(awarded_stars - previous_stars, 0)
	var previous_currency: int = star_currency
	var previous_no_damage: bool = is_stage_cleared_without_damage(stage_number)
	var progress_changed_now: bool = awarded_stars > previous_stars
	progress_changed_now = progress_changed_now or (
		stage_number <= STAGE_NO_DAMAGE_COUNT
		and cleared_without_damage
		and not previous_no_damage
	)
	if progress_changed_now:
		if awarded_stars > previous_stars:
			stage_best_stars[stage_number - 1] = awarded_stars
			star_currency += reward
		if stage_number <= STAGE_NO_DAMAGE_COUNT:
			stage_no_damage_clears[stage_number - 1] = (
				previous_no_damage or cleared_without_damage
			)
		var save_error: Error = save_settings()
		if save_error != OK:
			stage_best_stars[stage_number - 1] = previous_stars
			star_currency = previous_currency
			if stage_number <= STAGE_NO_DAMAGE_COUNT:
				stage_no_damage_clears[stage_number - 1] = previous_no_damage
			return _failure(
				"스테이지 결과를 저장하지 못했습니다: %s" % error_string(save_error)
			)
		progress_changed.emit()
	return {
		"ok": true,
		"stage_number": stage_number,
		"previous_stars": previous_stars,
		"stars": get_stage_best_stars(stage_number),
		"remaining_lives": remaining_lives,
		"cleared_without_damage": is_stage_cleared_without_damage(stage_number),
		"reward": reward,
		"star_currency": star_currency,
	}


func record_challenge_lines(lines: int) -> Error:
	var normalized_lines: int = maxi(lines, 0)
	if normalized_lines <= challenge_best_lines:
		return OK
	var previous_best: int = challenge_best_lines
	challenge_best_lines = normalized_lines
	var save_error: Error = save_settings()
	if save_error != OK:
		challenge_best_lines = previous_best
		return save_error
	progress_changed.emit()
	return OK


func reset_stage_progress() -> Error:
	var previous_stars: Array[int] = stage_best_stars.duplicate()
	var previous_no_damage: Array[bool] = stage_no_damage_clears.duplicate()
	var previous_currency: int = star_currency
	var previous_passive_levels: Array[int] = passive_levels.duplicate()
	var previous_challenge_best: int = challenge_best_lines
	stage_best_stars.fill(0)
	stage_no_damage_clears.fill(false)
	star_currency = 0
	passive_levels.fill(0)
	challenge_best_lines = 0
	var save_error: Error = save_settings()
	if save_error != OK:
		stage_best_stars = previous_stars
		stage_no_damage_clears = previous_no_damage
		star_currency = previous_currency
		passive_levels = previous_passive_levels
		challenge_best_lines = previous_challenge_best
		return save_error
	progress_changed.emit()
	return OK


func ensure_audio_buses() -> void:
	_ensure_audio_bus(MUSIC_BUS)
	_ensure_audio_bus(SFX_BUS)


func apply_audio() -> void:
	ensure_audio_buses()
	_apply_bus_volume(MUSIC_BUS, music_percent)
	_apply_bus_volume(SFX_BUS, sfx_percent)


func load_settings() -> void:
	_reset_settings_to_defaults()
	LOCALIZATION.install(language)

	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(settings_path)
	if load_error != OK:
		if load_error != ERR_FILE_NOT_FOUND:
			settings_error.emit("설정 파일을 읽지 못했습니다: %s" % error_string(load_error))
		return

	var needs_save: bool = false
	if _load_bindings_from_config(config):
		needs_save = true
	if _restore_escape_bindings():
		needs_save = true
	if _migrate_rotation_kick_binding():
		needs_save = true
	if not config.has_section_key("input", String(SELF_RESPAWN_ACTION)):
		if _migrate_self_respawn_binding():
			needs_save = true
	if _load_audio_from_config(config):
		needs_save = true
	if _load_progress_from_config(config):
		needs_save = true
	if _restore_defaults_for_duplicate_keys():
		needs_save = true
	if config.get_value("meta", "version", 0) != SETTINGS_SCHEMA_VERSION:
		needs_save = true
	if needs_save:
		save_settings()


func _reset_settings_to_defaults() -> void:
	_load_default_bindings()
	music_percent = 100.0
	sfx_percent = 100.0
	language = ENGLISH
	stage_best_stars = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	stage_no_damage_clears = [false, false, false, false, false]
	star_currency = 0
	passive_levels = [0, 0, 0, 0, 0, 0]
	challenge_best_lines = 0


func _load_bindings_from_config(config: ConfigFile) -> bool:
	var changed: bool = false
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = definition["action"]
		var slot_count: int = int(definition.get("slots", 1))
		if not config.has_section_key("input", String(action_name)):
			changed = true
			continue
		var stored_value: Variant = config.get_value(
			"input",
			String(action_name),
			_bindings[action_name]
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
	var music_value: Variant = config.get_value("audio", "music_percent", 100.0)
	if not config.has_section_key("audio", "music_percent"):
		changed = true
	if _is_finite_number(music_value):
		music_percent = clampf(float(music_value), 0.0, 100.0)
		changed = changed or not is_equal_approx(float(music_value), music_percent)
	else:
		music_percent = 100.0
		changed = true
	var sfx_value: Variant = config.get_value("audio", "sfx_percent", 100.0)
	if not config.has_section_key("audio", "sfx_percent"):
		changed = true
	if _is_finite_number(sfx_value):
		sfx_percent = clampf(float(sfx_value), 0.0, 100.0)
		changed = changed or not is_equal_approx(float(sfx_value), sfx_percent)
	else:
		sfx_percent = 100.0
		changed = true
	var stored_language: Variant = config.get_value("options", "language", ENGLISH)
	if not config.has_section_key("options", "language"):
		changed = true
	if stored_language in [KOREAN, CHINESE, ENGLISH]:
		language = String(stored_language)
	else:
		language = ENGLISH
		changed = true
	return changed


func _load_progress_from_config(config: ConfigFile) -> bool:
	var changed: bool = false
	var stored_challenge_best: Variant = config.get_value("progress", "challenge_best_lines", 0)
	if not config.has_section_key("progress", "challenge_best_lines"):
		changed = true
	if _is_finite_number(stored_challenge_best):
		challenge_best_lines = maxi(int(stored_challenge_best), 0)
		changed = changed or not is_equal_approx(
			float(stored_challenge_best), float(challenge_best_lines)
		)
	else:
		challenge_best_lines = 0
		changed = true
	var stored_currency: Variant = config.get_value("progress", "star_currency", 0)
	if not config.has_section_key("progress", "star_currency"):
		changed = true
	if _is_finite_number(stored_currency):
		star_currency = maxi(int(stored_currency), 0)
		changed = changed or not is_equal_approx(float(stored_currency), float(star_currency))
	else:
		star_currency = 0
		changed = true
	for stage_number: int in range(1, STAGE_COUNT + 1):
		var stored_stars: Variant = config.get_value(
			"progress",
			"stage_%d_best_stars" % stage_number,
			0
		)
		if not config.has_section_key("progress", "stage_%d_best_stars" % stage_number):
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
	if not config.has_section_key("progress", "stage_6_best_stars"):
		if stage_best_stars[4] > 0 and stage_best_stars[5] == 0:
			stage_best_stars[5] = 1
			changed = true
	for stage_number: int in range(1, STAGE_NO_DAMAGE_COUNT + 1):
		var no_damage_key: String = "stage_%d_no_damage" % stage_number
		var stored_no_damage: Variant = config.get_value(
			"progress",
			no_damage_key,
			false
		)
		if not config.has_section_key("progress", no_damage_key):
			changed = true
		if stored_no_damage is bool:
			stage_no_damage_clears[stage_number - 1] = bool(stored_no_damage)
		else:
			stage_no_damage_clears[stage_number - 1] = false
			changed = true
	var stored_passive_levels: Variant = config.get_value(
		"progress",
		"passive_levels",
		[]
	)
	if not config.has_section_key("progress", "passive_levels"):
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
	var config: ConfigFile = ConfigFile.new()
	config.set_value("meta", "version", SETTINGS_SCHEMA_VERSION)
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = definition["action"]
		config.set_value("input", String(action_name), get_action_keys(action_name))
	config.set_value("audio", "music_percent", music_percent)
	config.set_value("audio", "sfx_percent", sfx_percent)
	config.set_value("options", "language", language)
	config.set_value("progress", "star_currency", star_currency)
	config.set_value("progress", "passive_levels", passive_levels)
	config.set_value("progress", "challenge_best_lines", challenge_best_lines)
	for stage_number: int in range(1, STAGE_COUNT + 1):
		config.set_value(
			"progress",
			"stage_%d_best_stars" % stage_number,
			get_stage_best_stars(stage_number)
		)
		config.set_value(
			"progress",
			"stage_%d_no_damage" % stage_number,
			is_stage_cleared_without_damage(stage_number)
		)
	var save_error: Error = config.save(settings_path)
	if save_error != OK:
		settings_error.emit("설정을 저장하지 못했습니다: %s" % error_string(save_error))
	return save_error


func _snapshot_state() -> Dictionary:
	return {
		"bindings": _bindings.duplicate(true),
		"music_percent": music_percent,
		"sfx_percent": sfx_percent,
		"language": language,
		"stage_best_stars": stage_best_stars.duplicate(),
		"stage_no_damage_clears": stage_no_damage_clears.duplicate(),
		"star_currency": star_currency,
		"passive_levels": passive_levels.duplicate(),
		"challenge_best_lines": challenge_best_lines,
	}


func _restore_state(snapshot: Dictionary) -> void:
	_bindings = (snapshot["bindings"] as Dictionary).duplicate(true)
	music_percent = float(snapshot["music_percent"])
	sfx_percent = float(snapshot["sfx_percent"])
	language = String(snapshot["language"])
	stage_best_stars.clear()
	var saved_stars: Array = snapshot["stage_best_stars"] as Array
	for value: Variant in saved_stars:
		stage_best_stars.append(int(value))
	stage_no_damage_clears.clear()
	var saved_no_damage: Array = snapshot["stage_no_damage_clears"] as Array
	for value: Variant in saved_no_damage:
		stage_no_damage_clears.append(bool(value))
	star_currency = int(snapshot["star_currency"])
	challenge_best_lines = int(snapshot["challenge_best_lines"])
	passive_levels.clear()
	var saved_passives: Array = snapshot["passive_levels"] as Array
	for value: Variant in saved_passives:
		passive_levels.append(int(value))
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


func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_bus_volume(bus_name: StringName, percent: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	# ponytail: UI 값과 무관하게 SFX 실제 출력을 절반으로 고정. SFX 전용
	# 조절이 필요해지면 percent를 저장 값으로 바꿔 옵션에 노출한다.
	var effective_percent: float = percent * (0.5 if bus_name == SFX_BUS else 1.0)
	var muted: bool = effective_percent <= 0.0
	AudioServer.set_bus_mute(bus_index, muted)
	AudioServer.set_bus_volume_db(
		bus_index,
		-80.0 if muted else linear_to_db(effective_percent / 100.0) - 10.0
	)


func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message if language == KOREAN else "Operation failed."}
