class_name MainBoardModel
extends RefCounted

## [역할 / C++ 대응]
## 화면과 물리 엔진에 의존하지 않는 10×22 논리 보드다.
## `cells[y][x]`에는 EMPTY(-1) 또는 TetrominoData.Type 정수가 저장된다.
## C++로 보면 규칙을 담당하는 순수 모델 클래스이며, 소유자는 GameController다.
##
## [호출 관계]
## 생성자/주 호출자: GameController. 조회 호출자: GameView, BoardPhysics,
## CharacterController, 테스트. 이 클래스는 signal을 내보내지 않는다.
## 변경 알림은 상위 GameController가 담당한다.

const WIDTH: int = 10 # 보드의 가로 셀 수. 유효 x는 0~9.
const VISIBLE_HEIGHT: int = 20 # 플레이어에게 그려지는 행 수.
const HIDDEN_ROWS: int = 2 # 스폰/top-out 판정에 쓰는 화면 위 숨은 행 수.
const HEIGHT: int = VISIBLE_HEIGHT + HIDDEN_ROWS # 실제 저장되는 전체 행 수(22).
const EMPTY: int = -1 # 셀이 어떤 테트로미노에도 점유되지 않았음을 나타내는 sentinel.

# 행 우선 2차원 배열: `cells[y][x]`. PackedInt32Array는 연속 int32 저장소다.
var cells: Array[PackedInt32Array] = [] # 실제 보드 저장소. 바깥 index=y, 안쪽 index=x.


## 상황: `MainBoardModel.new()`로 논리 보드를 만들 때 자동 호출된다.
## 순서: `reset()` 한 단계로 22개의 빈 행을 구성한다.
## 결과: 즉시 배치 판정을 수행할 수 있는 빈 보드가 된다.
func _init() -> void:
	reset()


## 상황: 보드 생성 직후 또는 GameController가 게임을 재시작할 때 호출한다.
## 순서: ① 기존 cells clear ② HEIGHT번 `_empty_row()`를 만들어 append.
## 결과: 이전 고정 블록이 모두 사라지고 정확히 22×10 EMPTY 상태가 된다.
func reset() -> void:
	cells.clear()
	for _y: int in range(HEIGHT):
		cells.append(_empty_row())


## 임의의 활성 셀 배열을 보드 원점에 배치할 수 있는지 검사한다.
func can_place_cells(local_cells: Array[Vector2i], origin: Vector2i) -> bool:
	for local_cell: Vector2i in local_cells:
		var board_cell: Vector2i = origin + local_cell # 피스 로컬 좌표를 보드 절대 셀로 변환한 값.
		if not is_inside(board_cell):
			return false
		if cells[board_cell.y][board_cell.x] != EMPTY:
			return false
	return true


## 상황: GameView가 표시할 고스트의 최종 착지 위치가 필요할 때 호출된다.
## 순서: distance=0 → 한 칸 더 아래 후보를 `can_place_cells()` → 가능할 동안 1씩 증가.
## 결과: 현재 origin에서 충돌 직전까지 내려갈 수 있는 정수 셀 수를 반환한다.
func get_drop_distance_cells(local_cells: Array[Vector2i], origin: Vector2i) -> int:
	var distance: int = 0 # 현재 위치에서 안전하게 추가 낙하할 수 있다고 확인된 셀 수.
	while can_place_cells(local_cells, origin + Vector2i(0, distance + 1)):
		distance += 1
	return distance


## 상황: lock delay가 끝나 활성 피스를 논리 보드에 고정할 때 호출한다.
## 순서: 로컬 셀 순회 → 보드 좌표 변환 → 안전 범위 확인 → piece_type 기록.
## 결과: 해당 cells가 EMPTY에서 타입 정수로 바뀐다. 줄 삭제는 이 함수가 하지 않는다.
func lock_cells(piece_type: int, local_cells: Array[Vector2i], origin: Vector2i) -> void:
	for local_cell: Vector2i in local_cells:
		var board_cell: Vector2i = origin + local_cell # 실제 cells[y][x]에 기록할 절대 셀.
		if is_inside(board_cell):
			cells[board_cell.y][board_cell.x] = piece_type


## 상황: 피스를 고정한 직후 완성된 줄을 정리하고 삭제 개수가 필요할 때 호출한다.
## 순서: ① 모든 행 검사 ② 찬 행은 개수만 증가 ③ 나머지는 복사해 survivors에 보존
##       ④ HEIGHT가 될 때까지 빈 행을 앞에 삽입 ⑤ cells 교체.
## 결과: 완성 행이 사라지고 위 행이 아래로 내려오며 제거한 줄 수를 반환한다.
func clear_full_lines() -> int:
	var survivors: Array[PackedInt32Array] = [] # 삭제되지 않고 상대 순서를 유지할 행 복사본.
	var cleared: int = 0 # 이번 호출에서 발견한 완성 행 수.

	# 남은 행의 상대 순서를 보존한 뒤, 삭제된 수만큼 빈 행을 위에 보충한다.
	for y: int in range(HEIGHT):
		if _is_row_full(y):
			cleared += 1
		else:
			survivors.append(cells[y].duplicate())

	while survivors.size() < HEIGHT:
		survivors.push_front(_empty_row())

	cells = survivors
	return cleared


## 상황: 줄 정리 후 새 피스를 만들기 전에 top-out 여부를 판단할 때 호출한다.
## 순서: 숨은 y=0~1의 모든 x를 순회하고 EMPTY가 아닌 첫 셀에서 true 반환.
## 결과: 숨은 행에 블록이 하나라도 있으면 true, 전부 비었으면 false다.
func has_blocks_in_hidden_rows() -> bool:
	for y: int in range(HIDDEN_ROWS):
		for x: int in range(WIDTH):
			if cells[y][x] != EMPTY:
				return true
	return false


## 상황: 임의 Vector2i로 cells에 접근하기 전 안전성을 확인할 때 호출한다.
## 순서: x 하한/상한과 y 하한/상한을 논리 AND로 평가한다.
## 결과: 유효 범위 `[0,WIDTH) × [0,HEIGHT)` 안일 때만 true다.
func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT


## 상황: CharacterController나 테스트가 셀을 안전하게 읽을 때 호출한다.
## 순서: ① `is_inside()` ② 범위 밖이면 EMPTY 조기 반환 ③ 안이면 cells[y][x] 조회.
## 결과: 저장 타입 정수 또는 범위 밖을 뜻하는 EMPTY를 반환한다.
func get_cell(cell: Vector2i) -> int:
	if not is_inside(cell):
		return EMPTY
	return cells[cell.y][cell.x]


## 고정 블록 하나를 인접한 빈 셀로 옮긴다. 특수 스킬용 원자적 모델 연산이다.
func move_cell(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not is_inside(from_cell) or not is_inside(to_cell):
		return false
	if cells[from_cell.y][from_cell.x] == EMPTY or cells[to_cell.y][to_cell.x] != EMPTY:
		return false
	var piece_type: int = cells[from_cell.y][from_cell.x]
	cells[from_cell.y][from_cell.x] = EMPTY
	cells[to_cell.y][to_cell.x] = piece_type
	return true


## 고정 블록 한 칸을 제거한다. 범위 밖이나 빈 셀은 false다.
func remove_cell(cell: Vector2i) -> bool:
	if not is_inside(cell) or cells[cell.y][cell.x] == EMPTY:
		return false
	cells[cell.y][cell.x] = EMPTY
	return true


## 상황: `clear_full_lines()`가 행 하나의 삭제 여부를 판단할 때 호출한다.
## 순서: x를 순회하고 EMPTY를 발견하면 즉시 false, 끝까지 없으면 true.
## 결과: 행을 변경하지 않고 완성 여부만 반환한다.
func _is_row_full(y: int) -> bool:
	for x: int in range(WIDTH):
		if cells[y][x] == EMPTY:
			return false
	return true


## 상황: reset 또는 줄 삭제 후 보충용 빈 행이 필요할 때 호출한다.
## 순서: ① PackedInt32Array 생성 ② WIDTH로 resize ③ 모든 원소를 EMPTY로 fill.
## 결과: 다른 행과 저장소를 공유하지 않는 새 10칸 배열을 반환한다.
func _empty_row() -> PackedInt32Array:
	var row: PackedInt32Array = PackedInt32Array() # 호출자에게 넘길 새 연속 int32 행 저장소.
	row.resize(WIDTH)
	row.fill(EMPTY)
	return row
