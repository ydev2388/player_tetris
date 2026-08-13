class_name MainCharacterData
extends RefCounted

## 플레이 가능한 여덟 캐릭터의 선택 정보와 능력치 계산을 한곳에서 관리한다.
## 능력치는 공속(회전킥 쿨다운), 이동, 점프, 스태미나, 특수스킬, 체력을 사용한다.

const DEFAULT_CHARACTER_ID: String = "normal"
const PASSIVE_COUNT: int = 6
const PASSIVE_LEVEL_MAX: int = 3
const PASSIVE_EFFECT_STEP: float = 0.05
const HEALTH_PASSIVE_INDEX: int = 5
const CHARACTER_ORDER: Array[String] = [
	"normal",
	"boxer",
	"shield_guard",
	"firefighter",
	"cleaner",
	"chef",
	"clockmaker",
	"ninja",
]

const PROFILES: Dictionary = {
	"normal": {
		"display_name": "일반인",
		"unlock_text": "0별",
		"role": "균형형",
		"description": "성실하지만 경험이 부족한 기준 캐릭터.",
		"weapon": "목제 연습봉",
		"special_name": "전력 질주",
		"special_description": "2초 동안 좌우 이동속도가 60% 증가한다.",
		"special_base_cooldown": 7.0,
		"attack_speed": 3,
		"move": 3,
		"jump": 1,
		"stamina": 4,
		"special_skill": 4,
	},
	"boxer": {
		"display_name": "복서",
		"unlock_text": "3별",
		"role": "정면 돌파형",
		"description": "짧은 거리에서 블록을 강하게 밀어내는 공격형.",
		"weapon": "복싱 글러브",
		"special_name": "가드 브레이크",
		"special_description": "전방 블록을 가능한 거리만큼 최대 3칸 민다.",
		"special_base_cooldown": 6.0,
		"attack_speed": 4,
		"move": 3,
		"jump": 1,
		"stamina": 3,
		"special_skill": 3,
	},
	"shield_guard": {
		"display_name": "방패병",
		"unlock_text": "6별",
		"role": "정면 생존형",
		"description": "이동하는 보호벽으로 한쪽 위험을 견디는 수호자.",
		"weapon": "원형 방패",
		"special_name": "전방 보호벽",
		"special_description": "시전 방향 앞에 세로 3칸 보호벽을 2초 동안 유지한다.",
		"special_base_cooldown": 10.0,
		"attack_speed": 3,
		"move": 3,
		"jump": 1,
		"stamina": 6,
		"special_skill": 6,
	},
	"firefighter": {
		"display_name": "소방관",
		"unlock_text": "9별",
		"role": "낙하 경로 제어형",
		"description": "중력에 따라 흐르는 물길로 활성 블록의 착지 위치를 바꾼다.",
		"weapon": "소방 도끼 옆면",
		"special_name": "중력 물길",
		"special_description": "전방에 3셀 물길을 4초 만들고 자동 낙하마다 흐르는 방향으로 1칸 이동시킨다.",
		"special_base_cooldown": 13.0,
		"attack_speed": 3,
		"move": 3,
		"jump": 1,
		"stamina": 5,
		"special_skill": 5,
	},
	"cleaner": {
		"display_name": "청소부",
		"unlock_text": "12별",
		"role": "근거리 복구형",
		"description": "발밑의 노출된 고정 블록을 빠르게 정리하는 현장 전문가.",
		"weapon": "빗자루",
		"special_name": "대청소",
		"special_description": "발밑과 좌우 한 칸의 노출된 고정 블록을 최대 3개 제거한다.",
		"special_base_cooldown": 12.0,
		"attack_speed": 4,
		"move": 4,
		"jump": 1,
		"stamina": 4,
		"special_skill": 4,
	},
	"chef": {
		"display_name": "요리사",
		"unlock_text": "15별",
		"role": "생존 강화형",
		"description": "고기를 먹어 짧은 시간 빠르게 움직이고 다음 기믹이나 보스 공격을 버틴다.",
		"weapon": "프라이팬",
		"special_name": "고기 섭취",
		"special_description": "3초 동안 이동속도 +20%, 다음 기믹·보스 공격 1회 무효. 압착은 막지 못한다.",
		"special_base_cooldown": 9.0,
		"attack_speed": 3,
		"move": 4,
		"jump": 1,
		"stamina": 7,
		"special_skill": 7,
	},
	"clockmaker": {
		"display_name": "시계공",
		"unlock_text": "15별",
		"unlock_hint": "목표: 별 15개 (선택 제한 없음)",
		"role": "시간 정지형",
		"description": "황동 톱니 가방과 거대한 태엽 열쇠로 낙하 시간을 멈추는 괴짜 장인.",
		"weapon": "태엽 열쇠 지팡이",
		"special_name": "정지 태엽",
		"special_description": "활성 블록과 다음 가시·결박·씨앗 발동을 3초 동안 늦춘다.",
		"special_base_cooldown": 12.0,
		"attack_speed": 4,
		"move": 3,
		"jump": 1,
		"stamina": 5,
		"special_skill": 5,
	},
	"ninja": {
		"display_name": "닌자",
		"unlock_text": "전 스테이지 무피해",
		"unlock_hint": "목표: 전 스테이지 무피해 (선택 제한 없음)",
		"role": "고속 원거리형",
		"description": "긴 스카프를 휘날리며 활성 블록을 원거리에서 조작하는 고속 숙련자.",
		"weapon": "단봉",
		"special_name": "표창",
		"special_description": "전방 6칸으로 표창을 던져 활성 블록 덩어리 전체를 정확히 1칸 민다. 고정 블록에는 막힌다.",
		"special_base_cooldown": 5.0,
		"attack_speed": 8,
		"move": 9,
		"jump": 7,
		"stamina": 2,
		"special_skill": 2,
	},
}


static func has_character(character_id: String) -> bool:
	return PROFILES.has(character_id)


static func profile_for(character_id: String) -> Dictionary:
	if PROFILES.has(character_id):
		return PROFILES[character_id] as Dictionary
	return PROFILES[DEFAULT_CHARACTER_ID] as Dictionary


static func stat(character_id: String, key: String) -> int:
	return clampi(int(profile_for(character_id).get(key, 1)), 1, 10)


static func move_speed(character_id: String, passive_levels: Array = []) -> float:
	var base_speed: float = 140.0 + float(stat(character_id, "move")) * 10.0
	return base_speed * passive_speed_multiplier(passive_levels, 1)


static func jump_cells(character_id: String) -> int:
	return 2 + (stat(character_id, "jump") - 1) / 3


static func stamina_drain_multiplier(character_id: String, passive_levels: Array = []) -> float:
	var base_multiplier: float = 1.0 - float(stat(character_id, "stamina") - 1) * 0.06
	return base_multiplier * passive_cooldown_multiplier(passive_levels, 3)


static func special_cooldown_multiplier(
	character_id: String,
	passive_levels: Array = []
) -> float:
	var base_multiplier: float = 1.0 - float(stat(character_id, "special_skill") - 1) * 0.03
	return base_multiplier * passive_cooldown_multiplier(passive_levels, 4)


static func rotation_cooldown(character_id: String, passive_levels: Array = []) -> float:
	var base_cooldown: float = 2.1 - float(stat(character_id, "attack_speed")) * 0.1
	return base_cooldown * passive_cooldown_multiplier(passive_levels, 0)


static func special_cooldown(character_id: String, passive_levels: Array = []) -> float:
	var profile: Dictionary = profile_for(character_id)
	return float(profile["special_base_cooldown"]) * special_cooldown_multiplier(
		character_id,
		passive_levels
	)


static func jump_height_multiplier(passive_levels: Array = []) -> float:
	return passive_speed_multiplier(passive_levels, 2)


static func health_life_bonus(passive_levels: Array = []) -> int:
	return _passive_level(passive_levels, HEALTH_PASSIVE_INDEX)


static func passive_speed_multiplier(passive_levels: Array, index: int) -> float:
	return 1.0 + float(_passive_level(passive_levels, index)) * PASSIVE_EFFECT_STEP


static func passive_cooldown_multiplier(passive_levels: Array, index: int) -> float:
	return 1.0 - float(_passive_level(passive_levels, index)) * PASSIVE_EFFECT_STEP


static func _passive_level(passive_levels: Array, index: int) -> int:
	if index < 0 or index >= passive_levels.size():
		return 0
	return clampi(int(passive_levels[index]), 0, PASSIVE_LEVEL_MAX)
