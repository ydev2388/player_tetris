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
const FRAME_ALPHA_THRESHOLD: float = 0.5
static var _visible_region_cache: Dictionary = {}
const VISIBLE_HEIGHTS: Dictionary = {
	IDLE: 96.0,
	ATTACK: 96.0,
	HANG: 96.0,
	JUMP: 96.0,
	ROTATION_KICK: 96.0,
	SPECIAL: 96.0,
}
const NORMAL_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/normal/normal_reference_atlas_v8.png"
)
const BOXER_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/boxer/boxer_reference_atlas_v6.png"
)
const SHIELD_GUARD_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/shield_guard/shield_guard_reference_atlas_v6.png"
)
const FIREFIGHTER_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/firefighter/firefighter_reference_atlas_v6.png"
)
const CLEANER_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/cleaner/cleaner_reference_atlas_v6.png"
)
const SAINTESS_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/saintess/saintess_reference_atlas_v1.png"
)
const CLOCKMAKER_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/clockmaker/clockmaker_reference_atlas_v6.png"
)
const NINJA_ATLAS: Texture2D = preload(
	"res://assets/sprites/characters/ninja/ninja_reference_atlas_v6.png"
)

const PROFILES: Dictionary = {
	DEFAULT_CHARACTER_ID: {
		"character_id": DEFAULT_CHARACTER_ID,
		"display_name": "일반인",
		"texture": NORMAL_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
		"geometry_mode": "fixed_reference",
		"fixed_scale": Vector2.ONE,
		"fixed_offset": Vector2(0.0, 3.0),
		"hang_frame_count": 8,
	},
	"boxer": {
		"character_id": "boxer",
		"display_name": "복서",
		"texture": BOXER_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
		"geometry_mode": "fixed_reference",
		"fixed_scale": Vector2.ONE,
		"fixed_offset": Vector2(0.0, 3.0),
	},
	"shield_guard": {
		"character_id": "shield_guard",
		"display_name": "방패병",
		"texture": SHIELD_GUARD_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
		"geometry_mode": "fixed_reference",
		"fixed_scale": Vector2.ONE,
		"fixed_offset": Vector2(0.0, 3.0),
	},
	"firefighter": {
		"character_id": "firefighter",
		"display_name": "소방관",
		"texture": FIREFIGHTER_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
		"geometry_mode": "fixed_reference",
		"fixed_scale": Vector2.ONE,
		"fixed_offset": Vector2(0.0, 3.0),
	},
	"cleaner": {
		"character_id": "cleaner",
		"display_name": "청소부",
		"texture": CLEANER_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
		"geometry_mode": "fixed_reference",
		"fixed_scale": Vector2.ONE,
		"fixed_offset": Vector2(0.0, 3.0),
	},
	"chef": {
		"character_id": "chef",
		"display_name": "성녀",
		"texture": SAINTESS_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
		"geometry_mode": "fixed_reference",
		"fixed_scale": Vector2.ONE,
		"fixed_offset": Vector2(0.0, 3.0),
	},
	"clockmaker": {
		"character_id": "clockmaker",
		"display_name": "시계공",
		"texture": CLOCKMAKER_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
		"geometry_mode": "fixed_reference",
		"fixed_scale": Vector2.ONE,
		"fixed_offset": Vector2(0.0, 3.0),
	},
	"ninja": {
		"character_id": "ninja",
		"display_name": "닌자",
		"texture": NINJA_ATLAS,
		"display_offset": Vector2.ZERO,
		"display_size": FRAME_DISPLAY_SIZE,
		"geometry_mode": "fixed_reference",
		"fixed_scale": Vector2.ONE,
		"fixed_offset": Vector2(0.0, 3.0),
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
		Rect2(512, 256, 128, 128),
		Rect2(640, 256, 128, 128),
		Rect2(768, 256, 128, 128),
		Rect2(896, 256, 128, 128),
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


static func uses_fixed_geometry(character_id: String = DEFAULT_CHARACTER_ID) -> bool:
	return str(profile_for(character_id).get("geometry_mode", "legacy_alpha_fit")) == "fixed_reference"


static func fixed_scale_for(character_id: String = DEFAULT_CHARACTER_ID) -> Vector2:
	return profile_for(character_id).get("fixed_scale", Vector2.ONE) as Vector2


static func fixed_offset_for(character_id: String = DEFAULT_CHARACTER_ID) -> Vector2:
	return profile_for(character_id).get("fixed_offset", Vector2.ZERO) as Vector2


static func visible_height_for(
	state: String,
	character_id: String = DEFAULT_CHARACTER_ID
) -> float:
	var resolved_state: String = state if VISIBLE_HEIGHTS.has(state) else IDLE
	var profile_scale: float = display_size_for(character_id).y / FRAME_SIZE
	return float(VISIBLE_HEIGHTS[resolved_state]) * profile_scale


static func texture_for(
	_state: String,
	character_id: String = DEFAULT_CHARACTER_ID
) -> Texture2D:
	return profile_for(character_id)["texture"] as Texture2D


static func region_for(
	state: String,
	elapsed: float,
	character_id: String = DEFAULT_CHARACTER_ID
) -> Rect2:
	var resolved_state: String = state if REGIONS.has(state) else IDLE
	var frames: Array = regions_for(resolved_state, character_id)
	var frame_index: int = int(elapsed / float(FRAME_DURATIONS[resolved_state]))
	if resolved_state == IDLE or resolved_state == HANG:
		frame_index %= frames.size()
	else:
		frame_index = mini(frame_index, frames.size() - 1)
	return frames[frame_index]


static func regions_for(
	state: String,
	character_id: String = DEFAULT_CHARACTER_ID
) -> Array:
	var resolved_state: String = state if REGIONS.has(state) else IDLE
	var frames: Array = REGIONS[resolved_state]
	if resolved_state != HANG:
		return frames
	var requested_count: int = int(profile_for(character_id).get("hang_frame_count", 4))
	return frames.slice(0, clampi(requested_count, 1, frames.size()))


static func frame_count_for(
	state: String,
	character_id: String = DEFAULT_CHARACTER_ID
) -> int:
	return regions_for(state, character_id).size()


static func visible_region_for(
	state: String,
	elapsed: float,
	character_id: String = DEFAULT_CHARACTER_ID
) -> Rect2:
	var frame_region: Rect2 = region_for(state, elapsed, character_id)
	var texture: Texture2D = texture_for(state, character_id)
	return opaque_region_for(texture, frame_region)


static func opaque_region_for(texture: Texture2D, source_region: Rect2) -> Rect2:
	var cache_key: String = "%s:%d:%d:%d:%d" % [
		texture.resource_path,
		int(source_region.position.x),
		int(source_region.position.y),
		int(source_region.size.x),
		int(source_region.size.y),
	]
	if _visible_region_cache.has(cache_key):
		return _visible_region_cache[cache_key] as Rect2

	var image: Image = texture.get_image()
	var min_x: int = int(source_region.size.x)
	var min_y: int = int(source_region.size.y)
	var max_x: int = -1
	var max_y: int = -1
	var source_left: int = int(source_region.position.x)
	var source_top: int = int(source_region.position.y)
	for pixel_y: int in range(int(source_region.size.y)):
		for pixel_x: int in range(int(source_region.size.x)):
			if image.get_pixel(source_left + pixel_x, source_top + pixel_y).a < FRAME_ALPHA_THRESHOLD:
				continue
			min_x = mini(min_x, pixel_x)
			min_y = mini(min_y, pixel_y)
			max_x = maxi(max_x, pixel_x)
			max_y = maxi(max_y, pixel_y)

	var visible_region: Rect2 = source_region
	if max_x >= min_x and max_y >= min_y:
		visible_region = Rect2(
			source_region.position + Vector2(float(min_x), float(min_y)),
			Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1))
		)
	_visible_region_cache[cache_key] = visible_region
	return visible_region
