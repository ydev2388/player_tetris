class_name Stage4CharacterController
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
# GIT_GRID_SCALE은 원본 28px 기준 수치를 현재 32px 셀에 맞추는 배율이다.
const CELL_SIZE: float = 32.0 # 보드 한 셀의 픽셀 크기.
const GIT_GRID_SCALE: float = CELL_SIZE / 28.0 # 원본 28px 물리값을 32px 보드로 환산하는 배율.
const CHARACTER_WIDTH: float = CELL_SIZE # 논리 피해 판정 너비: 1셀.
const CHARACTER_HEIGHT: float = CELL_SIZE * 2.0 # 논리 피해 판정 높이: 2셀.
const MAX_LIVES: int = 3 # 게임 시작 시 생명 상한.
const MOVE_SPEED: float = 150.0 * GIT_GRID_SCALE # 수평 목표 최고속도(px/s).
const GROUND_ACCELERATION: float = 1800.0 * GIT_GRID_SCALE # 지상 가속도(px/s²).
const GROUND_DECELERATION: float = 1800.0 * GIT_GRID_SCALE # 지상 무입력 감속도(px/s²).
const AIR_ACCELERATION: float = 1800.0 * GIT_GRID_SCALE # 공중 가속도(px/s²).
const AIR_DECELERATION: float = 1800.0 * GIT_GRID_SCALE # 공중 무입력 감속도(px/s²).
const JUMP_VELOCITY: float = -350.0 * GIT_GRID_SCALE # 점프 시작 y속도. 위쪽이 음수다.
const GRAVITY: float = 1000.0 * GIT_GRID_SCALE # 매초 y속도에 더할 중력(px/s²).
const FALL_GRAVITY_MULTIPLIER: float = 1.0 # 하강 중 추가 중력 배율.
const MAX_FALL_SPEED: float = 3200.0 # 비정상적으로 큰 낙하를 막는 y속도 상한(px/s).
const COYOTE_TIME: float = 0.12 # 발판을 떠난 뒤에도 지상점프를 허용하는 초.
const JUMP_BUFFER_TIME: float = 0.12 # 착지 전에 누른 점프를 기억하는 초.
const JUMP_RELEASE_MULTIPLIER: float = 0.45 # 상승 중 키를 놓을 때 y속도에 곱하는 값.
const WALL_JUMP_HORIZONTAL_SPEED: float = 185.0 * GIT_GRID_SCALE # 벽 반대 x속도(px/s).
const WALL_JUMP_VERTICAL_MULTIPLIER: float = 1.0 # 벽점프의 JUMP_VELOCITY 배율.
const HANG_CLIMB_SPEED: float = 78.0 * GIT_GRID_SCALE # 매달린 상하 이동속도(px/s).
const HANG_REGRAB_COOLDOWN: float = 0.18 # 벽점프 직후 같은 벽 재매달림 금지 초.
const HANG_JUMP_GRACE_TIME: float = 0.15 # grab을 놓은 뒤에도 벽점프 가능한 초.
const WALL_JUMP_STEER_TIME: float = 0.65 # 벽점프 뒤 원래 벽 방향 공중 조향 보정 초.
const WALL_JUMP_STEER_ACCELERATION: float = 1500.0 # 위 조향 시 사용할 가속도(px/s²).

# 자원과 행동 비용/지속시간. 이름의 단위가 없으면 픽셀 또는 초당 값이다.
const MAX_STAMINA: float = 100.0 # stamina 상한과 reset 값.
const GROUND_STAMINA_REGEN: float = 24.0 # 지상 초당 회복량.
const AIR_STAMINA_REGEN: float = 10.0 # 공중 초당 회복량.
const HANG_STAMINA_DRAIN: float = MAX_STAMINA / 3.0 # 매달림 초당 소모량: 가득 차면 3초.
const PULL_STAMINA_COST: float = 10.0 # 성공한 블록 당기기 1회의 비용.
const PULL_RANGE: float = CELL_SIZE * 4.0 # 당기기 radial 최대 거리(px).
const ROTATION_STAMINA_COST: float = 25.0 # 회전 킥 시도 비용.
const ROTATION_COOLDOWN: float = 2.0 # 성공 회전 킥 재사용 대기시간(초).
const INVULNERABILITY_SECONDS: float = 1.2 # 피해 직후 추가 피해를 무시하는 초.
const ATTACK_COOLDOWN: float = 0.48 # 새 펀치 sequence 시작 간격(초).
const ATTACK_ANIMATION_DURATION: float = 0.4 # 공격 animation 우선 표시 초.
const PULL_ANIMATION_DURATION: float = 0.64 # 당기기 animation 우선 표시 초.

# Script 리소스는 C++의 namespace/static utility class를 참조하는 핸들과 비슷하다.
const INPUT_ACTIONS: Script = preload("res://scripts/input_actions.gd") # InputMap 기본값 유틸.
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

# 기존 공개 상수는 유지하고 실제 데이터만 전용 모듈에서 관리한다.
const PLAYER_ANIMATIONS: Texture2D = ANIMATION_DATA.IDLE_TEXTURE # 외부/테스트 호환용 idle 별칭.
const PLAYER_HANG_ANIMATIONS: Texture2D = ANIMATION_DATA.HANG_TEXTURE # hang texture 별칭.
const PLAYER_ATTACK_ANIMATIONS: Texture2D = ANIMATION_DATA.ATTACK_TEXTURE # attack texture 별칭.
const PLAYER_JUMP_ANIMATIONS: Texture2D = ANIMATION_DATA.JUMP_TEXTURE # jump texture 별칭.
const PLAYER_ANIMATION_REGIONS: Dictionary = ANIMATION_DATA.REGIONS # frame rect 표 별칭.
const PLAYER_ANIMATION_FRAME_DURATIONS: Dictionary = ANIMATION_DATA.FRAME_DURATIONS # 시간 표 별칭.

# 단계 1은 즉시 1칸, 0.4초/0.9초를 넘으면 추가 비용을 내고 한 칸씩 더 민다.
const PUNCH_STAGE_TIMES: Array[float] = [0.0, 0.4, 0.9] # 각 1칸 밀기를 시도하는 hold 임계 초.
const PUNCH_STAGE_COSTS: Array[float] = [0.0, 8.0, 10.0] # 각 단계 진입 시 추가 비용.
const PUNCH_TOTAL_COSTS: Array[float] = [0.0, 8.0, 18.0] # 단계별 누적 비용 조회표.
const PUNCH_BASE_REACH: float = 72.0 # 1단계 전방 최대 x 거리(px).
const PUNCH_MAX_HOLD_TIME: float = 0.9 # charge_time이 증가할 수 있는 상한(초).

# main.tscn의 상대 경로로 찾은 협력 객체. `@onready`라 `_ready()` 전에 유효해진다.
@onready var controller: Stage4GameController = $"../../GameController" # 피스/게임 상태 명령 대상.
@onready var sprite: Sprite2D = $Sprite # animation/flip/회전/색/깜빡임 대상.
@onready var left_ray: RayCast2D = $LeftRay # 왼쪽 매달릴 collision 탐지기.
@onready var right_ray: RayCast2D = $RightRay # 오른쪽 매달릴 collision 탐지기.

var _sfx_player: AudioStreamPlayer
var _sfx_cue_player: AudioStreamPlayer
var _meditation_loop_player: AudioStreamPlayer
var _charge_loop_player: AudioStreamPlayer

# GameView/테스트가 읽는 공개 상태.
var lives: int = MAX_LIVES # 남은 피격 허용 횟수. 0이면 controller.end_game().
var stamina: float = MAX_STAMINA # 행동 자원 0~100. 매달림/당기기/회전에 사용.
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
var _pull_animation_remaining: float = 0.0 # 0보다 크면 PULL animation 표시.
var _punch_stage: int = 0 # 이번 charge에서 성공한 밀기 횟수 0~3.
var _punch_blocked: bool = false # 한 단계 실패 후 같은 hold에서 이후 단계를 차단.
var _animation_state: String = ANIMATION_DATA.IDLE # 현재 sprite frame table key.
var _animation_time: float = 0.0 # 현재 animation_state에 머문 경과시간(초).


## 상황: CharacterBody2D가 씬에 준비될 때 Godot가 한 번 호출한다.
## 순서: pause 중에도 처리되도록 mode 설정 → 입력 기본값 보장
##       → controller.game_restarted에 `_reset_character()` 연결 → 즉시 reset.
## 결과: 첫 physics frame 전에 노드 참조와 모든 캐릭터 상태가 준비된다.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_player = _create_sfx_player()
	_sfx_cue_player = _create_sfx_player()
	_meditation_loop_player = _create_sfx_player()
	_charge_loop_player = _create_sfx_player()
	_meditation_loop_player.finished.connect(_restart_meditation_loop)
	_charge_loop_player.finished.connect(_restart_charge_loop)
	INPUT_ACTIONS.ensure_defaults()
	controller.game_restarted.connect(_reset_character)
	controller.lines_cleared.connect(_play_block_elimination_sfx)
	_reset_character()


## 상황: Godot의 고정 physics timestep마다 호출되는 캐릭터 최상위 상태 기계다.
## 순서: 비PLAYING 조기 정지 → timers 감소 → 기존/신규 명상 branch
##       → charge 처리 → hanging 또는 normal movement → 공통 시각/위치 검증.
## 결과: 한 frame에 서로 배타적인 이동 상태 하나만 실행되고 모든 후처리는 공통 적용된다.
func _physics_process(delta: float) -> void:
	if controller.state != Stage4GameController.GameState.PLAYING:
		_stop_for_inactive_game()
		return
	_update_timers(delta)

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
	_update_visual_state(delta)
	validate_position()


## 상황: 이미 명상 중이거나 이번 frame에 명상 조건을 만족했을 때 호출한다.
## 순서: 입력/매달림/접지 재검사 → 실패 시 명상 종료 → x 정지/중력/이동
##       → 이동 후 접지 재검사 → 지상 stamina 회복 → stats signal.
## 결과: 바닥을 따라 안정적으로 명상하며 stamina를 회복하고, 발판을 잃으면 즉시 종료한다.
func _handle_meditation(delta: float) -> void:
	if (
		not Input.is_action_pressed(&"character_meditate")
		or is_hanging
		or not is_on_floor()
	):
		_set_meditating(false)
		return

	velocity.x = 0.0
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	move_and_slide()
	if not is_on_floor():
		_set_meditating(false)
		return
	stamina = minf(MAX_STAMINA, stamina + GROUND_STAMINA_REGEN * delta)
	stats_changed.emit()


## 상황: PLAYING이고 명상/매달림이 아닌 일반 이동 frame에 호출한다.
## 순서: 수평 입력/접지 snapshot → facing/coyote → 수평속도 → 중력 → action
##       → 가변점프 → grab이면 hang 시도 → move_and_slide → stamina 회복 → signal.
## 결과: 입력이 실제 CharacterBody2D 이동과 행동으로 반영된다.
func _handle_movement(delta: float) -> void:
	var horizontal_input: float = Input.get_axis(&"character_left", &"character_right") # -1~+1 이동축.
	var grounded: bool = is_on_floor() # 이동 전 접지 snapshot.
	_update_facing(horizontal_input)
	_update_ground_contact(grounded)
	_apply_horizontal_movement(horizontal_input, grounded, delta)
	_apply_gravity(grounded, delta)
	_handle_action_input()
	_apply_variable_jump_cut()

	if Input.is_action_pressed(&"character_grab") and _hang_regrab_remaining <= 0.0:
		_try_start_hang()

	move_and_slide()
	_regenerate_stamina(delta)
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
## 순서: 회전/당기기/점프의 just_pressed 값을 같은 순서로 `_dispatch_action_input()`에 전달.
## 결과: 실제 우선순위 판단은 dispatcher 한곳에서 실행되어 테스트도 같은 경로를 사용할 수 있다.
func _handle_action_input() -> void:
	_dispatch_action_input(
		Input.is_action_just_pressed(&"character_rotation_kick"),
		Input.is_action_just_pressed(&"character_pull"),
		Input.is_action_just_pressed(&"character_jump")
	)


## 상황: 실입력 또는 테스트가 동시에 들어온 행동들의 우선순위를 결정할 때 호출한다.
## 순서: 회전 있으면 jump 취소/회전 후 return → 당기기 성공 시 buffer 제거/return
##       → 그 외에만 `_handle_jump_input()`.
## 결과: 한 frame에 회전 킥 > 성공한 당기기 > 점프 중 하나만 시작된다.
func _dispatch_action_input(
	rotation_kick_pressed: bool,
	pull_pressed: bool,
	jump_pressed: bool
) -> void:
	if rotation_kick_pressed:
		_cancel_jump_intent()
		_attempt_rotation_kick()
		return

	if pull_pressed and _attempt_pull_active_piece():
		_jump_buffer_remaining = 0.0
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


## 상황: 회전/당기기가 이번 frame을 소비하지 않았을 때 jump press를 처리한다.
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


## 상황: 일반 이동의 실제 `move_and_slide()`가 끝난 뒤 stamina를 회복할 때 호출한다.
## 순서: 현재 is_on_floor 재검사 → 지상이면 coyote 재충전/지상 회복
##       → 공중이면 공중 회복 → 둘 다 MAX_STAMINA로 제한.
## 결과: 이동 후 실제 접지 상태에 맞는 stamina가 계산된다.
func _regenerate_stamina(delta: float) -> void:
	if is_on_floor():
		_coyote_remaining = COYOTE_TIME
		stamina = minf(MAX_STAMINA, stamina + GROUND_STAMINA_REGEN * delta)
	else:
		stamina = minf(MAX_STAMINA, stamina + AIR_STAMINA_REGEN * delta)


## 상황: is_hanging=true인 physics frame의 전용 상태 처리로 호출한다.
## 순서: 종료조건 검사/조기 반환 → 붙은 body 이동 추적 → 상하 이동/접촉 재검사
##       → 성공적으로 계속 매달렸을 때 stamina/점프 마무리.
## 결과: 일반 중력/이동은 실행되지 않고 벽과 함께 움직이는 hang 상태가 유지 또는 종료된다.
func _handle_hanging(delta: float) -> void:
	if _handle_hang_exit_conditions():
		return
	_follow_hang_body()
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
## 순서: just_pressed면 sequence 시작 → charging+pressed면 charge_time 누적/단계 전진
##       → charging인데 release면 sequence 종료.
## 결과: 한 번 누르면 즉시 1단계, 오래 누르면 0.4/0.9초에 추가 단계가 시도된다.
func _handle_charge(delta: float) -> void:
	if Input.is_action_just_pressed(&"character_punch"):
		_start_punch_sequence()

	if _charging and Input.is_action_pressed(&"character_punch"):
		charge_time = minf(PUNCH_MAX_HOLD_TIME, charge_time + delta)
		_advance_punch_stages()
		stats_changed.emit()
	elif _charging:
		_release_charge_punch()


## 상황: X가 새로 눌렸을 때 새 연속 펀치를 시작할 수 있는지 처리한다.
## 순서: attack cooldown>0이면 종료 → charging=true → 시간/stage/block 초기화
##       → cooldown 설정 → `_advance_punch_stages()`로 시간 0의 1단계 즉시 시도.
## 결과: 쿨다운 중 입력은 무시되고, 가능하면 첫 1칸 펀치가 누른 frame에 실행된다.
func _start_punch_sequence() -> void:
	if _attack_cooldown_remaining > 0.0:
		return
	_charging = true
	charge_time = 0.0
	_punch_stage = 0
	_punch_blocked = false
	_attack_cooldown_remaining = ATTACK_COOLDOWN
	_play_sfx(SFX_CHARGE_START)
	_start_charge_loop()
	_advance_punch_stages()


## 상황: sequence 시작 또는 X hold 중 현재 시간까지 도달한 punch 단계를 반영할 때 호출한다.
## 순서: blocked=false, stage<3, charge_time>=다음 임계인 동안
##       → 목표 단계/추가 비용 계산 → `_attempt_incremental_punch()` → 실패 시 중단.
## 결과: 큰 delta가 여러 임계값을 넘어도 1→2→3 단계를 빠짐없이 순서대로 실행한다.
func _advance_punch_stages() -> void:
	# 큰 delta가 0.4초와 0.9초를 한 번에 지나도 각 단계를 순서대로 한 번씩 검증한다.
	while (
		not _punch_blocked
		and _punch_stage < PUNCH_STAGE_TIMES.size()
		and charge_time >= PUNCH_STAGE_TIMES[_punch_stage]
	):
		var next_stage: int = _punch_stage + 1 # 이번 while 반복에서 달성하려는 1~3 단계.
		var stamina_cost: float = PUNCH_STAGE_COSTS[_punch_stage] # 이번 추가 1칸의 비용.
		if not _attempt_incremental_punch(next_stage, stamina_cost):
			break


## 상황: charging 중 X가 더 이상 눌리지 않은 첫 frame에 호출한다.
## 순서: charging=false → charge_time=0 → blocked=false → stats signal.
## 결과: 현재 stage 표시가 0으로 돌아가고 다음 cooldown 이후 새 sequence가 가능하다.
func _release_charge_punch() -> void:
	_stop_charge_loop(true)
	_charging = false
	charge_time = 0.0
	_punch_blocked = false
	stats_changed.emit()


## 상황: hold 시간이 새 임계에 도달해 활성 피스를 추가 1칸 밀려 할 때 호출한다.
## 순서: stamina 검사 → 단계별 reach에서 근접 검사 → Controller 경로/이동 검사
##       → 성공 시 비용 차감/stage/attack animation/feedback/signal.
## 결과: 성공 true와 정확히 1칸 이동, 실패 false와 blocked=true로 같은 hold의 후속 시도를 막는다.
func _attempt_incremental_punch(target_stage: int, stamina_cost: float) -> bool:
	if stamina < stamina_cost:
		_punch_blocked = true
		_set_feedback("스태미나 부족")
		return false
	var stage_reach: float = PUNCH_BASE_REACH + float(target_stage - 1) * CELL_SIZE # 단계별 전방 x 도달거리.
	if not _is_near_active_piece(float(facing) * stage_reach, 74.0):
		_punch_blocked = true
		_set_feedback("활성 블록에 더 가까이")
		return false
	if not controller.push_active_piece(facing, 1):
		_punch_blocked = true
		_set_feedback("이동 경로가 막힘")
		return false

	stamina -= stamina_cost
	_play_sfx(SFX_PUNCH)
	if target_stage == 2:
		_play_sfx_cue(SFX_CHARGE_TIER1)
	elif target_stage == 3:
		_play_sfx_cue(SFX_CHARGE_READY)
	_punch_stage = target_stage
	_attack_animation_remaining = ATTACK_ANIMATION_DURATION
	_animation_state = ANIMATION_DATA.ATTACK
	_animation_time = 0.0
	_set_feedback("연속 펀치: %d칸" % target_stage)
	stats_changed.emit()
	return true


## 상황: 명상처럼 펀치와 배타적인 상태에 진입할 때 호출한다.
## 순서: charging이 아니면 종료 → charging/time/blocked 초기화 → stats signal.
## 결과: 이미 성공한 피스 이동은 유지하고 아직 진행 중인 hold 상태만 취소한다.
func _cancel_punch_sequence() -> void:
	if not _charging:
		return
	_stop_charge_loop(true)
	_charging = false
	charge_time = 0.0
	_punch_blocked = false
	stats_changed.emit()


## 상황: 명상 진입/종료, pause, 피해 또는 reset에서 명상 상태를 일관되게 바꿀 때 호출한다.
## 순서: 요청+PLAYING+접지+비매달림으로 next 계산 → 상태가 같으면 Controller만 동기화
##       → 변경 시 둘 다 저장 → 진입이면 펀치/점프/조향 취소·x정지, 종료면 feedback → signal.
## 결과: Character와 GameController의 명상 flag가 항상 일치한다.
func _set_meditating(active: bool) -> void:
	var next_state: bool = ( # 요청값에 실제 진입 전제조건을 적용한 최종 명상 상태.
		active
		and controller.state == Stage4GameController.GameState.PLAYING
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
		_jump_buffer_remaining = 0.0
		_hang_jump_grace_remaining = 0.0
		_variable_jump_active = false
		_cancel_wall_jump_control()
		velocity.x = 0.0
		_set_feedback("명상 ×2")
	else:
		_stop_meditation_loop()
		if controller.state == Stage4GameController.GameState.PLAYING:
			_play_sfx(SFX_MEDITATION_END)
			_set_feedback("명상 종료")
	stats_changed.emit()


## 상황: S 당기기가 action 우선순위에서 선택됐을 때 호출한다.
## 순서: 지상/상태 검사 → stamina → radial 거리 → 피스 중심과 캐릭터 x 차이
##       → 캐릭터 쪽 방향 계산 → Controller 1칸 이동 → 비용/animation/feedback/signal.
## 결과: 모든 조건과 경로가 유효할 때만 true와 1칸 이동, 실패는 비용 없이 false다.
func _attempt_pull_active_piece() -> bool:
	if (
		controller.state != Stage4GameController.GameState.PLAYING
		or not is_on_floor()
		or is_hanging
		or is_meditating
		or _charging
	):
		_set_feedback("지상에서만 블록 당기기 가능")
		return false
	if stamina < PULL_STAMINA_COST:
		_set_feedback("스태미나 부족")
		return false
	if not _is_near_active_piece(0.0, PULL_RANGE):
		_set_feedback("활성 블록이 너무 멀리 있음")
		return false

	var piece_center_x: float = _active_piece_center_x() # 활성 네 칸의 평균 픽셀 x.
	var horizontal_difference: float = position.x - piece_center_x # 양수면 캐릭터가 피스 오른쪽.
	if absf(horizontal_difference) < CELL_SIZE * 0.25:
		_set_feedback("같은 열의 블록은 당길 수 없음")
		return false
	var pull_direction: int = 1 if horizontal_difference > 0.0 else -1 # 피스가 캐릭터 쪽으로 갈 방향.
	if not controller.push_active_piece(pull_direction, 1):
		_set_feedback("당기는 경로가 막힘")
		return false

	stamina -= PULL_STAMINA_COST
	_pull_animation_remaining = PULL_ANIMATION_DURATION
	_animation_state = ANIMATION_DATA.PULL
	_animation_time = 0.0
	_set_feedback("블록 당기기: 1칸")
	stats_changed.emit()
	return true


## 상황: 당기기 방향을 정하기 위해 활성 피스의 수평 중심이 필요할 때 호출한다.
## 순서: 네 로컬 셀 조회 → 각 절대 셀 중심 x를 누적 → 셀 수로 나눔.
## 결과: BoardPhysics 로컬 좌표계의 평균 픽셀 x를 반환한다.
func _active_piece_center_x() -> float:
	var piece_cells: Array[Vector2i] = Stage4TetrominoData.get_cells( # 현재 회전의 네 로컬 셀.
		controller.active_type,
		controller.active_rotation
	)
	var center_x: float = 0.0 # 각 셀 중심 x의 합; 마지막에 평균으로 바뀐다.
	for local_cell: Vector2i in piece_cells:
		center_x += (
			float(controller.active_origin.x + local_cell.x) + 0.5
		) * CELL_SIZE
	return center_x / float(piece_cells.size())


## 상황: V 회전 킥이 action 우선순위에서 선택됐을 때 호출한다.
## 순서: cooldown → stamina → 활성 피스 88px 근접 검사 → 비용/spin 설정
##       → Controller.try_rotate(facing) → 성공/실패별 y속도/cooldown/feedback → signal.
## 결과: 시도 자체가 가능한 경우 비용을 내고 회전 성공 여부와 무관하게 점프/시각 반응이 난다.
func _attempt_rotation_kick() -> void:
	if rotation_cooldown_remaining > 0.0:
		_set_feedback("회전 킥 재사용 대기 중")
		return
	if stamina < ROTATION_STAMINA_COST:
		_set_feedback("스태미나 부족")
		return
	if not _is_near_active_piece(0.0, 88.0):
		_set_feedback("활성 블록에 닿지 않음")
		velocity.y = -120.0
		return

	stamina -= ROTATION_STAMINA_COST
	_spin_remaining = 0.35
	if controller.try_rotate(facing):
		_play_sfx(SFX_FLIP)
		velocity.y = -260.0
		rotation_cooldown_remaining = ROTATION_COOLDOWN
		_set_feedback("공중 회전 킥 성공")
	else:
		velocity.y = -140.0
		rotation_cooldown_remaining = ROTATION_COOLDOWN * 0.4
		_set_feedback("회전 공간 부족")
	stats_changed.emit()


## 상황: 일반 이동 중 C를 누르고 regrab cooldown이 0일 때 호출한다.
## 순서: cooldown 검사 → facing 쪽 Ray 우선, 반대쪽 fallback → collider 조회
##       → Node2D+stamina 검사 → hang/body/위치/벽방향 저장 → 조향 취소/정지/feedback.
## 결과: 유효한 벽을 찾을 때만 is_hanging=true가 되어 다음 frame부터 hang branch로 간다.
func _try_start_hang() -> void:
	if _hang_regrab_remaining > 0.0:
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
		_cancel_wall_jump_control()
		velocity = Vector2.ZERO
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


## 상황: 매 physics frame 끝과 BoardPhysics의 collision 동기화 직후 호출된다.
## 순서: PLAYING 검사 → 보드 아래면 damage/return → body Rect 계산
##       → 고정 또는 활성 블록과 겹치면 damage.
## 결과: 새 블록에 압착되거나 보드 밖으로 떨어진 상태가 한곳에서 피해로 변환된다.
func validate_position() -> void:
	if controller.state != Stage4GameController.GameState.PLAYING:
		return
	if _is_below_board():
		take_damage()
		return

	var body_rect: Rect2 = _character_body_rect() # 셀들과 교집합을 검사할 축소 피해 영역.
	if _overlaps_locked_block(body_rect) or _overlaps_active_piece(body_rect):
		take_damage()


## 상황: 위치 검증 첫 단계에서 낙사 기준을 확인할 때 호출한다.
## 순서: position.y와 `VISIBLE_HEIGHT*CELL_SIZE+80`을 비교한다.
## 결과: 캐릭터 중심이 보드 바닥보다 80px 아래면 true다.
func _is_below_board() -> bool:
	return position.y > Stage4BoardModel.VISIBLE_HEIGHT * CELL_SIZE + 80.0


## 상황: 블록 셀과의 압착 교집합을 검사하기 직전에 호출한다.
## 순서: 캐릭터 중심에서 절반 크기-2를 빼 좌상단 계산 → 전체 크기에서 4px 줄임.
## 결과: 물리 접촉만으로 오판하지 않도록 각 변이 2px 안쪽인 Rect2를 반환한다.
func _character_body_rect() -> Rect2:
	return Rect2(
		position - Vector2(CHARACTER_WIDTH * 0.5 - 2.0, CHARACTER_HEIGHT * 0.5 - 2.0),
		Vector2(CHARACTER_WIDTH - 4.0, CHARACTER_HEIGHT - 4.0)
	)


## 상황: 캐릭터 피해 Rect가 고정 BoardModel 셀과 겹치는지 확인할 때 호출한다.
## 순서: 전체 22×10 셀 순회 → EMPTY 건너뜀 → 셀 Rect 변환 → intersection.has_area.
## 결과: 첫 실제 면적 교집합에서 true, 끝까지 없으면 false다.
func _overlaps_locked_block(body_rect: Rect2) -> bool:
	for y: int in range(Stage4BoardModel.HEIGHT):
		for x: int in range(Stage4BoardModel.WIDTH):
			if controller.board.cells[y][x] == Stage4BoardModel.EMPTY:
				continue
			var solid_rect: Rect2 = _board_cell_rect(Vector2i(x, y)) # 현재 고정 셀의 픽셀 영역.
			if body_rect.intersection(solid_rect).has_area():
				return true
	return false


## 상황: 캐릭터 피해 Rect가 낙하 중 활성 피스와 겹치는지 확인할 때 호출한다.
## 순서: 현재 모양의 네 local cell 순회 → active_origin 합산 → 픽셀 Rect
##       → intersection.has_area에서 첫 겹침 true.
## 결과: 활성 피스를 BoardModel에 기록하지 않아도 정확히 압착을 감지한다.
func _overlaps_active_piece(body_rect: Rect2) -> bool:
	for local_cell: Vector2i in Stage4TetrominoData.get_cells(
		controller.active_type,
		controller.active_rotation
	):
		var solid_rect: Rect2 = _board_cell_rect(controller.active_origin + local_cell) # 활성 셀 영역.
		if body_rect.intersection(solid_rect).has_area():
			return true
	return false


## 상황: 추락/블록 겹침을 발견하거나 테스트가 피해를 직접 적용할 때 호출한다.
## 순서: 무적이면 종료 → 생명-1/무적 설정 → 명상/hang/jump/charge/속도 해제
##       → feedback → 생명 0이면 end_game/return → 안전 위치 탐색 → 없으면 end_game,
##       있으면 이동 → stats signal.
## 결과: 같은 압착에서 연속 피해를 막고 살아 있으면 가장 가까운 안전 발판으로 복귀한다.
func take_damage() -> void:
	if _invulnerability_remaining > 0.0:
		return
	lives -= 1
	_invulnerability_remaining = INVULNERABILITY_SECONDS
	_set_meditating(false)
	_play_sfx(SFX_HURT)
	_exit_hang()
	_hang_jump_grace_remaining = 0.0
	_cancel_wall_jump_control()
	_charging = false
	_stop_charge_loop()
	_punch_blocked = false
	velocity = Vector2.ZERO
	_set_feedback("압착 피해! 목숨 -1")

	if lives <= 0:
		controller.end_game()
		stats_changed.emit()
		return

	var safe_position: Variant = _find_safe_position() # Vector2 안전 위치 또는 공간 없음의 null.
	if safe_position == null:
		controller.end_game()
	else:
		position = safe_position as Vector2
	stats_changed.emit()


## 상황: GameView/테스트가 현재 연속 펀치 단계를 표시·검증할 때 호출한다.
## 순서: charging이 아니면 0 조기 반환, 맞으면 `_punch_stage` 반환.
## 결과: 외부에서 내부 flag를 직접 읽지 않고 0~3 단계를 얻는다.
func charge_level() -> int:
	if not _charging:
		return 0
	return _punch_stage


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


## 상황: 테스트나 설명 코드가 임의 hold 시간의 누적 비용을 요구할 때 호출한다.
## 순서: `push_distance_for_charge()` → 1-based 단계를 0-based index로 변환 → 표 조회.
## 결과: 0.0/8.0/18.0 중 하나를 반환한다.
static func stamina_cost_for_charge(seconds: float) -> float:
	return PUNCH_TOTAL_COSTS[push_distance_for_charge(seconds) - 1]


## 상황: punch/pull/rotation kick이 활성 피스와 충분히 가까운지 검사할 때 호출한다.
## 순서: 활성 네 셀 중심 계산 → difference=cell-character
##       → horizontal_reach=0이면 원형 거리, 아니면 같은 방향/x reach/y reach 검사.
## 결과: 셀 하나라도 범위 안이면 true이며 피스/캐릭터 상태는 바꾸지 않는다.
func _is_near_active_piece(horizontal_reach: float, radial_reach: float) -> bool:
	for local_cell: Vector2i in Stage4TetrominoData.get_cells(
		controller.active_type,
		controller.active_rotation
	):
		var cell: Vector2i = controller.active_origin + local_cell # 활성 절대 보드 셀.
		var cell_center: Vector2 = Vector2( # 숨은 행 offset을 뺀 셀 중심 픽셀.
			(float(cell.x) + 0.5) * CELL_SIZE,
			(float(cell.y - Stage4BoardModel.HIDDEN_ROWS) + 0.5) * CELL_SIZE
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
	for y: int in range(Stage4BoardModel.HEIGHT - 1, Stage4BoardModel.HIDDEN_ROWS, -1):
		for x: int in x_order:
			if _cell_is_solid(Vector2i(x, y)) or _cell_is_solid(Vector2i(x, y - 1)):
				continue
			var supported: bool = ( # 아래 셀이 바닥 또는 solid여서 설 수 있는지.
				y == Stage4BoardModel.HEIGHT - 1
				or _cell_is_solid(Vector2i(x, y + 1))
			)
			if supported:
				return Vector2(
					(float(x) + 0.5) * CELL_SIZE,
					float(y + 1 - Stage4BoardModel.HIDDEN_ROWS) * CELL_SIZE
					- CHARACTER_HEIGHT * 0.5
				)
	return null


## 상황: 안전 위치 후보의 몸/발판 셀이 점유됐는지 통합 확인할 때 호출한다.
## 순서: 범위 밖이면 false → 고정 셀이 차면 true → 활성 네 셀과 비교 → 기본 false.
## 결과: BoardModel과 활성 피스를 하나의 solid 판정처럼 제공한다.
func _cell_is_solid(cell: Vector2i) -> bool:
	if not controller.board.is_inside(cell):
		return false
	if controller.board.get_cell(cell) != Stage4BoardModel.EMPTY:
		return true
	for local_cell: Vector2i in Stage4TetrominoData.get_cells(
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
			(cell.y - Stage4BoardModel.HIDDEN_ROWS) * CELL_SIZE
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
	_pull_animation_remaining = maxf(0.0, _pull_animation_remaining - delta)
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
## 순서: timer>0이면 감소/TAU 비율만큼 facing 방향 회전
##       → 아니면 delta 기반 lerp로 rotation을 0에 접근.
## 결과: 0.35초 회전 후 갑자기 꺾이지 않고 정면으로 복귀한다.
func _update_spin_visual(delta: float) -> void:
	if _spin_remaining > 0.0:
		_spin_remaining = maxf(0.0, _spin_remaining - delta)
		sprite.rotation += TAU * delta / 0.35 * float(facing)
	else:
		sprite.rotation = lerpf(sprite.rotation, 0.0, minf(1.0, delta * 16.0))


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
## 순서: 목표 상태 조회 → 이전과 다르면 state 교체/time=0
##       → 같으면 time+=delta → `_apply_animation_frame()`.
## 결과: 상태 전환은 첫 frame부터, 같은 상태는 다음 frame으로 진행된다.
func _advance_character_animation(delta: float) -> void:
	var next_animation_state: String = _get_animation_state() # 이번 frame의 목표 상태 key.
	if next_animation_state != _animation_state:
		_animation_state = next_animation_state
		_animation_time = 0.0
	else:
		_animation_time += delta
	_apply_animation_frame()


## 상황: 겹칠 수 있는 gameplay flag 중 표시할 animation 하나를 고를 때 호출한다.
## 순서: attack timer → pull timer → hanging → 비접지 jump → idle 순 조기 반환.
## 결과: `attack > pull > hang > jump > idle` 우선순위의 상태 key를 반환한다.
func _get_animation_state() -> String:
	if _attack_animation_remaining > 0.0:
		return ANIMATION_DATA.ATTACK
	if _pull_animation_remaining > 0.0:
		return ANIMATION_DATA.PULL
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
	var target_size: Vector2 = Vector2(CELL_SIZE * 1.25, CHARACTER_HEIGHT) # 목표 화면 크기.
	if _animation_state == ANIMATION_DATA.ATTACK:
		target_size.x = CELL_SIZE * 1.8
	sprite.texture = ANIMATION_DATA.texture_for(_animation_state)
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.scale = target_size / region.size
	sprite.position = Vector2.ZERO


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
	_punch_stage = 0
	_punch_blocked = false
	_invulnerability_remaining = 0.0
	_feedback_remaining = 0.0
	_spin_remaining = 0.0
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
	_pull_animation_remaining = 0.0
	_animation_state = ANIMATION_DATA.IDLE
	_animation_time = 0.0
	position = Vector2(160.0, 608.0)
	velocity = Vector2.ZERO
	sprite.flip_h = false
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	sprite.visible = true
	_apply_animation_frame()
	stats_changed.emit()
	feedback_changed.emit()
