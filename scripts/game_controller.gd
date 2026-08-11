class_name MainGameController
extends Node

## [역할 / C++ 대응]
## 테트리스 규칙과 시간 진행의 중앙 오케스트레이터다. BoardModel과 PieceBag을 소유하고
## 활성/다음 피스, 줄 수, 게임 상태를 authoritative state로 유지한다.
##
## [호출 관계]
## Godot: `_ready()`, 매 프레임 `_process(delta)`.
## CharacterController: set_meditation_active(), push_active_piece(), try_rotate(), end_game().
## GameView/BoardPhysics/CharacterController: 상태를 읽고 signal을 구독한다.
## 호출 대상: BoardModel, PieceBag, TetrominoData, InputActions.
##
## `signal`은 C++ observer/event에 해당한다. `.emit()`하면 `.connect(callback)`으로
## 등록된 GameView/BoardPhysics/CharacterController 함수가 호출된다.

signal game_changed # 피스/상태 변경 후 View와 BoardPhysics에 동기화를 요구한다.
signal game_restarted # 전체 초기화 후 Character와 BoardPhysics에도 reset을 요구한다.
signal active_piece_descended(previous_origin: Vector2i, current_origin: Vector2i)
signal lines_cleared # 완성 행 제거 직후 SFX 등 피드백을 알린다.
signal stage_cleared(cleared_lines: int)
signal boss_attacked # 플레이어의 직접 공격에 보스가 가시로 반격할 때 알린다.

enum GameState {
	PLAYING,
	BOSS_FALLING,
	PAUSED,
	GAME_OVER,
}

const SHURIKEN_CONTACT_NONE: StringName = &"none"
const SHURIKEN_CONTACT_ACTIVE: StringName = &"active"
const SHURIKEN_CONTACT_FIXED: StringName = &"fixed"

# 게임 진행 규칙과 시간 상수.
const SPAWN_Y: int = 1 # 새 피스 원점의 숨은 보드 행 y.
const SPAWN_SIDE_MARGIN_CELLS: int = 1 # 우선 spawn에서 실제 점유 셀과 좌우 벽 사이에 비울 칸 수.
const LOCK_DELAY_SECONDS: float = 0.5 # 접지 후 고정까지 허용하는 게임 시간(초).
const MAX_LOCK_RESETS: int = 15 # 이동/회전으로 lock delay를 초기화할 수 있는 최대 횟수.
const MEDITATION_TIME_SCALE: float = 2.0 # 명상 시 기본 속도에 추가로 적용할 배율.
const GRAVITY_INTERVAL_SECONDS: float = 0.4666666666666667 # 셀당 고정 낙하 간격(초).
const SPAWN_RANDOM_SEED_OFFSET: int = 20839 # bag과 spawn-x 난수열을 분리하는 seed offset.
const GIMMICK_RANDOM_SEED_OFFSET: int = 39107 # 기믹 난수열을 기존 spawn 난수와 분리하는 seed offset.
const SURVIVAL_TIME_SECONDS: float = 90.0
const THORN_ON_SECONDS: float = 1.0
const THORN_OFF_SECONDS: float = 2.0
const BINDING_CHECK_INTERVAL_SECONDS: float = 10.0
const BINDING_PROBABILITY: float = 0.15
const BINDING_PROBABILITY_STEP: float = 0.05
const BINDING_DURATION_SECONDS: float = 2.0
const BOSS_BINDING_DURATION_SECONDS: float = 3.0
const BOSS_MAX_HEALTH: int = 3
const BOSS_POSITION: Vector2 = Vector2(240.0, 84.0)
const BOSS_DISPLAY_SIZE: Vector2 = Vector2(72.0, 192.0)
const BOSS_ATTACK_HITBOX_SIZE: Vector2 = Vector2(54.0, 132.0)
const BOSS_ATTACK_HITBOX_OFFSET: Vector2 = Vector2(0.0, -16.0)
const BOSS_DOWN_DISPLAY_SIZE: Vector2 = Vector2(72.0, 184.3125)
const BOSS_DOWN_DURATION_SECONDS: float = 0.72
const BOSS_FALL_SPEED: float = MainLayout.CELL_SIZE * 10.0
const BOSS_FALLEN_HOLD_SECONDS: float = 0.5
const INPUT_ACTIONS: Script = preload("res://scripts/input_actions.gd") # action 등록 유틸리티.

# 스테이지 기믹 규칙은 이 표에서만 선택한다.
const STAGE_GIMMICKS: Dictionary = {
	1: {"thorn_probability": 0.0, "binding_enabled": false},
	2: {"thorn_probability": 0.15, "binding_enabled": false},
	3: {"thorn_probability": 0.25, "binding_enabled": false},
	4: {"thorn_probability": 0.25, "binding_enabled": true},
	5: {
		"thorn_probability": 0.33,
		"binding_enabled": true,
		"binding_duration": BOSS_BINDING_DURATION_SECONDS,
	},
}

# SRS(Super Rotation System) wall-kick 표.
# key `"old>new"`마다 원점에 더해 시험할 Vector2i 후보를 우선순위 순으로 저장한다.
const JLSTZ_KICKS: Dictionary = {
	"0>1": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	"1>0": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	"1>2": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	"2>1": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	"2>3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
	"3>2": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	"3>0": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	"0>3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
}

const I_KICKS: Dictionary = {
	"0>1": [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, 1), Vector2i(1, -2)],
	"1>0": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, -1), Vector2i(-1, 2)],
	"1>2": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, -2), Vector2i(2, 1)],
	"2>1": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, 2), Vector2i(-2, -1)],
	"2>3": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, -1), Vector2i(-1, 2)],
	"3>2": [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, 1), Vector2i(1, -2)],
	"3>0": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, 2), Vector2i(-2, -1)],
	"0>3": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, -2), Vector2i(2, 1)],
}

# authoritative game state. View/Physics/Character는 읽거나 public method로만 변경한다.
var board: MainBoardModel = MainBoardModel.new() # 고정 셀을 소유하는 유일한 논리 보드.
var bag: MainPieceBag # 아직 나오지 않은 7-bag 피스 순서를 소유한다.
var state: GameState = GameState.PLAYING # 입력/시간 진행 허용 여부를 결정한다.
var meditation_active: bool = false # true면 테트리스 시간만 2배로 진행된다.
var fall_freeze_remaining: float = 0.0 # 시계공 특수 스킬로 피스 입력·낙하·고정을 멈추는 시간.

var active_type: int = MainTetrominoData.Type.T # 현재 낙하 중인 Type enum 정수.
var active_rotation: int = 0 # 활성 피스 회전 상태 0/1/2/3 = 0/90/180/270도.
var active_origin: Vector2i = Vector2i(3, SPAWN_Y) # 로컬 셀을 더할 보드 원점.
var active_cell_indices: Array[int] = [0, 1, 2, 3] # 팬 토스 뒤에도 원래 회전 중심을 보존하는 셀 식별자.
var next_type: int = MainTetrominoData.Type.I # 다음 spawn의 타입.
var active_piece_has_thorns: bool = false # 현재 활성 피스에만 한 번 정해지는 가시 여부.
var thorn_visible: bool = false # 가시 피스의 현재 ON/OFF phase 표시 상태.
var thorn_phase_timer: float = 0.0 # 가시 ON/OFF phase accumulator.

var transient_blocker_cells: Array[Vector2i] = [] # 방패병 보호벽처럼 고정시키지 않는 임시 충돌 셀.
var water_path_cells: Array[Vector2i] = [] # 소방관 물길이 차지하는 빈 표면 셀.
var water_path_direction: int = 0
var water_path_serial: int = 0
var _water_triggered_serial: int = -1

var score: int = 0 # 줄 삭제 공식으로 누적되는 총점.
var level: int = 1 # 중력 간격과 점수 배율에 쓰는 현재 레벨.
var total_lines: int = 0 # 제거한 누적 행 수. 10줄마다 level이 증가한다.
var stage_number: int = 1
var stage_time_remaining: float = SURVIVAL_TIME_SECONDS
var boss_health: int = 0
var boss_fall_position: Vector2 = Vector2(
	BOSS_POSITION.x,
	BOSS_POSITION.y + BOSS_DOWN_DISPLAY_SIZE.y * 0.5
)
var boss_fall_target_y: float = boss_fall_position.y
var boss_down_timer: float = 0.0
var boss_fall_hold_timer: float = 0.0
var boss_down: bool = false
var boss_falling: bool = false
var boss_fallen: bool = false

# 현재 피스 하나에만 적용되는 내부 accumulator/counter.
var _fall_accumulator: float = 0.0 # 한 셀 낙하로 아직 소비되지 않은 게임 시간(초).
var _lock_accumulator: float = 0.0 # 현재 접지에서 누적된 고정 대기시간(초).
var _lock_resets: int = 0 # 현재 피스의 이동/회전 lock delay 초기화 횟수.
var _spawn_random: RandomNumberGenerator = RandomNumberGenerator.new() # spawn x 전용 난수 엔진.
var _gimmick_random: RandomNumberGenerator = RandomNumberGenerator.new() # 기믹 전용 결정론 난수 엔진.
var _gimmick_roll_overrides: Array[bool] = [] # 자동 테스트가 확률 결과만 주입하는 내부 훅.
var binding_check_timer: float = 0.0 # 속박 적용 스테이지의 10초 주기 accumulator.
var binding_pending: bool = false # 공중에서 성공한 속박의 단일 pending 상태.
var binding_probability: float = BINDING_PROBABILITY # 다음 속박 판정에 사용할 누적 확률.
var _shown_stage_seconds: int = ceili(SURVIVAL_TIME_SECONDS)
@onready var character: MainCharacterController = get_node_or_null("../BoardPhysics/Character") as MainCharacterController


## 상황: main.tscn의 GameController가 씬 트리에 들어올 때 Godot가 한 번 호출한다.
## 순서: ① PROCESS_MODE_ALWAYS 설정 ② 입력 기본값 보장 ③ `reset_game()`.
## 결과: pause 입력도 항상 받고 첫 frame 전에 플레이 가능한 상태가 준비된다.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	INPUT_ACTIONS.ensure_defaults()
	var game_root: Node = get_parent()
	if game_root != null:
		stage_number = int(game_root.get_meta("stage_number", 1))
	reset_game()


## 상황: Godot physics frame마다 호출되는 C++ update loop 대응 함수다.
## 순서: restart 조기 처리 → pause 처리 → PLAYING 검사 → 명상 delta 계산
##       → `_advance_gravity()` → `_advance_lock_delay()`.
## 결과: 입력과 경과시간에 따라 피스가 낙하·고정되며 pause에서는 진행되지 않는다.
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(&"restart_game"):
		reset_game()
		return
	if Input.is_action_just_pressed(&"pause_game") and state != GameState.BOSS_FALLING:
		toggle_pause()

	if state == GameState.BOSS_FALLING:
		_advance_boss_fall(delta)
		return
	if state != GameState.PLAYING:
		return
	if fall_freeze_remaining > 0.0:
		fall_freeze_remaining = maxf(0.0, fall_freeze_remaining - delta)
		game_changed.emit()
		return

	var effective_delta: float = delta
	if meditation_active:
		effective_delta *= MEDITATION_TIME_SCALE
	_advance_gravity(effective_delta)
	_advance_lock_delay(effective_delta)
	_advance_stage_gimmicks(delta)
	_advance_stage_timer(delta)


## 상황: PLAYING frame에서 중력에 따른 셀 낙하를 진행할 때 호출한다.
## 순서: delta 누적 → 고정 간격 조회 → 간격 이상인 동안 반복
##       → 아래 배치 가능 시 이동/emit, 막히면 잔여 누적을 비우고 종료.
## 결과: 큰 delta에서도 낙하 단계를 빠뜨리지 않고 바닥에서는 lock 처리에 넘긴다.
func _advance_gravity(effective_delta: float) -> void:
	_fall_accumulator += effective_delta
	var interval: float = GRAVITY_INTERVAL_SECONDS # 한 셀 내려가는 데 필요한 초.
	while _fall_accumulator >= interval:
		_fall_accumulator -= interval
		if can_place_active(active_origin + Vector2i.DOWN):
			var previous_origin: Vector2i = active_origin
			active_origin += Vector2i.DOWN
			_apply_water_slide_if_needed()
			game_changed.emit()
			active_piece_descended.emit(previous_origin, active_origin)
		else:
			_fall_accumulator = 0.0
			break


## 상황: 중력 처리 직후 활성 피스의 접지 대기시간을 갱신할 때 호출한다.
## 순서: 접지 검사 → 접지면 시간 누적/임계값에서 lock
##       → 공중이면 accumulator와 reset 횟수를 모두 0으로 초기화.
## 결과: 피스가 바닥에 닿자마자 고정되지 않고 0.5초 조작 여유를 얻는다.
func _advance_lock_delay(effective_delta: float) -> void:
	if is_grounded():
		_lock_accumulator += effective_delta
		if _lock_accumulator >= LOCK_DELAY_SECONDS:
			lock_active_piece()
	else:
		_lock_accumulator = 0.0
		_lock_resets = 0


## 상황: 최초 시작, R 입력 또는 테스트가 완전히 새 게임을 요구할 때 호출한다.
## 순서: 보드 reset → 새 bag/난수 seed → 상태/timer 초기화
##       → next 확보 → 첫 spawn → restarted/change signal.
## 결과: 이전 상태가 모두 폐기되고 같은 seed면 같은 게임 순서를 재현한다.
func reset_game(seed_value: int = -1) -> void:
	board.reset()
	bag = MainPieceBag.new(seed_value)
	if seed_value >= 0:
		_spawn_random.seed = seed_value + SPAWN_RANDOM_SEED_OFFSET
		_gimmick_random.seed = seed_value + GIMMICK_RANDOM_SEED_OFFSET
	else:
		_spawn_random.randomize()
		_gimmick_random.randomize()
	total_lines = 0
	boss_health = BOSS_MAX_HEALTH if is_boss_stage() else 0
	boss_fall_position = Vector2(
		BOSS_POSITION.x,
		BOSS_POSITION.y + BOSS_DOWN_DISPLAY_SIZE.y * 0.5
	)
	boss_fall_target_y = boss_fall_position.y
	boss_down_timer = 0.0
	boss_fall_hold_timer = 0.0
	boss_down = false
	boss_falling = false
	boss_fallen = false
	stage_time_remaining = SURVIVAL_TIME_SECONDS
	_shown_stage_seconds = ceili(SURVIVAL_TIME_SECONDS)
	state = GameState.PLAYING
	meditation_active = false
	fall_freeze_remaining = 0.0
	clear_skill_effects()
	_reset_piece_timers()
	next_type = bag.next_piece()
	spawn_next_piece()
	game_restarted.emit()
	game_changed.emit()


func is_survival_stage() -> bool:
	return stage_number < 5


func is_boss_stage() -> bool:
	return stage_number == 5


func is_boss_alive() -> bool:
	return is_boss_stage() and boss_health > 0


func is_boss_down() -> bool:
	return is_boss_stage() and boss_down


func is_boss_falling() -> bool:
	return is_boss_stage() and boss_falling


func is_boss_fallen() -> bool:
	return is_boss_stage() and boss_fallen


func boss_hitbox() -> Rect2:
	return Rect2(
		BOSS_POSITION + BOSS_ATTACK_HITBOX_OFFSET - BOSS_ATTACK_HITBOX_SIZE * 0.5,
		BOSS_ATTACK_HITBOX_SIZE
	)


func get_boss_landing_y() -> float:
	var boss_rect: Rect2 = Rect2(
		BOSS_POSITION - BOSS_DISPLAY_SIZE * 0.5,
		BOSS_DISPLAY_SIZE
	)
	var landing_surface_y: float = float(MainBoardModel.VISIBLE_HEIGHT) * MainLayout.CELL_SIZE
	for y: int in range(MainBoardModel.HEIGHT):
		var cell_top: float = float(y - MainBoardModel.HIDDEN_ROWS) * MainLayout.CELL_SIZE
		if cell_top < boss_rect.end.y:
			continue
		for x: int in range(MainBoardModel.WIDTH):
			if board.cells[y][x] == MainBoardModel.EMPTY:
				continue
			var cell_left: float = float(x) * MainLayout.CELL_SIZE
			var cell_right: float = cell_left + MainLayout.CELL_SIZE
			if boss_rect.position.x < cell_right and boss_rect.end.x > cell_left:
				landing_surface_y = minf(landing_surface_y, cell_top)
	return landing_surface_y


func boss_hitbox_overlaps(hitbox: Rect2) -> bool:
	if state != GameState.PLAYING or not is_boss_alive():
		return false
	var target: Rect2 = boss_hitbox()
	return (
		hitbox.position.x < target.end.x
		and hitbox.end.x > target.position.x
		and hitbox.position.y < target.end.y
		and hitbox.end.y > target.position.y
	)


func notify_boss_attacked() -> bool:
	if state != GameState.PLAYING or not is_boss_alive():
		return false
	boss_attacked.emit()
	return true


func get_stage_gimmick_config() -> Dictionary:
	return STAGE_GIMMICKS.get(stage_number, STAGE_GIMMICKS[1]) as Dictionary


func _advance_stage_gimmicks(delta: float) -> void:
	if state != GameState.PLAYING:
		return
	var config: Dictionary = get_stage_gimmick_config()
	if float(config.get("thorn_probability", 0.0)) > 0.0:
		_advance_thorn_timer(delta)
	else:
		_reset_active_piece_gimmick()
	if not bool(config.get("binding_enabled", false)):
		binding_check_timer = 0.0
		binding_pending = false
		binding_probability = BINDING_PROBABILITY
		return
	binding_check_timer += delta
	while binding_check_timer >= BINDING_CHECK_INTERVAL_SECONDS:
		binding_check_timer -= BINDING_CHECK_INTERVAL_SECONDS
		_attempt_binding_roll()


func _advance_thorn_timer(delta: float) -> void:
	if not active_piece_has_thorns:
		thorn_visible = false
		thorn_phase_timer = 0.0
		return
	thorn_phase_timer += delta
	var changed: bool = false
	var phase_duration: float = THORN_ON_SECONDS if thorn_visible else THORN_OFF_SECONDS
	while thorn_phase_timer >= phase_duration:
		thorn_phase_timer -= phase_duration
		thorn_visible = not thorn_visible
		changed = true
		phase_duration = THORN_ON_SECONDS if thorn_visible else THORN_OFF_SECONDS
	if changed:
		game_changed.emit()


func _initialize_active_piece_gimmick() -> void:
	var probability: float = float(get_stage_gimmick_config().get("thorn_probability", 0.0))
	active_piece_has_thorns = probability > 0.0 and _gimmick_random.randf() < probability
	thorn_visible = active_piece_has_thorns
	thorn_phase_timer = 0.0


func _reset_active_piece_gimmick() -> void:
	active_piece_has_thorns = false
	thorn_visible = false
	thorn_phase_timer = 0.0


func active_piece_has_visible_thorns() -> bool:
	return (
		float(get_stage_gimmick_config().get("thorn_probability", 0.0)) > 0.0
		and active_piece_has_thorns
		and thorn_visible
	)


func _attempt_binding_roll() -> void:
	if binding_pending or _character_is_bound():
		return
	if not _next_gimmick_roll():
		binding_probability = minf(
			1.0,
			binding_probability + BINDING_PROBABILITY_STEP
		)
		return
	binding_probability = BINDING_PROBABILITY
	if _character_has_surface_contact():
		if is_instance_valid(character):
			character.apply_binding(get_binding_duration_seconds())
	else:
		binding_pending = true


func notify_binding_surface_contact(surface_contact: bool) -> void:
	if (
		not binding_pending
		or not surface_contact
		or not bool(get_stage_gimmick_config().get("binding_enabled", false))
	):
		return
	if _character_is_bound():
		binding_pending = false
		return
	if not is_instance_valid(character):
		return
	binding_pending = false
	character.apply_binding(get_binding_duration_seconds())


func get_binding_duration_seconds() -> float:
	return float(get_stage_gimmick_config().get("binding_duration", BINDING_DURATION_SECONDS))


func _character_has_surface_contact() -> bool:
	return is_instance_valid(character) and character.can_receive_binding()


func _character_is_bound() -> bool:
	return is_instance_valid(character) and character.is_bound


func _next_gimmick_roll() -> bool:
	if not _gimmick_roll_overrides.is_empty():
		return _gimmick_roll_overrides.pop_front()
	return _gimmick_random.randf() < binding_probability


func _advance_stage_timer(delta: float) -> void:
	if not is_survival_stage():
		return
	stage_time_remaining = maxf(stage_time_remaining - delta, 0.0)
	var shown_seconds: int = ceili(stage_time_remaining)
	if shown_seconds != _shown_stage_seconds:
		_shown_stage_seconds = shown_seconds
		game_changed.emit()
	if stage_time_remaining > 0.0:
		return
	if total_lines < 1:
		end_game()
		return
	state = GameState.PAUSED
	meditation_active = false
	game_changed.emit()
	stage_cleared.emit(total_lines)


## 상황: 게임 시작 또는 이전 피스를 고정한 뒤 다음 활성 피스가 필요할 때 호출한다.
## 순서: next→active 이동 → bag에서 새 next → 회전/timer 초기화
##       → 유효 spawn 무작위 선택 → 없으면 end_game, 있으면 origin 대입/emit.
## 결과: 성공하면 true와 새 활성 피스, 실패하면 false와 GAME_OVER 상태가 된다.
func spawn_next_piece() -> bool:
	active_type = next_type
	next_type = bag.next_piece()
	active_rotation = 0
	active_cell_indices = [0, 1, 2, 3]
	_water_triggered_serial = -1
	_reset_piece_timers()

	var spawn_origin: Variant = _choose_random_spawn_origin(active_type) # Vector2i 또는 불가를 뜻하는 null.
	if spawn_origin == null:
		end_game()
		return false
	active_origin = spawn_origin as Vector2i
	_initialize_active_piece_gimmick()

	game_changed.emit()
	return true


## 상황: CharacterController가 명상을 시작/종료하거나 reset할 때 호출한다.
## 순서: 요청값과 `state == PLAYING`을 AND하여 meditation_active에 저장한다.
## 결과: game over/pause에서는 강제로 false이며 다음 `_process()` 시간 배율이 달라진다.
func set_meditation_active(active: bool) -> void:
	meditation_active = active and state == GameState.PLAYING


## 시계공의 정지 태엽. 지속 중에는 활성 피스의 입력·낙하·고정 시간이 모두 멈춘다.
func freeze_falling_blocks(seconds: float) -> bool:
	if state != GameState.PLAYING or seconds <= 0.0:
		return false
	fall_freeze_remaining = maxf(fall_freeze_remaining, seconds)
	game_changed.emit()
	return true


func clear_fall_freeze() -> void:
	if fall_freeze_remaining <= 0.0:
		return
	fall_freeze_remaining = 0.0
	game_changed.emit()


## 현재 회전 상태에서 팬 토스로 남아 있는 셀만 반환한다.
func active_local_cells(rotation: int = -1) -> Array[Vector2i]:
	var resolved_rotation: int = active_rotation if rotation < 0 else rotation
	var all_cells: Array[Vector2i] = MainTetrominoData.get_cells(active_type, resolved_rotation)
	var result: Array[Vector2i] = []
	for index: int in active_cell_indices:
		if index >= 0 and index < all_cells.size():
			result.append(all_cells[index])
	return result


func active_board_cells(origin: Vector2i = active_origin, rotation: int = -1) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for local_cell: Vector2i in active_local_cells(rotation):
		result.append(origin + local_cell)
	return result


func can_place_active(
	origin: Vector2i,
	rotation: int = -1,
	include_transient_blockers: bool = true
) -> bool:
	var local_cells: Array[Vector2i] = active_local_cells(rotation)
	if not board.can_place_cells(local_cells, origin):
		return false
	if include_transient_blockers:
		for local_cell: Vector2i in local_cells:
			if origin + local_cell in transient_blocker_cells:
				return false
	return true


func set_transient_blockers(cells: Array[Vector2i]) -> void:
	transient_blocker_cells = cells.duplicate()
	game_changed.emit()


func clear_transient_blockers() -> void:
	if transient_blocker_cells.is_empty():
		return
	transient_blocker_cells.clear()
	game_changed.emit()


func clear_skill_effects() -> void:
	fall_freeze_remaining = 0.0
	transient_blocker_cells.clear()
	water_path_cells.clear()
	water_path_direction = 0
	water_path_serial += 1
	_water_triggered_serial = -1


## 소방관의 물길을 고정 블록과 바닥만 기준으로 계산한다.
func create_water_path(start_cell: Vector2i, direction: int, maximum_steps: int = 4) -> bool:
	water_path_cells.clear()
	water_path_direction = signi(direction)
	water_path_serial += 1
	_water_triggered_serial = -1
	if state != GameState.PLAYING or water_path_direction == 0 or maximum_steps < 1:
		game_changed.emit()
		return false

	var cursor: Vector2i = start_cell
	for _step: int in range(maximum_steps):
		if cursor.x < 0 or cursor.x >= MainBoardModel.WIDTH:
			break
		cursor.y = clampi(cursor.y, 0, MainBoardModel.HEIGHT - 1)
		while cursor.y < MainBoardModel.HEIGHT - 1:
			var below := cursor + Vector2i.DOWN
			if board.get_cell(below) != MainBoardModel.EMPTY:
				break
			cursor = below
		if board.get_cell(cursor) != MainBoardModel.EMPTY:
			break
		if cursor not in water_path_cells:
			water_path_cells.append(cursor)
		var next := cursor + Vector2i(water_path_direction, 0)
		if next.x < 0 or next.x >= MainBoardModel.WIDTH:
			break
		if board.get_cell(next) != MainBoardModel.EMPTY:
			break
		cursor = next
	_apply_water_slide_if_needed()
	game_changed.emit()
	return not water_path_cells.is_empty()


func clear_water_path() -> void:
	if water_path_cells.is_empty():
		return
	water_path_cells.clear()
	water_path_direction = 0
	water_path_serial += 1
	_water_triggered_serial = -1
	game_changed.emit()


func _apply_water_slide_if_needed() -> void:
	if water_path_cells.is_empty() or _water_triggered_serial == water_path_serial:
		return
	var touches_water: bool = false
	for cell: Vector2i in active_board_cells():
		if cell in water_path_cells:
			touches_water = true
			break
	if not touches_water:
		return
	_water_triggered_serial = water_path_serial
	var was_grounded: bool = is_grounded()
	for distance: int in range(2, 0, -1):
		var target := active_origin + Vector2i(water_path_direction * distance, 0)
		if can_place_active(target):
			active_origin = target
			_reset_lock_after_transform(was_grounded)
			break
	game_changed.emit()


## 전방 한 칸의 활성 도형 또는 고정 블록을 가능한 거리만큼 민다.
func push_front_target(
	target_cell: Vector2i,
	direction: int,
	maximum_distance: int,
	require_exposed_fixed: bool = false
) -> int:
	if state != GameState.PLAYING or direction == 0 or maximum_distance < 1:
		return 0
	var step_x: int = signi(direction)
	if target_cell in active_board_cells():
		var was_grounded: bool = is_grounded()
		var moved_active: int = 0
		for distance: int in range(1, maximum_distance + 1):
			if not can_place_active(active_origin + Vector2i(step_x * distance, 0)):
				break
			moved_active = distance
		if moved_active > 0:
			active_origin += Vector2i(step_x * moved_active, 0)
			_reset_lock_after_transform(was_grounded)
			game_changed.emit()
		return moved_active

	if board.get_cell(target_cell) == MainBoardModel.EMPTY:
		return 0
	var above := target_cell + Vector2i.UP
	if (
		require_exposed_fixed
		and board.is_inside(above)
		and board.get_cell(above) != MainBoardModel.EMPTY
	):
		return 0
	var current: Vector2i = target_cell
	var moved_fixed: int = 0
	for _distance: int in range(maximum_distance):
		var destination := current + Vector2i(step_x, 0)
		if destination in active_board_cells() or not board.move_cell(current, destination):
			break
		current = destination
		moved_fixed += 1
	if moved_fixed > 0:
		game_changed.emit()
	return moved_fixed


## 캐릭터 발밑을 중심으로 노출된 고정 블록을 최대 세 칸 제거한다.
func clean_exposed_cells(center_below: Vector2i) -> int:
	if state != GameState.PLAYING:
		return 0
	var removed: int = 0
	for x_offset: int in range(-1, 2):
		var cell := center_below + Vector2i(x_offset, 0)
		if not board.is_inside(cell) or board.get_cell(cell) == MainBoardModel.EMPTY:
			continue
		var above := cell + Vector2i.UP
		if board.is_inside(above) and board.get_cell(above) != MainBoardModel.EMPTY:
			continue
		if board.remove_cell(cell):
			removed += 1
	if removed > 0:
		game_changed.emit()
	return removed


## 요리사의 대각선 팬 토스. 활성 미노는 분리해 즉시 고정하고 고정 블록은 이동한다.
func pan_toss(target_cell: Vector2i, direction: Vector2i) -> bool:
	if state != GameState.PLAYING or absi(direction.x) != 1 or absi(direction.y) != 1:
		return false
	var destination := target_cell + direction
	var horizontal := target_cell + Vector2i(direction.x, 0)
	var vertical := target_cell + Vector2i(0, direction.y)
	for path_cell: Vector2i in [destination, horizontal, vertical]:
		if not board.is_inside(path_cell) or board.get_cell(path_cell) != MainBoardModel.EMPTY:
			return false
		if path_cell in active_board_cells() and path_cell != target_cell:
			return false

	var active_cells: Array[Vector2i] = active_board_cells()
	var active_index: int = active_cells.find(target_cell)
	if active_index >= 0:
		if active_cell_indices.size() <= 1:
			return false
		var removed_index: int = active_cell_indices[active_index]
		if not board.place_cell(destination, active_type):
			return false
		active_cell_indices.erase(removed_index)
		_resolve_immediate_line_clear()
		_resolve_active_overlap_upward()
		game_changed.emit()
		return true

	if board.get_cell(target_cell) == MainBoardModel.EMPTY:
		return false
	var above := target_cell + Vector2i.UP
	if board.is_inside(above) and board.get_cell(above) != MainBoardModel.EMPTY:
		return false
	if not board.move_cell(target_cell, destination):
		return false
	_resolve_immediate_line_clear()
	game_changed.emit()
	return true


func _resolve_immediate_line_clear() -> void:
	var cleared: int = board.clear_full_lines()
	if cleared <= 0:
		return
	_apply_line_clear_rewards(cleared)


func _resolve_active_overlap_upward() -> void:
	if can_place_active(active_origin, active_rotation, false):
		return
	for offset: int in range(1, MainBoardModel.HEIGHT + 1):
		var candidate := active_origin + Vector2i.UP * offset
		if can_place_active(candidate, active_rotation, false):
			active_origin = candidate
			return
	end_game()


## 청소부의 대청소. 화면 하단 세 줄에서 위 블록을 받치지 않는 고정 블록을 제거한다.
func clean_bottom_exposed_blocks(maximum_count: int = 3) -> int:
	if state != GameState.PLAYING or maximum_count <= 0:
		return 0
	var removed: int = 0
	var first_row: int = MainBoardModel.HEIGHT - 3
	for y: int in range(MainBoardModel.HEIGHT - 1, first_row - 1, -1):
		for x: int in range(MainBoardModel.WIDTH):
			var cell := Vector2i(x, y)
			if board.get_cell(cell) == MainBoardModel.EMPTY:
				continue
			var above := cell + Vector2i.UP
			if board.is_inside(above) and board.get_cell(above) != MainBoardModel.EMPTY:
				continue
			if board.remove_cell(cell):
				removed += 1
				if removed >= maximum_count:
					game_changed.emit()
					return removed
	if removed > 0:
		game_changed.emit()
	return removed


## 닌자의 표창. 고정 블록에 막히며 같은 행의 활성 피스만 정확히 한 칸 민다.
func throw_shuriken_at_active_piece(
	start_cell: Vector2i,
	direction: int,
	reach: int = 6,
	forbidden_cells: Array[Vector2i] = []
) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"contact": SHURIKEN_CONTACT_NONE,
		"travel_cells": 0,
		"impact_cell": start_cell,
		"direction": signi(direction),
	}
	if state != GameState.PLAYING or direction == 0 or reach < 1:
		return result
	var step_x: int = signi(direction)
	var active_cells: Array[Vector2i] = active_board_cells()
	var last_inside_cell: Vector2i = start_cell
	for distance: int in range(1, reach + 1):
		var target := start_cell + Vector2i(step_x * distance, 0)
		if not board.is_inside(target):
			result["travel_cells"] = distance - 1
			result["impact_cell"] = last_inside_cell
			return result
		last_inside_cell = target
		if board.get_cell(target) != MainBoardModel.EMPTY:
			result["contact"] = SHURIKEN_CONTACT_FIXED
			result["travel_cells"] = distance
			result["impact_cell"] = target
			return result
		if target in active_cells:
			result["contact"] = SHURIKEN_CONTACT_ACTIVE
			result["travel_cells"] = distance
			result["impact_cell"] = target
			result["success"] = push_active_piece(step_x, 1, forbidden_cells)
			return result
	result["travel_cells"] = reach
	result["impact_cell"] = last_inside_cell
	return result


## 상황: 새 피스의 무작위 spawn x 후보 집합을 지정한 좌우 여백으로 계산할 때 호출한다.
## 순서: 기본 모양 조회 → 빈 모양 조기 반환 → local min/max x 계산
##       → 실제 점유 셀이 여백 안쪽에 드는 원점 x 순회 → `can_place()` 후보만 append.
## 결과: 원점이 아니라 네 실제 셀을 기준으로 여백과 기존 블록 충돌을 모두 만족한 후보를 반환한다.
func _valid_spawn_origins(
	piece_type: int,
	side_margin_cells: int = SPAWN_SIDE_MARGIN_CELLS
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = MainTetrominoData.get_cells(piece_type, 0) # 회전 0의 로컬 셀.
	var candidates: Array[Vector2i] = [] # 실제 배치 가능한 spawn 원점 목록.
	if cells.is_empty():
		return candidates

	var minimum_x: int = cells[0].x # 모양 자체에서 가장 왼쪽 local x.
	var maximum_x: int = cells[0].x # 모양 자체에서 가장 오른쪽 local x.
	for cell: Vector2i in cells:
		minimum_x = mini(minimum_x, cell.x)
		maximum_x = maxi(maximum_x, cell.x)

	var safe_margin: int = maxi(0, side_margin_cells) # 음수 입력은 벽 밖 허용이 아니라 여백 0으로 취급한다.
	var first_origin_x: int = safe_margin - minimum_x # 가장 왼쪽 실제 셀이 margin 열에서 시작하는 원점.
	var end_origin_x: int = ( # range 상한은 exclusive이므로 오른쪽 여백 직전 다음 원점을 사용한다.
		MainBoardModel.WIDTH - safe_margin - maximum_x
	)
	for origin_x: int in range(first_origin_x, end_origin_x):
		var origin: Vector2i = Vector2i(origin_x, SPAWN_Y) # 현재 검사 중인 spawn 원점.
		if board.can_place(piece_type, 0, origin):
			candidates.append(origin)
	return candidates


## 상황: `spawn_next_piece()`가 후보 중 실제 spawn 한 곳을 정할 때 호출한다.
## 순서: 한 칸 여백 후보 계산 → 있으면 그 집합 사용 → 없으면 여백 0 후보로 fallback
##       → fallback도 비면 null → 아니면 선택된 집합에서 균등 random index 조회.
## 결과: 평소에는 벽과 한 칸 떨어진 원점, 중앙이 막히면 벽 옆 예외 원점, 전부 막히면 null을 반환한다.
func _choose_random_spawn_origin(piece_type: int) -> Variant:
	var candidates: Array[Vector2i] = _valid_spawn_origins( # 벽과 한 칸 떨어진 우선 후보.
		piece_type,
		SPAWN_SIDE_MARGIN_CELLS
	)
	if candidates.is_empty():
		candidates = _valid_spawn_origins(piece_type, 0) # 조기 game over를 막는 벽 옆 예외 후보.
	if candidates.is_empty():
		return null
	var index: int = _spawn_random.randi_range(0, candidates.size() - 1) # 선택된 후보 index.
	return candidates[index]


## 상황: 캐릭터 펀치가 활성 피스를 수평으로 여러 칸 밀 때 호출한다.
## 순서: 입력/state 검사 → 방향 ±1 정규화 → 모든 중간 위치 검증
##       → 이동 전 접지 저장 → origin 이동 → lock delay 조정 → emit.
## 결과: 전 경로가 비었을 때만 원자적으로 이동해 true, 막히면 변화 없이 false다.
func push_active_piece(
	direction: int,
	distance: int,
	forbidden_cells: Array[Vector2i] = []
) -> bool:
	if state != GameState.PLAYING or direction == 0 or distance < 1:
		return false

	var normalized_direction: int = signi(direction)
	for step: int in range(1, distance + 1):
		var target: Vector2i = active_origin + Vector2i(normalized_direction * step, 0) # 중간 후보.
		if (
			not can_place_active(target)
			or _piece_overlaps_forbidden_cells(
				active_type,
				active_rotation,
				target,
				forbidden_cells
			)
		):
			return false

	var was_grounded: bool = is_grounded()
	active_origin += Vector2i(normalized_direction * distance, 0)
	_reset_lock_after_transform(was_grounded)
	game_changed.emit()
	return true


## 상황: 캐릭터 블록 플립이 활성 피스를 시계/반시계 방향으로 돌릴 때 호출한다.
## 순서: state/O 검사 → 새 회전/SRS key 계산 → kick 표 선택
##       → 후보를 순서대로 can_place/금지 셀 검사 → 최초 성공 적용/timer reset/emit.
## 결과: 보드와 캐릭터 점유 셀을 모두 피하는 보정 위치가 있으면 true, 모두 막히면 false다.
func try_rotate(
	direction: int,
	forbidden_cells: Array[Vector2i] = []
) -> bool:
	if state != GameState.PLAYING:
		return false
	if active_type == MainTetrominoData.Type.O:
		if _piece_overlaps_forbidden_cells(
			active_type,
			active_rotation,
			active_origin,
			forbidden_cells
		):
			return false
		game_changed.emit()
		return true

	var old_rotation: int = active_rotation # SRS 시작 회전.
	var new_rotation: int = posmod(active_rotation + direction, 4) # 0~3 목표 회전.
	var transition: String = "%d>%d" % [old_rotation, new_rotation] # 예: "0>1".
	var kick_table: Dictionary = I_KICKS if active_type == MainTetrominoData.Type.I else JLSTZ_KICKS # 모양별 표.
	var kick_tests: Array = kick_table.get(transition, [Vector2i.ZERO]) # 시험할 offset 목록.
	var was_grounded: bool = is_grounded() # 회전 전 접지 snapshot.

	# SRS는 보정 후보를 표 순서대로 검사하고 처음 배치 가능한 위치만 채택한다.
	for kick_variant: Variant in kick_tests:
		var kick: Vector2i = kick_variant # Variant 원소를 명시형 좌표로 변환.
		var target: Vector2i = active_origin + kick # 이번 offset을 적용한 원점.
		if not can_place_active(target, new_rotation):
			continue
		if _piece_overlaps_forbidden_cells(
			active_type,
			new_rotation,
			target,
			forbidden_cells
		):
			continue
		active_rotation = new_rotation
		active_origin = target
		_reset_lock_after_transform(was_grounded)
		game_changed.emit()
		return true
	return false


## 상황: SRS 후보가 캐릭터처럼 BoardModel 밖에서 전달된 점유 셀을 침범하는지 검사한다.
## 결과: 후보 피스 네 셀 중 하나라도 forbidden_cells에 있으면 true다.
func _piece_overlaps_forbidden_cells(
	piece_type: int,
	rotation: int,
	origin: Vector2i,
	forbidden_cells: Array[Vector2i]
) -> bool:
	if forbidden_cells.is_empty():
		return false
	var cells: Array[Vector2i] = (
		active_local_cells(rotation)
		if piece_type == active_type
		else MainTetrominoData.get_cells(piece_type, rotation)
	)
	for local_cell: Vector2i in cells:
		if origin + local_cell in forbidden_cells:
			return true
	return false


## 상황: 접지 lock delay가 끝나 활성 피스를 고정 블록으로 전환할 때 호출한다.
## 순서: PLAYING 검사 → board.lock_piece → clear_full_lines → 줄
##       → hidden-row top-out이면 end_game → 아니면 spawn_next_piece.
## 결과: 현재 피스 수명이 끝나고 게임오버 또는 다음 피스로 전환된다.
func lock_active_piece() -> void:
	if state != GameState.PLAYING:
		return

	board.lock_cells(active_type, active_local_cells(), active_origin)
	var cleared: int = board.clear_full_lines() # 이번 고정으로 동시에 삭제된 행 수.
	if cleared > 0:
		_apply_line_clear_rewards(cleared)

	if board.has_blocks_in_hidden_rows():
		end_game()
		return
	spawn_next_piece()


func _apply_line_clear_rewards(cleared: int) -> void:
	if cleared <= 0:
		return
	score += line_clear_score(cleared, level)
	total_lines += cleared
	level = level_for_lines(total_lines)
	lines_cleared.emit()


## 상황: P/Esc 입력 또는 테스트가 일시정지 상태를 전환할 때 호출한다.
## 순서: GAME_OVER면 무시 → PLAYING/PAUSED 토글 → 비PLAYING이면 명상 해제 → emit.
## 결과: 다음 `_process()`의 시간 진행 여부와 화면 overlay가 바뀐다.
func toggle_pause() -> void:
	if state == GameState.GAME_OVER or state == GameState.BOSS_FALLING or boss_fallen:
		return
	state = GameState.PAUSED if state == GameState.PLAYING else GameState.PLAYING
	if state != GameState.PLAYING:
		meditation_active = false
	game_changed.emit()


## 상황: spawn 불가, top-out 또는 캐릭터 생명 소진 때 호출한다.
## 순서: state=GAME_OVER → 명상 해제 → game_changed emit.
## 결과: 게임 시간과 캐릭터 물리가 멈추고 View가 게임오버를 표시한다.
func end_game() -> void:
	state = GameState.GAME_OVER
	meditation_active = false
	_reset_active_piece_gimmick()
	binding_check_timer = 0.0
	binding_pending = false
	binding_probability = BINDING_PROBABILITY
	game_changed.emit()


## 상황: lock delay나 이동/회전 전후의 바닥 접촉을 판정할 때 호출한다.
## 순서: 현재 원점보다 y+1 위치를 `board.can_place()`로 검사하고 논리 부정한다.
## 결과: 한 칸 아래로 이동할 수 없으면 true이며 상태는 바꾸지 않는다.
func is_grounded() -> bool:
	return not can_place_active(active_origin + Vector2i.DOWN, active_rotation, false)


## 상황: GameView가 활성 피스의 예상 착지 고스트를 그릴 때 호출한다.
## 순서: drop distance 조회 → 현재 원점에 `(0,distance)` 합산.
## 결과: 실제 피스를 움직이지 않고 예상 착지 원점을 반환한다.
func ghost_origin() -> Vector2i:
	var distance: int = board.get_drop_distance_cells(active_local_cells(), active_origin) # 남은 셀 수.
	return active_origin + Vector2i(0, distance)


static func line_clear_score(cleared_lines: int, current_level: int) -> int:
	var base_scores: Array[int] = [0, 100, 300, 550, 900]
	if cleared_lines < 1 or cleared_lines >= base_scores.size():
		return 0
	return base_scores[cleared_lines] * maxi(current_level, 1)


static func level_for_lines(lines: int) -> int:
	return 1 + floori(float(maxi(lines, 0)) / 10.0)


static func stage_stars_for_lines(lines: int) -> int:
	var cleared_lines: int = maxi(lines, 0)
	if cleared_lines >= 3:
		return 3
	if cleared_lines >= 2:
		return 2
	return 1 if cleared_lines >= 1 else 0


## 상황: 새 게임 또는 새 피스가 시작되어 이전 피스의 시간 상태를 버릴 때 호출한다.
## 순서: fall accumulator → lock accumulator → lock reset count를 모두 0으로 대입.
## 결과: 새 피스가 이전 피스의 낙하/고정 시간을 상속하지 않는다.
func _reset_piece_timers() -> void:
	_fall_accumulator = 0.0
	_lock_accumulator = 0.0
	_lock_resets = 0


## 상황: 활성 피스가 수평 이동 또는 회전에 성공한 직후 호출한다.
## 순서: 이동 전/후 중 하나라도 접지인지 검사 → reset 횟수 상한 검사
##       → 허용되면 lock accumulator=0, reset count+1.
## 결과: 바닥 조작 시간을 연장하되 최대 15회로 무한 지연을 막는다.
func _reset_lock_after_transform(was_grounded: bool) -> void:
	if (was_grounded or is_grounded()) and _lock_resets < MAX_LOCK_RESETS:
		_lock_accumulator = 0.0
		_lock_resets += 1


func damage_boss(cleared_lines: int) -> void:
	if not is_boss_stage() or boss_health <= 0 or cleared_lines <= 0:
		return
	boss_health = maxi(0, boss_health - cleared_lines)
	if boss_health > 0:
		game_changed.emit()
		return
	meditation_active = false
	_reset_active_piece_gimmick()
	binding_check_timer = 0.0
	binding_pending = false
	binding_probability = BINDING_PROBABILITY
	boss_fall_position = Vector2(
		BOSS_POSITION.x,
		BOSS_POSITION.y + BOSS_DOWN_DISPLAY_SIZE.y * 0.5
	)
	boss_fall_target_y = get_boss_landing_y()
	boss_down_timer = 0.0
	boss_fall_hold_timer = 0.0
	boss_down = true
	boss_falling = false
	boss_fallen = false
	state = GameState.BOSS_FALLING
	game_changed.emit()


func _advance_boss_fall(delta: float) -> void:
	if boss_fallen:
		boss_fall_hold_timer += maxf(delta, 0.0)
		if boss_fall_hold_timer < BOSS_FALLEN_HOLD_SECONDS:
			return
		state = GameState.PAUSED
		game_changed.emit()
		stage_cleared.emit(total_lines)
		return
	var remaining_delta: float = maxf(delta, 0.0)
	if boss_down:
		boss_down_timer += remaining_delta
		if boss_down_timer < BOSS_DOWN_DURATION_SECONDS:
			game_changed.emit()
			return
		remaining_delta = boss_down_timer - BOSS_DOWN_DURATION_SECONDS
		boss_down_timer = 0.0
		boss_down = false
		boss_falling = true
	if not boss_falling:
		return
	boss_fall_position.y = minf(
		boss_fall_position.y + BOSS_FALL_SPEED * remaining_delta,
		boss_fall_target_y
	)
	if boss_fall_position.y >= boss_fall_target_y:
		boss_fall_position.y = boss_fall_target_y
		boss_falling = false
		boss_fallen = true
		boss_fall_hold_timer = 0.0
	game_changed.emit()
