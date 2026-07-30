class_name Stage4TetrominoData
extends RefCounted

## [역할 / C++ 대응]
## 테트로미노 7종의 모양, 색, 표시 이름을 제공하는 불변 데이터 유틸리티다.
## `class_name`은 전역에서 쓸 수 있는 타입 이름을 등록하며, `extends RefCounted`는
## C++의 참조 카운트 기반 경량 객체와 비슷하다. 모든 API가 `static func`이므로
## 인스턴스를 만들지 않고 `Stage4TetrominoData.get_cells(...)`처럼 호출한다.
##
## [호출 관계]
## 호출자: PieceBag(종류 개수), BoardModel(배치/고정), GameController(스폰/회전),
##         BoardPhysics(충돌체), GameView(렌더링), CharacterController(상호작용 판정).
## 호출 대상: Godot의 Vector2i/Color/배열 연산만 사용하며 다른 게임 객체는 호출하지 않는다.

# C++의 `enum class Type`에 가까운 정수 열거형이다.
enum Type {
	I,
	J,
	L,
	O,
	S,
	T,
	Z,
}

const TYPE_COUNT: int = 7 # Type enum에 들어 있는 서로 다른 테트로미노 종류 수.

# Type enum 정수를 같은 index의 표시 색에 대응시킨다.
const COLORS: Array[Color] = [
	Color("#38d9ff"), # I
	Color("#4d7cff"), # J
	Color("#ff9f43"), # L
	Color("#ffd93d"), # O
	Color("#56e39f"), # S
	Color("#b86bff"), # T
	Color("#ff5c74"), # Z
]


## 상황: 보드 판정, 렌더링, 충돌체, 캐릭터 상호작용이 피스 모양을 요구할 때 호출된다.
## 순서: ① `_base_cells()`로 0도 모양 복사 ② O면 즉시 반환
##       ③ rotation을 0~3으로 정규화 ④ 그 횟수만큼 `_rotate_clockwise()` 적용.
## 결과: 피스 원점(origin)을 기준으로 한 네 칸의 로컬 좌표를 반환하며 전역 상태는 바꾸지 않는다.
static func get_cells(piece_type: int, rotation: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = _base_cells(piece_type) # 회전을 누적할 작업용 좌표 복사본.
	if piece_type == Type.O:
		return cells

	var turns: int = posmod(rotation, 4) # 음수 회전도 0~3회의 시계방향 회전으로 정규화한 값.
	for _turn: int in range(turns):
		cells = _rotate_clockwise(cells, piece_type == Type.I)
	return cells


## 상황: 테스트나 보조 UI가 타입에 대응하는 대표색을 요구할 때 호출된다.
## 순서: ① 배열 index 범위 검사 ② 범위 밖이면 흰색, 안이면 COLORS의 같은 index 조회.
## 결과: Color 값을 반환하며 데이터 테이블은 변경하지 않는다.
static func get_color(piece_type: int) -> Color:
	if piece_type < 0 or piece_type >= COLORS.size():
		return Color.WHITE
	return COLORS[piece_type]


## 상황: GameView._draw_block()이 스프라이트 atlas의 문자열 key를 만들 때 호출한다.
## 순서: `match`(C++ switch)로 enum을 비교하고 대응 문자 반환, `_`(default)는 "?" 반환.
## 결과: I/J/L/O/S/T/Z 중 하나 또는 잘못된 타입을 뜻하는 "?"를 반환한다.
static func get_display_name(piece_type: int) -> String:
	match piece_type:
		Type.I:
			return "I"
		Type.J:
			return "J"
		Type.L:
			return "L"
		Type.O:
			return "O"
		Type.S:
			return "S"
		Type.T:
			return "T"
		Type.Z:
			return "Z"
		_:
			return "?"


## 상황: `get_cells()`가 회전을 적용하기 전 원본 좌표가 필요할 때만 호출한다.
## 순서: ① 빈 배열 생성 ② 타입별 `match` ③ 회전 0의 네 Vector2i를 대입.
## 결과: 새 배열을 반환하므로 호출자가 회전시켜도 상수 원본은 훼손되지 않는다.
static func _base_cells(piece_type: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [] # 선택된 타입의 네 로컬 셀을 담아 반환할 배열.
	match piece_type:
		Type.I:
			cells = [
				Vector2i(0, 1),
				Vector2i(1, 1),
				Vector2i(2, 1),
				Vector2i(3, 1),
			]
		Type.J:
			cells = [
				Vector2i(0, 0),
				Vector2i(0, 1),
				Vector2i(1, 1),
				Vector2i(2, 1),
			]
		Type.L:
			cells = [
				Vector2i(2, 0),
				Vector2i(0, 1),
				Vector2i(1, 1),
				Vector2i(2, 1),
			]
		Type.O:
			cells = [
				Vector2i(1, 0),
				Vector2i(2, 0),
				Vector2i(1, 1),
				Vector2i(2, 1),
			]
		Type.S:
			cells = [
				Vector2i(1, 0),
				Vector2i(2, 0),
				Vector2i(0, 1),
				Vector2i(1, 1),
			]
		Type.T:
			cells = [
				Vector2i(1, 0),
				Vector2i(0, 1),
				Vector2i(1, 1),
				Vector2i(2, 1),
			]
		Type.Z:
			cells = [
				Vector2i(0, 0),
				Vector2i(1, 0),
				Vector2i(1, 1),
				Vector2i(2, 1),
			]
	return cells


## 상황: `get_cells()`가 현재 좌표를 시계 방향으로 한 번 돌려야 할 때 호출한다.
## 순서: ① 빈 결과 배열 생성 ② I면 (1.5,1.5), 나머지는 (1,1) 기준 상대좌표 계산
##       ③ `(x,y) -> (-y,x)` 변환 ④ 중심점을 다시 더해 결과 배열에 append.
## 결과: 90도 회전된 새 배열을 반환한다. range-for 문법은 C++ range-for와 같다.
static func _rotate_clockwise(cells: Array[Vector2i], is_i_piece: bool) -> Array[Vector2i]:
	var rotated: Array[Vector2i] = [] # 입력과 별도로 생성되는 90도 회전 결과.
	if is_i_piece:
		for cell: Vector2i in cells:
			var relative_x: float = float(cell.x) - 1.5 # I 회전중심 기준 x.
			var relative_y: float = float(cell.y) - 1.5 # I 회전중심 기준 y.
			rotated.append(Vector2i(
				int(round(1.5 - relative_y)),
				int(round(1.5 + relative_x))
			))
	else:
		for cell: Vector2i in cells:
			var relative: Vector2i = cell - Vector2i.ONE # (1,1) 회전중심 기준 좌표.
			rotated.append(Vector2i(-relative.y, relative.x) + Vector2i.ONE)
	return rotated
