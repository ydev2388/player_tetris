class_name MainBoardModel
extends RefCounted

## Pure 10x22 logical board with transactional cell mutation and detached snapshots.
## MainGameSession owns this model; View, Physics, and tests read it through controller/session APIs.

const WIDTH: int = 10 # 보드의 가로 셀 수. 유효 x는 0~9.
const VISIBLE_HEIGHT: int = 20 # 플레이어에게 그려지는 행 수.
const HIDDEN_ROWS: int = 2 # 스폰/top-out 판정에 쓰는 화면 위 숨은 행 수.
const HEIGHT: int = VISIBLE_HEIGHT + HIDDEN_ROWS # 실제 저장되는 전체 행 수(22).
const EMPTY: int = -1 # 셀이 어떤 테트로미노에도 점유되지 않았음을 나타내는 sentinel.

# 행 우선 2차원 배열. 외부에는 복사 snapshot과 조회/명령 API만 노출한다.
# GDScript의 `_`는 강제 private는 아니지만, 제품 코드와 테스트 모두 이 경계를 지킨다.
var _cells: Array[PackedInt32Array] = []
var _ice_cells: Array[PackedByteArray] = []


## 상황: `MainBoardModel.new()`로 논리 보드를 만들 때 자동 호출된다.
## 순서: `reset()` 한 단계로 22개의 빈 행을 구성한다.
## 결과: 즉시 배치 판정을 수행할 수 있는 빈 보드가 된다.
func _init() -> void:
	reset()


## 상황: 보드 생성 직후 또는 GameController가 게임을 재시작할 때 호출한다.
## 순서: ① 기존 cells clear ② HEIGHT번 `_empty_row()`를 만들어 append.
## 결과: 이전 고정 블록이 모두 사라지고 정확히 22×10 EMPTY 상태가 된다.
func reset() -> void:
	_cells.clear()
	_ice_cells.clear()
	for _y: int in range(HEIGHT):
		_cells.append(_empty_row())
		_ice_cells.append(_empty_ice_row())


func is_ice_cell(cell: Vector2i) -> bool:
	return is_inside(cell) and _ice_cells[cell.y][cell.x] == 1


func _set_ice_cell(cell: Vector2i, active: bool) -> void:
	if is_inside(cell):
		_ice_cells[cell.y][cell.x] = 1 if active else 0


## View/Physics/테스트가 보드 전체를 비교해야 할 때 쓰는 읽기 전용 deep copy다.
## 반환 배열을 변경해도 원본 보드는 바뀌지 않는다.
func create_snapshot() -> Dictionary:
	var cell_rows: Array[PackedInt32Array] = []
	var ice_rows: Array[PackedByteArray] = []
	for y: int in range(HEIGHT):
		cell_rows.append(_cells[y].duplicate())
		ice_rows.append(_ice_cells[y].duplicate())
	return {
		"cells": cell_rows,
		"ice_cells": ice_rows,
	}


## BoardPhysics의 변경 감지용 값이다. 내부 배열 자체는 노출하지 않는다.
func content_signature() -> int:
	return hash([_cells, _ice_cells])


## 단일 셀을 불변식을 지키며 변경한다. EMPTY 셀에는 얼음 metadata를 남기지 않는다.
## 테스트 fixture와 향후 stage setup도 raw 배열 대신 이 명령을 사용한다.
func set_cell(cell: Vector2i, piece_type: int, ice: bool = false) -> bool:
	if not is_inside(cell) or not _is_valid_piece_type(piece_type, true):
		return false
	_cells[cell.y][cell.x] = piece_type
	_set_ice_cell(cell, ice and piece_type != EMPTY)
	return true


func _empty_row() -> PackedInt32Array:
	var row: PackedInt32Array = PackedInt32Array()
	row.resize(WIDTH)
	row.fill(EMPTY)
	return row


func _empty_ice_row() -> PackedByteArray:
	var row: PackedByteArray = PackedByteArray()
	row.resize(WIDTH)
	row.fill(0)
	return row


## 임의의 활성 셀 배열을 보드 원점에 배치할 수 있는지 검사한다.
func can_place_cells(local_cells: Array[Vector2i], origin: Vector2i) -> bool:
	for local_cell: Vector2i in local_cells:
		var board_cell: Vector2i = origin + local_cell # 피스 로컬 좌표를 보드 절대 셀로 변환한 값.
		if not is_inside(board_cell):
			return false
		if _cells[board_cell.y][board_cell.x] != EMPTY:
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
## 결과: 모든 대상이 유효할 때만 한 번에 고정하고 true를 반환한다.
##       범위 밖·중복·점유 대상이 하나라도 있으면 원본을 바꾸지 않고 false다.
func lock_cells(
	piece_type: int,
	local_cells: Array[Vector2i],
	origin: Vector2i,
	ice: bool = false
) -> bool:
	if not _is_valid_piece_type(piece_type) or local_cells.is_empty():
		return false
	var target_cells: Array[Vector2i] = []
	for local_cell: Vector2i in local_cells:
		var board_cell: Vector2i = origin + local_cell
		if (
			not is_inside(board_cell)
			or board_cell in target_cells
			or _cells[board_cell.y][board_cell.x] != EMPTY
		):
			return false
		target_cells.append(board_cell)
	for board_cell: Vector2i in target_cells:
		_cells[board_cell.y][board_cell.x] = piece_type
		_set_ice_cell(board_cell, ice)
	return true


## 상황: 피스를 고정한 직후 완성된 줄을 정리하고 삭제 개수가 필요할 때 호출한다.
## 순서: ① 모든 행 검사 ② 찬 행은 개수만 증가 ③ 나머지는 복사해 survivors에 보존
##       ④ HEIGHT가 될 때까지 빈 행을 앞에 삽입 ⑤ cells 교체.
## 결과: 완성 행이 사라지고 위 행이 아래로 내려오며 제거한 줄 수를 반환한다.
func clear_full_lines() -> int:
	var survivors: Array[PackedInt32Array] = [] # 삭제되지 않고 상대 순서를 유지한 행 복사본.
	var ice_survivors: Array[PackedByteArray] = []
	var cleared: int = 0 # 이번 호출에서 동시에 삭제된 행 수.

	# 남은 행의 상대 순서를 보존한 뒤, 삭제된 수만큼 빈 행을 위에 보충한다.
	for y: int in range(HEIGHT):
		if _is_row_full(y):
			cleared += 1
		else:
			survivors.append(_cells[y].duplicate())
			ice_survivors.append(_ice_cells[y].duplicate())

	while survivors.size() < HEIGHT:
		survivors.push_front(_empty_row())
		ice_survivors.push_front(_empty_ice_row())

	_cells = survivors
	_ice_cells = ice_survivors
	return cleared



## 상황: 줄 정리 후 새 피스를 만들기 전에 top-out 여부를 판단할 때 호출한다.
## 순서: 숨은 y=0~1의 모든 x를 순회하고 EMPTY가 아닌 첫 셀에서 true 반환.
## 결과: 숨은 행에 블록이 하나라도 있으면 true, 전부 비었으면 false다.
func has_blocks_in_hidden_rows() -> bool:
	for y: int in range(HIDDEN_ROWS):
		for x: int in range(WIDTH):
			if _cells[y][x] != EMPTY:
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
	return _cells[cell.y][cell.x]


## 고정 블록 하나를 인접한 빈 셀로 옮긴다. 특수 스킬용 원자적 모델 연산이다.
func move_cell(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not is_inside(from_cell) or not is_inside(to_cell):
		return false
	if _cells[from_cell.y][from_cell.x] == EMPTY or _cells[to_cell.y][to_cell.x] != EMPTY:
		return false
	var piece_type: int = _cells[from_cell.y][from_cell.x]
	var ice: bool = is_ice_cell(from_cell)
	_cells[from_cell.y][from_cell.x] = EMPTY
	_cells[to_cell.y][to_cell.x] = piece_type
	_set_ice_cell(from_cell, false)
	_set_ice_cell(to_cell, ice)
	return true


## 고정 블록 한 칸을 제거한다. 범위 밖이나 빈 셀은 false다.
func remove_cell(cell: Vector2i) -> bool:
	if not is_inside(cell) or _cells[cell.y][cell.x] == EMPTY:
		return false
	_cells[cell.y][cell.x] = EMPTY
	_set_ice_cell(cell, false)
	return true


## 상황: `clear_full_lines()`가 행 하나의 삭제 여부를 판단할 때 호출한다.
## 순서: x를 순회하고 EMPTY를 발견하면 즉시 false, 끝까지 없으면 true.
## 결과: 행을 변경하지 않고 완성 여부만 반환한다.
func _is_row_full(y: int) -> bool:
	for x: int in range(WIDTH):
		if _cells[y][x] == EMPTY:
			return false
	return true


func _is_valid_piece_type(piece_type: int, allow_empty: bool = false) -> bool:
	if allow_empty and piece_type == EMPTY:
		return true
	return piece_type >= 0 and piece_type < MainTetrominoData.TYPE_COUNT
