class_name MainGameController
extends Node

## [역할 / C++ 대응]
## 테트리스 규칙과 시간 진행의 중앙 오케스트레이터다. BoardModel과 PieceBag을 소유하고
## 활성/다음 피스, 점수, 레벨, 게임 상태를 authoritative state로 유지한다.
##
## [호출 관계]
## Godot: `_ready()`, 매 프레임 `_process(delta)`.
## CharacterController: set_meditation_active(), push_active_piece(), try_rotate(), end_game().
## GameView/BoardPhysics/CharacterController: 상태를 읽고 signal을 구독한다.
## 호출 대상: BoardModel, PieceBag, TetrominoData, InputActions.
##
## `signal`은 C++ observer/event에 해당한다. `.emit()`하면 `.connect(callback)`으로
## 등록된 GameView/BoardPhysics/CharacterController 함수가 호출된다.

signal game_changed # 피스/점수/상태 변경 후 View와 BoardPhysics에 동기화를 요구한다.
signal game_restarted # 전체 초기화 후 Character와 BoardPhysics에도 reset을 요구한다.
signal active_piece_descended(previous_origin: Vector2i, current_origin: Vector2i)
signal lines_cleared # 완성 행 제거 직후 SFX 등 피드백을 알린다.

enum GameState {
	PLAYING,
	PAUSED,
	GAME_OVER,
}

# 게임 진행 규칙과 시간 상수.
const SPAWN_Y: int = 1 # 새 피스 원점의 숨은 보드 행 y.
const LOCK_DELAY_SECONDS: float = 0.5 # 접지 후 고정까지 허용하는 게임 시간(초).
const MAX_LOCK_RESETS: int = 15 # 이동/회전으로 lock delay를 초기화할 수 있는 최대 횟수.
const MEDITATION_TIME_SCALE: float = 2.0 # 명상 중 테트리스 중력/lock 시간 배율.
const SPAWN_RANDOM_SEED_OFFSET: int = 20839 # bag과 spawn-x 난수열을 분리하는 seed offset.
const INPUT_ACTIONS: Script = preload("res://scripts/input_actions.gd") # action 등록 유틸리티.

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

var active_type: int = MainTetrominoData.Type.T # 현재 낙하 중인 Type enum 정수.
var active_rotation: int = 0 # 활성 피스 회전 상태 0/1/2/3 = 0/90/180/270도.
var active_origin: Vector2i = Vector2i(3, SPAWN_Y) # 로컬 셀을 더할 보드 원점.
var next_type: int = MainTetrominoData.Type.I # 다음 spawn의 타입.

var score: int = 0 # 줄 삭제 공식으로 누적되는 총점.
var level: int = 1 # 중력 간격과 점수 배율에 쓰는 현재 레벨.
var total_lines: int = 0 # 제거한 누적 행 수. 10줄마다 level이 증가한다.

# 현재 피스 하나에만 적용되는 내부 accumulator/counter.
var _fall_accumulator: float = 0.0 # 한 셀 낙하로 아직 소비되지 않은 게임 시간(초).
var _lock_accumulator: float = 0.0 # 현재 접지에서 누적된 고정 대기시간(초).
var _lock_resets: int = 0 # 현재 피스의 이동/회전 lock delay 초기화 횟수.
var _spawn_random: RandomNumberGenerator = RandomNumberGenerator.new() # spawn x 전용 난수 엔진.


## 상황: main.tscn의 GameController가 씬 트리에 들어올 때 Godot가 한 번 호출한다.
## 순서: ① PROCESS_MODE_ALWAYS 설정 ② 입력 기본값 보장 ③ `reset_game()`.
## 결과: pause 입력도 항상 받고 첫 frame 전에 플레이 가능한 상태가 준비된다.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	INPUT_ACTIONS.ensure_defaults()
	reset_game()


## 상황: Godot physics frame마다 호출되는 C++ update loop 대응 함수다.
## 순서: restart 조기 처리 → pause 처리 → PLAYING 검사 → 명상 delta 계산
##       → `_advance_gravity()` → `_advance_lock_delay()`.
## 결과: 입력과 경과시간에 따라 피스가 낙하·고정되며 pause에서는 진행되지 않는다.
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(&"restart_game"):
		reset_game()
		return
	if Input.is_action_just_pressed(&"pause_game"):
		toggle_pause()

	if state != GameState.PLAYING:
		return

	var effective_delta: float = ( # 명상 배율을 적용해 테트리스 규칙에만 사용할 시간.
		delta * MEDITATION_TIME_SCALE if meditation_active else delta
	)
	_advance_gravity(effective_delta)
	_advance_lock_delay(effective_delta)


## 상황: PLAYING frame에서 중력에 따른 셀 낙하를 진행할 때 호출한다.
## 순서: delta 누적 → level 간격 조회 → 간격 이상인 동안 반복
##       → 아래 배치 가능 시 이동/emit, 막히면 잔여 누적을 비우고 종료.
## 결과: 큰 delta에서도 낙하 단계를 빠뜨리지 않고 바닥에서는 lock 처리에 넘긴다.
func _advance_gravity(effective_delta: float) -> void:
	_fall_accumulator += effective_delta
	var interval: float = gravity_interval() # 현재 level에서 한 셀 내려가는 데 필요한 초.
	while _fall_accumulator >= interval:
		_fall_accumulator -= interval
		if board.can_place(active_type, active_rotation, active_origin + Vector2i.DOWN):
			var previous_origin: Vector2i = active_origin
			active_origin += Vector2i.DOWN
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
## 순서: 보드 reset → 새 bag/난수 seed → 점수/상태/timer 초기화
##       → next 확보 → 첫 spawn → restarted/change signal.
## 결과: 이전 상태가 모두 폐기되고 같은 seed면 같은 게임 순서를 재현한다.
func reset_game(seed_value: int = -1) -> void:
	board.reset()
	bag = MainPieceBag.new(seed_value)
	if seed_value >= 0:
		_spawn_random.seed = seed_value + SPAWN_RANDOM_SEED_OFFSET
	else:
		_spawn_random.randomize()
	score = 0
	level = 1
	total_lines = 0
	state = GameState.PLAYING
	meditation_active = false
	_reset_piece_timers()
	next_type = bag.next_piece()
	spawn_next_piece()
	game_restarted.emit()
	game_changed.emit()


## 상황: 게임 시작 또는 이전 피스를 고정한 뒤 다음 활성 피스가 필요할 때 호출한다.
## 순서: next→active 이동 → bag에서 새 next → 회전/timer 초기화
##       → 유효 spawn 무작위 선택 → 없으면 end_game, 있으면 origin 대입/emit.
## 결과: 성공하면 true와 새 활성 피스, 실패하면 false와 GAME_OVER 상태가 된다.
func spawn_next_piece() -> bool:
	active_type = next_type
	next_type = bag.next_piece()
	active_rotation = 0
	_reset_piece_timers()

	var spawn_origin: Variant = _choose_random_spawn_origin(active_type) # Vector2i 또는 불가를 뜻하는 null.
	if spawn_origin == null:
		end_game()
		return false
	active_origin = spawn_origin as Vector2i

	game_changed.emit()
	return true


## 상황: CharacterController가 명상을 시작/종료하거나 reset할 때 호출한다.
## 순서: 요청값과 `state == PLAYING`을 AND하여 meditation_active에 저장한다.
## 결과: game over/pause에서는 강제로 false이며 다음 `_process()` 시간 배율이 달라진다.
func set_meditation_active(active: bool) -> void:
	meditation_active = active and state == GameState.PLAYING


## 상황: 새 피스의 무작위 spawn x 후보 집합을 계산할 때 호출한다.
## 순서: 기본 모양 조회 → 빈 모양 조기 반환 → local min/max x 계산
##       → 보드 안 원점 x 순회 → `can_place()` 가능한 원점만 append.
## 결과: 현재 보드에서 실제 배치 가능한 Vector2i 후보 배열을 반환한다.
func _valid_spawn_origins(piece_type: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = MainTetrominoData.get_cells(piece_type, 0) # 회전 0의 로컬 셀.
	var candidates: Array[Vector2i] = [] # 실제 배치 가능한 spawn 원점 목록.
	if cells.is_empty():
		return candidates

	var minimum_x: int = cells[0].x # 모양 자체에서 가장 왼쪽 local x.
	var maximum_x: int = cells[0].x # 모양 자체에서 가장 오른쪽 local x.
	for cell: Vector2i in cells:
		minimum_x = mini(minimum_x, cell.x)
		maximum_x = maxi(maximum_x, cell.x)

	for origin_x: int in range(1 - minimum_x, MainBoardModel.WIDTH - 1 - maximum_x):
		var origin: Vector2i = Vector2i(origin_x, SPAWN_Y) # 양쪽 경계 한 열을 비운 spawn 원점.
		if board.can_place(piece_type, 0, origin):
			candidates.append(origin)
	return candidates


## 상황: `spawn_next_piece()`가 후보 중 실제 spawn 한 곳을 정할 때 호출한다.
## 순서: 유효 후보 계산 → 빈 배열이면 null → 아니면 균등 random index 조회.
## 결과: Vector2i 하나 또는 배치 불가능을 뜻하는 null Variant를 반환한다.
func _choose_random_spawn_origin(piece_type: int) -> Variant:
	var candidates: Array[Vector2i] = _valid_spawn_origins(piece_type) # 가능한 모든 원점.
	if candidates.is_empty():
		return null
	var index: int = _spawn_random.randi_range(0, candidates.size() - 1) # 선택된 후보 index.
	return candidates[index]


## 상황: 캐릭터 펀치가 활성 피스를 수평으로 여러 칸 밀 때 호출한다.
## 순서: 입력/state 검사 → 방향 ±1 정규화 → 모든 중간 위치 검증
##       → 이동 전 접지 저장 → origin 이동 → lock delay 조정 → emit.
## 결과: 전 경로가 비었을 때만 원자적으로 이동해 true, 막히면 변화 없이 false다.
func push_active_piece(direction: int, distance: int) -> bool:
	if state != GameState.PLAYING or direction == 0 or distance < 1:
		return false

	var normalized_direction: int = signi(direction) # 왼쪽 -1 또는 오른쪽 +1.
	for step: int in range(1, distance + 1):
		var target: Vector2i = active_origin + Vector2i(normalized_direction * step, 0) # 중간 후보.
		if not board.can_place(active_type, active_rotation, target):
			return false

	var was_grounded: bool = is_grounded() # 이동 전 접지 상태 snapshot.
	active_origin += Vector2i(normalized_direction * distance, 0)
	_reset_lock_after_transform(was_grounded)
	game_changed.emit()
	return true


## 상황: 캐릭터 회전 킥이 활성 피스를 시계/반시계 방향으로 돌릴 때 호출한다.
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
		if not board.can_place(active_type, new_rotation, target):
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
	for local_cell: Vector2i in MainTetrominoData.get_cells(piece_type, rotation):
		if origin + local_cell in forbidden_cells:
			return true
	return false


## 상황: 접지 lock delay가 끝나 활성 피스를 고정 블록으로 전환할 때 호출한다.
## 순서: PLAYING 검사 → board.lock_piece → clear_full_lines → 점수/줄/레벨
##       → hidden-row top-out이면 end_game → 아니면 spawn_next_piece.
## 결과: 현재 피스 수명이 끝나고 게임오버 또는 다음 피스로 전환된다.
func lock_active_piece() -> void:
	if state != GameState.PLAYING:
		return

	board.lock_piece(active_type, active_rotation, active_origin)
	var cleared: int = board.clear_full_lines() # 이번 고정으로 동시에 삭제된 행 수.
	if cleared > 0:
		score += line_clear_score(cleared, level)
		total_lines += cleared
		level = level_for_lines(total_lines)
		lines_cleared.emit()

	if board.has_blocks_in_hidden_rows():
		end_game()
		return
	spawn_next_piece()


## 상황: P/Esc 입력 또는 테스트가 일시정지 상태를 전환할 때 호출한다.
## 순서: GAME_OVER면 무시 → PLAYING/PAUSED 토글 → 비PLAYING이면 명상 해제 → emit.
## 결과: 다음 `_process()`의 시간 진행 여부와 화면 overlay가 바뀐다.
func toggle_pause() -> void:
	if state == GameState.GAME_OVER:
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
	game_changed.emit()


## 상황: lock delay나 이동/회전 전후의 바닥 접촉을 판정할 때 호출한다.
## 순서: 현재 원점보다 y+1 위치를 `board.can_place()`로 검사하고 논리 부정한다.
## 결과: 한 칸 아래로 이동할 수 없으면 true이며 상태는 바꾸지 않는다.
func is_grounded() -> bool:
	return not board.can_place(active_type, active_rotation, active_origin + Vector2i.DOWN)


## 상황: GameView가 활성 피스의 예상 착지 고스트를 그릴 때 호출한다.
## 순서: drop distance 조회 → 현재 원점에 `(0,distance)` 합산.
## 결과: 실제 피스를 움직이지 않고 예상 착지 원점을 반환한다.
func ghost_origin() -> Vector2i:
	var distance: int = board.get_drop_distance(active_type, active_rotation, active_origin) # 남은 셀 수.
	return active_origin + Vector2i(0, distance)


## 상황: 중력 accumulator의 한 셀 낙하 임계값이 필요할 때 호출한다.
## 순서: level-1마다 0.055초 차감 → `maxf`로 0.08초 하한 적용.
## 결과: 현재 level의 셀당 낙하 간격(초)을 반환한다.
func gravity_interval() -> float:
	return maxf(0.08, 0.70 - float(level - 1) * 0.055)


## 상황: 줄 삭제 직후 이번 삭제 점수를 계산할 때 호출한다.
## 순서: 기본점수 표 생성 → 1~4 범위 검사 → 기본점수×최소 1인 레벨.
## 결과: 잘못된 줄 수는 0, 정상 입력은 레벨 배율 점수를 반환한다.
static func line_clear_score(cleared_lines: int, current_level: int) -> int:
	var base_scores: Array[int] = [0, 100, 300, 550, 900] # index=동시 삭제 줄 수.
	if cleared_lines < 1 or cleared_lines >= base_scores.size():
		return 0
	return base_scores[cleared_lines] * maxi(current_level, 1)


## 상황: total_lines가 증가한 뒤 새 레벨을 계산할 때 호출한다.
## 순서: 음수 lines를 0으로 제한 → 10으로 나눈 몫 floor → 시작 레벨 1 더함.
## 결과: 0~9줄=1, 10~19줄=2 형태의 정수 레벨을 반환한다.
static func level_for_lines(lines: int) -> int:
	return 1 + floori(float(maxi(lines, 0)) / 10.0)


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
