class_name BlockFighterProgressionService
extends RefCounted

const CHARACTER_DATA: Script = preload("res://scripts/character_data.gd")
const STAGE_COUNT: int = 10
const MAX_STAGE_STARS: int = 3
const MAX_PASSIVE_LEVEL: int = 3
const PASSIVE_IDS: Array[String] = [
	"attack_speed", "move", "jump", "stamina", "special_skill", "health",
]

var stage_best_stars: Array[int] = []
var stage_no_damage_clears: Array[bool] = []
var star_currency: int = 0
var passive_levels: Array[int] = []
var challenge_best_lines: int = 0
var debug_all_characters_unlocked: bool = false


func _init() -> void:
	reset_defaults()


func reset_defaults() -> void:
	stage_best_stars.assign([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	stage_no_damage_clears.assign([
		false, false, false, false, false,
		false, false, false, false, false,
	])
	star_currency = 0
	passive_levels.assign([0, 0, 0, 0, 0, 0])
	challenge_best_lines = 0
	debug_all_characters_unlocked = false


func snapshot() -> Dictionary:
	return {
		"stage_best_stars": stage_best_stars.duplicate(),
		"stage_no_damage_clears": stage_no_damage_clears.duplicate(),
		"star_currency": star_currency,
		"passive_levels": passive_levels.duplicate(),
		"challenge_best_lines": challenge_best_lines,
		"debug_all_characters_unlocked": debug_all_characters_unlocked,
	}


func restore(snapshot_value: Dictionary) -> void:
	stage_best_stars.assign(snapshot_value.get("stage_best_stars", []))
	stage_no_damage_clears.assign(snapshot_value.get("stage_no_damage_clears", []))
	star_currency = int(snapshot_value.get("star_currency", 0))
	passive_levels.assign(snapshot_value.get("passive_levels", []))
	challenge_best_lines = int(snapshot_value.get("challenge_best_lines", 0))
	debug_all_characters_unlocked = bool(
		snapshot_value.get("debug_all_characters_unlocked", false)
	)


func get_stage_best_stars(stage_number: int) -> int:
	if stage_number < 1 or stage_number > STAGE_COUNT:
		return 0
	return stage_best_stars[stage_number - 1]


func is_stage_unlocked(stage_number: int) -> bool:
	if stage_number < 1 or stage_number > STAGE_COUNT:
		return false
	return stage_number == 1 or get_stage_best_stars(stage_number - 1) > 0


func is_challenge_unlocked() -> bool:
	return get_stage_best_stars(STAGE_COUNT) > 0


func get_total_best_stars() -> int:
	var total := 0
	for stars: int in stage_best_stars:
		total += stars
	return total


func is_stage_cleared_without_damage(stage_number: int) -> bool:
	if stage_number < 1 or stage_number > STAGE_COUNT:
		return false
	return stage_no_damage_clears[stage_number - 1]


func has_all_stage_no_damage_clears() -> bool:
	return not stage_no_damage_clears.has(false)


func is_character_unlocked(character_id: String) -> bool:
	if not CHARACTER_DATA.has_character(character_id):
		return false
	if debug_all_characters_unlocked:
		return true
	var profile: Dictionary = CHARACTER_DATA.profile_for(character_id)
	if bool(profile.get("unlock_all_no_damage", false)):
		return has_all_stage_no_damage_clears()
	return get_total_best_stars() >= int(profile.get("unlock_stars", 0))


func unlock_all_characters_for_debug() -> bool:
	if debug_all_characters_unlocked:
		return false
	debug_all_characters_unlocked = true
	return true


func get_passive_level(passive_id: String) -> int:
	var index := PASSIVE_IDS.find(passive_id)
	return 0 if index < 0 else passive_levels[index]


func get_passive_cost(passive_id: String) -> int:
	if not PASSIVE_IDS.has(passive_id):
		return 0
	var level := get_passive_level(passive_id)
	return 0 if level >= MAX_PASSIVE_LEVEL else level + 1


func get_passive_levels() -> Array[int]:
	return passive_levels.duplicate()


func upgrade_passive(passive_id: String) -> Dictionary:
	var index := PASSIVE_IDS.find(passive_id)
	if index < 0:
		return _failure("알 수 없는 패시브입니다.")
	var current_level := passive_levels[index]
	if current_level >= MAX_PASSIVE_LEVEL:
		return _failure("이미 최대 레벨입니다.")
	var cost := current_level + 1
	if star_currency < cost:
		return _failure("별이 부족합니다. 필요한 별: %d개" % cost)
	passive_levels[index] = current_level + 1
	star_currency -= cost
	return {
		"ok": true,
		"passive_id": passive_id,
		"level": passive_levels[index],
		"cost": cost,
		"star_currency": star_currency,
	}


func reset_passive_upgrades() -> Dictionary:
	var refund := 0
	for level: int in passive_levels:
		for spent_level: int in range(1, level + 1):
			refund += spent_level
	passive_levels.fill(0)
	star_currency += refund
	return {"ok": true, "refund": refund, "star_currency": star_currency}


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
	var awarded_stars := clampi(stars, 1, MAX_STAGE_STARS)
	var previous_stars := get_stage_best_stars(stage_number)
	var previous_no_damage := is_stage_cleared_without_damage(stage_number)
	var reward := maxi(awarded_stars - previous_stars, 0)
	var changed := awarded_stars > previous_stars or (
		cleared_without_damage and not previous_no_damage
	)
	if awarded_stars > previous_stars:
		stage_best_stars[stage_number - 1] = awarded_stars
		star_currency += reward
	if cleared_without_damage:
		stage_no_damage_clears[stage_number - 1] = true
	return {
		"ok": true,
		"changed": changed,
		"stage_number": stage_number,
		"previous_stars": previous_stars,
		"stars": get_stage_best_stars(stage_number),
		"remaining_lives": remaining_lives,
		"cleared_without_damage": is_stage_cleared_without_damage(stage_number),
		"reward": reward,
		"star_currency": star_currency,
	}


func record_challenge_lines(lines: int) -> bool:
	var normalized_lines := maxi(lines, 0)
	if normalized_lines <= challenge_best_lines:
		return false
	challenge_best_lines = normalized_lines
	return true


func reset_stage_progress() -> void:
	reset_defaults()


func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
