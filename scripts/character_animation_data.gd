class_name Stage4CharacterAnimationData
extends RefCounted

## [역할 / C++ 대응]
## 캐릭터 애니메이션의 상태 이름, 텍스처, 프레임 사각형, 프레임 시간을 모은
## 읽기 전용 데이터 테이블이다. CharacterController가 이 클래스의 정적 함수만 호출한다.
##
## `preload()`는 C++ 프로그램 시작 전에 리소스 핸들을 준비하는 정적 로딩에 가깝고,
## `Rect2(x, y, w, h)`는 스프라이트 시트에서 잘라 쓸 픽셀 영역이다.
##
## [호출 관계]
## 호출자: CharacterController의 상수 별칭과 `_apply_animation_frame()`.
## 호출 대상: Texture2D 리소스와 Dictionary/Array 조회만 사용한다.

const IDLE: String = "idle" # 지상 대기/기본 상태 key.
const HANG: String = "hang" # 벽 또는 블록에 매달린 상태 key.
const PULL: String = "pull" # 블록 당기기 일회성 동작 key.
const ATTACK: String = "attack" # 펀치 일회성 동작 key.
const JUMP: String = "jump" # 공중 이동 상태 key.
const ROTATION_KICK: String = "rotation_kick" # V 회전 킥 전용 1회전 상태 key.

const IDLE_TEXTURE: Texture2D = preload("res://assets/player_animations.png") # idle과 pull frame 시트.
const HANG_TEXTURE: Texture2D = preload("res://assets/player_hang_animations.png") # hang frame 시트.
const ATTACK_TEXTURE: Texture2D = preload("res://assets/player_attack_animations.png") # punch 시트.
const JUMP_TEXTURE: Texture2D = preload("res://assets/player_jump_animations.png") # jump frame 시트.
const ROTATION_KICK_TEXTURE: Texture2D = preload(
	"res://assets/player_rotation_kick_animations.png"
) # 기존 jump 픽셀을 동일한 중심축에 재배치한 회전 킥 시트.

# 상태별 sprite-sheet source frame 목록.
const REGIONS: Dictionary = {
	IDLE: [
		Rect2(45, 55, 165, 270),
		Rect2(255, 55, 165, 270),
		Rect2(455, 55, 165, 270),
		Rect2(655, 55, 165, 270),
	],
	HANG: [
		Rect2(30, 80, 365, 700),
		Rect2(470, 80, 365, 700),
		Rect2(910, 80, 365, 700),
		Rect2(1350, 80, 365, 700),
	],
	PULL: [
		Rect2(25, 770, 200, 285),
		Rect2(235, 770, 200, 285),
		Rect2(435, 770, 200, 285),
		Rect2(635, 770, 200, 285),
	],
	ATTACK: [
		Rect2(30, 180, 380, 550),
		Rect2(465, 180, 380, 550),
		Rect2(900, 180, 380, 550),
		Rect2(1335, 180, 380, 550),
	],
	JUMP: [
		Rect2(20, 260, 240, 390),
		Rect2(270, 310, 250, 340),
		Rect2(530, 370, 225, 280),
		Rect2(780, 180, 220, 420),
		Rect2(1015, 140, 220, 400),
		Rect2(1260, 115, 200, 360),
		Rect2(1490, 190, 230, 460),
		Rect2(1750, 320, 220, 330),
	],
	ROTATION_KICK: [
		Rect2(0, 0, 64, 64),
		Rect2(64, 0, 64, 64),
		Rect2(128, 0, 64, 64),
		Rect2(192, 0, 64, 64),
		Rect2(256, 0, 64, 64),
		Rect2(320, 0, 64, 64),
		Rect2(384, 0, 64, 64),
		Rect2(448, 0, 64, 64),
	],
}

# 상태별 한 frame의 표시 시간(초).
const FRAME_DURATIONS: Dictionary = {
	IDLE: 0.18,
	HANG: 0.16,
	PULL: 0.16,
	ATTACK: 0.10,
	JUMP: 0.0875,
	ROTATION_KICK: 0.0525,
}


## 상황: CharacterController._apply_animation_frame()이 현재 상태의 texture를 바꿀 때 호출한다.
## 순서: ① state match ② hang/attack/jump 전용 시트 선택 ③ 나머지는 기본 idle 시트 선택.
## 결과: Texture2D 참조만 반환하며 리소스나 캐릭터 상태는 변경하지 않는다.
static func texture_for(state: String) -> Texture2D:
	match state:
		HANG:
			return HANG_TEXTURE
		ATTACK:
			return ATTACK_TEXTURE
		JUMP:
			return JUMP_TEXTURE
		ROTATION_KICK:
			return ROTATION_KICK_TEXTURE
		_:
			return IDLE_TEXTURE


## 상황: CharacterController가 elapsed 시간에 해당하는 sprite frame을 요구할 때 호출한다.
## 순서: ① 상태별 frame 배열/지속시간 조회 ② elapsed/duration으로 index 계산
##       ③ idle/hang은 나머지 연산으로 반복 ④ 일회성은 마지막 index로 제한.
## 결과: sprite sheet에서 사용할 Rect2를 반환하며 idle/hang만 무한 반복된다.
static func region_for(state: String, elapsed: float) -> Rect2:
	var frames: Array = REGIONS[state] # 현재 상태에 등록된 source Rect2 목록.
	var frame_index: int = int(elapsed / float(FRAME_DURATIONS[state])) # 경과시간 기준 원시 frame 번호.
	if state == IDLE or state == HANG:
		frame_index %= frames.size()
	else:
		frame_index = mini(frame_index, frames.size() - 1)
	return frames[frame_index]
