class_name MainCharacterAnimationData
extends RefCounted

## 128px 균일 격자 캐릭터 atlas와 상태별 재생 규칙을 보관한다.
## 현재는 일반인을 기본 profile로 등록하고, 후속 캐릭터는 PROFILES에
## atlas과 표시 메타데이터만 추가하면 같은 Controller 상태 기계를 공유한다.

const IDLE: String = "idle"
const HANG: String = "hang"
const ATTACK: String = "attack"
const JUMP: String = "jump"
const ROTATION_KICK: String = "rotation_kick"
const SPECIAL: String = "special"

const DEFAULT_CHARACTER_ID: String = "normal"
const FRAME_SIZE: float = 128.0
const FRAME_DISPLAY_SIZE: Vector2 = Vector2(FRAME_SIZE, FRAME_SIZE)
const NORMAL_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/normal/normal_atlas.png"
)
const BOXER_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/boxer/boxer_atlas.png"
)
const SHIELD_GUARD_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/shield_guard/shield_guard_atlas.png"
)
const FIREFIGHTER_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/firefighter/firefighter_atlas.png"
)
const CLEANER_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/cleaner/cleaner_atlas.png"
)
const CHEF_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/chef/chef_atlas.png"
)
const CLOCKMAKER_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/clockmaker/clockmaker_atlas.png"
)
const NINJA_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/ninja/ninja_atlas.png"
)

const PROFILES: Dictionary = {
	DEFAULT_CHARACTER_ID: {
		"character_id": DEFAULT_CHARACTER_ID,
		"display_name": "일반인",
		"texture": NORMAL_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
	},
	"boxer": {
		"character_id": "boxer",
		"display_name": "복서",
		"texture": BOXER_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
	},
	"shield_guard": {
		"character_id": "shield_guard",
		"display_name": "방패병",
		"texture": SHIELD_GUARD_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
	},
	"firefighter": {
		"character_id": "firefighter",
		"display_name": "소방관",
		"texture": FIREFIGHTER_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
	},
	"cleaner": {
		"character_id": "cleaner",
		"display_name": "청소부",
		"texture": CLEANER_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
	},
	"chef": {
		"character_id": "chef",
		"display_name": "요리사",
		"texture": CHEF_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
	},
	"clockmaker": {
		"character_id": "clockmaker",
		"display_name": "시계공",
		"texture": CLOCKMAKER_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
	},
	"ninja": {
		"character_id": "ninja",
		"display_name": "닌자",
		"texture": NINJA_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
	},
}

const REGIONS: Dictionary = {
	IDLE: [
		Rect2(0, 0, 128, 128),
		Rect2(128, 0, 128, 128),
		Rect2(256, 0, 128, 128),
		Rect2(384, 0, 128, 128),
	],
	ATTACK: [
		Rect2(0, 128, 128, 128),
		Rect2(128, 128, 128, 128),
		Rect2(256, 128, 128, 128),
		Rect2(384, 128, 128, 128),
	],
	HANG: [
		Rect2(0, 256, 128, 128),
		Rect2(128, 256, 128, 128),
		Rect2(256, 256, 128, 128),
		Rect2(384, 256, 128, 128),
	],
	JUMP: [
		Rect2(0, 384, 128, 128),
		Rect2(128, 384, 128, 128),
		Rect2(256, 384, 128, 128),
		Rect2(384, 384, 128, 128),
		Rect2(512, 384, 128, 128),
		Rect2(640, 384, 128, 128),
		Rect2(768, 384, 128, 128),
		Rect2(896, 384, 128, 128),
	],
	ROTATION_KICK: [
		Rect2(0, 512, 128, 128),
		Rect2(128, 512, 128, 128),
		Rect2(256, 512, 128, 128),
		Rect2(384, 512, 128, 128),
		Rect2(512, 512, 128, 128),
		Rect2(640, 512, 128, 128),
		Rect2(768, 512, 128, 128),
		Rect2(896, 512, 128, 128),
	],
	SPECIAL: [
		Rect2(0, 640, 128, 128),
		Rect2(128, 640, 128, 128),
		Rect2(256, 640, 128, 128),
		Rect2(384, 640, 128, 128),
		Rect2(512, 640, 128, 128),
		Rect2(640, 640, 128, 128),
		Rect2(768, 640, 128, 128),
		Rect2(896, 640, 128, 128),
	],
}

const FRAME_DURATIONS: Dictionary = {
	IDLE: 0.18,
	HANG: 0.16,
	ATTACK: 0.10,
	JUMP: 0.0875,
	ROTATION_KICK: 0.0525,
	SPECIAL: 0.10,
}


static func has_character(character_id: String) -> bool:
	return PROFILES.has(character_id)


static func profile_for(character_id: String = DEFAULT_CHARACTER_ID) -> Dictionary:
	if PROFILES.has(character_id):
		return PROFILES[character_id] as Dictionary
	return PROFILES[DEFAULT_CHARACTER_ID] as Dictionary


static func display_name_for(character_id: String = DEFAULT_CHARACTER_ID) -> String:
	return str(profile_for(character_id)["display_name"])


static func display_offset_for(character_id: String = DEFAULT_CHARACTER_ID) -> Vector2:
	return profile_for(character_id)["display_offset"] as Vector2


static func display_size_for(character_id: String = DEFAULT_CHARACTER_ID) -> Vector2:
	return profile_for(character_id)["display_size"] as Vector2


static func texture_for(
	_state: String,
	character_id: String = DEFAULT_CHARACTER_ID
) -> Texture2D:
	return profile_for(character_id)["texture"] as Texture2D


static func region_for(
	state: String,
	elapsed: float,
	_character_id: String = DEFAULT_CHARACTER_ID
) -> Rect2:
	var resolved_state: String = state if REGIONS.has(state) else IDLE
	var frames: Array = REGIONS[resolved_state]
	var frame_index: int = int(elapsed / float(FRAME_DURATIONS[resolved_state]))
	if resolved_state == IDLE or resolved_state == HANG:
		frame_index %= frames.size()
	else:
		frame_index = mini(frame_index, frames.size() - 1)
	return frames[frame_index]
