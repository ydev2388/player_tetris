class_name MainCharacterController
extends CharacterBody2D

## [역할 / C++ 대응]
## 플레이어 캐릭터의 물리, 입력, 스태미나, 공격, 매달리기, 피해, 애니메이션을
## 한 physics-frame 상태 기계로 묶은 컨트롤러다. CharacterBody2D의 `velocity`,
## `move_and_slide()`, `is_on_floor()`를 사용하므로 C++의 kinematic character와 비슷하다.
##
## [호출 관계]
## Godot: `_ready()`, 고정 timestep마다 `_physics_process(delta)`.
## GameController.game_restarted signal: `_reset_character()`.
## BoardPhysics: 보드 충돌체 갱신 뒤 `validate_position()`.
## GameView: 공개 stats/getter를 읽고 `stats_changed`/`feedback_changed`를 구독.
## 호출 대상: GameController(명상 속도, 피스 밀기/회전, 게임 종료),
##           BoardModel/TetrominoData(공간 판정), AnimationData, Input.
##
## GDScript 핵심: 들여쓰기가 C++의 `{}` 블록을 대신하고, `var x: Type`은 지역/멤버 변수,
## `func f(a: T) -> R`은 함수 시그니처, `and/or/not`은 `&&/||/!`에 해당한다.

signal stats_changed # 생명/stamina/charge/cooldown 변경을 GameView에 알린다.
signal feedback_changed # feedback_text 변경/만료를 GameView에 알린다.

# 좌표/이동 상수. Godot 2D는 +x가 오른쪽, +y가 아래이므로 점프 속도는 음수다.
# GIT_GRID_SCALE은 원본 28px 기준 수치를 현재 48px 셀에 맞추는 배율이다.
const CELL_SIZE: float = MainLayout.CELL_SIZE # 보드 한 셀의 표시·물리 크기.
const GIT_GRID_SCALE: float = CELL_SIZE / 28.0 # 원본 28px 물리값을 48px 보드로 환산하는 배율.
const CHARACTER_HEIGHT: float = CELL_SIZE * 2.0 # 논리 피해 판정 높이: 2셀.
const CHARACTER_COLLIDER_WIDTH: float = 28.0 * MainLayout.DISPLAY_SCALE
const CHARACTER_COLLIDER_HEIGHT: float = 60.0 * MainLayout.DISPLAY_SCALE
const CHARACTER_COLLIDER_OFFSET_Y: float = 2.0 * MainLayout.DISPLAY_SCALE
const RESPAWN_TOP_MARGIN_CELLS: int = 1 # 피격 재스폰 시 캐릭터 윗면과 화면 위의 간격.
const RESPAWN_CENTER_Y: float = ( # 윗면 48px + 논리 몸체 반높이 48px.
	RESPAWN_TOP_MARGIN_CELLS * CELL_SIZE + CHARACTER_HEIGHT * 0.5
)
const RESPAWN_BODY_SIZE: Vector2 = Vector2( # 프레임과 무관한 재스폰 점유 영역.
	28.0 * MainLayout.DISPLAY_SCALE,
	64.0 * MainLayout.DISPLAY_SCALE
)
const MAX_LIVES: int = 3 # 게임 시작 시 생명 상한.
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
const HANG_REGRAB_COOLDOWN: float = 0.18 # 벽점프 직후 같은 벽 재매달림 금지 초.
const HANG_JUMP_GRACE_TIME: float = 0.15 # grab을 놓은 뒤에도 벽점프 가능한 초.
const WALL_JUMP_STEER_TIME: float = 0.65 # 벽점프 뒤 원래 벽 방향 공중 조향 보정 초.
const WALL_JUMP_STEER_ACCELERATION: float = 1500.0 * MainLayout.DISPLAY_SCALE

# 자원과 행동 비용/지속시간. 이름의 단위가 없으면 픽셀 또는 초당 값이다.
const MAX_STAMINA: float = 100.0 # stamina 상한과 reset 값.
const HANG_STAMINA_DRAIN: float = MAX_STAMINA / 3.0 # 매달림 초당 소모량: 가득 차면 3초.
const ROTATION_COOLDOWN: float = 2.0 # 성공 회전 킥 재사용 대기시간(초).
const ROTATION_FAILED_COOLDOWN: float = 1.0 # 대상 없음/공간 부족 회전 킥 대기시간(초).
const ROTATION_SPIN_DURATION: float = 0.42 # 전용 8 frame과 한 바퀴 회전의 전체 시간.
const SELF_RESPAWN_HOLD_SECONDS: float = 1.0 # 자력 재스폰을 확정하기 위한 연속 입력 시간.
const POST_SPIN_APEX_SPEED: float = 40.0 * MainLayout.DISPLAY_SCALE # 종료 후 jump frame 경계.
const INVULNERABILITY_SECONDS: float = 1.2 # 피해 직후 추가 피해를 무시하는 초.
const ATTACK_COOLDOWN: float = 0.48 # 새 펀치 sequence 시작 간격(초).
const ATTACK_ANIMATION_DURATION: float = 0.4 # 공격 animation 우선 표시 초.
const PUNCH_HIT_CONFIRM_SECONDS: float = 0.1 # X release 뒤 주먹 판정을 유지하는 시간.

# Script 리소스는 C++의 namespace/static utility class를 참조하는 핸들과 비슷하다.
const ANIMATION_DATA: Script = preload("res://scripts/character_animation_data.gd") # frame 데이터.
const SFX_HURT: AudioStream = preload("res://assets/sfx/01_player_hurt.wav")
const SFX_PUNCH: AudioStream = preload("res://assets/sfx/02_block_punch.wav")
const SFX_FLIP: AudioStream = preload("res://assets/sfx/03a_block_flip.wav")
const SFX_JUMP: AudioStream = preload("res://assets/sfx/04_jump.wav")
const SFX_MEDITATION_START: AudioStream = preload("res://assets/sfx/05a_meditation_start.wav")
const SFX_MEDITATION_LOOP: AudioStream = preload("res://assets/sfx/05b_meditation_loop.wav")
const SFX_MEDITATION_END: AudioStream = preload("res://assets/sfx/05c_meditation_end.wav")
const SFX_CHARGE_START: AudioStream = preload("res://assets/sfx/06a_charge_start.wav")
const SFX_CHARGE_LOOP: AudioStream = preload("res://assets/sfx/06b_charge_loop.wav")
const SFX_CHARGE_TIER1: AudioStream = preload("res://assets/sfx/06c_charge_tier1.wav")
const SFX_CHARGE_READY: AudioStream = preload("res://assets/sfx/06d_charge_ready.wav")
const SFX_CHARGE_RELEASE: AudioStream = preload("res://assets/sfx/06e_charge_release.wav")
const SFX_BLOCK_ELIMINATION: AudioStream = preload("res://assets/sfx/07_block_elimination.wav")
const SFX_WALL_CLIMB: AudioStream = preload("res://assets/sfx/09_wall_climb.wav")

# 0.4초/0.9초 hold 뒤 release하면 각각 2칸/3칸 차지 펀치를 실행한다.
const PUNCH_STAGE_TIMES: Array[float] = [0.0, 0.4, 0.9] # charge 단계별 hold 임계 초.
const PUNCH_TOTAL_COSTS: Array[float] = [0.0, 8.0, 18.0] # 단계별 누적 비용 조회표.
const PUNCH_MAX_HOLD_TIME: float = 0.9 # charge_time이 증가할 수 있는 상한(초).
const PUNCH_HITBOX_WIDTH: float = 27.2 # 주먹 스프라이트 끝에서 5px 더 넓힌 전방 판정 길이(px).
const CRUSH_ALPHA_THRESHOLD: float = 128.0 / 255.0 # 반투명 외곽을 제외할 알파 경계.
const CRUSH_CORE_SIZE: Vector2 = Vector2(
	28.0 * MainLayout.DISPLAY_SCALE,
	64.0 * MainLayout.DISPLAY_SCALE
)
const FIXED_SUPPORT_TOLERANCE: float = MainLayout.DISPLAY_SCALE

# main.tscn의 상대 경로로 찾은 협력 객체. `@onready`라 `_ready()` 전에 유효해진다.
@onready var controller: MainGameController = $"../../GameController" # 피스/게임 상태 명령 대상.
@onready var sprite: Sprite2D = $Sprite # animation/flip/회전/색/깜빡임 대상.
@onready var left_ray: RayCast2D = $LeftRay # 왼쪽 매달릴 collision 탐지기.
@onready var right_ray: RayCast2D = $RightRay # 오른쪽 매달릴 collision 탐지기.

var _sfx_player: AudioStreamPlayer
var _sfx_cue_player: AudioStreamPlayer
var _meditation_loop_player: AudioStreamPlayer
var _charge_loop_player: AudioStreamPlayer

# GameView/테스트가 읽는 공개 상태.
var lives: int = MAX_LIVES # 남은 피격 허용 횟수. 0이면 controller.end_game().
var stamina: float = MAX_STAMINA # 행동 자원 0~100. 매달림에 사용.
var facing: int = 1 # 바라보는 방향: 왼쪽 -1, 오른쪽 +1.
var is_hanging: bool = false # true면 일반 이동 대신 벽 추적/상하 이동 branch를 실행.
var is_meditating: bool = false # true면 정지·회복하고 Controller 테트리스 시간을 2배로 함.
var charge_time: float = 0.0 # 현재 X hold 경과시간. release/reset 때 0.
var rotation_cooldown_remaining: float = 0.0 # 0보다 크면 회전 킥 입력 거부; 매 frame 감소.
var feedback_text: String = "" # GameView가 표시할 최근 행동 결과. 1.4초 후 지워진다.

# 이 클래스 내부의 상태 기계용 변수. `_`는 C++의 private와 같은 강제 접근 제한은
# 아니지만 외부에서 사용하지 말라는 GDScript 관례다.
var _charging: bool = false # X를 누른 뒤 release 전이며 punch 단계를 진행 중인지.
var _invulnerability_remaining: float = 0.0 # 0보다 크면 take_damage를 무시하고 깜빡임.
var _feedback_remaining: float = 0.0 # 0이 되면 feedback_text를 지우는 countdown(초).
var _spin_remaining: float = 0.0 # 회전 킥 sprite 회전을 계속할 countdown(초).
var _spin_elapsed: float = 0.0 # 현재 회전 킥에서 소비한 시간(0~0.42초).
var _spin_direction: int = 1 # 회전 시작 때 고정한 방향; 도중 facing 변경과 무관.
var _pending_rotation_launch_velocity: float = 0.0 # 새 active collider 동기화 다음 frame에 적용할 y속도.
var _post_spin_animation_seeded: bool = false # 종료 frame seed를 한 번 보존할 flag.
var _hang_body: Node2D # 매달린 실제 collider. 활성 피스면 움직임을 따라간다.
var _hang_last_global_position: Vector2 # 붙은 body의 이전 frame 위치; 이동 delta 계산용.
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
var _pending_punch_stage: int = 0 # 0이면 없음, 1~3이면 판정 대기 중인 펀치 거리.
var _pending_punch_hit_remaining: float = 0.0 # release 뒤 남은 주먹 판정 시간.
var _ignore_initial_jump_until_released: bool = false # 메뉴 Z로 게임을 열었을 때 첫 점프를 막는다.
var _charge_audio_started: bool = false # 차지 임계 도달 뒤 차지 사운드가 시작됐는지.
var _animation_state: String = ANIMATION_DATA.IDLE # 현재 sprite frame table key.
var _animation_time: float = 0.0 # 현재 animation_state에 머문 경과시간(초).
var _respawn_airborne_pending: bool = false # 순간이동 직후 이전 바닥 접지 cache를 한 번 무시.
var _was_grounded_for_stamina: bool = true # 비접지→접지 전환에서만 stamina를 완충하기 위한 이전 상태.
var _self_respawn_hold_time: float = 0.0 # Q 또는 사용자 지정 키를 연속으로 누른 시간.
var _self_respawn_requires_release: bool = false # 발동 뒤 같은 hold의 연속 생명 차감을 막는다.
var _crush_mask_cache: Dictionary = {} # 상태/프레임별 화면 픽셀 몸통 마스크.
var _animation_image_cache: Dictionary = {} # texture path별 CPU alpha 판정용 Image.
var _respawn_random: RandomNumberGenerator = RandomNumberGenerator.new() # 캐릭터 X 전용 난수열.


## 상황: CharacterBody2D가 씬에 준비될 때 Godot가 한 번 호출한다.
## 순서: pause 중에도 처리되도록 mode 설정 → SFX player 준비
##       → controller.game_restarted에 `_reset_character()` 연결 → 즉시 reset.
## 결과: 첫 physics frame 전에 노드 참조와 모든 캐릭터 상태가 준비된다.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ignore_initial_jump_until_released = Input.is_action_pressed(&"character_jump")
	_sfx_player = _create_sfx_player()
	_sfx_cue_player = _create_sfx_player()
	_meditation_loop_player = _create_sfx_player()
	_charge_loop_player = _create_sfx_player()
	_meditation_loop_player.finished.connect(_restart_meditation_loop)
	_charge_loop_player.finished.connect(_restart_charge_loop)
	_respawn_random.randomize()
	controller.game_restarted.connect(_reset_character)
	controller.active_piece_descended.connect(handle_active_piece_descended)
	controller.lines_cleared.connect(_play_block_elimination_sfx)
	_reset_character()


## 상황: Godot의 고정 physics timestep마다 호출되는 캐릭터 최상위 상태 기계다.
## 순서: 비PLAYING 조기 정지 → timers 감소 → 기존/신규 명상 branch
##       → charge 처리 → hanging 또는 normal movement → 공통 시각/위치 검증.
## 결과: 한 frame에 서로 배타적인 이동 상태 하나만 실행되고 모든 후처리는 공통 적용된다.
func _physics_process(delta: float) -> void:
	if controller.state != MainGameController.GameState.PLAYING:
		_stop_for_inactive_game()
		return
	_update_timers(delta)
	if _handle_self_respawn_input(delta):
		_finish_physics_frame(delta)
		return

	if is_meditating:
		_handle_meditation(delta)
		_finish_physics_frame(delta)
		return
	if _can_start_meditating():
		_set_meditating(true)
		_handle_meditation(delta)
		_finish_physics_frame(delta)
		return

	_handle_charge(delta)
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
	velocity = Vector2.ZERO
	_pending_punch_stage = 0
	_pending_punch_hit_remaining = 0.0
	if not Input.is_action_pressed(&"character_self_respawn"):
		_reset_self_respawn_input()


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
## 순서: meditate hold, 접지, 비매달림, 비charging 네 조건을 AND 평가한다.
## 결과: 모든 조건이 참일 때만 true이며 상태 자체는 변경하지 않는다.
func _can_start_meditating() -> bool:
	return (
		Input.is_action_pressed(&"character_meditate")
		and is_on_floor()
		and not is_hanging
		and not _charging
	)


## 상황: 명상/매달림/일반 이동 중 하나가 끝난 모든 활성 physics frame에서 호출한다.
## 순서: `_update_visual_state(delta)` → `validate_position()`.
## 결과: gameplay 상태에 맞는 sprite가 적용되고 새 블록 겹침/추락 피해가 처리된다.
func _finish_physics_frame(delta: float) -> void:
	_resolve_pending_punch(delta)
	_update_visual_state(delta)
	validate_position()


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
	var target_horizontal_speed: float = horizontal_input * MOVE_SPEED # 입력축 기반 목표 x속도.
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
## 순서: 회전/점프의 just_pressed 값을 `_dispatch_action_input()`에 전달.
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
		jump_pressed
	)


## 상황: 실입력 또는 테스트가 동시에 들어온 행동들의 우선순위를 결정할 때 호출한다.
## 순서: 회전 있으면 jump 취소/회전 후 return → 그 외에만 `_handle_jump_input()`.
## 결과: 한 frame에 회전 킥 또는 점프 중 하나만 시작된다.
func _dispatch_action_input(
	rotation_kick_pressed: bool,
	jump_pressed: bool
) -> void:
	if rotation_kick_pressed:
		_cancel_jump_intent()
		_attempt_rotation_kick()
		return

	_handle_jump_input(jump_pressed)


## 상황: 회전 킥이 점프보다 우선되어 기존 점프 의도를 폐기해야 할 때 호출한다.
## 순서: jump buffer → hang grace → variable jump flag → wall-jump control 순서로 초기화.
## 결과: 같은 frame 또는 직전 frame의 점프 상태가 회전 킥과 중복 실행되지 않는다.
func _cancel_jump_intent() -> void:
	_jump_buffer_remaining = 0.0
	_hang_jump_grace_remaining = 0.0
	_variable_jump_active = false
	_cancel_wall_jump_control()


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
	velocity.y = JUMP_VELOCITY
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
	_follow_hang_body()
	if not is_hanging:
		return
	if _has_fixed_support_underfoot():
		_exit_hang()
		return
	if not _move_while_hanging():
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
	if is_instance_valid(_hang_body):
		var body_delta: Vector2 = _hang_body.global_position - _hang_last_global_position # body의 frame 이동량.
		# ponytail: 2칸 초과 상향 이동은 다음 피스 스폰으로 간주한다; 큰 SRS kick이 필요하면 교체 signal로 바꾼다.
		if body_delta.y < -CELL_SIZE * 2.0:
			_exit_hang()
			return
		global_position += body_delta
		_hang_last_global_position = _hang_body.global_position


## 상황: 붙은 body를 따라간 뒤 사용자의 위/아래 매달림 이동을 적용할 때 호출한다.
## 순서: 방향 조회 → velocity 설정 → 무입력이면 true → move_and_slide
##       → 양 RayCast 강제 갱신 → 붙은 쪽 충돌 확인 → 접촉 없으면 hang 해제/false.
## 결과: 벽을 따라 이동하되 끝을 벗어난 순간 일반 공중 상태로 전환된다.
func _move_while_hanging() -> bool:
	var climb_direction: float = _hang_climb_direction() # 위 -1, 정지 0, 아래 +1.
	velocity = Vector2(0.0, climb_direction * HANG_CLIMB_SPEED)
	if is_zero_approx(climb_direction):
		return true

	move_and_slide()
	left_ray.force_raycast_update()
	right_ray.force_raycast_update()
	var still_touching_wall: bool = ( # 최초 매달린 벽 방향 RayCast의 최신 충돌 상태.
		left_ray.is_colliding() if _hang_jump_facing < 0 else right_ray.is_colliding()
	)
	if still_touching_wall:
		return true
	_exit_hang()
	return false


## 상황: 매달린 상태에서 수직 입력을 속도 부호로 바꿀 때 호출한다.
## 순서: 0에서 시작 → 물리 위키면 -1 → meditate(아래) action이면 +1을 더함.
## 결과: 위/아래 동시 입력은 0, 위=-1, 아래=+1을 반환한다.
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
	stamina = maxf(0.0, stamina - HANG_STAMINA_DRAIN * delta)
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
		JUMP_VELOCITY * WALL_JUMP_VERTICAL_MULTIPLIER
	)
	_set_feedback("벽 점프")


## 상황: 명상이 아닌 모든 physics frame에서 X 펀치 hold 상태를 갱신할 때 호출한다.
## 순서: just_pressed면 sequence 시작 → hold 중에는 charge_time만 누적
##       → release 때 일반 또는 차지 펀치를 한 번 실행한다.
## 결과: 짧은 탭은 일반 펀치, 0.4/0.9초 hold는 각각 2칸/3칸 차지 펀치가 된다.
func _handle_charge(delta: float) -> void:
	if Input.is_action_just_pressed(&"character_punch"):
		_start_punch_sequence()

	if _charging and Input.is_action_pressed(&"character_punch"):
		charge_time = minf(PUNCH_MAX_HOLD_TIME, charge_time + delta)
		if charge_time >= PUNCH_STAGE_TIMES[1]:
			_start_charge_audio()
		stats_changed.emit()
	elif _charging:
		if charge_time < PUNCH_STAGE_TIMES[1]:
			_perform_tap_punch()
		else:
			_perform_charge_punch(push_distance_for_charge(charge_time))
		_release_charge_punch()


## 상황: X가 새로 눌렸을 때 새 연속 펀치를 시작할 수 있는지 처리한다.
## 순서: attack cooldown>0이면 종료 → charging=true → 시간/stage 초기화
##       → 차지 사운드 상태 초기화.
## 결과: 쿨다운 중 입력은 무시되고, release 전까지 일반/차지 동작을 유보한다.
func _start_punch_sequence() -> void:
	if _attack_cooldown_remaining > 0.0:
		return
	_charging = true
	charge_time = 0.0
	_charge_audio_started = false


## 상황: X를 짧게 눌렀다 놓았을 때 일반 펀치를 실행한다.
## 결과: 공격 animation을 표시하고 0.1초 주먹 판정 중 맞은 활성 블록을 1칸 민다.
func _perform_tap_punch() -> void:
	_start_attack_animation()
	_attack_cooldown_remaining = ATTACK_COOLDOWN
	_play_sfx(SFX_PUNCH)
	_begin_punch_hit_confirmation(1)
	stats_changed.emit()


func _start_attack_animation() -> void:
	_attack_animation_remaining = ATTACK_ANIMATION_DURATION
	_animation_state = ANIMATION_DATA.ATTACK
	_animation_time = 0.0


## 상황: charging 중 X가 더 이상 눌리지 않은 첫 frame에 호출한다.
## 순서: charging=false → charge_time=0 → stats signal.
## 결과: 현재 stage 표시가 0으로 돌아가고 다음 cooldown 이후 새 sequence가 가능하다.
func _release_charge_punch() -> void:
	_stop_charge_loop(_charge_audio_started)
	_charging = false
	charge_time = 0.0
	_charge_audio_started = false
	stats_changed.emit()


## 상황: X release 때 hold 시간에 맞는 차지 펀치를 실행할 때 호출한다.
## 순서: 비용 검사 → attack 시작 → 0.1초 주먹 판정을 예약한다.
## 결과: 판정 중 블록을 맞춘 경우에만 2칸 또는 3칸을 한 번에 민다.
func _perform_charge_punch(target_stage: int) -> void:
	var stamina_cost: float = PUNCH_TOTAL_COSTS[target_stage - 1]
	if stamina < stamina_cost:
		_set_feedback("스태미나 부족")
		return
	_start_attack_animation()
	_attack_cooldown_remaining = ATTACK_COOLDOWN
	_play_sfx(SFX_PUNCH)
	_begin_punch_hit_confirmation(target_stage)
	stats_changed.emit()


func _begin_punch_hit_confirmation(target_stage: int) -> void:
	_pending_punch_stage = target_stage
	_pending_punch_hit_remaining = PUNCH_HIT_CONFIRM_SECONDS


func _resolve_pending_punch(delta: float) -> void:
	if _pending_punch_stage == 0:
		return

	var target_stage: int = _pending_punch_stage
	if _punch_hits_active_piece():
		_pending_punch_stage = 0
		_pending_punch_hit_remaining = 0.0
		if controller.push_active_piece(facing, target_stage):
			if target_stage == 1:
				_set_feedback("펀치: 1칸")
			else:
				stamina -= PUNCH_TOTAL_COSTS[target_stage - 1]
				if target_stage == 2:
					_play_sfx_cue(SFX_CHARGE_TIER1)
				else:
					_play_sfx_cue(SFX_CHARGE_READY)
				_set_feedback("차지 펀치: %d칸" % target_stage)
		else:
			_set_feedback("이동 경로가 막힘")
		stats_changed.emit()
		return

	_pending_punch_hit_remaining = maxf(0.0, _pending_punch_hit_remaining - delta)
	if _pending_punch_hit_remaining <= 0.0:
		_pending_punch_stage = 0
		_set_feedback("일반 펀치" if target_stage == 1 else "공격이 빗나감")


## 상황: 명상처럼 펀치와 배타적인 상태에 진입할 때 호출한다.
## 순서: charging이 아니면 종료 → charging/time 초기화 → stats signal.
## 결과: 이미 성공한 피스 이동은 유지하고 아직 진행 중인 hold 상태만 취소한다.
func _cancel_punch_sequence() -> void:
	if not _charging:
		return
	_stop_charge_loop(_charge_audio_started)
	_charging = false
	charge_time = 0.0
	_charge_audio_started = false
	stats_changed.emit()


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
		_cancel_punch_sequence()
		_pending_rotation_launch_velocity = 0.0
		_jump_buffer_remaining = 0.0
		_hang_jump_grace_remaining = 0.0
		_variable_jump_active = false
		_cancel_wall_jump_control()
		velocity.x = 0.0
		_set_feedback("명상 ×2")
	else:
		_stop_meditation_loop()
		if controller.state == MainGameController.GameState.PLAYING:
			_play_sfx(SFX_MEDITATION_END)
			_set_feedback("명상 종료")
	stats_changed.emit()


## 상황: S 블록 플립이 action 우선순위에서 선택됐을 때 호출한다.
## 순서: cooldown → spin 시작 → 활성 피스 88px 근접 검사
##       → 가까우면 실제 물리 몸체 점유 셀을 계산해 Controller.try_rotate(facing, 금지 셀)
##       → 성공/공간 부족/대상 없음별 y속도/cooldown/feedback → signal.
## 결과: 스태미나를 쓰지 않으며 대상이 없어도 한 바퀴 동작과 짧은 cooldown이 적용된다.
func _attempt_rotation_kick() -> void:
	if rotation_cooldown_remaining > 0.0:
		_set_feedback("회전 킥 재사용 대기 중")
		return

	_start_rotation_spin()
	if not _is_near_active_piece(0.0, MainLayout.scaled(88.0)):
		_pending_rotation_launch_velocity = 0.0
		_set_feedback("활성 블록에 닿지 않음")
		velocity.y = MainLayout.scaled(-120.0)
		rotation_cooldown_remaining = ROTATION_FAILED_COOLDOWN
		stats_changed.emit()
		return

	if controller.try_rotate(facing, _rotation_forbidden_cells()):
		_play_sfx(SFX_FLIP)
		# game_changed로 새 active shape를 만든 같은 physics frame에는 아직 PhysicsServer에
		# 반영되지 않을 수 있다. 이번 frame 수직 이동을 멈추고 다음 frame에 발사한다.
		velocity.y = 0.0
		_pending_rotation_launch_velocity = MainLayout.scaled(-260.0)
		rotation_cooldown_remaining = ROTATION_COOLDOWN
		_set_feedback("공중 회전 킥 성공")
	else:
		_pending_rotation_launch_velocity = 0.0
		velocity.y = MainLayout.scaled(-140.0)
		rotation_cooldown_remaining = ROTATION_FAILED_COOLDOWN
		_set_feedback("회전 공간 부족")
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


## 상황: 회전 킥의 SRS 후보가 현재 캐릭터 물리 몸체를 덮지 않게 금지 셀이 필요할 때 호출한다.
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


## 상황: 지연된 회전 킥 발사 경로가 새 활성 피스와 겹치는지 확인할 때 호출한다.
## 결과: 활성 네 셀 중 하나라도 대상 Rect와 양의 면적으로 교차하면 true다.
func _active_piece_overlaps_rect(target_rect: Rect2) -> bool:
	for local_cell: Vector2i in MainTetrominoData.get_cells(
		controller.active_type,
		controller.active_rotation
	):
		if _rects_overlap_with_area(
			target_rect,
			_board_cell_rect(controller.active_origin + local_cell)
		):
			return true
	return false


## 상황: 성공/실패와 무관하게 실제 회전 킥 동작을 시작할 때 호출한다.
## 순서: 전체/경과 timer 초기화 → 현재 facing을 방향 snapshot으로 저장 → 각도 정자세.
## 결과: 이후 방향 입력이 바뀌어도 0.42초 동안 시작 방향으로 한 바퀴를 완주한다.
func _start_rotation_spin() -> void:
	_spin_remaining = ROTATION_SPIN_DURATION
	_spin_elapsed = 0.0
	_spin_direction = -1 if facing < 0 else 1
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

	var ray: RayCast2D # 우선순위 검사 끝에 실제 매달릴 충돌을 감지한 RayCast.
	if facing < 0 and left_ray.is_colliding():
		ray = left_ray
	elif facing > 0 and right_ray.is_colliding():
		ray = right_ray
	elif left_ray.is_colliding():
		ray = left_ray
		facing = -1
	elif right_ray.is_colliding():
		ray = right_ray
		facing = 1
	else:
		return

	var collider: Object = ray.get_collider() # 벽 또는 활성 피스일 수 있는 런타임 객체.
	if collider is Node2D and stamina > 0.0:
		var returned_from_wall_jump: bool = _wall_jump_control_remaining > 0.0 # 직전 벽으로 복귀했는지.
		is_hanging = true
		_hang_body = collider as Node2D
		_hang_last_global_position = _hang_body.global_position
		_hang_jump_facing = facing
		_hang_jump_grace_remaining = 0.0
		_pending_rotation_launch_velocity = 0.0
		_cancel_wall_jump_control()
		velocity = Vector2.ZERO
		_play_sfx(SFX_WALL_CLIMB)
		_set_feedback("벽 점프 재매달리기" if returned_from_wall_jump else "매달리기")


## 상황: grab 해제, stamina 소진, 벽 끝, 벽점프 또는 피해로 hang을 끝낼 때 호출한다.
## 순서: is_hanging=false → `_hang_body=null`.
## 결과: 다음 physics frame은 일반 이동 branch를 실행하고 body를 더 이상 추적하지 않는다.
func _exit_hang() -> void:
	is_hanging = false
	_hang_body = null


## 상황: 접지하거나 다른 배타 행동이 시작되어 벽점프 특수 조향을 끝낼 때 호출한다.
## 순서: `_wall_jump_control_remaining=0` 한 단계다.
## 결과: 이후 수평 이동은 일반 지상/공중 acceleration만 사용한다.
func _cancel_wall_jump_control() -> void:
	_wall_jump_control_remaining = 0.0


## 상황: GameController가 자연 중력으로 활성 피스를 정확히 한 칸 내린 직후 호출한다.
## 순서: 실제 한 칸 하강 검증 → 현재 애니메이션 알파 마스크와 활성 셀 교집합
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
	if not _crush_mask_overlaps_active_piece(current_origin):
		return

	if _has_fixed_support_underfoot():
		take_damage()


## 상황: 자연 낙하한 네 블록 중 하나가 현재 캐릭터 몸통 픽셀에 닿는지 판정한다.
## 순서: 현재 프레임의 캐시된 불투명 픽셀 → flip/rotation 변환 → 네 셀 Rect 포함 검사.
## 결과: 알파 128 이상이면서 중앙 28×64px 안인 실제 표시 픽셀이 닿을 때만 true다.
func _crush_mask_overlaps_active_piece(origin: Vector2i) -> bool:
	var active_rects: Array[Rect2] = []
	for local_cell: Vector2i in MainTetrominoData.get_cells(
		controller.active_type,
		controller.active_rotation
	):
		active_rects.append(_board_cell_rect(origin + local_cell))

	for mask_point: Vector2 in _current_crush_mask_points():
		var displayed_point: Vector2 = mask_point
		if sprite.flip_h:
			displayed_point.x = -displayed_point.x
		displayed_point = displayed_point.rotated(sprite.rotation)
		var board_point: Vector2 = position + sprite.position + displayed_point
		for active_rect: Rect2 in active_rects:
			if active_rect.has_point(board_point):
				return true
	return false


## 상황: 현재 애니메이션 프레임의 압사 몸통 마스크가 필요할 때 호출한다.
## 순서: 상태/region key 캐시 조회 → 화면 중앙 28×64 각 픽셀을 source region으로 역매핑
##       → 원본 alpha가 128 이상인 화면 픽셀 중심만 저장.
## 결과: 투명 여백과 뻗은 팔다리가 빠진 정확한 화면 픽셀 좌표 목록을 반환한다.
func _current_crush_mask_points() -> Array[Vector2]:
	var region: Rect2 = ANIMATION_DATA.region_for(_animation_state, _animation_time)
	var cache_key: String = "%s:%d:%d:%d:%d" % [
		_animation_state,
		int(region.position.x),
		int(region.position.y),
		int(region.size.x),
		int(region.size.y),
	]
	if _crush_mask_cache.has(cache_key):
		return _crush_mask_cache[cache_key] as Array[Vector2]

	var texture: Texture2D = ANIMATION_DATA.texture_for(_animation_state)
	var image_key: String = texture.resource_path
	var image: Image
	if _animation_image_cache.has(image_key):
		image = _animation_image_cache[image_key] as Image
	else:
		image = texture.get_image()
		_animation_image_cache[image_key] = image

	var target_size: Vector2 = _animation_target_size(_animation_state)
	var points: Array[Vector2] = []
	var half_core: Vector2 = CRUSH_CORE_SIZE * 0.5
	for pixel_y: int in range(int(-half_core.y), int(half_core.y)):
		for pixel_x: int in range(int(-half_core.x), int(half_core.x)):
			var display_point: Vector2 = Vector2(
				float(pixel_x) + 0.5,
				float(pixel_y) + 0.5
			)
			var normalized: Vector2 = (display_point + target_size * 0.5) / target_size
			if (
				normalized.x < 0.0
				or normalized.x >= 1.0
				or normalized.y < 0.0
				or normalized.y >= 1.0
			):
				continue
			var source_pixel: Vector2i = Vector2i(
				int(floor(region.position.x + normalized.x * region.size.x)),
				int(floor(region.position.y + normalized.y * region.size.y))
			)
			if image.get_pixelv(source_pixel).a >= CRUSH_ALPHA_THRESHOLD:
				points.append(display_point)

	_crush_mask_cache[cache_key] = points
	return points


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

	var foot_left: float = position.x - CRUSH_CORE_SIZE.x * 0.5
	var foot_right: float = position.x + CRUSH_CORE_SIZE.x * 0.5
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
## 순서: 정상 플레이/보드 내부면 종료 → 보드 아래면 안전 위치 검색 및 무피해 복귀.
## 결과: 일반 블록 겹침이나 낙사는 목숨을 깎지 않고 압착 전용 경로만 피해를 준다.
func validate_position() -> void:
	if controller.state != MainGameController.GameState.PLAYING:
		return
	if not _is_below_board():
		return

	var safe_position: Variant = _find_safe_position()
	if safe_position == null:
		controller.end_game()
		return
	position = safe_position as Vector2
	velocity = Vector2.ZERO
	_set_feedback("보드 이탈: 안전 위치 복귀")


## 상황: 위치 검증 첫 단계에서 낙사 기준을 확인할 때 호출한다.
## 순서: position.y와 `VISIBLE_HEIGHT*CELL_SIZE+80`을 비교한다.
## 결과: 캐릭터 중심이 보드 바닥보다 80px 아래면 true다.
func _is_below_board() -> bool:
	return (
		position.y
		> MainBoardModel.VISIBLE_HEIGHT * CELL_SIZE + MainLayout.scaled(80.0)
	)


## 상황: 자연 낙하 블록과 고정 지지면 사이의 직접 압착을 발견했을 때 호출한다.
## 순서: 무적이면 종료 → 생명-1/무적 설정 → 명상/hang/jump/charge/속도 해제
##       → feedback → 생명 0이면 end_game/return → 안전 위치 탐색 → 없으면 end_game,
##       있으면 상단 한 칸 아래의 무작위 안전 열로 이동 → stats signal.
## 결과: 같은 압착에서 연속 피해를 막고 살아 있으면 블록과 겹치지 않게 상단에서 재시작한다.
func take_damage() -> void:
	if _invulnerability_remaining > 0.0:
		return
	_lose_life_and_respawn("압착 피해! 목숨 -1")


## 상황: 압착 또는 자력 재스폰이 실제 생명 하나를 소비하기로 확정했을 때 호출한다.
## 순서: 생명/무적 갱신 → 모든 행동과 시각 회전 취소 → 게임오버 또는 상단 안전 재스폰.
## 결과: 두 진입점이 같은 정리·재스폰 규칙을 사용하며 자력 재스폰은 호출 전에 무적을 우회한다.
func _lose_life_and_respawn(feedback_message: String) -> void:
	lives -= 1
	_invulnerability_remaining = INVULNERABILITY_SECONDS
	_set_meditating(false)
	_play_sfx(SFX_HURT)
	_exit_hang()
	_hang_jump_grace_remaining = 0.0
	_hang_regrab_remaining = 0.0
	_cancel_wall_jump_control()
	_cancel_jump_intent()
	_charging = false
	_stop_charge_loop()
	charge_time = 0.0
	_attack_animation_remaining = 0.0
	_pending_punch_stage = 0
	_pending_punch_hit_remaining = 0.0
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
	_set_feedback(feedback_message)

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


## 상황: GameView/테스트가 현재 연속 펀치 단계를 표시·검증할 때 호출한다.
## 순서: charging이 아니면 0 조기 반환, 맞으면 현재 hold 시간의 단계를 계산한다.
## 결과: 외부에서 내부 flag를 직접 읽지 않고 0~3 단계를 얻는다.
func charge_level() -> int:
	if not _charging:
		return 0
	return push_distance_for_charge(charge_time)


## 상황: charge bar와 sprite glow가 펀치 hold 진행률을 요구할 때 호출한다.
## 순서: charging이면 charge_time/0.9를 0~1 clamp, 아니면 0.
## 결과: UI에 바로 쓸 수 있는 정규화 float를 반환한다.
func charge_ratio() -> float:
	return clampf(charge_time / 0.9, 0.0, 1.0) if _charging else 0.0


## 상황: GameView가 회전 킥 cooldown bar를 계산할 때 호출한다.
## 순서: 남은 초/전체 2초 → 0~1 clamp.
## 결과: 1은 방금 사용, 0은 즉시 사용 가능을 의미한다.
func rotation_cooldown_ratio() -> float:
	return clampf(rotation_cooldown_remaining / ROTATION_COOLDOWN, 0.0, 1.0)


## 상황: 테스트/비용 helper가 임의 hold 초의 이론적 펀치 단계를 구할 때 호출한다.
## 순서: stage index 1부터 임계시간과 비교 → seconds가 작아지는 첫 index 반환
##       → 모든 임계 이상이면 전체 stage 수 3 반환.
## 결과: runtime 상태와 무관한 1~3 정수 단계를 반환한다.
static func push_distance_for_charge(seconds: float) -> int:
	for stage_index: int in range(1, PUNCH_STAGE_TIMES.size()):
		if seconds < PUNCH_STAGE_TIMES[stage_index]:
			return stage_index
	return PUNCH_STAGE_TIMES.size()


## 상황: 펀치가 활성 블록을 실제로 때렸는지 확인할 때 호출한다.
## 순서: 몸 바로 앞의 좁은 주먹 Rect를 만들고 활성 피스 셀과 양의 면적 교차를 검사한다.
## 결과: 블록이 멀리 있으면 false이며, 몸에 닿은 전방 블록만 true다.
func _punch_hits_active_piece() -> bool:
	return _active_piece_overlaps_rect(_punch_hitbox_rect())


func _punch_hitbox_rect() -> Rect2:
	var body_rect: Rect2 = _character_collider_rect()
	var fist_x: float = (
		body_rect.end.x if facing > 0 else body_rect.position.x - PUNCH_HITBOX_WIDTH
	)
	return Rect2(
		Vector2(fist_x, body_rect.position.y),
		Vector2(PUNCH_HITBOX_WIDTH, body_rect.size.y)
	)


## 상황: rotation kick이 활성 피스와 충분히 가까운지 검사할 때 호출한다.
## 순서: 활성 네 셀 중심 계산 → difference=cell-character
##       → horizontal_reach=0이면 원형 거리, 아니면 같은 방향/x reach/y reach 검사.
## 결과: 셀 하나라도 범위 안이면 true이며 피스/캐릭터 상태는 바꾸지 않는다.
func _is_near_active_piece(horizontal_reach: float, radial_reach: float) -> bool:
	for local_cell: Vector2i in MainTetrominoData.get_cells(
		controller.active_type,
		controller.active_rotation
	):
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

	for local_cell: Vector2i in MainTetrominoData.get_cells(
		controller.active_type,
		controller.active_rotation
	):
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
	for local_cell: Vector2i in MainTetrominoData.get_cells(
		controller.active_type,
		controller.active_rotation
	):
		if controller.active_origin + local_cell == cell:
			return true
	return false


## 상황: 고정/활성 셀과 캐릭터 Rect의 교집합을 계산하기 전에 호출한다.
## 순서: x×CELL_SIZE와 `(y-HIDDEN_ROWS)×CELL_SIZE`로 좌상단 계산 → 32×32 Rect.
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
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_attack_animation_remaining = maxf(0.0, _attack_animation_remaining - delta)
	_invulnerability_remaining = maxf(0.0, _invulnerability_remaining - delta)
	_feedback_remaining = maxf(0.0, _feedback_remaining - delta)
	_coyote_remaining = maxf(0.0, _coyote_remaining - delta)
	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)
	_hang_regrab_remaining = maxf(0.0, _hang_regrab_remaining - delta)
	_hang_jump_grace_remaining = maxf(0.0, _hang_jump_grace_remaining - delta)
	_wall_jump_control_remaining = maxf(0.0, _wall_jump_control_remaining - delta)
	if _feedback_remaining <= 0.0 and not feedback_text.is_empty():
		feedback_text = ""
		feedback_changed.emit()


## 상황: gameplay 처리가 끝난 활성 physics frame마다 sprite를 최신 상태로 만들 때 호출한다.
## 순서: 회전 킥 spin → 명상/charge 색 → 피해 blink → frame animation.
## 결과: 서로 다른 시각 효과가 고정된 순서로 합성된다.
func _update_visual_state(delta: float) -> void:
	_update_spin_visual(delta)
	_update_sprite_modulation()
	_update_damage_blink()
	_advance_character_animation(delta)


## 상황: 회전 킥 spin timer 중 또는 끝난 뒤 sprite 각도를 갱신할 때 호출한다.
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


## 상황: 한 바퀴 완료 후 회전 킥 전용 상태에서 실제 이동 상태 animation으로 돌아갈 때 호출한다.
## 순서: 접지면 idle 0 → 공중이면 y속도를 ±40과 비교해 jump 4/5/6 frame 시간 선택.
## 결과: 공중에서 준비 자세로 재시작하지 않고 상승·정점·하강에 맞는 pose로 바로 이어진다.
func _seed_post_spin_animation() -> void:
	if is_on_floor():
		_animation_state = ANIMATION_DATA.IDLE
		_animation_time = 0.0
	else:
		var jump_frame_index: int
		if velocity.y < -POST_SPIN_APEX_SPEED:
			jump_frame_index = 4
		elif velocity.y > POST_SPIN_APEX_SPEED:
			jump_frame_index = 6
		else:
			jump_frame_index = 5
		_animation_state = ANIMATION_DATA.JUMP
		_animation_time = (
			float(jump_frame_index)
			* float(ANIMATION_DATA.FRAME_DURATIONS[ANIMATION_DATA.JUMP])
		)
	_post_spin_animation_seeded = true


## 상황: 현재 명상 또는 punch charge 상태를 색으로 표시할 때 호출한다.
## 순서: 명상이면 시간 pulse/청색 modulation → 아니면 charge_ratio/주황 glow.
## 결과: sprite.modulate가 두 상태 중 현재 우선 상태를 반영한다.
func _update_sprite_modulation() -> void:
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
		var charge_glow: float = charge_ratio() # 0~1 punch hold 진행률.
		sprite.modulate = Color(
			1.0,
			1.0 - charge_glow * 0.15,
			1.0 - charge_glow * 0.35,
			1.0
		)


## 상황: 피해 무적시간을 캐릭터 깜빡임으로 표현할 때 호출한다.
## 순서: 무적 timer>0이면 `int(timer*12)%2`로 visible 토글 → 아니면 true.
## 결과: 무적 중에만 깜빡이고 종료 frame에는 반드시 다시 보인다.
func _update_damage_blink() -> void:
	if _invulnerability_remaining > 0.0:
		sprite.visible = int(_invulnerability_remaining * 12.0) % 2 == 0
	else:
		sprite.visible = true


## 상황: gameplay 상태에서 현재 animation state/frame을 결정할 때 호출한다.
## 순서: 회전 종료 seed면 해당 frame 즉시 적용 → 목표 상태 조회 → 회전 킥이면 elapsed 동기화
##       → 일반 상태는 이전과 다르면 time=0, 같으면 time+=delta → frame 적용.
## 결과: 회전 킥은 정확히 8 frame을 사용하고 종료 seed가 jump 0 frame으로 덮이지 않는다.
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
	else:
		_animation_time += delta
	_apply_animation_frame()


## 상황: 겹칠 수 있는 gameplay flag 중 표시할 animation 하나를 고를 때 호출한다.
## 순서: 회전 킥 → attack timer → hanging → 비접지 jump → idle 순 조기 반환.
## 결과: `rotation kick > attack > hang > jump > idle` 우선순위 key를 반환한다.
func _get_animation_state() -> String:
	if _spin_remaining > 0.0:
		return ANIMATION_DATA.ROTATION_KICK
	if _attack_animation_remaining > 0.0:
		return ANIMATION_DATA.ATTACK
	if is_hanging:
		return ANIMATION_DATA.HANG
	if not is_on_floor():
		return ANIMATION_DATA.JUMP
	return ANIMATION_DATA.IDLE


## 상황: animation 시간/state가 정해진 뒤 실제 Sprite2D frame을 적용할 때 호출한다.
## 순서: sprite 유효성 → region 조회 → 기본 target size → attack 너비 확대
##       → texture/region/scale/position 대입.
## 결과: 원본 frame 크기가 달라도 게임 안에서는 일정한 캐릭터 높이로 보인다.
func _apply_animation_frame() -> void:
	if not is_instance_valid(sprite):
		return
	var region: Rect2 = ANIMATION_DATA.region_for(_animation_state, _animation_time) # source frame.
	var target_size: Vector2 = _animation_target_size(_animation_state) # 목표 화면 크기.
	sprite.texture = ANIMATION_DATA.texture_for(_animation_state)
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.scale = target_size / region.size
	sprite.position = Vector2.ZERO


## 상황: sprite 표시와 픽셀 마스크 역매핑이 같은 화면 크기를 사용해야 할 때 호출한다.
## 결과: 공격은 57.6×64px, 그 외 상태는 40×64px 크기를 반환한다.
func _animation_target_size(animation_state: String) -> Vector2:
	if animation_state == ANIMATION_DATA.ROTATION_KICK:
		return Vector2.ONE * CHARACTER_HEIGHT
	if animation_state == ANIMATION_DATA.ATTACK:
		return Vector2(CELL_SIZE * 1.8, CHARACTER_HEIGHT)
	return Vector2(CELL_SIZE * 1.25, CHARACTER_HEIGHT)


## 상황: 행동 성공/실패를 사용자에게 짧게 알려야 할 때 호출한다.
## 순서: text 대입 → 표시 timer=1.4초 → feedback_changed emit.
## 결과: View가 즉시 표시하고 `_update_timers()`가 나중에 자동 삭제한다.
func _set_feedback(message: String) -> void:
	feedback_text = message
	_feedback_remaining = 1.4
	feedback_changed.emit()


func _create_sfx_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = &"SFX"
	add_child(player)
	return player


func _play_sfx(stream: AudioStream) -> void:
	_sfx_player.stream = stream
	_sfx_player.play()


func _play_sfx_cue(stream: AudioStream) -> void:
	_sfx_cue_player.stream = stream
	_sfx_cue_player.play()


func _play_block_elimination_sfx() -> void:
	_play_sfx_cue(SFX_BLOCK_ELIMINATION)


func _start_meditation_loop() -> void:
	_meditation_loop_player.stream = SFX_MEDITATION_LOOP
	_meditation_loop_player.play()


func _stop_meditation_loop() -> void:
	_meditation_loop_player.stop()


func _restart_meditation_loop() -> void:
	if is_meditating:
		_meditation_loop_player.play()


func _start_charge_loop() -> void:
	_charge_loop_player.stream = SFX_CHARGE_LOOP
	_charge_loop_player.play()


func _start_charge_audio() -> void:
	if _charge_audio_started:
		return
	_charge_audio_started = true
	_play_sfx(SFX_CHARGE_START)
	_start_charge_loop()


func _stop_charge_loop(play_release: bool = false) -> void:
	_charge_loop_player.stop()
	if play_release:
		_play_sfx(SFX_CHARGE_RELEASE)


func _restart_charge_loop() -> void:
	if _charging:
		_charge_loop_player.play()


## 상황: 캐릭터 최초 준비 또는 GameController.reset_game()의 restart signal에서 호출한다.
## 순서: 공개 stats/모든 timer·flag 초기화 → 시작 position/velocity
##       → sprite transform/color/visibility → 첫 animation frame → 두 signal.
## 결과: 이전 게임의 hang body, charge, 무적, animation이 남지 않는 새 캐릭터가 된다.
func _reset_character() -> void:
	if _meditation_loop_player:
		_stop_meditation_loop()
		_stop_charge_loop()
	lives = MAX_LIVES
	stamina = MAX_STAMINA
	facing = 1
	is_hanging = false
	is_meditating = false
	controller.set_meditation_active(false)
	charge_time = 0.0
	rotation_cooldown_remaining = 0.0
	feedback_text = ""
	_charging = false
	_charge_audio_started = false
	_invulnerability_remaining = 0.0
	_feedback_remaining = 0.0
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
	_wall_jump_control_remaining = 0.0
	_wall_jump_wall_facing = 1
	_variable_jump_active = false
	_attack_cooldown_remaining = 0.0
	_attack_animation_remaining = 0.0
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
	stats_changed.emit()
	feedback_changed.emit()
