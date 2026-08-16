class_name MainCharacterController
extends CharacterBody2D

const STANDING_WALL_CONTACT_TOLERANCE: float = 0.75
const BLOCK_VISUAL_INSET: float = 2.0

## [역할 / C++ 대응]
## 플레이어 캐릭터의 물리, 입력, 스태미나, 공격, 매달리기, 피해, 애니메이션을
## 한 physics-frame 상태 기계로 묶은 컨트롤러다. CharacterBody2D의 `velocity`,
## `move_and_slide()`, `is_on_floor()`를 사용하므로 C++의 kinematic character와 비슷하다.
##
## [호출 관계]
## Godot: `_ready()`, 고정 timestep마다 `_physics_process(delta)`.
## GameController.game_restarted signal: `_reset_character()`.
## BoardPhysics: 보드 충돌체 갱신 뒤 `validate_position()`.
## GameView: 공개 stats/getter와 `stats_changed`를 구독.
## 호출 대상: GameController(명상 속도, 피스 밀기/회전, 게임 종료),
##           BoardModel/TetrominoData(공간 판정), AnimationData, Input.
##
## GDScript 핵심: 들여쓰기가 C++의 `{}` 블록을 대신하고, `var x: Type`은 지역/멤버 변수,
## `func f(a: T) -> R`은 함수 시그니처, `and/or/not`은 `&&/||/!`에 해당한다.

signal stats_changed # 생명/stamina/cooldown 변경을 GameView에 알린다.
signal binding_started
signal binding_ended

# 좌표/이동 상수. Godot 2D는 +x가 오른쪽, +y가 아래이므로 점프 속도는 음수다.
# GIT_GRID_SCALE은 원본 28px 기준 수치를 현재 48px 셀에 맞추는 배율이다.
const CELL_SIZE: float = MainLayout.CELL_SIZE # 보드 한 셀의 표시·물리 크기.
const GIT_GRID_SCALE: float = CELL_SIZE / 28.0 # 원본 28px 물리값을 48px 보드로 환산하는 배율.
const CHARACTER_HEIGHT: float = CELL_SIZE * 2.0 # 논리 피해 판정 높이: 2셀.
const CHARACTER_COLLIDER_WIDTH: float = 28.0 * MainLayout.DISPLAY_SCALE
const CHARACTER_COLLIDER_HEIGHT: float = 60.0 * MainLayout.DISPLAY_SCALE
const CHARACTER_COLLIDER_OFFSET_Y: float = 2.0 * MainLayout.DISPLAY_SCALE
const BOARD_MIN_X: float = CHARACTER_COLLIDER_WIDTH * 0.5
const BOARD_MAX_X: float = MainBoardModel.WIDTH * CELL_SIZE - CHARACTER_COLLIDER_WIDTH * 0.5
const BOARD_MIN_Y: float = CHARACTER_COLLIDER_HEIGHT * 0.5 - CHARACTER_COLLIDER_OFFSET_Y
const BOARD_MAX_Y: float = (
	MainBoardModel.VISIBLE_HEIGHT * CELL_SIZE
	- CHARACTER_COLLIDER_HEIGHT * 0.5
	- CHARACTER_COLLIDER_OFFSET_Y
)
const RESPAWN_TOP_MARGIN_CELLS: int = 1 # 피격 재스폰 시 캐릭터 윗면과 화면 위의 간격.
const RESPAWN_CENTER_Y: float = ( # 윗면 48px + 논리 몸체 반높이 48px.
	RESPAWN_TOP_MARGIN_CELLS * CELL_SIZE + CHARACTER_HEIGHT * 0.5
)
const RESPAWN_BODY_SIZE: Vector2 = Vector2( # 프레임과 무관한 재스폰 점유 영역.
	28.0 * MainLayout.DISPLAY_SCALE,
	64.0 * MainLayout.DISPLAY_SCALE
)
const MAX_LIVES: int = 3 # 패시브 적용 전 게임 시작 시 생명 상한.
const MOVE_SPEED: float = 150.0 * GIT_GRID_SCALE # 수평 목표 최고속도(px/s).
const GROUND_ACCELERATION: float = 1800.0 * GIT_GRID_SCALE # 지상 가속도(px/s²).
const GROUND_DECELERATION: float = 1800.0 * GIT_GRID_SCALE # 지상 무입력 감속도(px/s²).
const AIR_ACCELERATION: float = 1800.0 * GIT_GRID_SCALE # 공중 가속도(px/s²).
const AIR_DECELERATION: float = 1800.0 * GIT_GRID_SCALE # 공중 무입력 감속도(px/s²).
const JUMP_VELOCITY: float = -350.0 * GIT_GRID_SCALE # 점프 시작 y속도. 위쪽이 음수다.
const GRAVITY: float = 1000.0 * GIT_GRID_SCALE # 매초 y속도에 더할 중력(px/s²).
const FALL_GRAVITY_MULTIPLIER: float = 1.0 # 하강 중 추가 중력 배율.
const MAX_FALL_SPEED: float = 3200.0 * MainLayout.DISPLAY_SCALE
const COYOTE_TIME: float = 0.12 # 발판을 떠난 뒤에도 지상점프를 허용하는 초.
const JUMP_BUFFER_TIME: float = 0.12 # 착지 전에 누른 점프를 기억하는 초.
const JUMP_RELEASE_MULTIPLIER: float = 0.45 # 상승 중 키를 놓을 때 y속도에 곱하는 값.
const WALL_JUMP_HORIZONTAL_SPEED: float = 185.0 * GIT_GRID_SCALE # 벽 반대 x속도(px/s).
const WALL_JUMP_VERTICAL_MULTIPLIER: float = 1.0 # 벽점프의 JUMP_VELOCITY 배율.
const HANG_CLIMB_SPEED: float = 78.0 * GIT_GRID_SCALE # 매달린 상하 이동속도(px/s).
const HANG_CORNER_CLIMB_SPEED: float = 115.0 * GIT_GRID_SCALE
const HANG_HAND_OFFSET_Y: float = CHARACTER_HEIGHT / 3.0 # hang 스프라이트 손의 캐릭터 중심 기준 높이.
const HANG_WALL_GAP: float = 0.0 # 공통 콜라이더 옆면과 실제 벽면 사이의 고정 간격.
const IDLE_ANIMATION_SPEED_EPSILON: float = 0.5 # 정지로 간주해 대기 첫 프레임을 고정하는 속도.
const HANG_REGRAB_COOLDOWN: float = 0.18 # 벽점프 직후 같은 벽 재매달림 금지 초.
const HANG_JUMP_GRACE_TIME: float = 0.15 # grab을 놓은 뒤에도 벽점프 가능한 초.
const WALL_JUMP_STEER_TIME: float = 0.65 # 벽점프 뒤 원래 벽 방향 공중 조향 보정 초.
const WALL_JUMP_STEER_ACCELERATION: float = 1500.0 * MainLayout.DISPLAY_SCALE

# 자원과 행동 비용/지속시간. 이름의 단위가 없으면 픽셀 또는 초당 값이다.
const MAX_STAMINA: float = 100.0 # stamina 상한과 reset 값.
const HANG_STAMINA_DRAIN: float = MAX_STAMINA / 3.0 # 매달림 초당 소모량: 가득 차면 3초.
const ROTATION_COOLDOWN: float = 2.0 # 성공 블록 플립 재사용 대기시간(초).
const ROTATION_SPIN_DURATION: float = 0.42 # 전용 8 frame과 한 바퀴 회전의 전체 시간.
const SELF_RESPAWN_HOLD_SECONDS: float = 1.0 # 자력 재스폰을 확정하기 위한 연속 입력 시간.
const POST_SPIN_APEX_SPEED: float = 40.0 * MainLayout.DISPLAY_SCALE # 종료 후 jump frame 경계.
const INVULNERABILITY_SECONDS: float = 1.2 # 피해 직후 추가 피해를 무시하는 초.
const ATTACK_ANIMATION_DURATION: float = 0.4 # 공격 animation 우선 표시 초.
const SPECIAL_ANIMATION_DURATION: float = 0.8 # 8 frame 특수 스킬 표시 초.
const PUNCH_HIT_CONFIRM_SECONDS: float = 0.1 # 공격 시작 뒤 주먹 판정을 유지하는 시간.
const BOXER_SPECIAL_HIT_TIME: float = 0.25
const SHIELD_SPECIAL_HIT_TIME: float = 0.25
const FIREFIGHTER_SPECIAL_HIT_TIME: float = 0.6
const CLEANER_SPECIAL_HIT_TIME: float = 0.4
const CHEF_SPECIAL_HIT_TIME: float = 0.3
const CLOCKMAKER_SPECIAL_HIT_TIME: float = 0.4
const NINJA_SPECIAL_HIT_TIME: float = 0.25
const CHEF_MEAT_DURATION: float = 3.0
const CHEF_MEAT_MOVE_MULTIPLIER: float = 1.2

# Script 리소스는 C++의 namespace/static utility class를 참조하는 핸들과 비슷하다.
const ANIMATION_DATA: Script = preload("res://scripts/character_animation_data.gd") # frame 데이터.
const CHARACTER_DATA: Script = preload("res://scripts/character_data.gd") # 베타 캐릭터 능력치 데이터.
const SAINTESS_AURA_SHADER: Shader = preload("res://shaders/saintess_aura.gdshader")
const SAINTESS_BARRIER_TEXTURE: Texture2D = preload(
	"res://assets/sprites/effects/saintess/saintess_barrier_v1.png"
)
const SFX_HURT: AudioStream = preload("res://assets/sfx/01_player_hurt.wav")
const SFX_PUNCH: AudioStream = preload("res://assets/sfx/02_block_punch.wav")
const SFX_FLIP: AudioStream = preload("res://assets/sfx/03a_block_flip.wav")
const SFX_JUMP: AudioStream = preload("res://assets/sfx/04_jump.wav")
const SFX_MEDITATION_START: AudioStream = preload("res://assets/sfx/05a_meditation_start.wav")
const SFX_MEDITATION_LOOP: AudioStream = preload("res://assets/sfx/05b_meditation_loop.wav")
const SFX_MEDITATION_END: AudioStream = preload("res://assets/sfx/05c_meditation_end.wav")
const SFX_BLOCK_ELIMINATION: AudioStream = preload("res://assets/sfx/07_block_elimination.wav")
const SFX_WALL_CLIMB: AudioStream = preload("res://assets/sfx/09_wall_climb.wav")

const BASIC_ATTACK_FORWARD_REACH: float = CELL_SIZE # 무기 외형과 무관한 전방 한 블록 판정 길이.
const ROTATION_KICK_BOSS_REACH: float = 27.2 # 기본 공격 확장의 영향을 받지 않는 기존 발차기 보스 판정.
const SHURIKEN_SPEED: float = CELL_SIZE * 12.0
const SHURIKEN_REACH_CELLS: int = 6
const SHURIKEN_IMPACT_DURATION: float = 0.37
const SHURIKEN_COLLISION_SIZE: Vector2 = Vector2(32.0, 32.0)
const FRAME_ALPHA_THRESHOLD: float = 128.0 / 255.0 # 표시 실루엣의 반투명 외곽 제외 경계.
const FIXED_SUPPORT_FOOT_WIDTH: float = 28.0 * MainLayout.DISPLAY_SCALE
const FIXED_SUPPORT_TOLERANCE: float = MainLayout.DISPLAY_SCALE

@export var character_id: String = ANIMATION_DATA.DEFAULT_CHARACTER_ID

# main.tscn의 상대 경로로 찾은 협력 객체. `@onready`라 `_ready()` 전에 유효해진다.
@onready var controller: MainGameController = $"../../GameController" # 피스/게임 상태 명령 대상.
@onready var sprite: Sprite2D = $Sprite # animation/flip/회전/색/깜빡임 대상.
@onready var crush_sensor: ShapeCast2D = $CrushSensor # 외형과 무관한 머리 압착 센서.
@onready var left_ray: RayCast2D = $LeftRay # 왼쪽 매달릴 collision 탐지기.
@onready var right_ray: RayCast2D = $RightRay # 오른쪽 매달릴 collision 탐지기.
@onready var boundaries: StaticBody2D = $"../Boundaries" # 바닥과 양쪽 보드 벽 collision 소유자.

var _sfx_player: AudioStreamPlayer
var _sfx_cue_player: AudioStreamPlayer
var _meditation_loop_player: AudioStreamPlayer
var _saintess_aura_material: ShaderMaterial
var _saintess_barrier_sprite: Sprite2D

# GameView/테스트가 읽는 공개 상태.
var lives: int = MAX_LIVES # 남은 피격 허용 횟수. 0이면 controller.end_game().
var stamina: float = MAX_STAMINA # 행동 자원 0~100. 매달림에 사용.
var facing: int = 1 # 바라보는 방향: 왼쪽 -1, 오른쪽 +1.
var is_hanging: bool = false # true면 일반 이동 대신 벽 추적/상하 이동 branch를 실행.
var is_meditating: bool = false # true면 정지하고 Controller 테트리스 시간을 2배로 함.
var is_bound: bool = false
var binding_timer: float = 0.0
var rotation_cooldown_remaining: float = 0.0 # 0보다 크면 블록 플립 입력 거부; 매 frame 감소.
var special_cooldown_remaining: float = 0.0 # 고유 특수 스킬 재사용 대기시간.
var passive_levels: Array[int] = [0, 0, 0, 0, 0, 0] # 상점에서 구매한 전역 패시브 레벨.

# 이 클래스 내부의 상태 기계용 변수. `_`는 C++의 private와 같은 강제 접근 제한은
# 아니지만 외부에서 사용하지 말라는 GDScript 관례다.
var _invulnerability_remaining: float = 0.0 # 0보다 크면 take_damage를 무시하고 깜빡임.
var _spin_remaining: float = 0.0 # 블록 플립 sprite 회전을 계속할 countdown(초).
var _spin_elapsed: float = 0.0 # 현재 블록 플립에서 소비한 시간(0~0.42초).
var _spin_direction: int = 1 # 회전 시작 때 고정한 방향; 도중 facing 변경과 무관.
var _pending_rotation_launch_velocity: float = 0.0 # 새 active collider 동기화 다음 frame에 적용할 y속도.
var _post_spin_animation_seeded: bool = false # 종료 frame seed를 한 번 보존할 flag.
var _hang_body: Node2D # 매달린 실제 collider. 활성 피스면 움직임을 따라간다.
var _hang_last_global_position: Vector2 # 붙은 body의 이전 frame 위치; 이동 delta 계산용.
var _hang_top_global_y: float = 0.0 # 현재 매달린 외부 옆면 구간의 상단.
var _hang_bottom_global_y: float = 0.0 # 현재 매달린 외부 옆면 구간의 하단.
var _hang_face_global_x: float = 0.0 # 공통 콜라이더가 붙는 실제 벽면 X.
var _hang_animation_direction: float = 0.0 # 매달림 이동 분기가 채택한 방향: 위 -1/정지 0/아래 +1.
var _hang_corner_climb_active: bool = false
var _hang_corner_climb_start_global: Vector2 = Vector2.ZERO
var _hang_corner_climb_target_global: Vector2 = Vector2.ZERO
var _hang_corner_climb_progress: float = 0.0
var _hang_corner_climb_duration: float = 0.0
var _coyote_remaining: float = 0.0 # 0보다 크면 발판을 떠났어도 지상점프 허용.
var _jump_buffer_remaining: float = 0.0 # 0보다 크면 최근 jump press를 착지까지 기억.
var _hang_regrab_remaining: float = 0.0 # 0보다 크면 새 매달리기 시작 금지.
var _hang_jump_grace_remaining: float = 0.0 # grab 해제 뒤 벽점프 허용 countdown.
var _hang_jump_facing: int = 1 # 매달린 벽 방향(-1 왼쪽/+1 오른쪽)을 jump까지 보존.
var _wall_jump_control_remaining: float = 0.0 # 원래 벽 방향 공중 조향 보정 countdown.
var _wall_jump_wall_facing: int = 1 # 직전 벽점프가 출발한 벽 방향.
var _variable_jump_active: bool = false # true면 jump release로 상승속도를 줄일 수 있음.
var _attack_cooldown_remaining: float = 0.0 # 0보다 크면 새 펀치 sequence 시작 금지.
var _attack_animation_remaining: float = 0.0 # 0보다 크면 ATTACK animation이 최우선.
var _special_animation_remaining: float = 0.0 # 0보다 크면 SPECIAL animation을 표시.
var _sprint_remaining: float = 0.0 # 일반인 전력 질주의 남은 시간.
var _pending_special_id: String = ""
var _pending_special_remaining: float = 0.0
var _pending_barrier_position: Vector2 = Vector2.ZERO
var _pending_barrier_direction: int = 0
var _pending_water_start_cell: Vector2i = Vector2i.ZERO
var _pending_water_direction: int = 0
var _pending_cleaner_center_below: Vector2i = Vector2i.ZERO
var _barrier_remaining: float = 0.0
var _barrier_direction: int = 0
var _water_remaining: float = 0.0
var _chef_meat_remaining: float = 0.0
var _chef_meat_guard_available: bool = false
var _last_special_succeeded: bool = true
var _ninja_special_result: Dictionary = {}
var _ninja_projectile: Dictionary = {}
var _pending_punch_stage: int = 0 # 0이면 없음, 1~3이면 판정 대기 중인 펀치 거리.
var _pending_punch_hit_remaining: float = 0.0 # 공격 시작 뒤 남은 주먹 판정 시간.
var _ignore_initial_jump_until_released: bool = false # 메뉴 Z로 게임을 열었을 때 첫 점프를 막는다.
var _animation_state: String = ANIMATION_DATA.IDLE # 현재 sprite frame table key.
var _animation_time: float = 0.0 # 현재 animation_state에 머문 경과시간(초).
var _respawn_airborne_pending: bool = false # 순간이동 직후 이전 바닥 접지 cache를 한 번 무시.
var _was_grounded_for_stamina: bool = true # 비접지→접지 전환에서만 stamina를 완충하기 위한 이전 상태.
var _self_respawn_hold_time: float = 0.0 # Q 또는 사용자 지정 키를 연속으로 누른 시간.
var _self_respawn_requires_release: bool = false # 발동 뒤 같은 hold의 연속 생명 차감을 막는다.
var _frame_alpha_bounds_cache: Dictionary = {} # 캐릭터/프레임별 불투명 영역.
var _animation_image_cache: Dictionary = {} # texture path별 CPU alpha 판정용 Image.
var _respawn_random: RandomNumberGenerator = RandomNumberGenerator.new() # 캐릭터 X 전용 난수열.


## 상황: CharacterBody2D가 씬에 준비될 때 Godot가 한 번 호출한다.
## 순서: pause 중에도 처리되도록 mode 설정 → SFX player 준비
##       → controller.game_restarted에 `_reset_character()` 연결 → 즉시 reset.
## 결과: 첫 physics frame 전에 노드 참조와 모든 캐릭터 상태가 준비된다.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ANIMATION_DATA.has_character(character_id):
		character_id = ANIMATION_DATA.DEFAULT_CHARACTER_ID
	_ignore_initial_jump_until_released = Input.is_action_pressed(&"character_jump")
	_sfx_player = _create_sfx_player()
	_sfx_cue_player = _create_sfx_player()
	_meditation_loop_player = _create_sfx_player()
	_setup_saintess_aura_material()
	_meditation_loop_player.finished.connect(_restart_meditation_loop)
	_respawn_random.randomize()
	controller.game_restarted.connect(_reset_character)
	controller.active_piece_descended.connect(handle_active_piece_descended)
	controller.lines_cleared.connect(_play_block_elimination_sfx)
	_reset_character()


## 후속 캐릭터 선택 UI가 시각 profile을 교체할 때 사용한다.
func set_character_id(value: String) -> bool:
	if not ANIMATION_DATA.has_character(value) or not CHARACTER_DATA.has_character(value):
		return false
	if character_id == value:
		return true
	character_id = value
	_frame_alpha_bounds_cache.clear()
	_animation_image_cache.clear()
	_animation_state = ANIMATION_DATA.IDLE
	_animation_time = 0.0
	_special_animation_remaining = 0.0
	special_cooldown_remaining = 0.0
	_sprint_remaining = 0.0
	_cancel_character_skill_effects()
	controller.clear_skill_effects()
	_apply_animation_frame()
	_sync_saintess_aura()
	return true


func set_passive_levels(values: Array) -> void:
	passive_levels.clear()
	for index: int in range(MainCharacterData.PASSIVE_COUNT):
		var value: int = int(values[index]) if index < values.size() else 0
		passive_levels.append(clampi(value, 0, MainCharacterData.PASSIVE_LEVEL_MAX))
	lives = get_max_lives()
	stats_changed.emit()


func get_max_lives() -> int:
	return MAX_LIVES + CHARACTER_DATA.health_life_bonus(passive_levels)


## 능력 코드가 추가되면 발동 직후 이 메서드를 호출한다.
func play_special_animation() -> void:
	_special_animation_remaining = SPECIAL_ANIMATION_DURATION
	_animation_state = ANIMATION_DATA.SPECIAL
	_animation_time = 0.0
	_apply_animation_frame()


func _handle_special_input() -> void:
	if Input.is_action_just_pressed(&"character_special"):
		_attempt_special_skill()


func _attempt_special_skill() -> bool:
	if special_cooldown_remaining > 0.0:
		return false
	if not _can_use_special():
		return false
	if (character_id == "firefighter" or character_id == "cleaner") and not is_on_floor():
		return false

	var delay: float = 0.0
	match character_id:
		"normal":
			_sprint_remaining = 2.0
		"boxer":
			delay = BOXER_SPECIAL_HIT_TIME
		"shield_guard":
			delay = SHIELD_SPECIAL_HIT_TIME
			# Bind the barrier to the cast pose so turning during the wind-up cannot
			# move it to the other side of the character.
			_pending_barrier_position = position
			_pending_barrier_direction = facing
		"firefighter":
			delay = FIREFIGHTER_SPECIAL_HIT_TIME
			# The hose path belongs to the cast pose, just like the shield barrier.
			# Turning or being displaced during the long wind-up must not redirect it.
			_pending_water_start_cell = _front_board_cell()
			_pending_water_direction = facing
		"cleaner":
			delay = CLEANER_SPECIAL_HIT_TIME
			# Cleaning targets the three cells under the cast pose. Movement during
			# the sweep animation must not relocate the affected row.
			_pending_cleaner_center_below = _cell_below_feet()
		"chef":
			delay = CHEF_SPECIAL_HIT_TIME
		"clockmaker":
			delay = CLOCKMAKER_SPECIAL_HIT_TIME
		"ninja":
			delay = NINJA_SPECIAL_HIT_TIME
			_ninja_special_result.clear()
			_ninja_projectile.clear()
		_:
			return false

	special_cooldown_remaining = current_special_cooldown()
	play_special_animation()
	if delay > 0.0:
		_pending_special_id = character_id
		_pending_special_remaining = delay
	stats_changed.emit()
	return true


func _can_use_special() -> bool:
	return (
		_pending_special_id.is_empty()
		and not is_hanging
		and not is_meditating
		and _attack_animation_remaining <= 0.0
		and _spin_remaining <= 0.0
	)


func _resolve_pending_special() -> void:
	var skill_id: String = _pending_special_id
	_pending_special_id = ""
	_pending_special_remaining = 0.0
	match skill_id:
		"boxer":
			var boxer_target: Variant = _boxer_special_target_cell()
			var moved: int = 0
			if boxer_target != null:
				moved = controller.push_front_target(
					boxer_target as Vector2i,
					facing,
					3,
					true
				)
			_last_special_succeeded = moved > 0
		"shield_guard":
			_barrier_direction = _pending_barrier_direction
			var barrier_cells: Array[Vector2i] = _available_barrier_cells_from(
				_barrier_cells_at(_pending_barrier_position, _pending_barrier_direction)
			)
			if barrier_cells.is_empty():
				_last_special_succeeded = false
				_barrier_remaining = 0.0
				_barrier_direction = 0
				controller.clear_transient_blockers()
			else:
				_last_special_succeeded = true
				_barrier_remaining = 2.0
				controller.set_transient_blockers(barrier_cells)
			_pending_barrier_position = Vector2.ZERO
			_pending_barrier_direction = 0
		"firefighter":
			var created: bool = controller.create_water_path(
				_pending_water_start_cell,
				_pending_water_direction,
				3
			)
			_last_special_succeeded = created
			_water_remaining = 4.0 if created else 0.0
			_pending_water_start_cell = Vector2i.ZERO
			_pending_water_direction = 0
		"cleaner":
			var removed: int = controller.clean_exposed_cells(_pending_cleaner_center_below)
			_last_special_succeeded = removed > 0
			_pending_cleaner_center_below = Vector2i.ZERO
		"chef":
			_chef_meat_remaining = CHEF_MEAT_DURATION
			_chef_meat_guard_available = true
			_last_special_succeeded = true
		"clockmaker":
			_last_special_succeeded = controller.freeze_falling_blocks(3.0)
		"ninja":
			_start_ninja_projectile()
			_last_special_succeeded = true
	stats_changed.emit()


func _cancel_character_skill_effects() -> void:
	_pending_special_id = ""
	_pending_special_remaining = 0.0
	_pending_barrier_position = Vector2.ZERO
	_pending_barrier_direction = 0
	_pending_water_start_cell = Vector2i.ZERO
	_pending_water_direction = 0
	_pending_cleaner_center_below = Vector2i.ZERO
	_barrier_remaining = 0.0
	_barrier_direction = 0
	_water_remaining = 0.0
	_chef_meat_remaining = 0.0
	_chef_meat_guard_available = false
	_last_special_succeeded = true
	_ninja_special_result.clear()
	_ninja_projectile.clear()
	if is_instance_valid(controller):
		controller.clear_fall_freeze()
		controller.clear_transient_blockers()
		controller.clear_water_path()


func clear_runtime_state() -> void:
	if is_instance_valid(controller):
		_set_meditating(false)
	_end_binding()
	_exit_hang()
	_cancel_jump_intent()
	_cancel_wall_jump_control()
	_cancel_character_skill_effects()
	_attack_cooldown_remaining = 0.0
	_attack_animation_remaining = 0.0
	_special_animation_remaining = 0.0
	_spin_remaining = 0.0
	_spin_elapsed = 0.0
	_pending_rotation_launch_velocity = 0.0
	_post_spin_animation_seeded = false
	_self_respawn_hold_time = 0.0
	_self_respawn_requires_release = false
	_invulnerability_remaining = 0.0
	velocity = Vector2.ZERO
	if is_instance_valid(sprite):
		sprite.rotation = 0.0
		sprite.modulate = Color.WHITE
		sprite.visible = true
	for player: AudioStreamPlayer in [_sfx_player, _sfx_cue_player, _meditation_loop_player]:
		if is_instance_valid(player):
			player.stop()
	stats_changed.emit()


## 상황: Godot의 고정 physics timestep마다 호출되는 캐릭터 최상위 상태 기계다.
## 순서: 비PLAYING 조기 정지 → timers 감소 → 기존/신규 명상 branch
##       → punch 처리 → hanging 또는 normal movement → 공통 시각/위치 검증.
## 결과: 한 frame에 서로 배타적인 이동 상태 하나만 실행되고 모든 후처리는 공통 적용된다.
func _physics_process(delta: float) -> void:
	if controller.state != MainGameController.GameState.PLAYING:
		_stop_for_inactive_game()
		return
	_update_timers(delta)
	_advance_ninja_projectile(delta)
	if is_bound:
		_update_binding(delta)
		_finish_physics_frame(delta)
		return
	_handle_special_input()
	if _handle_self_respawn_input(delta):
		_finish_physics_frame(delta)
		return

	if is_meditating and not Input.is_action_just_pressed(&"character_rotation_kick"):
		_handle_meditation(delta)
		_finish_physics_frame(delta)
		return
	if is_meditating:
		_set_meditating(false)
	if _can_start_meditating():
		_set_meditating(true)
		_handle_meditation(delta)
		_finish_physics_frame(delta)
		return

	_handle_punch()
	if is_hanging:
		_handle_hanging(delta)
	else:
		_handle_movement(delta)
	_finish_physics_frame(delta)


## 상황: `_physics_process()`가 PAUSED/GAME_OVER 상태를 발견했을 때 호출한다.
## 순서: `_set_meditating(false)` → velocity를 Vector2.ZERO로 설정.
## 결과: 캐릭터가 움직이지 않고 명상에 의한 테트리스 배율도 남지 않는다.
func _stop_for_inactive_game() -> void:
	_set_meditating(false)
	if controller.state == MainGameController.GameState.GAME_OVER:
		_end_binding()
	velocity = Vector2.ZERO
	_pending_punch_stage = 0
	_pending_punch_hit_remaining = 0.0
	if not Input.is_action_pressed(&"character_self_respawn"):
		_reset_self_respawn_input()


func apply_binding(duration: float = 2.0) -> void:
	if is_bound or controller.state != MainGameController.GameState.PLAYING:
		return
	if _consume_chef_meat_guard("고기 섭취: 기믹 무효"):
		return
	_set_meditating(false)
	_exit_hang()
	_cancel_jump_intent()
	_cancel_wall_jump_control()
	_pending_rotation_launch_velocity = 0.0
	velocity = Vector2.ZERO
	is_bound = true
	binding_timer = maxf(duration, 0.0)
	binding_started.emit()
	stats_changed.emit()


func _update_binding(delta: float) -> void:
	velocity = Vector2.ZERO
	binding_timer = maxf(0.0, binding_timer - delta)
	if binding_timer <= 0.0:
		_end_binding()


func _end_binding() -> void:
	if not is_bound:
		binding_timer = 0.0
		return
	is_bound = false
	binding_timer = 0.0
	binding_ended.emit()
	stats_changed.emit()


func can_receive_binding() -> bool:
	if _active_piece_overlaps_rect(_character_collider_rect()):
		return false
	if is_hanging:
		return _hang_body == boundaries
	return is_on_floor() and _has_fixed_support_underfoot()


## 상황: PLAYING 중 자력 재스폰 키를 누르거나 놓을 때 매 physics frame 호출한다.
## 순서: 발동 후 release latch 처리 → 해제 시 진행 초기화 → hold 누적 → 1초면 생명 차감.
## 결과: 짧은 입력은 무해하고, 한 번 발동한 hold는 키를 놓기 전 다시 발동하지 않는다.
func _handle_self_respawn_input(delta: float) -> bool:
	var pressed: bool = Input.is_action_pressed(&"character_self_respawn")
	if _self_respawn_requires_release:
		if not pressed:
			_reset_self_respawn_input()
		return false
	if not pressed:
		if _self_respawn_hold_time > 0.0:
			_self_respawn_hold_time = 0.0
			stats_changed.emit()
		return false

	_self_respawn_hold_time = minf(
		SELF_RESPAWN_HOLD_SECONDS,
		_self_respawn_hold_time + delta
	)
	stats_changed.emit()
	if _self_respawn_hold_time < SELF_RESPAWN_HOLD_SECONDS:
		return false

	_self_respawn_hold_time = 0.0
	_lose_life_and_respawn("자력 재스폰: 목숨 -1")
	_self_respawn_requires_release = true
	return true


## 상황: 키 해제·비활성 게임·새 게임에서 자력 재스폰 입력 상태를 비운다.
## 결과: 다음 hold가 0초부터 시작되고 발동 후 release latch가 해제된다.
func _reset_self_respawn_input() -> void:
	_self_respawn_hold_time = 0.0
	_self_respawn_requires_release = false


## 상황: 명상 중이 아닌 physics frame에서 새 명상 진입 가능성을 판단할 때 호출한다.
## 순서: meditate hold, 접지, 비매달림 조건을 AND 평가한다.
## 결과: 모든 조건이 참일 때만 true이며 상태 자체는 변경하지 않는다.
func _can_start_meditating() -> bool:
	return (
		Input.is_action_pressed(&"character_meditate")
		and not Input.is_action_just_pressed(&"character_rotation_kick")
		and is_on_floor()
		and not is_hanging
		and _pending_special_id.is_empty()
		and _special_animation_remaining <= 0.0
	)


## 상황: 명상/매달림/일반 이동 중 하나가 끝난 모든 활성 physics frame에서 호출한다.
## 순서: `_update_visual_state(delta)` → 보드 경계/추락 위치 검증.
## 결과: gameplay 상태에 맞는 sprite가 적용되고 캐릭터가 보드 밖으로 나가지 않는다.
func _finish_physics_frame(delta: float) -> void:
	_resolve_pending_punch(delta)
	_sync_barrier_cells()
	_update_visual_state(delta)
	validate_position()
	controller.notify_binding_surface_contact(can_receive_binding())


## 상황: 이미 명상 중이거나 이번 frame에 명상 조건을 만족했을 때 호출한다.
## 순서: 입력/매달림/접지 재검사 → 실패 시 명상 종료 → x 정지/중력/이동
##       → 이동 후 접지 재검사 → 접지 상태 기록 → stats signal.
## 결과: 바닥을 따라 안정적으로 명상하고, 발판을 잃으면 즉시 종료한다.
func _handle_meditation(delta: float) -> void:
	if (
		not Input.is_action_pressed(&"character_meditate")
		or is_hanging
		or not is_on_floor()
	):
		_set_meditating(false)
		return

	velocity.x = 0.0
	velocity.y = minf(
		velocity.y + GRAVITY * delta,
		MAX_FALL_SPEED
	)
	move_and_slide()
	if not is_on_floor():
		_was_grounded_for_stamina = false
		_set_meditating(false)
		return
	_was_grounded_for_stamina = true
	stats_changed.emit()


## 상황: PLAYING이고 명상/매달림이 아닌 일반 이동 frame에 호출한다.
## 순서: 수평 입력/접지 snapshot → facing/coyote → 수평속도 → 중력 → action
##       → 가변점프 → grab이면 hang 시도 → move_and_slide → 착지 완충 → signal.
## 결과: 입력이 실제 CharacterBody2D 이동과 행동으로 반영된다.
func _handle_movement(delta: float) -> void:
	var horizontal_input: float = Input.get_axis(&"character_left", &"character_right") # -1~+1 이동축.
	var grounded: bool = is_on_floor() and not _respawn_airborne_pending # 순간이동 전 접지 제외.
	_respawn_airborne_pending = false
	_update_facing(horizontal_input)
	_update_ground_contact(grounded)
	_apply_horizontal_movement(horizontal_input, grounded, delta)
	_apply_gravity(grounded, delta)
	_apply_pending_rotation_launch(delta)
	_handle_action_input()
	_apply_variable_jump_cut()

	if Input.is_action_pressed(&"character_grab") and _hang_regrab_remaining <= 0.0:
		_try_start_hang()

	move_and_slide()
	_handle_stamina_landing()
	stats_changed.emit()


## 상황: 일반 이동에서 수평 입력을 읽은 직후 호출한다.
## 순서: 0에 가까운 입력은 무시 → 부호를 facing에 저장 → 왼쪽이면 sprite.flip_h.
## 결과: 다음 펀치/회전/매달림 방향과 화면 방향이 입력을 따라간다.
func _update_facing(horizontal_input: float) -> void:
	if not is_zero_approx(horizontal_input):
		facing = signi(int(horizontal_input))
		sprite.flip_h = facing < 0


## 상황: 일반 이동 시작 시 현재 접지 snapshot을 처리할 때 호출한다.
## 순서: grounded가 false면 아무것도 하지 않음 → true면 coyote timer 충전/벽점프 조향 취소.
## 결과: 발판을 떠난 뒤 0.12초 점프 여유가 생기고 지상에서는 벽점프 보정이 끝난다.
func _update_ground_contact(grounded: bool) -> void:
	if grounded:
		_coyote_remaining = COYOTE_TIME
		_cancel_wall_jump_control()


## 상황: 일반 이동에서 이번 frame의 목표 수평속도를 반영할 때 호출한다.
## 순서: target speed 계산 → 무입력/입력과 지상/공중 조합으로 가속도 선택
##       → 원래 벽으로 조향 중이면 전용 가속도로 교체 → move_toward.
## 결과: velocity.x가 즉시 점프하지 않고 delta에 비례해 목표속도로 접근한다.
func _apply_horizontal_movement(
	horizontal_input: float,
	grounded: bool,
	delta: float
) -> void:
	var acceleration: float # 아래 조건에서 선택될 이번 frame 가속/감속도.
	var target_horizontal_speed: float = horizontal_input * current_move_speed() # 캐릭터 이동 능력치 기반 목표 x속도.
	if is_zero_approx(horizontal_input):
		acceleration = GROUND_DECELERATION if grounded else AIR_DECELERATION
	else:
		acceleration = GROUND_ACCELERATION if grounded else AIR_ACCELERATION

	# 벽 점프 직후 원래 벽 방향을 직접 입력했을 때만 공중 조향력을 높인다.
	# 방향 입력이 없으면 자동으로 벽에 돌아가지 않으므로 궤적을 직접 제어할 수 있다.
	var steering_back_to_wall: bool = ( # 벽점프 후 사용자가 출발 벽 쪽을 직접 누르는 상태.
		not grounded
		and not is_zero_approx(horizontal_input)
		and _wall_jump_control_remaining > 0.0
		and signi(int(horizontal_input)) == _wall_jump_wall_facing
	)
	if steering_back_to_wall:
		acceleration = WALL_JUMP_STEER_ACCELERATION
	velocity.x = move_toward(velocity.x, target_horizontal_speed, acceleration * delta)


## 상황: 수평속도 계산 뒤 이번 frame의 수직 중력을 적용할 때 호출한다.
## 순서: grounded면 종료 → 상승/하강 배율 선택 → `GRAVITY*delta` 가산 → max fall clamp.
## 결과: velocity.y가 물리적으로 누적되며 극단적인 delta에도 3200px/s를 넘지 않는다.
func _apply_gravity(grounded: bool, delta: float) -> void:
	if grounded:
		return
	var gravity_multiplier: float = FALL_GRAVITY_MULTIPLIER if velocity.y > 0.0 else 1.0 # 하강/상승 배율.
	velocity.y = minf(
		velocity.y + GRAVITY * gravity_multiplier * delta,
		MAX_FALL_SPEED
	)


## 상황: 일반 이동 frame에서 단발 행동 입력을 읽을 때 호출한다.
## 순서: 회전/점프의 just_pressed 값과 위/아래 화살표 방향을 dispatcher에 전달.
## 결과: 실제 우선순위 판단은 dispatcher 한곳에서 실행되어 테스트도 같은 경로를 사용할 수 있다.
func _handle_action_input() -> void:
	var jump_pressed: bool = Input.is_action_just_pressed(&"character_jump")
	if _ignore_initial_jump_until_released:
		if Input.is_action_pressed(&"character_jump"):
			jump_pressed = false
		else:
			_ignore_initial_jump_until_released = false
	_dispatch_action_input(
		Input.is_action_just_pressed(&"character_rotation_kick"),
		jump_pressed,
		_rotation_direction_for_input()
	)


## 상황: 실입력 또는 테스트가 동시에 들어온 행동들의 우선순위를 결정할 때 호출한다.
## 순서: 회전 있으면 jump 취소/회전 후 return → 그 외에만 `_handle_jump_input()`.
## 결과: 한 frame에 블록 플립 또는 점프 중 하나만 시작된다.
func _dispatch_action_input(
	rotation_kick_pressed: bool,
	jump_pressed: bool,
	rotation_direction: int = 0
) -> void:
	if rotation_kick_pressed:
		_cancel_jump_intent()
		_attempt_rotation_kick(rotation_direction)
		return

	_handle_jump_input(jump_pressed)


## 상황: 블록 플립이 점프보다 우선되어 기존 점프 의도를 폐기해야 할 때 호출한다.
## 순서: jump buffer → hang grace → variable jump flag → wall-jump control 순서로 초기화.
## 결과: 같은 frame 또는 직전 frame의 점프 상태가 블록 플립과 중복 실행되지 않는다.
func _cancel_jump_intent() -> void:
	_jump_buffer_remaining = 0.0
	_hang_jump_grace_remaining = 0.0
	_variable_jump_active = false
	_cancel_wall_jump_control()


## 상황: S와 위/아래 화살표가 같은 frame에 입력됐을 때 블록 플립 방향을 계산한다.
## 순서: 한쪽 화살표만 눌렸으면 위는 현재 facing, 아래는 반대 facing을 선택한다.
## 결과: 화살표가 없거나 둘 다 눌리면 기존 facing 기반 동작을 유지한다.
func _rotation_direction_for_input() -> int:
	return _rotation_direction_for_arrows(
		Input.is_key_pressed(KEY_UP),
		Input.is_key_pressed(KEY_DOWN)
	)


func _rotation_direction_for_arrows(up_pressed: bool, down_pressed: bool) -> int:
	if up_pressed == down_pressed:
		return facing
	return facing if up_pressed else -facing


## 상황: 회전이 이번 frame을 소비하지 않았을 때 jump press를 처리한다.
## 순서: press+hang grace면 벽점프/return → press면 jump buffer 충전
##       → buffer와 coyote가 모두 남았으면 지상점프.
## 결과: grab 해제 직후 벽점프가 지상점프보다 우선하고 착지 전 입력도 보존된다.
func _handle_jump_input(jump_pressed: bool) -> void:
	if jump_pressed and _hang_jump_grace_remaining > 0.0:
		_perform_wall_jump()
		return
	if jump_pressed:
		_jump_buffer_remaining = JUMP_BUFFER_TIME
	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		_start_ground_jump()


## 상황: jump buffer와 coyote timer가 동시에 남아 지상점프가 확정될 때 호출한다.
## 순서: y속도에 JUMP_VELOCITY 대입 → buffer/coyote/hang grace를 0
##       → variable jump flag 활성화.
## 결과: 캐릭터가 상승하기 시작하며 키를 일찍 놓아 높이를 줄일 수 있다.
func _start_ground_jump() -> void:
	_play_sfx(SFX_JUMP)
	velocity.y = current_jump_velocity()
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	_hang_jump_grace_remaining = 0.0
	_variable_jump_active = true


## 상황: 일반 이동에서 점프 키 release가 상승 높이에 영향을 줄 수 있는지 처리한다.
## 순서: release+variable flag+상승 중이면 y속도×0.45/flag 해제
##       → 아니고 이미 정점/하강이면 flag만 해제.
## 결과: 짧게 누른 점프는 낮고, 계속 누른 점프는 최대 높이에 도달한다.
func _apply_variable_jump_cut() -> void:
	if (
		Input.is_action_just_released(&"character_jump")
		and _variable_jump_active
		and velocity.y < 0.0
	):
		velocity.y *= JUMP_RELEASE_MULTIPLIER
		_variable_jump_active = false
	elif velocity.y >= 0.0:
		_variable_jump_active = false


## 상황: 일반 이동의 `move_and_slide()`가 끝난 뒤 실제 착지를 판정할 때 호출한다.
## 순서: 현재 is_on_floor 재검사 → 비접지→접지 전환이면 MAX_STAMINA 설정
##       → 현재 접지 상태를 다음 frame 비교용으로 저장.
## 결과: 공중·연속 접지 중에는 충전하지 않고 새로운 발판 착지 순간에만 한 번 완충한다.
func _handle_stamina_landing() -> void:
	var grounded_now: bool = is_on_floor()
	var just_landed: bool = grounded_now and not _was_grounded_for_stamina
	if grounded_now:
		_coyote_remaining = COYOTE_TIME
	if just_landed and stamina < MAX_STAMINA:
		stamina = MAX_STAMINA
	_was_grounded_for_stamina = grounded_now


## 상황: is_hanging=true인 physics frame의 전용 상태 처리로 호출한다.
## 순서: 종료조건 검사/조기 반환 → 붙은 body 이동 추적 → 상하 이동/접촉 재검사
##       → 성공적으로 계속 매달렸을 때 stamina/점프 마무리.
## 결과: 일반 중력/이동은 실행되지 않고 벽과 함께 움직이는 hang 상태가 유지 또는 종료된다.
func _handle_hanging(delta: float) -> void:
	# 벽과 바닥에 동시에 닿아도 매달림 자체는 stamina 착지 발판으로 세지 않는다.
	_was_grounded_for_stamina = false
	if _handle_hang_exit_conditions():
		return
	if _hang_corner_climb_active:
		_advance_hang_corner_climb(delta)
		return
	_follow_hang_body()
	if not is_hanging:
		return
	_snap_to_hang_face()
	global_position.y = clampf(
		global_position.y,
		_hang_top_global_y,
		_hang_bottom_global_y
	)
	if not _hang_surface_still_exists():
		_exit_hang()
		velocity = Vector2.ZERO
		return
	if _has_fixed_support_underfoot() and _hang_climb_direction() >= 0.0:
		_exit_hang()
		return
	if not _move_while_hanging(delta):
		return
	_finish_hanging_frame(delta)


## 상황: 매달림 frame 시작 시 더 유지할 수 있는지 판단할 때 호출한다.
## 순서: stamina<=0이면 grace 없이 해제/true → grab release면 해제/grace 충전
##       → 같은 frame jump press면 즉시 벽점프 → 종료했으면 true, 아니면 false.
## 결과: true면 호출자가 나머지 hang 처리를 건너뛴다.
func _handle_hang_exit_conditions() -> bool:
	if stamina <= 0.0:
		_hang_jump_grace_remaining = 0.0
		_exit_hang()
		return true
	if not Input.is_action_pressed(&"character_grab"):
		_exit_hang()
		_hang_jump_grace_remaining = HANG_JUMP_GRACE_TIME
		if Input.is_action_just_pressed(&"character_jump"):
			_perform_wall_jump()
		return true
	return false


## 상황: 매달린 collider가 활성 피스처럼 움직일 수 있어 그 이동을 따라가야 할 때 호출한다.
## 순서: body 유효성 검사 → 현재-이전 global 위치 delta 계산 → 캐릭터에 더함
##       → 현재 위치를 다음 frame 기준값으로 저장.
## 결과: 상대 위치를 유지한 채 움직이는 블록과 함께 캐릭터가 이동한다.
func _follow_hang_body() -> void:
	if not is_instance_valid(_hang_body):
		_exit_hang()
		velocity = Vector2.ZERO
		return
	if is_instance_valid(_hang_body):
		var body_delta: Vector2 = _hang_body.global_position - _hang_last_global_position # body의 frame 이동량.
		# ponytail: 2칸 초과 상향 이동은 다음 피스 스폰으로 간주한다; 큰 SRS kick이 필요하면 교체 signal로 바꾼다.
		if body_delta.y < -CELL_SIZE * 2.0:
			_exit_hang()
			return
		if _hang_follow_hits_fixed_geometry(body_delta):
			_exit_hang()
			velocity = Vector2.ZERO
			return
		var position_before_follow: Vector2 = global_position
		global_position += body_delta
		_hang_face_global_x += body_delta.x
		_hang_top_global_y += body_delta.y
		_hang_bottom_global_y += body_delta.y
		if not _limit_hang_bounds_to_visible_board():
			global_position = position_before_follow
			_exit_hang()
			velocity = Vector2.ZERO
			return
		var limited_follow_y: float = clampf(
			global_position.y,
			_hang_top_global_y,
			_hang_bottom_global_y
		)
		if not is_equal_approx(limited_follow_y, global_position.y):
			global_position = position_before_follow
			_exit_hang()
			velocity = Vector2.ZERO
			return
		_hang_last_global_position = _hang_body.global_position


func _hang_follow_hits_fixed_geometry(body_delta: Vector2) -> bool:
	if body_delta.is_zero_approx():
		return false
	var current_rect: Rect2 = _character_collider_rect()
	var target_rect := Rect2(current_rect.position + body_delta, current_rect.size)
	var board_size := Vector2(
		MainBoardModel.WIDTH * CELL_SIZE,
		MainBoardModel.VISIBLE_HEIGHT * CELL_SIZE
	)
	if (
		target_rect.position.x < 0.0
		or target_rect.end.x > board_size.x
		or target_rect.end.y > board_size.y
	):
		return true
	var swept_rect: Rect2 = current_rect.merge(target_rect)
	for y: int in range(MainBoardModel.HEIGHT):
		for x: int in range(MainBoardModel.WIDTH):
			if controller.board.cells[y][x] == MainBoardModel.EMPTY:
				continue
			if _rects_overlap_with_area(swept_rect, _board_cell_rect(Vector2i(x, y))):
				return true
	return false


func _hang_surface_still_exists() -> bool:
	if not is_instance_valid(_hang_body):
		return false
	if _hang_body.name == &"LockedBlocks":
		return _locked_hang_surface_still_exists()
	var hang_ray: RayCast2D = left_ray if _hang_jump_facing < 0 else right_ray
	hang_ray.force_raycast_update()
	return hang_ray.is_colliding() and hang_ray.get_collider() == _hang_body


func _locked_hang_surface_still_exists() -> bool:
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return false
	var local_face_x: float = parent.to_local(
		Vector2(_hang_face_global_x, global_position.y)
	).x
	var local_hand_y: float = parent.to_local(global_position).y - HANG_HAND_OFFSET_Y
	for y: int in range(MainBoardModel.HEIGHT):
		for x: int in range(MainBoardModel.WIDTH):
			if controller.board.cells[y][x] == MainBoardModel.EMPTY:
				continue
			var cell_rect: Rect2 = _board_cell_rect(Vector2i(x, y))
			var cell_face_x: float = (
				cell_rect.position.x if _hang_jump_facing > 0 else cell_rect.end.x
			)
			if (
				is_equal_approx(cell_face_x, local_face_x)
				and local_hand_y >= cell_rect.position.y
				and local_hand_y <= cell_rect.end.y
			):
				return true
	return false


## 상황: 붙은 body를 따라간 뒤 사용자의 위/아래 매달림 이동을 적용할 때 호출한다.
## 순서: 방향 조회 → velocity 설정 → 무입력이면 true → move_and_slide
##       → 외부 옆면 범위 clamp → 양 RayCast 강제 갱신 → 붙은 쪽 충돌 확인.
## 결과: 벽을 따라 이동하되 끝을 벗어난 순간 일반 공중 상태로 전환된다.
func _move_while_hanging(delta: float = -1.0) -> bool:
	var climb_direction: float = _hang_climb_direction() # 위 -1, 정지 0, 아래 +1.
	_hang_animation_direction = climb_direction
	velocity = Vector2.ZERO
	if is_zero_approx(climb_direction):
		return true

	var movement_delta: float = (
		get_physics_process_delta_time() if delta < 0.0 else maxf(delta, 0.0)
	)
	var previous_global_position: Vector2 = global_position
	var requested_global_y: float = clampf(
		global_position.y + climb_direction * HANG_CLIMB_SPEED * movement_delta,
		_hang_top_global_y,
		_hang_bottom_global_y
	)
	var requested_global_position := Vector2(global_position.x, requested_global_y)
	var requested_local_position: Vector2 = get_parent().to_local(requested_global_position)
	if not _character_position_overlaps_solid(requested_local_position):
		global_position.y = requested_global_y
	else:
		global_position = previous_global_position
	_snap_to_hang_face()
	if (
		climb_direction < 0.0
		and global_position.y <= _hang_top_global_y + 0.75
		and _try_start_hang_corner_climb()
	):
		return true
	if _hang_surface_still_exists():
		return true
	_exit_hang()
	return false


## 상황: 매달린 상태에서 수직 입력을 속도 부호로 바꿀 때 호출한다.
## 순서: 0에서 시작 → 물리 위키면 -1 → meditate(아래) action이면 +1을 더함.
## 결과: 위/아래 동시 입력은 0, 위=-1, 아래=+1을 반환한다.
func _try_start_hang_corner_climb() -> bool:
	if _hang_body == boundaries or not is_instance_valid(_hang_body):
		return false
	if _hang_body.name != &"LockedBlocks":
		return false
	var surface_top_global_y: float = _hang_top_global_y - HANG_HAND_OFFSET_Y
	var target_global_position := Vector2(
		_hang_face_global_x
		+ float(_hang_jump_facing) * CHARACTER_COLLIDER_WIDTH * 0.5,
		surface_top_global_y
		- CHARACTER_COLLIDER_OFFSET_Y
		- CHARACTER_COLLIDER_HEIGHT * 0.5
	)
	var target_local_position: Vector2 = get_parent().to_local(target_global_position)
	if _character_position_overlaps_solid(target_local_position):
		return false
	if (
		target_local_position.x < BOARD_MIN_X
		or target_local_position.x > BOARD_MAX_X
		or target_local_position.y < BOARD_MIN_Y
		or target_local_position.y > BOARD_MAX_Y
	):
		return false
	_hang_corner_climb_active = true
	_hang_corner_climb_start_global = global_position
	_hang_corner_climb_target_global = target_global_position
	_hang_corner_climb_progress = 0.0
	var path_length: float = (
		absf(target_global_position.y - global_position.y)
		+ absf(target_global_position.x - global_position.x)
	)
	_hang_corner_climb_duration = maxf(
		path_length / maxf(HANG_CORNER_CLIMB_SPEED, 1.0),
		0.18
	)
	return true


func _advance_hang_corner_climb(delta: float) -> void:
	_hang_animation_direction = -1.0 if Input.is_key_pressed(KEY_UP) else 0.0
	if not Input.is_key_pressed(KEY_UP):
		velocity = Vector2.ZERO
		_finish_hanging_frame(delta)
		return
	_hang_corner_climb_progress = minf(
		1.0,
		_hang_corner_climb_progress
		+ maxf(delta, 0.0) / maxf(_hang_corner_climb_duration, 0.001)
	)
	var progress: float = _hang_corner_climb_progress
	var corner_position: Vector2
	if progress < 0.72:
		var vertical_progress: float = progress / 0.72
		corner_position = Vector2(
			_hang_corner_climb_start_global.x,
			lerpf(
				_hang_corner_climb_start_global.y,
				_hang_corner_climb_target_global.y,
				vertical_progress
			)
		)
	else:
		var horizontal_progress: float = (progress - 0.72) / 0.28
		corner_position = Vector2(
			lerpf(
				_hang_corner_climb_start_global.x,
				_hang_corner_climb_target_global.x,
				horizontal_progress
			),
			_hang_corner_climb_target_global.y
		)
	global_position = corner_position
	velocity = Vector2.ZERO
	stamina = maxf(
		0.0,
		stamina
		- HANG_STAMINA_DRAIN
		* CHARACTER_DATA.stamina_drain_multiplier(character_id)
		* maxf(delta, 0.0)
	)
	if _hang_corner_climb_progress >= 1.0:
		var completed_local_position: Vector2 = get_parent().to_local(
			_hang_corner_climb_target_global
		)
		_exit_hang()
		position = completed_local_position
		velocity = Vector2.ZERO
	stats_changed.emit()


func _character_position_overlaps_solid(candidate_position: Vector2) -> bool:
	var collider_size := Vector2(
		CHARACTER_COLLIDER_WIDTH,
		CHARACTER_COLLIDER_HEIGHT
	)
	var collider_center: Vector2 = candidate_position + Vector2(
		0.0,
		CHARACTER_COLLIDER_OFFSET_Y
	)
	var candidate_rect := Rect2(collider_center - collider_size * 0.5, collider_size)
	for y: int in range(MainBoardModel.HEIGHT):
		for x: int in range(MainBoardModel.WIDTH):
			if controller.board.cells[y][x] == MainBoardModel.EMPTY:
				continue
			if _rects_overlap_with_area(candidate_rect, _board_cell_rect(Vector2i(x, y))):
				return true
	for local_cell: Vector2i in controller.active_local_cells():
		if _rects_overlap_with_area(
			candidate_rect,
			_board_cell_rect(controller.active_origin + local_cell)
		):
			return true
	return false


func _hang_climb_direction() -> float:
	var climb_direction: float = 0.0 # 상하 입력을 합산할 방향값.
	if Input.is_key_pressed(KEY_UP):
		climb_direction -= 1.0
	# 아래 키는 지상에서는 명상, 매달린 동안에는 하강 입력으로 문맥이 바뀐다.
	if Input.is_action_pressed(&"character_meditate"):
		climb_direction += 1.0
	return climb_direction


## 상황: 이번 frame에도 벽 접촉이 유지된 뒤 hang 상태를 마무리할 때 호출한다.
## 순서: velocity=0 → 초당 drain×delta 차감/0 clamp → jump just_pressed면 벽점프
##       → stats_changed emit.
## 결과: 정지 매달림도 stamina를 소비하며 HUD가 매 frame 최신 값을 표시한다.
func _finish_hanging_frame(delta: float) -> void:
	velocity = Vector2.ZERO
	stamina = maxf(
		0.0,
		stamina
		- HANG_STAMINA_DRAIN
		* CHARACTER_DATA.stamina_drain_multiplier(character_id, passive_levels)
		* delta
	)
	if Input.is_action_just_pressed(&"character_jump"):
		_perform_wall_jump()
	stats_changed.emit()


## 상황: 매달린 중 jump 또는 grab 해제 후 grace 안의 jump가 들어오면 호출한다.
## 순서: 벽 방향 저장 → hang 해제 → regrab/grace/control/coyote/buffer 설정
##       → facing을 벽 반대로 변경 → 반대 x속도/위 y속도 → feedback.
## 결과: 즉시 벽에서 떨어져 상승하며 잠시 같은 벽 재매달림이 금지된다.
func _perform_wall_jump() -> void:
	_play_sfx(SFX_JUMP)
	var wall_facing: int = _hang_jump_facing # 해제 후에도 사용할 출발 벽 방향 snapshot.
	_exit_hang()
	_hang_regrab_remaining = HANG_REGRAB_COOLDOWN
	_hang_jump_grace_remaining = 0.0
	_wall_jump_wall_facing = wall_facing
	_wall_jump_control_remaining = WALL_JUMP_STEER_TIME
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_variable_jump_active = true
	facing = -wall_facing
	sprite.flip_h = facing < 0
	velocity = Vector2(
		-float(wall_facing) * WALL_JUMP_HORIZONTAL_SPEED,
		current_jump_velocity() * WALL_JUMP_VERTICAL_MULTIPLIER
	)


## 상황: 명상이 아닌 physics frame에서 새 펀치 입력을 처리한다.
## 결과: 입력 시간과 관계없이 전방 블록을 한 칸 미는 기본 공격을 시작한다.
func _handle_punch() -> void:
	if Input.is_action_just_pressed(&"character_punch"):
		_perform_tap_punch()
## 상황: X를 짧게 눌렀다 놓았을 때 일반 펀치를 실행한다.
## 결과: 공격 animation을 표시하고 0.1초 주먹 판정 중 맞은 활성 블록을 1칸 민다.
func _perform_tap_punch() -> void:
	if (
		_attack_cooldown_remaining > 0.0
		or _barrier_remaining > 0.0
		or _special_animation_remaining > 0.0
	):
		return
	_start_attack_animation()
	_attack_cooldown_remaining = current_attack_cooldown()
	_play_sfx(SFX_PUNCH)
	_begin_punch_hit_confirmation(1)
	stats_changed.emit()


## 상황: 펀치가 시작되어 ATTACK sprite 상태를 처음부터 재생해야 할 때 호출한다.
## 순서: 남은 animation 시간을 전체 길이로 설정 → state를 ATTACK → frame 시간을 0으로 초기화.
## 결과: 기존 idle/jump/hang frame과 무관하게 공격 첫 frame부터 표시된다.
func _start_attack_animation() -> void:
	_attack_animation_remaining = ATTACK_ANIMATION_DURATION
	_animation_state = ANIMATION_DATA.ATTACK
	_animation_time = 0.0


## 상황: X를 놓은 순간 계산된 1~3단계 펀치를 짧은 hit 판정 창에 등록할 때 호출한다.
## 순서: 목표 이동 칸 수와 남은 판정 시간을 두 private 멤버에 저장한다.
## 결과: `_resolve_pending_punch()`가 이후 physics frame에서 실제 전방 겹침을 확인한다.
func _begin_punch_hit_confirmation(target_stage: int) -> void:
	_pending_punch_stage = target_stage
	_pending_punch_hit_remaining = PUNCH_HIT_CONFIRM_SECONDS


## 상황: 펀치 모션의 0.1초 판정 창 동안 매 physics frame 호출된다.
## 순서: 예약 없음 조기 반환 → hitbox 검사 → 성공 시 피스 이동/비용/SFX 처리
##       → 빗나가면 delta만큼 timeout 감소 → 만료 시 예약 해제와 feedback.
## 결과: 키를 놓은 시점과 sprite 주먹이 닿는 시점 사이에서도 한 번만 원자적으로 판정한다.
func _resolve_pending_punch(delta: float) -> void:
	if _pending_punch_stage == 0:
		return

	var target_stage: int = _pending_punch_stage # 호환용 값. 기본 공격은 항상 1칸이다.
	if controller.boss_hitbox_overlaps(_punch_hitbox_rect()):
		_pending_punch_stage = 0
		_pending_punch_hit_remaining = 0.0
		controller.notify_boss_attacked()
		take_thorn_damage("보스 가시 피해! 목숨 -1")
		return
	var target_cell: Variant = _basic_attack_target_cell()
	var hits_active_piece: bool = target_cell != null
	var moved: int = 0
	if hits_active_piece:
		moved = 1 if controller.push_active_piece(
			facing,
			1,
			_rotation_forbidden_cells()
		) else 0
	if hits_active_piece and controller.active_piece_has_visible_thorns():
		take_thorn_damage()
	if moved > 0:
		_pending_punch_stage = 0
		_pending_punch_hit_remaining = 0.0
		stats_changed.emit()
		return

	_pending_punch_hit_remaining = maxf(0.0, _pending_punch_hit_remaining - delta)
	if _pending_punch_hit_remaining <= 0.0:
		_pending_punch_stage = 0


## 상황: 명상 진입/종료, pause, 피해 또는 reset에서 명상 상태를 일관되게 바꿀 때 호출한다.
## 순서: 요청+PLAYING+접지+비매달림으로 next 계산 → 상태가 같으면 Controller만 동기화
##       → 변경 시 둘 다 저장 → 진입이면 펀치/점프/조향 취소·x정지, 종료면 feedback → signal.
## 결과: Character와 GameController의 명상 flag가 항상 일치한다.
func _set_meditating(active: bool) -> void:
	var next_state: bool = ( # 요청값에 실제 진입 전제조건을 적용한 최종 명상 상태.
		active
		and controller.state == MainGameController.GameState.PLAYING
		and is_on_floor()
		and not is_hanging
	)
	if is_meditating == next_state:
		controller.set_meditation_active(next_state)
		return

	is_meditating = next_state
	controller.set_meditation_active(next_state)
	if is_meditating:
		_play_sfx(SFX_MEDITATION_START)
		_start_meditation_loop()
		_pending_rotation_launch_velocity = 0.0
		_jump_buffer_remaining = 0.0
		_hang_jump_grace_remaining = 0.0
		_variable_jump_active = false
		_cancel_wall_jump_control()
		velocity.x = 0.0
	else:
		_stop_meditation_loop()
		if controller.state == MainGameController.GameState.PLAYING:
			_play_sfx(SFX_MEDITATION_END)
	stats_changed.emit()


## 상황: S 블록 플립이 action 우선순위에서 선택됐을 때 호출한다.
## 순서: cooldown → spin 시작 → 활성 피스 88px 근접 검사
##       → 가까우면 실제 물리 몸체 점유 셀을 계산해 Controller.try_rotate(입력 방향, 금지 셀)
##       → 성공/공간 부족/대상 없음별 y속도/cooldown/feedback → signal.
## 결과: 스태미나를 쓰지 않으며 대상이 없어도 한 바퀴 동작과 짧은 cooldown이 적용된다.
func _attempt_rotation_kick(rotation_direction: int = 0) -> void:
	if is_meditating or _special_animation_remaining > 0.0 or not _pending_special_id.is_empty():
		return
	if rotation_cooldown_remaining > 0.0:
		return

	var resolved_direction: int = facing if rotation_direction == 0 else signi(rotation_direction)
	_start_rotation_spin(resolved_direction)
	if controller.boss_hitbox_overlaps(_forward_attack_rect(ROTATION_KICK_BOSS_REACH)):
		controller.notify_boss_attacked()
		take_thorn_damage("보스 가시 피해! 목숨 -1")
		rotation_cooldown_remaining = current_rotation_cooldown()
		stats_changed.emit()
		return
	if not _is_near_active_piece(0.0, MainLayout.scaled(88.0)):
		_pending_rotation_launch_velocity = 0.0
		velocity.y = MainLayout.scaled(-120.0)
		rotation_cooldown_remaining = current_rotation_cooldown()
		stats_changed.emit()
		return

	var thorn_contact: bool = controller.active_piece_has_visible_thorns()
	if controller.try_rotate(resolved_direction, _rotation_forbidden_cells(), true):
		_play_sfx(SFX_FLIP)
		# game_changed로 새 active shape를 만든 같은 physics frame에는 아직 PhysicsServer에
		# 반영되지 않을 수 있다. 이번 frame 수직 이동을 멈추고 다음 frame에 발사한다.
		velocity.y = 0.0
		_pending_rotation_launch_velocity = MainLayout.scaled(-260.0)
		rotation_cooldown_remaining = current_rotation_cooldown()
	else:
		_pending_rotation_launch_velocity = 0.0
		velocity.y = MainLayout.scaled(-140.0)
		rotation_cooldown_remaining = current_rotation_cooldown()
	if thorn_contact:
		take_thorn_damage("가시 회전킥 피해! 목숨 -1")
	stats_changed.emit()


## 상황: 성공한 회전으로 재구성된 active collider가 물리 서버에 반영된 다음 이동 frame에 호출한다.
## 순서: 이번 frame 예상 이동을 포함한 swept Rect 계산 → 새 active cell과 교차하면 상승 취소.
## 결과: collider 동기화 지연 중에도 블록을 관통하지 않고, 빈 경로면 저장한 속도를 한 번 적용한다.
func _apply_pending_rotation_launch(delta: float) -> void:
	if is_zero_approx(_pending_rotation_launch_velocity):
		return
	var launch_velocity: float = _pending_rotation_launch_velocity
	_pending_rotation_launch_velocity = 0.0
	var current_rect: Rect2 = _character_collider_rect()
	var moved_rect: Rect2 = Rect2(
		current_rect.position + Vector2(0.0, launch_velocity * maxf(delta, 0.0)),
		current_rect.size
	)
	var swept_rect: Rect2 = current_rect.merge(moved_rect)
	if _active_piece_overlaps_rect(swept_rect):
		velocity.y = 0.0
		return
	velocity.y = launch_velocity


## 상황: 블록 플립의 SRS 후보가 현재 캐릭터 물리 몸체를 덮지 않게 금지 셀이 필요할 때 호출한다.
## 순서: 42×90px 충돌체와 +3px 오프셋으로 Rect 계산 → 모든 보드 셀과 양의 면적 교차 검사.
## 결과: 경계 접촉은 제외하고 실제 면적이 겹치는 보드 좌표만 반환한다.
func _rotation_forbidden_cells() -> Array[Vector2i]:
	var forbidden_cells: Array[Vector2i] = []
	var collider_rect: Rect2 = _character_collider_rect()
	for y: int in range(MainBoardModel.HEIGHT):
		for x: int in range(MainBoardModel.WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if _rects_overlap_with_area(collider_rect, _board_cell_rect(cell)):
				forbidden_cells.append(cell)
	return forbidden_cells


## 상황: 회전 안전 검사에서 실제 CharacterBody2D의 고정 사각 충돌 영역이 필요할 때 호출한다.
## 결과: sprite 회전과 무관한 42×90px, 중심 Y+3px의 BoardPhysics 로컬 Rect를 반환한다.
func _character_collider_rect() -> Rect2:
	var collider_size: Vector2 = Vector2(
		CHARACTER_COLLIDER_WIDTH,
		CHARACTER_COLLIDER_HEIGHT
	)
	var collider_center: Vector2 = position + Vector2(
		0.0,
		CHARACTER_COLLIDER_OFFSET_Y
	)
	return Rect2(collider_center - collider_size * 0.5, collider_size)


## 상황: 지연된 블록 플립 발사 경로가 새 활성 피스와 겹치는지 확인할 때 호출한다.
## 결과: 활성 네 셀 중 하나라도 대상 Rect와 양의 면적으로 교차하면 true다.
func _active_piece_overlaps_rect(target_rect: Rect2) -> bool:
	for local_cell: Vector2i in controller.active_local_cells():
		if _rects_overlap_with_area(
			target_rect,
			_board_cell_rect(controller.active_origin + local_cell)
		):
			return true
	return false


## 상황: 성공/실패와 무관하게 실제 블록 플립 동작을 시작할 때 호출한다.
## 순서: 전체/경과 timer 초기화 → 선택된 회전 방향 snapshot 저장 → 각도 정자세.
## 결과: 이후 방향 입력이 바뀌어도 0.42초 동안 시작 방향으로 한 바퀴를 완주한다.
func _start_rotation_spin(rotation_direction: int = 0) -> void:
	_spin_remaining = ROTATION_SPIN_DURATION
	_spin_elapsed = 0.0
	_spin_direction = facing if rotation_direction == 0 else signi(rotation_direction)
	_post_spin_animation_seeded = false
	sprite.rotation = 0.0


## 상황: 일반 이동 중 C를 누르고 regrab cooldown이 0일 때 호출한다.
## 순서: cooldown 검사 → 고정 지지면이면 종료 → facing 쪽 Ray 우선, 반대쪽 fallback → collider 조회
##       → Node2D+stamina 검사 → hang/body/위치/벽방향 저장 → 조향 취소/정지/feedback.
## 결과: 유효한 벽을 찾을 때만 is_hanging=true가 되어 다음 frame부터 hang branch로 간다.
func _try_start_hang() -> void:
	if _hang_regrab_remaining > 0.0:
		return
	if _has_fixed_support_underfoot():
		return

	# A grab may only begin on the side the character is visibly facing. The
	# previous opposite-ray fallback let a wall touching the character's back
	# silently reverse `facing` and start a hang.
	var ray: RayCast2D = left_ray if facing < 0 else right_ray
	ray.force_raycast_update()
	if not ray.is_colliding():
		return

	var collider: Object = ray.get_collider() # 벽 또는 활성 피스일 수 있는 런타임 객체.
	if collider is Node2D and stamina > 0.0:
		var returned_from_wall_jump: bool = _wall_jump_control_remaining > 0.0 # 직전 벽으로 복귀했는지.
		_hang_body = collider as Node2D
		_hang_jump_facing = facing
		if not _set_hang_vertical_bounds(ray):
			_hang_body = null
			return
		var visible_center_range: Vector2 = _visible_board_character_center_range()
		if (
			global_position.y < visible_center_range.x
			or global_position.y > visible_center_range.y
		):
			_hang_body = null
			_clear_hang_vertical_bounds()
			return
		_snap_to_hang_face()
		is_hanging = true
		_hang_animation_direction = 0.0
		_hang_last_global_position = _hang_body.global_position
		_hang_jump_grace_remaining = 0.0
		_pending_rotation_launch_velocity = 0.0
		_cancel_wall_jump_control()
		velocity = Vector2.ZERO
		_play_sfx(SFX_WALL_CLIMB)


## 상황: grab 해제, stamina 소진, 벽 끝, 벽점프 또는 피해로 hang을 끝낼 때 호출한다.
## 순서: is_hanging=false → `_hang_body=null` → 외부 옆면 범위 초기화.
## 결과: 다음 physics frame은 일반 이동 branch를 실행하고 body를 더 이상 추적하지 않는다.
func _exit_hang() -> void:
	is_hanging = false
	_hang_animation_direction = 0.0
	_hang_corner_climb_active = false
	_hang_corner_climb_start_global = Vector2.ZERO
	_hang_corner_climb_target_global = Vector2.ZERO
	_hang_corner_climb_progress = 0.0
	_hang_corner_climb_duration = 0.0
	_hang_body = null
	_clear_hang_vertical_bounds()


## 상황: C로 잡은 충돌 지점에서 세로로 이어진 외부 옆면 범위를 저장할 때 호출한다.
## 순서: RayCast 접촉점의 노출된 셀 외곽면을 찾고, 같은 면에서 위·아래로 맞닿은 셀만 확장한다.
## 결과: 매달림 이동은 처음 잡은 블록 옆면의 실제 길이를 넘지 않으며, 면을 못 찾으면 false다.
func _set_hang_vertical_bounds(ray: RayCast2D) -> bool:
	var collision_rects: Array[Rect2] = []
	for child: Node in _hang_body.get_children():
		if not child is CollisionShape2D:
			continue
		var collision: CollisionShape2D = child as CollisionShape2D
		if collision.disabled or collision.shape == null:
			continue
		collision_rects.append(collision.global_transform * collision.shape.get_rect())

	if collision_rects.is_empty():
		_clear_hang_vertical_bounds()
		return false

	var contact_point: Vector2 = ray.get_collision_point()
	var hit_rect: Rect2 = Rect2()
	var found_hit_face: bool = false
	for rect: Rect2 in collision_rects:
		var face_x: float = rect.position.x if _hang_jump_facing > 0 else rect.end.x
		if not is_equal_approx(face_x, contact_point.x):
			continue
		if contact_point.y < rect.position.y or contact_point.y > rect.end.y:
			continue
		if _hang_body == boundaries or _is_hang_face_exposed(rect, collision_rects):
			hit_rect = rect
			found_hit_face = true
			break

	if not found_hit_face:
		_clear_hang_vertical_bounds()
		return false
	_hang_face_global_x = (
		hit_rect.position.x if _hang_jump_facing > 0 else hit_rect.end.x
	)
	if _hang_body == boundaries:
		_hang_top_global_y = hit_rect.position.y + HANG_HAND_OFFSET_Y
		_hang_bottom_global_y = hit_rect.end.y + HANG_HAND_OFFSET_Y
		return _limit_hang_bounds_to_visible_board()

	var hang_face_x: float = (
		hit_rect.position.x if _hang_jump_facing > 0 else hit_rect.end.x
	)
	var top_y: float = hit_rect.position.y
	var bottom_y: float = hit_rect.end.y
	var expanded: bool = true
	while expanded:
		expanded = false
		for rect: Rect2 in collision_rects:
			var face_x: float = rect.position.x if _hang_jump_facing > 0 else rect.end.x
			if not is_equal_approx(face_x, hang_face_x):
				continue
			if not _is_hang_face_exposed(rect, collision_rects):
				continue
			if is_equal_approx(rect.end.y, top_y):
				top_y = rect.position.y
				expanded = true
			if is_equal_approx(rect.position.y, bottom_y):
				bottom_y = rect.end.y
				expanded = true

	_hang_top_global_y = top_y + HANG_HAND_OFFSET_Y
	_hang_bottom_global_y = bottom_y + HANG_HAND_OFFSET_Y
	return _limit_hang_bounds_to_visible_board()


func _limit_hang_bounds_to_visible_board() -> bool:
	var center_range: Vector2 = _visible_board_character_center_range()
	_hang_top_global_y = maxf(_hang_top_global_y, center_range.x)
	_hang_bottom_global_y = minf(_hang_bottom_global_y, center_range.y)
	if _hang_top_global_y <= _hang_bottom_global_y:
		return true
	_clear_hang_vertical_bounds()
	return false


func _visible_board_character_center_range() -> Vector2:
	var board_top: float = (
		get_parent().global_position.y + MainLayout.BOARD_VISUAL_OFFSET.y
	)
	var board_bottom: float = board_top + MainLayout.BOARD_SIZE.y
	return Vector2(
		board_top + CHARACTER_COLLIDER_HEIGHT * 0.5 - CHARACTER_COLLIDER_OFFSET_Y,
		board_bottom - CHARACTER_COLLIDER_HEIGHT * 0.5 - CHARACTER_COLLIDER_OFFSET_Y
	)


func _clear_hang_vertical_bounds() -> void:
	_hang_top_global_y = 0.0
	_hang_bottom_global_y = 0.0
	_hang_face_global_x = 0.0


## 감지선의 여유 거리와 관계없이 공통 42×90 콜라이더 옆면을 실제 벽면에 맞춘다.
func _snap_to_hang_face() -> void:
	if is_zero_approx(_hang_face_global_x):
		return
	global_position.x = (
		_hang_face_global_x
		- float(_hang_jump_facing) * (
			CHARACTER_COLLIDER_WIDTH * 0.5 + HANG_WALL_GAP
		)
	)


## 상황: 후보 셀의 매달리는 쪽 면이 다른 셀로 막혔는지 확인할 때 호출한다.
## 결과: 캐릭터 쪽에 맞닿은 셀이 없을 때만 true다.
func _is_hang_face_exposed(rect: Rect2, collision_rects: Array[Rect2]) -> bool:
	for other: Rect2 in collision_rects:
		if other == rect:
			continue
		var touches_hang_side: bool = (
			is_equal_approx(other.end.x, rect.position.x)
			if _hang_jump_facing > 0
			else is_equal_approx(other.position.x, rect.end.x)
		)
		if not touches_hang_side:
			continue
		if minf(other.end.y, rect.end.y) > maxf(other.position.y, rect.position.y):
			return false
	return true


## 상황: 접지하거나 다른 배타 행동이 시작되어 벽점프 특수 조향을 끝낼 때 호출한다.
## 순서: `_wall_jump_control_remaining=0` 한 단계다.
## 결과: 이후 수평 이동은 일반 지상/공중 acceleration만 사용한다.
func _cancel_wall_jump_control() -> void:
	_wall_jump_control_remaining = 0.0


## 상황: GameController가 자연 중력으로 활성 피스를 정확히 한 칸 내린 직후 호출한다.
## 순서: 실제 한 칸 하강 검증 → 공통 CrushSensor와 활성 셀 교집합
##       → 고정 지지면이 발밑이면 압착 피해, 아니면 1.2배 낙하 상태 시작.
## 결과: 좌우 이동/회전/고정 블록 접촉은 피해를 만들지 않고 자연 낙하 압착만 처리된다.
func handle_active_piece_descended(
	previous_origin: Vector2i,
	current_origin: Vector2i
) -> void:
	if controller.state != MainGameController.GameState.PLAYING:
		return
	if current_origin != previous_origin + Vector2i.DOWN:
		return
	var sensor_rect: Rect2 = _crush_sensor_rect()
	if sensor_rect.size.is_zero_approx():
		return
	if _active_piece_overlaps_crush_sensor(previous_origin, sensor_rect):
		return
	if not _active_piece_overlaps_crush_sensor(current_origin, sensor_rect):
		return
	if not _active_piece_crossed_crush_sensor_from_above(
		previous_origin,
		current_origin,
		sensor_rect
	):
		return
	if _has_fixed_support_underfoot():
		take_damage()


## 상황: 캐릭터의 공통 머리 압착 영역을 계산할 때 호출한다.
## 순서: 씬의 RectangleShape2D 위치와 크기를 캐릭터 좌표로 변환한다.
## 결과: sprite atlas나 animation frame과 무관한 동일한 압착 영역을 반환한다.
func _crush_sensor_rect() -> Rect2:
	var rectangle: RectangleShape2D = crush_sensor.shape as RectangleShape2D
	if rectangle == null:
		return Rect2()
	var center: Vector2 = position + crush_sensor.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


func _active_piece_overlaps_crush_sensor(origin: Vector2i, sensor_rect: Rect2) -> bool:
	for local_cell: Vector2i in controller.active_local_cells():
		if _rects_overlap_with_area(
			sensor_rect,
			_board_cell_rect(origin + local_cell)
		):
			return true
	return false


func _active_piece_crossed_crush_sensor_from_above(
	previous_origin: Vector2i,
	current_origin: Vector2i,
	sensor_rect: Rect2
) -> bool:
	for local_cell: Vector2i in controller.active_local_cells():
		var previous_rect: Rect2 = _board_cell_rect(previous_origin + local_cell)
		var current_rect: Rect2 = _board_cell_rect(current_origin + local_cell)
		var overlaps_horizontally: bool = (
			current_rect.position.x < sensor_rect.end.x
			and current_rect.end.x > sensor_rect.position.x
		)
		if not overlaps_horizontally:
			continue
		if previous_rect.end.y > sensor_rect.position.y + FIXED_SUPPORT_TOLERANCE:
			continue
		if current_rect.end.y <= sensor_rect.position.y:
			continue
		if current_rect.position.y >= sensor_rect.end.y:
			continue
		return true
	return false

## 상황: 낙하 블록과 겹친 순간 캐릭터가 아래 고정 지지면에 직접 붙어 있는지 검사한다.
## 순서: 28px 발 너비와 보드 바닥 비교 → 고정 셀 윗면과 1px 이내인지 비교.
## 결과: Boundaries 바닥 또는 LockedBlocks 윗면만 true이며 활성 피스는 제외된다.
func _has_fixed_support_underfoot() -> bool:
	var foot_y: float = (
		position.y
		+ CHARACTER_COLLIDER_OFFSET_Y
		+ CHARACTER_COLLIDER_HEIGHT * 0.5
	)
	var board_floor_y: float = MainBoardModel.VISIBLE_HEIGHT * CELL_SIZE
	if absf(foot_y - board_floor_y) <= FIXED_SUPPORT_TOLERANCE:
		return true

	var foot_left: float = position.x - FIXED_SUPPORT_FOOT_WIDTH * 0.5
	var foot_right: float = position.x + FIXED_SUPPORT_FOOT_WIDTH * 0.5
	for y: int in range(MainBoardModel.HEIGHT):
		for x: int in range(MainBoardModel.WIDTH):
			if controller.board.cells[y][x] == MainBoardModel.EMPTY:
				continue
			var solid_rect: Rect2 = _board_cell_rect(Vector2i(x, y))
			if absf(foot_y - solid_rect.position.y) > FIXED_SUPPORT_TOLERANCE:
				continue
			if foot_right > solid_rect.position.x and foot_left < solid_rect.end.x:
				return true
	return false


## 상황: 매 physics frame 끝과 BoardPhysics collision 동기화 직후 안전망으로 호출된다.
## 순서: 캐릭터 collider가 보드 안에 있도록 위치를 clamp → 보드 아래면 안전 위치 검색.
## 결과: 상하좌우 보드 밖 이탈을 막고, 기존 추락 복귀 경로도 유지한다.
func validate_position() -> void:
	if controller.state != MainGameController.GameState.PLAYING:
		return
	_clamp_to_board_bounds()
	if not _is_below_board():
		return

	var safe_position: Variant = _find_safe_position()
	if safe_position == null:
		controller.end_game()
		return
	position = safe_position as Vector2
	velocity = Vector2.ZERO


func _clamp_to_board_bounds() -> void:
	var clamped_position: Vector2 = Vector2(
		clampf(position.x, BOARD_MIN_X, BOARD_MAX_X),
		clampf(position.y, BOARD_MIN_Y, BOARD_MAX_Y)
	)
	if not is_equal_approx(clamped_position.x, position.x):
		velocity.x = 0.0
	if not is_equal_approx(clamped_position.y, position.y):
		velocity.y = 0.0
	position = clamped_position


## 상황: 위치 검증 첫 단계에서 낙사 기준을 확인할 때 호출한다.
## 순서: position.y와 `VISIBLE_HEIGHT*CELL_SIZE+80`을 비교한다.
## 결과: 캐릭터 중심이 보드 바닥보다 80px 아래면 true다.
func _is_below_board() -> bool:
	return (
		position.y
		> MainBoardModel.VISIBLE_HEIGHT * CELL_SIZE + MainLayout.scaled(80.0)
	)


## 상황: 자연 낙하 블록과 고정 지지면 사이의 직접 압착을 발견했을 때 호출한다.
## 순서: 무적이면 종료 → 생명-1/무적 설정 → 명상/hang/jump/속도 해제
##       → feedback → 생명 0이면 end_game/return → 안전 위치 탐색 → 없으면 end_game,
##       있으면 상단 한 칸 아래의 무작위 안전 열로 이동 → stats signal.
## 결과: 같은 압착에서 연속 피해를 막고 살아 있으면 블록과 겹치지 않게 상단에서 재시작한다.
func take_damage() -> void:
	if _invulnerability_remaining > 0.0:
		return
	if _barrier_remaining > 0.0 and _danger_is_from_direction(_barrier_direction):
		return
	_lose_life_and_respawn("압착 피해! 목숨 -1")


func take_thorn_damage(_feedback_message: String = "") -> void:
	if _invulnerability_remaining > 0.0:
		return
	if _consume_chef_meat_guard():
		return
	lives -= 1
	_invulnerability_remaining = INVULNERABILITY_SECONDS
	_play_sfx(SFX_HURT)
	if lives <= 0:
		controller.end_game()
	stats_changed.emit()


func _consume_chef_meat_guard(_feedback_message: String = "") -> bool:
	if (
		character_id != "chef"
		or _chef_meat_remaining <= 0.0
		or not _chef_meat_guard_available
	):
		return false
	_chef_meat_guard_available = false
	_sync_saintess_aura()
	stats_changed.emit()
	return true


## 상황: 압착 또는 자력 재스폰이 실제 생명 하나를 소비하기로 확정했을 때 호출한다.
## 순서: 생명/무적 갱신 → 모든 행동과 시각 회전 취소 → 게임오버 또는 상단 안전 재스폰.
## 결과: 두 진입점이 같은 정리·재스폰 규칙을 사용하며 자력 재스폰은 호출 전에 무적을 우회한다.
func _lose_life_and_respawn(_feedback_message: String) -> void:
	_end_binding()
	lives -= 1
	_invulnerability_remaining = INVULNERABILITY_SECONDS
	_set_meditating(false)
	_play_sfx(SFX_HURT)
	_exit_hang()
	_hang_jump_grace_remaining = 0.0
	_hang_regrab_remaining = 0.0
	_cancel_wall_jump_control()
	_cancel_jump_intent()
	_attack_animation_remaining = 0.0
	_special_animation_remaining = 0.0
	_pending_punch_stage = 0
	_pending_punch_hit_remaining = 0.0
	_cancel_character_skill_effects()
	_spin_remaining = 0.0
	_spin_elapsed = 0.0
	_pending_rotation_launch_velocity = 0.0
	_post_spin_animation_seeded = false
	_self_respawn_hold_time = 0.0
	_self_respawn_requires_release = Input.is_action_pressed(
		&"character_self_respawn"
	)
	velocity = Vector2.ZERO
	sprite.rotation = 0.0

	if lives <= 0:
		controller.end_game()
		stats_changed.emit()
		return

	var respawn_position: Variant = _find_top_respawn_position() # Vector2 또는 안전 열 없음의 null.
	if respawn_position == null:
		controller.end_game()
	else:
		position = respawn_position as Vector2
		_respawn_airborne_pending = true
		_was_grounded_for_stamina = false
	stats_changed.emit()


## 상황: GameView가 자력 재스폰 hold 진행 막대와 문구를 갱신할 때 호출한다.
## 결과: 미입력·발동 후 release 대기에는 0, 누르는 동안에는 0~1 비율을 반환한다.
func self_respawn_hold_ratio() -> float:
	if _self_respawn_requires_release:
		return 0.0
	return clampf(_self_respawn_hold_time / SELF_RESPAWN_HOLD_SECONDS, 0.0, 1.0)


## 상황: GameView가 블록 플립 cooldown bar를 계산할 때 호출한다.
## 순서: 남은 초/전체 2초 → 0~1 clamp.
## 결과: 1은 방금 사용, 0은 즉시 사용 가능을 의미한다.
func rotation_cooldown_ratio() -> float:
	return clampf(rotation_cooldown_remaining / current_rotation_cooldown(), 0.0, 1.0)


func special_cooldown_ratio() -> float:
	return clampf(special_cooldown_remaining / current_special_cooldown(), 0.0, 1.0)


func character_profile() -> Dictionary:
	return CHARACTER_DATA.profile_for(character_id)


func character_display_name() -> String:
	return str(character_profile()["display_name"])


func special_display_name() -> String:
	return str(character_profile()["special_name"])


func current_move_speed() -> float:
	var speed: float = CHARACTER_DATA.move_speed(character_id, passive_levels) * GIT_GRID_SCALE
	if _sprint_remaining > 0.0:
		return speed * 1.6
	if _chef_meat_remaining > 0.0:
		return speed * CHEF_MEAT_MOVE_MULTIPLIER
	return speed


func current_jump_velocity() -> float:
	var height: float = (
		float(CHARACTER_DATA.jump_cells(character_id))
		* CELL_SIZE
		* CHARACTER_DATA.jump_height_multiplier(passive_levels)
	)
	return -sqrt(2.0 * GRAVITY * height)


func current_rotation_cooldown() -> float:
	return CHARACTER_DATA.rotation_cooldown(character_id, passive_levels)


func current_special_cooldown() -> float:
	return CHARACTER_DATA.special_cooldown(character_id, passive_levels)


func current_attack_cooldown() -> float:
	return CHARACTER_DATA.attack_cooldown(character_id, passive_levels)


func is_special_animating() -> bool:
	return _special_animation_remaining > 0.0


func special_visual_frame(frame_count: int) -> int:
	if frame_count <= 1:
		return 0
	var elapsed: float = SPECIAL_ANIMATION_DURATION - _special_animation_remaining
	return clampi(floori(elapsed / SPECIAL_ANIMATION_DURATION * float(frame_count)), 0, frame_count - 1)


func special_visual_elapsed() -> float:
	return clampf(SPECIAL_ANIMATION_DURATION - _special_animation_remaining, 0.0, SPECIAL_ANIMATION_DURATION)


func last_special_succeeded() -> bool:
	return _last_special_succeeded


func ninja_special_result() -> Dictionary:
	return _ninja_special_result.duplicate()


func _start_ninja_projectile() -> void:
	var start_cell: Vector2i = _front_board_cell() - Vector2i(facing, 0)
	var start_position := Vector2(
		(float(start_cell.x) + 0.5) * CELL_SIZE,
		(float(start_cell.y - MainBoardModel.HIDDEN_ROWS) + 0.5) * CELL_SIZE
	)
	_ninja_projectile = {
		"position": start_position,
		"row": start_cell.y,
		"direction": facing,
		"travel_pixels": 0.0,
		"active": true,
	}
	_ninja_special_result = {
		"position": start_position,
		"direction": facing,
		"success": false,
		"contact": MainGameController.SHURIKEN_CONTACT_NONE,
		"in_flight": true,
		"impact_elapsed": 0.0,
		"flight_elapsed": 0.0,
	}


func _advance_ninja_projectile(delta: float) -> void:
	if _ninja_projectile.is_empty():
		if not _ninja_special_result.is_empty() and not bool(_ninja_special_result.get("in_flight", false)):
			_ninja_special_result["impact_elapsed"] = (
				float(_ninja_special_result.get("impact_elapsed", 0.0)) + maxf(delta, 0.0)
			)
			if float(_ninja_special_result["impact_elapsed"]) >= SHURIKEN_IMPACT_DURATION:
				_ninja_special_result.clear()
			stats_changed.emit()
		return
	if not bool(_ninja_projectile.get("active", false)):
		return
	var direction: int = int(_ninja_projectile["direction"])
	var position_now: Vector2 = _ninja_projectile["position"] as Vector2
	var traveled: float = float(_ninja_projectile["travel_pixels"])
	_ninja_special_result["flight_elapsed"] = (
		float(_ninja_special_result.get("flight_elapsed", 0.0)) + maxf(delta, 0.0)
	)
	var maximum_travel: float = float(SHURIKEN_REACH_CELLS) * CELL_SIZE
	var step: float = minf(SHURIKEN_SPEED * maxf(delta, 0.0), maximum_travel - traveled)
	var next_position := position_now + Vector2(float(direction) * step, 0.0)
	var projectile_half_size: Vector2 = SHURIKEN_COLLISION_SIZE * 0.5
	var sweep := Rect2(
		Vector2(
			minf(position_now.x, next_position.x) - projectile_half_size.x,
			position_now.y - projectile_half_size.y
		),
		Vector2(
			absf(next_position.x - position_now.x) + SHURIKEN_COLLISION_SIZE.x,
			SHURIKEN_COLLISION_SIZE.y
		)
	)
	var active_cells: Array[Vector2i] = controller.active_board_cells()
	var hit_cell: Variant = null
	var hit_contact: StringName = MainGameController.SHURIKEN_CONTACT_NONE
	var hit_distance: float = INF
	for y: int in range(MainBoardModel.HEIGHT):
		for x: int in range(MainBoardModel.WIDTH):
			var cell := Vector2i(x, y)
			var is_active_cell: bool = cell in active_cells
			if not is_active_cell and controller.board.get_cell(cell) == MainBoardModel.EMPTY:
				continue
			var cell_rect: Rect2 = _board_cell_rect(cell)
			if not sweep.intersects(cell_rect, true):
				continue
			var signed_distance: float = (cell_rect.get_center().x - position_now.x) * float(direction)
			if signed_distance < -projectile_half_size.x or signed_distance >= hit_distance:
				continue
			hit_distance = maxf(signed_distance, 0.0)
			hit_cell = cell
			hit_contact = (
				MainGameController.SHURIKEN_CONTACT_ACTIVE
				if is_active_cell
				else MainGameController.SHURIKEN_CONTACT_FIXED
			)
	if hit_cell != null:
		var impact_cell: Vector2i = hit_cell as Vector2i
		var impact_position: Vector2 = _board_cell_rect(impact_cell).get_center()
		var succeeded: bool = false
		if hit_contact == MainGameController.SHURIKEN_CONTACT_ACTIVE:
			succeeded = controller.push_active_piece(
				direction,
				1,
				_rotation_forbidden_cells()
			)
		_finish_ninja_projectile(impact_position, hit_contact, succeeded)
		return
	traveled += step
	_ninja_projectile["position"] = next_position
	_ninja_projectile["travel_pixels"] = traveled
	_ninja_special_result["position"] = next_position
	if traveled >= maximum_travel or next_position.x < 0.0 or next_position.x > MainLayout.BOARD_SIZE.x:
		_finish_ninja_projectile(
			next_position,
			MainGameController.SHURIKEN_CONTACT_NONE,
			false
		)
	stats_changed.emit()


func _finish_ninja_projectile(
	impact_position: Vector2,
	contact: StringName,
	succeeded: bool
) -> void:
	_ninja_projectile.clear()
	_ninja_special_result["position"] = impact_position
	_ninja_special_result["contact"] = contact
	_ninja_special_result["success"] = succeeded
	_ninja_special_result["in_flight"] = false
	_ninja_special_result["impact_elapsed"] = 0.0
	_last_special_succeeded = succeeded
	stats_changed.emit()


func sprint_remaining() -> float:
	return _sprint_remaining


func barrier_remaining() -> float:
	return _barrier_remaining


## 기본 공격 전용으로 무기 그림과 무관한 전방 한 칸·몸 전체 높이 판정 영역을 반환한다.
func water_remaining() -> float:
	return _water_remaining


func chef_meat_remaining() -> float:
	return _chef_meat_remaining


func chef_meat_guard_available() -> bool:
	return _chef_meat_guard_available


## 상황: 테스트/비용 helper가 임의 hold 초의 이론적 펀치 단계를 구할 때 호출한다.
## 순서: stage index 1부터 임계시간과 비교 → seconds가 작아지는 첫 index 반환
##       → 모든 임계 이상이면 전체 stage 수 3 반환.
## 결과: runtime 상태와 무관한 1~3 정수 단계를 반환한다.
## 상황: 펀치가 활성 블록을 실제로 때렸는지 확인할 때 호출한다.
## 순서: 몸 바로 앞의 좁은 주먹 Rect를 만들고 활성 피스 셀과 양의 면적 교차를 검사한다.
## 결과: 블록이 멀리 있으면 false이며, 몸에 닿은 전방 블록만 true다.
func _punch_hits_active_piece() -> bool:
	return _basic_attack_target_cell() != null


func _punch_hitbox_rect() -> Rect2:
	return _forward_attack_rect(BASIC_ATTACK_FORWARD_REACH)


func _forward_attack_rect(forward_reach: float) -> Rect2:
	var body_rect: Rect2 = _character_collider_rect()
	var fist_x: float = (
		body_rect.end.x if facing > 0 else body_rect.position.x - forward_reach
	)
	return Rect2(
		Vector2(fist_x, body_rect.position.y),
		Vector2(forward_reach, body_rect.size.y)
	)


func _basic_attack_target_cell() -> Variant:
	var active_cells: Array[Vector2i] = controller.active_board_cells()
	for target_cell: Vector2i in _basic_attack_target_cells():
		if target_cell in active_cells:
			return target_cell
	return null


## X attacks only the two board cells immediately in front of the character's
## lower occupied cell.  This discrete rule is intentionally independent from
## the taller rectangular boss hitbox, whose behaviour remains unchanged.
func _basic_attack_target_cells() -> Array[Vector2i]:
	var lower_body_cell: Vector2i = _cell_below_feet() + Vector2i.UP
	var front_x: int = lower_body_cell.x + signi(facing)
	var target_cells: Array[Vector2i] = []
	for y_offset: int in range(2):
		var target_cell := Vector2i(front_x, lower_body_cell.y - y_offset)
		if controller.board.is_inside(target_cell):
			target_cells.append(target_cell)
	return target_cells


## 상황: rotation kick이 활성 피스와 충분히 가까운지 검사할 때 호출한다.
## 순서: 활성 네 셀 중심 계산 → difference=cell-character
##       → horizontal_reach=0이면 원형 거리, 아니면 같은 방향/x reach/y reach 검사.
## 결과: 셀 하나라도 범위 안이면 true이며 피스/캐릭터 상태는 바꾸지 않는다.
func _is_near_active_piece(horizontal_reach: float, radial_reach: float) -> bool:
	for local_cell: Vector2i in controller.active_local_cells():
		var cell: Vector2i = controller.active_origin + local_cell # 활성 절대 보드 셀.
		var cell_center: Vector2 = Vector2( # 숨은 행 offset을 뺀 셀 중심 픽셀.
			(float(cell.x) + 0.5) * CELL_SIZE,
			(float(cell.y - MainBoardModel.HIDDEN_ROWS) + 0.5) * CELL_SIZE
		)
		var difference: Vector2 = cell_center - position # 캐릭터 중심에서 셀 중심으로의 벡터.
		if is_zero_approx(horizontal_reach):
			if difference.length() <= radial_reach:
				return true
		elif signf(difference.x) == signf(horizontal_reach):
			if absf(difference.x) <= absf(horizontal_reach) and absf(difference.y) <= radial_reach:
				return true
	return false


## 상황: 피해 후 생명이 남아 캐릭터를 겹치지 않는 발판으로 옮길 때 호출한다.
## 순서: 아래→위, 중앙→바깥 순회 → 몸의 두 셀이 비었는지
##       → 아래가 바닥/solid인지 → 첫 후보의 캐릭터 중심 픽셀 계산.
## 결과: 가장 아래·중앙에 가까운 안전 Vector2 또는 공간이 없으면 null을 반환한다.
func _find_safe_position() -> Variant:
	var x_order: Array[int] = [4, 5, 3, 6, 2, 7, 1, 8, 0, 9] # 중앙 우선 x 순서.
	for y: int in range(MainBoardModel.HEIGHT - 1, MainBoardModel.HIDDEN_ROWS, -1):
		for x: int in x_order:
			if _cell_is_solid(Vector2i(x, y)) or _cell_is_solid(Vector2i(x, y - 1)):
				continue
			var supported: bool = ( # 아래 셀이 바닥 또는 solid여서 설 수 있는지.
				y == MainBoardModel.HEIGHT - 1
				or _cell_is_solid(Vector2i(x, y + 1))
			)
			if supported:
				return Vector2(
					(float(x) + 0.5) * CELL_SIZE,
					float(y + 1 - MainBoardModel.HIDDEN_ROWS) * CELL_SIZE
					- CHARACTER_HEIGHT * 0.5
				)
	return null


## 상황: 압착 피해 뒤 생명이 남아 화면 상단에서 재스폰할 때 호출한다.
## 순서: 열 중앙 10곳 중 고정/활성 블록과 28×64px 몸통이 겹치지 않는 후보를 수집
##       → 캐릭터 전용 난수기로 균등 선택.
## 결과: 윗면 Y=48px인 안전 Vector2 또는 안전한 열이 없으면 null을 반환한다.
func _find_top_respawn_position() -> Variant:
	var candidates: Array[Vector2] = _top_respawn_candidates()
	if candidates.is_empty():
		return null
	var index: int = _respawn_random.randi_range(0, candidates.size() - 1)
	return candidates[index]


## 상황: 상단 재스폰이 가능한 모든 가로 열을 결정할 때 호출한다.
## 결과: X가 각 보드 열 중앙이고 Y가 96px인 충돌 없는 후보만 왼쪽부터 반환한다.
func _top_respawn_candidates() -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	for x: int in range(MainBoardModel.WIDTH):
		var candidate: Vector2 = Vector2(
			(float(x) + 0.5) * CELL_SIZE,
			RESPAWN_CENTER_Y
		)
		if not _respawn_overlaps_any_block(candidate):
			candidates.append(candidate)
	return candidates


## 상황: 재스폰 후보의 고정·활성 블록 겹침을 한 곳에서 검사한다.
## 순서: 전체 고정 셀 검사 → 현재 활성 피스 네 셀 검사.
## 결과: 경계 접촉은 허용하고 양의 면적으로 1px이라도 교차할 때만 true다.
func _respawn_overlaps_any_block(candidate: Vector2) -> bool:
	var body_rect: Rect2 = _respawn_rect_at(candidate)
	for y: int in range(MainBoardModel.HEIGHT):
		for x: int in range(MainBoardModel.WIDTH):
			if controller.board.cells[y][x] == MainBoardModel.EMPTY:
				continue
			if _rects_overlap_with_area(body_rect, _board_cell_rect(Vector2i(x, y))):
				return true

	for local_cell: Vector2i in controller.active_local_cells():
		var active_rect: Rect2 = _board_cell_rect(controller.active_origin + local_cell)
		if _rects_overlap_with_area(body_rect, active_rect):
			return true
	return false


## 상황: 후보 중심을 프레임과 무관한 재스폰 몸통 영역으로 변환한다.
func _respawn_rect_at(candidate: Vector2) -> Rect2:
	return Rect2(candidate - RESPAWN_BODY_SIZE * 0.5, RESPAWN_BODY_SIZE)


## 상황: 재스폰 몸통과 블록이 실제 픽셀 면적으로 겹치는지 검사한다.
## 결과: 모서리나 변이 닿기만 하면 false, 양쪽 축에서 양의 길이가 겹치면 true다.
func _rects_overlap_with_area(first: Rect2, second: Rect2) -> bool:
	return (
		first.position.x < second.end.x
		and first.end.x > second.position.x
		and first.position.y < second.end.y
		and first.end.y > second.position.y
	)


## 상황: 안전 위치 후보의 몸/발판 셀이 점유됐는지 통합 확인할 때 호출한다.
## 순서: 범위 밖이면 false → 고정 셀이 차면 true → 활성 네 셀과 비교 → 기본 false.
## 결과: BoardModel과 활성 피스를 하나의 solid 판정처럼 제공한다.
func _cell_is_solid(cell: Vector2i) -> bool:
	if not controller.board.is_inside(cell):
		return false
	if controller.board.get_cell(cell) != MainBoardModel.EMPTY:
		return true
	for local_cell: Vector2i in controller.active_local_cells():
		if controller.active_origin + local_cell == cell:
			return true
	return false


func _character_center_cell() -> Vector2i:
	return Vector2i(
		clampi(floori(position.x / CELL_SIZE), 0, MainBoardModel.WIDTH - 1),
		clampi(
			floori(position.y / CELL_SIZE) + MainBoardModel.HIDDEN_ROWS,
			0,
			MainBoardModel.HEIGHT - 1
		)
	)


func _front_board_cell() -> Vector2i:
	return Vector2i(
		floori(position.x / CELL_SIZE) + facing,
		clampi(
			floori((position.y - CELL_SIZE * 0.5) / CELL_SIZE)
			+ MainBoardModel.HIDDEN_ROWS,
			0,
			MainBoardModel.HEIGHT - 1
		)
	)


## Boxer guard break checks the two cells in front of the fixed gameplay
## collider. The lower movable cell wins; the upper cell is the fallback.
func _boxer_special_target_cell() -> Variant:
	var active_cells: Array[Vector2i] = controller.active_board_cells()
	for candidate: Vector2i in _boxer_special_target_cells():
		if candidate in active_cells:
			return candidate
		if controller.board.get_cell(candidate) == MainBoardModel.EMPTY:
			continue
		var above: Vector2i = candidate + Vector2i.UP
		if (
			controller.board.is_inside(above)
			and controller.board.get_cell(above) != MainBoardModel.EMPTY
		):
			continue
		return candidate
	return null


func _boxer_special_target_cells() -> Array[Vector2i]:
	var collider_rect: Rect2 = _character_collider_rect()
	var front_x: int = floori(collider_rect.get_center().x / CELL_SIZE) + signi(facing)
	var lower_y: int = clampi(
		floori((collider_rect.end.y - 0.001) / CELL_SIZE) + MainBoardModel.HIDDEN_ROWS,
		0,
		MainBoardModel.HEIGHT - 1
	)
	var candidates: Array[Vector2i] = []
	for y_offset: int in range(2):
		var candidate := Vector2i(front_x, lower_y - y_offset)
		if controller.board.is_inside(candidate):
			candidates.append(candidate)
	return candidates


func _cell_below_feet() -> Vector2i:
	var collider_bottom: float = (
		position.y
		+ CHARACTER_COLLIDER_OFFSET_Y
		+ CHARACTER_COLLIDER_HEIGHT * 0.5
	)
	return Vector2i(
		clampi(floori(position.x / CELL_SIZE), 0, MainBoardModel.WIDTH - 1),
		clampi(
			floori((collider_bottom + 1.0) / CELL_SIZE)
			+ MainBoardModel.HIDDEN_ROWS,
			0,
			MainBoardModel.HEIGHT - 1
		)
	)


func _barrier_cells() -> Array[Vector2i]:
	return _barrier_cells_at(position, _barrier_direction)


func _barrier_cells_at(cast_position: Vector2, direction: int) -> Array[Vector2i]:
	if direction == 0:
		return []
	var collider_center := cast_position + Vector2(0.0, CHARACTER_COLLIDER_OFFSET_Y)
	var collider_bottom: float = collider_center.y + CHARACTER_COLLIDER_HEIGHT * 0.5
	var lower_row: int = clampi(
		floori((collider_bottom - 0.001) / CELL_SIZE) + MainBoardModel.HIDDEN_ROWS,
		0,
		MainBoardModel.HEIGHT - 1
	)
	var front_x: int = floori(collider_center.x / CELL_SIZE) + signi(direction)
	var cells: Array[Vector2i] = []
	for y_offset: int in range(3):
		var cell := Vector2i(front_x, lower_row - y_offset)
		if controller.board.is_inside(cell):
			cells.append(cell)
	return cells


func _available_barrier_cells() -> Array[Vector2i]:
	return _available_barrier_cells_from(_barrier_cells())


func _available_barrier_cells_from(candidate_cells: Array[Vector2i]) -> Array[Vector2i]:
	var active_cells: Array[Vector2i] = controller.active_board_cells()
	var available: Array[Vector2i] = []
	for cell: Vector2i in candidate_cells:
		if controller.board.get_cell(cell) != MainBoardModel.EMPTY:
			continue
		if cell in active_cells:
			continue
		available.append(cell)
	return available


func _sync_barrier_cells() -> void:
	if _barrier_remaining <= 0.0:
		controller.clear_transient_blockers()
	return


func _danger_is_from_direction(direction: int) -> bool:
	if direction == 0:
		return false
	var character_x: int = _character_center_cell().x
	for cell: Vector2i in controller.active_board_cells():
		if signi(cell.x - character_x) == direction:
			return true
	return false


## 상황: 고정/활성 셀과 캐릭터 Rect의 교집합을 계산하기 전에 호출한다.
## 순서: x×CELL_SIZE와 `(y-HIDDEN_ROWS)×CELL_SIZE`로 좌상단 계산 → 48×48 Rect.
## 결과: CharacterBody와 같은 BoardPhysics 로컬 좌표계의 Rect2를 반환한다.
func _board_cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		Vector2(
			cell.x * CELL_SIZE,
			(cell.y - MainBoardModel.HIDDEN_ROWS) * CELL_SIZE
		),
		Vector2.ONE * CELL_SIZE
	)


## 상황: PLAYING physics frame 시작부에서 시간 제한 상태들을 진행할 때 호출한다.
## 순서: 모든 cooldown/animation/무적/입력 유예 timer를 `max(0,value-delta)`로 감소
##       → feedback 만료 시 text clear/signal.
## 결과: timer가 음수가 되지 않고 0을 경계로 각 기능이 자동 종료된다.
func _update_timers(delta: float) -> void:
	rotation_cooldown_remaining = maxf(0.0, rotation_cooldown_remaining - delta)
	special_cooldown_remaining = maxf(0.0, special_cooldown_remaining - delta)
	_sprint_remaining = maxf(0.0, _sprint_remaining - delta)
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_attack_animation_remaining = maxf(0.0, _attack_animation_remaining - delta)
	_special_animation_remaining = maxf(0.0, _special_animation_remaining - delta)
	var pending_before: float = _pending_special_remaining
	_pending_special_remaining = maxf(0.0, _pending_special_remaining - delta)
	if pending_before > 0.0 and _pending_special_remaining <= 0.0 and not _pending_special_id.is_empty():
		_resolve_pending_special()
	var barrier_before: float = _barrier_remaining
	_barrier_remaining = maxf(0.0, _barrier_remaining - delta)
	if barrier_before > 0.0 and _barrier_remaining <= 0.0:
		controller.clear_transient_blockers()
		_barrier_direction = 0
	var water_before: float = _water_remaining
	_water_remaining = maxf(0.0, _water_remaining - delta)
	if water_before > 0.0 and _water_remaining <= 0.0:
		controller.clear_water_path()
	_chef_meat_remaining = maxf(0.0, _chef_meat_remaining - delta)
	if _chef_meat_remaining <= 0.0:
		_chef_meat_guard_available = false
	_invulnerability_remaining = maxf(0.0, _invulnerability_remaining - delta)
	_coyote_remaining = maxf(0.0, _coyote_remaining - delta)
	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)
	_hang_regrab_remaining = maxf(0.0, _hang_regrab_remaining - delta)
	_hang_jump_grace_remaining = maxf(0.0, _hang_jump_grace_remaining - delta)
	_wall_jump_control_remaining = maxf(0.0, _wall_jump_control_remaining - delta)


## 상황: gameplay 처리가 끝난 활성 physics frame마다 sprite를 최신 상태로 만들 때 호출한다.
## 순서: 블록 플립 spin → 명상 색 → 피해 blink → frame animation.
## 결과: 서로 다른 시각 효과가 고정된 순서로 합성된다.
func _update_visual_state(delta: float) -> void:
	_update_spin_visual(delta)
	_update_sprite_modulation()
	_update_damage_blink()
	_advance_character_animation(delta)
	_sync_saintess_aura()


func _setup_saintess_aura_material() -> void:
	_saintess_aura_material = ShaderMaterial.new()
	_saintess_aura_material.shader = SAINTESS_AURA_SHADER
	_saintess_aura_material.set_shader_parameter("aura_enabled", false)
	sprite.material = _saintess_aura_material
	_saintess_barrier_sprite = Sprite2D.new()
	_saintess_barrier_sprite.name = "SaintessBarrier"
	_saintess_barrier_sprite.texture = SAINTESS_BARRIER_TEXTURE
	_saintess_barrier_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_saintess_barrier_sprite.z_index = sprite.z_index + 2
	_saintess_barrier_sprite.visible = false
	add_child(_saintess_barrier_sprite)


func _sync_saintess_aura() -> void:
	if _saintess_aura_material == null:
		return
	var barrier_active: bool = (
		character_id == "chef"
		and _chef_meat_remaining > 0.0
		and _chef_meat_guard_available
	)
	_saintess_aura_material.set_shader_parameter("aura_enabled", barrier_active)
	if not is_instance_valid(_saintess_barrier_sprite):
		return
	_saintess_barrier_sprite.visible = barrier_active
	_saintess_barrier_sprite.position = sprite.position
	_saintess_barrier_sprite.scale = sprite.scale
	if barrier_active:
		var pulse: float = 0.56 + 0.06 * sin(float(Time.get_ticks_msec()) * 0.004)
		_saintess_barrier_sprite.modulate = Color(1.0, 1.0, 0.92, pulse)


## 상황: 블록 플립 spin timer 중 또는 끝난 뒤 sprite 각도를 갱신할 때 호출한다.
## 순서: 남은 시간까지만 delta 소비 → elapsed 진행률 → smoothstep → 방향×TAU 각도 직접 계산
##       → 완료 frame은 TAU와 시각적으로 같은 0도로 정규화하고 후속 animation을 seed.
## 결과: 누적 오차나 TAU→0 역보간 없이 0.42초 동안 같은 방향으로 정확히 한 바퀴 돈다.
func _update_spin_visual(delta: float) -> void:
	if _spin_remaining <= 0.0:
		sprite.rotation = 0.0
		return

	var consumed_delta: float = minf(maxf(delta, 0.0), _spin_remaining)
	_spin_elapsed = minf(ROTATION_SPIN_DURATION, _spin_elapsed + consumed_delta)
	_spin_remaining = maxf(0.0, ROTATION_SPIN_DURATION - _spin_elapsed)
	var progress: float = clampf(_spin_elapsed / ROTATION_SPIN_DURATION, 0.0, 1.0)
	var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)

	if _spin_remaining <= 0.0:
		sprite.rotation = 0.0
		_seed_post_spin_animation()
	else:
		sprite.rotation = -TAU * eased_progress * float(_spin_direction)


## 상황: 한 바퀴 완료 후 블록 플립 전용 상태에서 실제 이동 상태 animation으로 돌아갈 때 호출한다.
## 순서: 접지면 idle 0 → 공중이면 y속도를 ±40과 비교해 jump 4/5/6 frame 시간 선택.
## 결과: 공중에서 준비 자세로 재시작하지 않고 상승·정점·하강에 맞는 pose로 바로 이어진다.
func _seed_post_spin_animation() -> void:
	if is_on_floor():
		_animation_state = ANIMATION_DATA.IDLE
		_animation_time = 0.0
	else:
		_animation_state = ANIMATION_DATA.JUMP
		_set_jump_animation_time_from_velocity()
	_post_spin_animation_seeded = true


## 상황: 현재 매달림/명상 상태를 색으로 표시할 때 호출한다.
## 순서: 매달림이면 stamina 기반 적색 점멸 → 명상이면 청색 pulse → 아니면 기본색.
## 결과: sprite.modulate가 현재 상태의 우선 시각 효과를 반영한다.
func _update_sprite_modulation() -> void:
	if is_hanging:
		var stamina_ratio: float = clampf(stamina / MAX_STAMINA, 0.0, 1.0)
		if is_zero_approx(stamina_ratio):
			sprite.modulate = Color(1.0, 0.0, 0.0, 1.0)
			return
		var danger: float = 1.0 - stamina_ratio
		var blink_frequency: float = lerpf(1.5, 12.0, danger)
		var pulse: float = (
			sin(float(Time.get_ticks_msec()) * TAU * blink_frequency / 1000.0) + 1.0
		) * 0.5
		var red_strength: float = danger * pulse
		sprite.modulate = Color(
			1.0,
			1.0 - red_strength * 0.9,
			1.0 - red_strength * 0.9,
			1.0
		)
		return
	if is_meditating:
		var meditation_pulse: float = ( # 0~1로 왕복하는 명상 밝기.
			sin(float(Time.get_ticks_msec()) * 0.008) + 1.0
		) * 0.5
		sprite.modulate = Color(
			0.72 + meditation_pulse * 0.10,
			0.92 + meditation_pulse * 0.08,
			1.0,
			1.0
		)
	else:
		sprite.modulate = Color.WHITE
	## 상황: 피해 무적시간을 캐릭터 깜빡임으로 표현할 때 호출한다.
## 순서: 무적 timer>0이면 `int(timer*12)%2`로 visible 토글 → 아니면 true.
## 결과: 무적 중에만 깜빡이고 종료 frame에는 반드시 다시 보인다.
func _update_damage_blink() -> void:
	if _invulnerability_remaining > 0.0:
		sprite.visible = int(_invulnerability_remaining * 12.0) % 2 == 0
	else:
		sprite.visible = true


## 상황: gameplay 상태에서 현재 animation state/frame을 결정할 때 호출한다.
## 순서: 회전 종료 seed면 해당 frame 즉시 적용 → 목표 상태 조회 → 블록 플립이면 elapsed 동기화
##       → 일반 상태는 이전과 다르면 time=0, 같으면 time+=delta → frame 적용.
## 결과: 블록 플립은 정확히 8 frame을 사용하고 종료 seed가 jump 0 frame으로 덮이지 않는다.
func _advance_character_animation(delta: float) -> void:
	if _post_spin_animation_seeded:
		_post_spin_animation_seeded = false
		_apply_animation_frame()
		return

	var next_animation_state: String = _get_animation_state() # 이번 frame의 목표 상태 key.
	if next_animation_state == ANIMATION_DATA.ROTATION_KICK:
		_animation_state = next_animation_state
		_animation_time = minf(
			_spin_elapsed,
			ROTATION_SPIN_DURATION
			- float(ANIMATION_DATA.FRAME_DURATIONS[ANIMATION_DATA.ROTATION_KICK]) * 0.001
		)
		_apply_animation_frame()
		return
	if next_animation_state != _animation_state:
		_animation_state = next_animation_state
		_animation_time = 0.0
	if next_animation_state == ANIMATION_DATA.HANG:
		# Movement runs before rendering and records the accepted climb input.
		# `_finish_hanging_frame()` clears velocity, so neither the
		# cleared velocity nor a second raw-input read may drive this animation.
		_advance_hang_animation_time(delta, _hang_animation_direction)
	elif next_animation_state == ANIMATION_DATA.JUMP:
		# Airborne art follows actual vertical motion.  A long drop therefore
		# holds the extended terminal-fall frame instead of advancing into a
		# grounded crouch or standing pose while the body is still in the air.
		_set_jump_animation_time_from_velocity()
	elif (
		next_animation_state == ANIMATION_DATA.IDLE
		and absf(velocity.x) <= IDLE_ANIMATION_SPEED_EPSILON
	):
		# 대기/이동은 같은 4프레임 계약을 유지하지만 정지 중에는
		# 걷기 포즈를 순환하지 않아 캐릭터가 움찔거리지 않게 한다.
		_animation_time = 0.0
	else:
		_animation_time += delta
	_apply_animation_frame()


## Map actual vertical speed to takeoff, rise, apex and four falling poses.
## The final pose is safe to hold for an arbitrarily long fall.
func _set_jump_animation_time_from_velocity() -> void:
	var frame_index: int = _jump_animation_frame_for_velocity(velocity.y)
	_animation_time = (
		float(frame_index)
		* float(ANIMATION_DATA.FRAME_DURATIONS[ANIMATION_DATA.JUMP])
		+ 0.001
	)


func _jump_animation_frame_for_velocity(vertical_speed: float) -> int:
	var apex_speed: float = POST_SPIN_APEX_SPEED
	if vertical_speed < -apex_speed:
		var launch_speed: float = maxf(absf(current_jump_velocity()), 1.0)
		var rise_ratio: float = clampf(-vertical_speed / launch_speed, 0.0, 1.0)
		if rise_ratio > 0.66:
			return 0
		if rise_ratio > 0.33:
			return 1
		return 2
	if vertical_speed <= apex_speed:
		return 3
	var fall_frame_step: float = maxf(GRAVITY * 0.14, 1.0)
	return clampi(
		4 + floori((vertical_speed - apex_speed) / fall_frame_step),
		4,
		7
	)


## Keep still hanging visually planted, and tie the foot cycle to climb intent.
## Up plays the selected skin's climb poses forward; down plays the cycle in reverse.
func _advance_hang_animation_time(delta: float, climb_direction: float) -> void:
	if is_zero_approx(climb_direction):
		_animation_time = 0.0
		return
	var frame_duration: float = float(
		ANIMATION_DATA.FRAME_DURATIONS[ANIMATION_DATA.HANG]
	)
	var cycle_duration: float = frame_duration * float(
		ANIMATION_DATA.frame_count_for(ANIMATION_DATA.HANG, character_id)
	)
	if climb_direction < 0.0:
		_animation_time = fposmod(_animation_time + delta, cycle_duration)
	else:
		_animation_time = fposmod(_animation_time - delta, cycle_duration)


## 상황: 겹칠 수 있는 gameplay flag 중 표시할 animation 하나를 고를 때 호출한다.
## 순서: 블록 플립 → attack timer → 매달림 → 비접지 jump → idle 순 조기 반환.
## 결과: `rotation kick > attack > hang > jump > idle` 우선순위 key를 반환한다.
func _get_animation_state() -> String:
	if _spin_remaining > 0.0:
		return ANIMATION_DATA.ROTATION_KICK
	if _special_animation_remaining > 0.0:
		return ANIMATION_DATA.SPECIAL
	if _attack_animation_remaining > 0.0:
		return ANIMATION_DATA.ATTACK
	if is_hanging:
		return ANIMATION_DATA.HANG
	if not is_on_floor():
		return ANIMATION_DATA.JUMP
	return ANIMATION_DATA.IDLE


## 상황: animation 시간/state가 정해진 뒤 실제 Sprite2D frame을 적용할 때 호출한다.
## 순서: 현재 frame의 불투명 경계와 고정 충돌체 발선을 정렬한다.
## 결과: 원본 투명 여백이 달라도 HANG을 포함한 frame 전환 시 몸 크기와 기준 위치가 흔들리지 않는다.
func _apply_animation_frame() -> void:
	if not is_instance_valid(sprite):
		return
	var region: Rect2 = ANIMATION_DATA.region_for(
		_animation_state,
		_animation_time,
		character_id
	) # source frame.
	sprite.texture = ANIMATION_DATA.texture_for(_animation_state, character_id)
	sprite.region_enabled = true
	sprite.region_rect = region
	if ANIMATION_DATA.uses_fixed_geometry(character_id):
		sprite.scale = ANIMATION_DATA.fixed_scale_for(character_id)
		var fixed_position: Vector2 = (
			ANIMATION_DATA.display_offset_for(character_id)
			+ MainLayout.BOARD_VISUAL_OFFSET
			+ ANIMATION_DATA.fixed_offset_for(character_id)
		)
		fixed_position.x += _standing_wall_visual_offset_x(region)
		sprite.position = fixed_position
		return
	var frame_bounds: Rect2 = _frame_alpha_bounds(region)
	var visible_height: float = ANIMATION_DATA.visible_height_for(
		_animation_state,
		character_id
	)
	var uniform_scale: float = visible_height / maxf(frame_bounds.size.y, 1.0)
	var source_center: Vector2 = region.size * 0.5
	var visible_center_x: float = frame_bounds.position.x + frame_bounds.size.x * 0.5
	var visible_bottom: float = frame_bounds.end.y
	var ground_anchor_y: float = (
		CHARACTER_COLLIDER_OFFSET_Y + CHARACTER_COLLIDER_HEIGHT * 0.5
	)
	sprite.scale = Vector2.ONE * uniform_scale
	sprite.position = (
		ANIMATION_DATA.display_offset_for(character_id)
		+ MainLayout.BOARD_VISUAL_OFFSET
		+ Vector2(
			-(visible_center_x - source_center.x) * uniform_scale,
			ground_anchor_y - (visible_bottom - source_center.y) * uniform_scale
		)
	)


## 상황: 현재 atlas frame 안에서 실제로 보이는 픽셀 영역이 필요할 때 호출한다.
## 순서: 캐시 확인 → atlas Image 재사용 → alpha 경계값 이상인 픽셀의 최소 Rect 계산.
## 결과: 투명 공백을 제외한 source-local 경계를 반환하고 같은 frame은 다시 검색하지 않는다.
## Align only standing art with a wall already touching the fixed collider.
## The CharacterBody2D and its 42x90 collider never move for this correction.
func _standing_wall_visual_offset_x(region: Rect2) -> float:
	if _animation_state != ANIMATION_DATA.IDLE or is_hanging or not is_on_floor():
		return 0.0
	var wall_direction: int = _standing_wall_contact_direction()
	if wall_direction == 0:
		return 0.0

	var frame_bounds: Rect2 = _frame_alpha_bounds(region)
	var displayed_wall_edge: float
	if wall_direction > 0:
		displayed_wall_edge = (
			ANIMATION_DATA.FRAME_SIZE - frame_bounds.position.x
			if sprite.flip_h
			else frame_bounds.end.x
		) - ANIMATION_DATA.FRAME_SIZE * 0.5
	else:
		displayed_wall_edge = (
			ANIMATION_DATA.FRAME_SIZE - frame_bounds.end.x
			if sprite.flip_h
			else frame_bounds.position.x
		) - ANIMATION_DATA.FRAME_SIZE * 0.5

	var visual_inset: float = _standing_wall_visual_inset(wall_direction)
	var target_wall_edge: float = float(wall_direction) * (
		CHARACTER_COLLIDER_WIDTH * 0.5 + visual_inset
	)
	return target_wall_edge - displayed_wall_edge


## Use the full body height instead of the hang rays: while standing, the ray
## origin can lie exactly on a seam between two adjacent block collision boxes.
func _standing_wall_contact_direction() -> int:
	var collider_rect: Rect2 = _character_collider_rect()
	var board_width: float = float(MainBoardModel.WIDTH) * CELL_SIZE
	var touching_left: bool = (
		absf(collider_rect.position.x) <= STANDING_WALL_CONTACT_TOLERANCE
		or _standing_collider_touches_block_face(collider_rect, -1)
	)
	var touching_right: bool = (
		absf(collider_rect.end.x - board_width) <= STANDING_WALL_CONTACT_TOLERANCE
		or _standing_collider_touches_block_face(collider_rect, 1)
	)
	if touching_left and touching_right:
		return facing
	if touching_left:
		return -1
	if touching_right:
		return 1
	return 0


func _standing_wall_visual_inset(direction: int) -> float:
	var collider_rect: Rect2 = _character_collider_rect()
	var board_width: float = float(MainBoardModel.WIDTH) * CELL_SIZE
	if direction < 0 and absf(collider_rect.position.x) <= STANDING_WALL_CONTACT_TOLERANCE:
		return 0.0
	if direction > 0 and absf(collider_rect.end.x - board_width) <= STANDING_WALL_CONTACT_TOLERANCE:
		return 0.0
	return BLOCK_VISUAL_INSET


func _standing_collider_touches_block_face(collider_rect: Rect2, direction: int) -> bool:
	for y: int in range(MainBoardModel.HEIGHT):
		for x: int in range(MainBoardModel.WIDTH):
			if controller.board.cells[y][x] == MainBoardModel.EMPTY:
				continue
			if _standing_rect_touches_face(collider_rect, _board_cell_rect(Vector2i(x, y)), direction):
				return true
	for local_cell: Vector2i in controller.active_local_cells():
		var active_cell: Vector2i = controller.active_origin + local_cell
		if _standing_rect_touches_face(collider_rect, _board_cell_rect(active_cell), direction):
			return true
	return false


func _standing_rect_touches_face(body_rect: Rect2, block_rect: Rect2, direction: int) -> bool:
	var vertical_overlap: float = (
		minf(body_rect.end.y, block_rect.end.y)
		- maxf(body_rect.position.y, block_rect.position.y)
	)
	if vertical_overlap <= STANDING_WALL_CONTACT_TOLERANCE:
		return false
	var body_face_x: float = body_rect.end.x if direction > 0 else body_rect.position.x
	var block_face_x: float = block_rect.position.x if direction > 0 else block_rect.end.x
	return absf(body_face_x - block_face_x) <= STANDING_WALL_CONTACT_TOLERANCE


func _frame_alpha_bounds(region: Rect2) -> Rect2:
	var cache_key: String = "%s:%d:%d:%d:%d" % [
		character_id,
		int(region.position.x),
		int(region.position.y),
		int(region.size.x),
		int(region.size.y),
	]
	if _frame_alpha_bounds_cache.has(cache_key):
		return _frame_alpha_bounds_cache[cache_key] as Rect2

	var texture: Texture2D = ANIMATION_DATA.texture_for(_animation_state, character_id)
	var image_key: String = texture.resource_path
	var image: Image
	if _animation_image_cache.has(image_key):
		image = _animation_image_cache[image_key] as Image
	else:
		image = texture.get_image()
		_animation_image_cache[image_key] = image

	var min_x: int = int(region.size.x)
	var min_y: int = int(region.size.y)
	var max_x: int = -1
	var max_y: int = -1
	var source_left: int = int(region.position.x)
	var source_top: int = int(region.position.y)
	for pixel_y: int in range(int(region.size.y)):
		for pixel_x: int in range(int(region.size.x)):
			if image.get_pixel(source_left + pixel_x, source_top + pixel_y).a < FRAME_ALPHA_THRESHOLD:
				continue
			min_x = mini(min_x, pixel_x)
			min_y = mini(min_y, pixel_y)
			max_x = maxi(max_x, pixel_x)
			max_y = maxi(max_y, pixel_y)

	var bounds: Rect2 = Rect2(Vector2.ZERO, region.size)
	if max_x >= min_x and max_y >= min_y:
		bounds = Rect2(
			Vector2(float(min_x), float(min_y)),
			Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1))
		)
	_frame_alpha_bounds_cache[cache_key] = bounds
	return bounds


## 상황: 캐릭터가 서로 독립적으로 재생할 SFX channel을 준비할 때 호출된다.
## 순서: AudioStreamPlayer 생성 → SFX bus 지정 → 캐릭터 자식으로 소유권 연결.
## 결과: scene free 시 함께 정리되는 player 참조를 반환한다.
func _create_sfx_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new() # 캐릭터가 수명을 소유할 새 node.
	player.bus = &"SFX"
	add_child(player)
	return player


## 상황: 점프·피격·펀치처럼 직전 효과음을 교체해도 되는 단발음을 재생할 때 호출된다.
## 결과: 주 SFX player의 stream을 교체하고 즉시 처음부터 재생한다.
func _play_sfx(stream: AudioStream) -> void:
	_sfx_player.stream = stream
	_sfx_player.play()


## 상황: 줄 삭제처럼 주 효과음과 겹쳐야 하는 보조 cue를 재생할 때 호출된다.
## 결과: 별도 cue player를 사용하므로 `_play_sfx()` 재생을 끊지 않는다.
func _play_sfx_cue(stream: AudioStream) -> void:
	_sfx_cue_player.stream = stream
	_sfx_cue_player.play()


## 상황: GameController의 lines_cleared signal을 받았을 때 호출되는 adapter다.
## 결과: 줄 삭제 전용 stream을 보조 cue channel에서 재생한다.
func _play_block_elimination_sfx() -> void:
	_play_sfx_cue(SFX_BLOCK_ELIMINATION)


## 상황: 명상 시작 원샷 뒤 지속음을 반복 재생해야 할 때 호출된다.
## 결과: 명상 loop stream을 전용 player에 지정하고 재생한다.
func _start_meditation_loop() -> void:
	_meditation_loop_player.stream = SFX_MEDITATION_LOOP
	_meditation_loop_player.play()


## 상황: 명상 해제·피해·pause로 지속음을 즉시 끊어야 할 때 호출된다.
## 결과: stream 참조는 유지하고 재생 cursor만 정지한다.
func _stop_meditation_loop() -> void:
	_meditation_loop_player.stop()


## 상황: pause 해제 후 실제 상태가 아직 명상이면 loop를 다시 이어갈 때 호출된다.
## 결과: `is_meditating`이 true인 경우에만 전용 player를 재생한다.
func _restart_meditation_loop() -> void:
	if is_meditating:
		_meditation_loop_player.play()


## 상황: 캐릭터 최초 준비 또는 GameController.reset_game()의 restart signal에서 호출한다.
## 순서: 공개 stats/모든 timer·flag 초기화 → 시작 position/velocity
##       → sprite transform/color/visibility → 첫 animation frame → 두 signal.
## 결과: 이전 게임의 hang body, 무적, animation이 남지 않는 새 캐릭터가 된다.
func _reset_character() -> void:
	if _meditation_loop_player:
		_stop_meditation_loop()
	_cancel_character_skill_effects()
	lives = get_max_lives()
	stamina = MAX_STAMINA
	facing = 1
	is_hanging = false
	_hang_body = null
	_clear_hang_vertical_bounds()
	is_meditating = false
	is_bound = false
	binding_timer = 0.0
	controller.set_meditation_active(false)
	rotation_cooldown_remaining = 0.0
	special_cooldown_remaining = 0.0
	_invulnerability_remaining = 0.0
	_spin_remaining = 0.0
	_spin_elapsed = 0.0
	_spin_direction = 1
	_pending_rotation_launch_velocity = 0.0
	_post_spin_animation_seeded = false
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_hang_regrab_remaining = 0.0
	_hang_jump_grace_remaining = 0.0
	_hang_jump_facing = 1
	_hang_animation_direction = 0.0
	_hang_corner_climb_active = false
	_hang_corner_climb_start_global = Vector2.ZERO
	_hang_corner_climb_target_global = Vector2.ZERO
	_hang_corner_climb_progress = 0.0
	_hang_corner_climb_duration = 0.0
	_wall_jump_control_remaining = 0.0
	_wall_jump_wall_facing = 1
	_variable_jump_active = false
	_attack_cooldown_remaining = 0.0
	_attack_animation_remaining = 0.0
	_special_animation_remaining = 0.0
	_sprint_remaining = 0.0
	_pending_punch_stage = 0
	_pending_punch_hit_remaining = 0.0
	_animation_state = ANIMATION_DATA.IDLE
	_animation_time = 0.0
	_respawn_airborne_pending = false
	_was_grounded_for_stamina = true
	_reset_self_respawn_input()
	position = Vector2(
		MainLayout.BOARD_SIZE.x * 0.5,
		MainLayout.BOARD_SIZE.y - CHARACTER_HEIGHT * 0.5
	)
	velocity = Vector2.ZERO
	sprite.flip_h = false
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	sprite.visible = true
	_apply_animation_frame()
	_sync_saintess_aura()
	stats_changed.emit()
