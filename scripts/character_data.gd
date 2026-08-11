class_name MainCharacterData
extends RefCounted

## 플레이 가능한 여덟 캐릭터의 선택 정보와 능력치 계산을 한곳에서 관리한다.
## 능력치는 공속(회전킥 쿨다운), 이동, 점프, 스태미나, 특수스킬만 사용한다.

const DEFAULT_CHARACTER_ID: String = "normal"
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
		"special_description": "전방 블록을 가능한 거리만큼 최대 3칸 밀고 정면 충돌을 잠시 막는다.",
		"special_base_cooldown": 6.0,
		"attack_speed": 4,
		"move": 3,
		"jump": 1,
		"stamina": 3,
		"special_skill": 3,
	},
	"shield_guard": {
		"display_name": "방패병",
		"unlock_text": "7별",
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
		"unlock_text": "12별",
		"role": "낙하 경로 제어형",
		"description": "중력에 따라 흐르는 물길로 활성 블록의 착지 위치를 바꾼다.",
		"weapon": "소방 도끼 옆면",
		"special_name": "중력 물길",
		"special_description": "전방 물길을 만들고 닿은 활성 블록을 흐르는 방향으로 최대 2칸 미끄러뜨린다.",
		"special_base_cooldown": 13.0,
		"attack_speed": 3,
		"move": 3,
		"jump": 1,
		"stamina": 5,
		"special_skill": 5,
	},
	"cleaner": {
		"display_name": "청소부",
		"unlock_text": "18별",
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
		"unlock_text": "24별",
		"role": "정밀 재배치형",
		"description": "프라이팬으로 블록 한 칸을 위나 아래 대각선으로 옮긴다.",
		"weapon": "프라이팬",
		"special_name": "팬 토스",
		"special_description": "전방 블록 한 칸을 앞·위 또는 앞·아래 대각선으로 이동한다.",
		"special_base_cooldown": 9.0,
		"attack_speed": 3,
		"move": 4,
		"jump": 1,
		"stamina": 7,
		"special_skill": 7,
	},
	"clockmaker": {
		"display_name": "시계공",
		"unlock_text": "조건",
		"unlock_hint": "시간을 멈추려면 먼저 시간을 견뎌라.",
		"role": "시간 정지형",
		"description": "황동 톱니 가방과 거대한 태엽 열쇠로 낙하 시간을 멈추는 괴짜 장인.",
		"weapon": "태엽 열쇠 지팡이",
		"special_name": "정지 태엽",
		"special_description": "낙하 중인 활성 블록의 중력과 고정 시간을 3초 동안 멈추고 캐릭터만 움직인다.",
		"special_base_cooldown": 12.0,
		"attack_speed": 4,
		"move": 3,
		"jump": 1,
		"stamina": 5,
		"special_skill": 5,
	},
	"ninja": {
		"display_name": "닌자",
		"unlock_text": "조건",
		"unlock_hint": "상처 없이 속도를 견뎌라.",
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


static func move_speed(character_id: String) -> float:
	return 140.0 + float(stat(character_id, "move")) * 10.0


static func jump_cells(character_id: String) -> int:
	return 2 + (stat(character_id, "jump") - 1) / 3


static func stamina_drain_multiplier(character_id: String) -> float:
	return 1.0 - float(stat(character_id, "stamina") - 1) * 0.06


static func special_cooldown_multiplier(character_id: String) -> float:
	return 1.0 - float(stat(character_id, "special_skill") - 1) * 0.03


static func rotation_cooldown(character_id: String) -> float:
	return 2.1 - float(stat(character_id, "attack_speed")) * 0.1


static func special_cooldown(character_id: String) -> float:
	var profile: Dictionary = profile_for(character_id)
	return float(profile["special_base_cooldown"]) * special_cooldown_multiplier(character_id)
