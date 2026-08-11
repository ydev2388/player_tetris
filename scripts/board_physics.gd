class_name MainBoardPhysics
extends Node2D

## [역할 / C++ 대응]
## 논리 BoardModel을 Godot 2D 충돌체로 투영하는 어댑터다.
## BoardModel이 authoritative state이고, 이 노드는 StaticBody2D를
## 재구성할 뿐 게임 규칙을 결정하지 않는다. 자연 낙하 압사 규칙은
## GameController의 전용 신호를 받은 CharacterController가 처리한다.
##
## [호출 관계]
## Godot가 `_ready()`를 호출한다. 이후 GameController의 `game_changed` /
## `game_restarted` signal이 동기화를 호출한다. 동기화 뒤에는
## CharacterController.validate_position()을 안전망으로 deferred call한다.
## 씬 경로 `$Node`는 C++에서 미리 주입받은 자식 노드 포인터와 비슷하다.

const CELL_SIZE: float = MainLayout.CELL_SIZE # 화면·물리가 공유하는 48px 셀.
const BOARD_PIXEL_SIZE: Vector2 = Vector2(
	MainBoardModel.WIDTH * CELL_SIZE,
	MainBoardModel.VISIBLE_HEIGHT * CELL_SIZE
) # 화면에 보이는 보드의 전체 픽셀 크기(480×960).

# main.tscn에서 주입되는 협력 노드들.
@onready var controller: MainGameController = $"../GameController" # authoritative BoardModel 소유자.
@onready var locked_body: StaticBody2D = $LockedBlocks # 이미 고정된 셀 collision의 부모.
@onready var active_body: StaticBody2D = $ActivePiece # 낙하 중 피스 collision의 부모.
@onready var character: MainCharacterController = $Character # 겹침 재검증을 요청할 플레이어.

# 논리 보드가 같을 때 수백 개의 고정 CollisionShape 재생성을 피하는 캐시다.
var _last_board_signature: int = -1 # 마지막 collider 재구성 때의 고정 보드 hash.


## 상황: main.tscn의 BoardPhysics가 씬 트리에 들어올 때 Godot가 한 번 호출한다.
## 순서: ① `_build_boundaries()` ② controller의 change/restart signal 연결
##       ③ `_sync_from_model()`로 최초 collision 생성.
## 결과: 이후 모델 변경이 자동으로 물리 collision에 반영되는 구독 관계가 완성된다.
func _ready() -> void:
	_build_boundaries()
	controller.game_changed.connect(_sync_from_model)
	controller.game_restarted.connect(_on_game_restarted)
	_sync_from_model()


## 상황: 최초 준비, 게임 재시작, controller.game_changed signal 때 호출된다.
## 순서: ① `_board_signature()` 계산 ② 고정 보드가 달라졌을 때만 collider 재구성
##       ③ 활성 피스는 항상 동기화 ④ 캐릭터 검증을 deferred queue에 등록.
## 결과: 논리 모델과 물리 공간이 일치한다. deferred는 현재 signal 처리가 끝난 뒤 실행된다.
func _sync_from_model() -> void:
	var signature: int = _board_signature() # 현재 고정 셀 전체에서 계산한 변경 감지 hash.
	if signature != _last_board_signature:
		_last_board_signature = signature
		_rebuild_locked_colliders()
	_sync_active_piece()
	_validate_character.call_deferred()


## 상황: GameController.reset_game()이 game_restarted signal을 emit할 때 호출된다.
## 순서: ① signature를 불가능한 초기값 -1로 되돌림 ② `_sync_from_model()`.
## 결과: 새 보드가 우연히 이전 hash와 같아도 고정 collider를 반드시 다시 만든다.
func _on_game_restarted() -> void:
	_last_board_signature = -1
	_sync_from_model()


## 상황: 물리 노드의 최초 `_ready()`에서 보드 외곽 collision을 만들 때 호출한다.
## 순서: 같은 Boundaries body에 바닥 → 왼쪽 벽 → 오른쪽 벽 사각형을 차례로 추가.
## 결과: 캐릭터가 화면 아래·좌·우 보드 경계를 통과하지 못한다.
func _build_boundaries() -> void:
	var boundaries: StaticBody2D = $Boundaries # 세 외곽 collision shape를 소유할 정적 body.
	_add_box_shape(
		boundaries,
		Vector2(BOARD_PIXEL_SIZE.x * 0.5, BOARD_PIXEL_SIZE.y + CELL_SIZE * 0.5),
		Vector2(BOARD_PIXEL_SIZE.x, CELL_SIZE)
	)
	_add_box_shape(
		boundaries,
		Vector2(-CELL_SIZE * 0.5, BOARD_PIXEL_SIZE.y * 0.5 - CELL_SIZE),
		Vector2(CELL_SIZE, BOARD_PIXEL_SIZE.y + CELL_SIZE * 4.0)
	)
	_add_box_shape(
		boundaries,
		Vector2(BOARD_PIXEL_SIZE.x + CELL_SIZE * 0.5, BOARD_PIXEL_SIZE.y * 0.5 - CELL_SIZE),
		Vector2(CELL_SIZE, BOARD_PIXEL_SIZE.y + CELL_SIZE * 4.0)
	)


## 상황: `_sync_from_model()`이 고정 셀 hash 변화를 감지했을 때 호출한다.
## 순서: ① 이전 shape 전부 제거 ② 전체 cells 순회 ③ EMPTY 건너뜀
##       ④ 논리 셀 중심을 픽셀 좌표로 변환 ⑤ 48×48 shape 추가.
## 결과: locked_body의 자식 collision들이 현재 BoardModel과 정확히 대응한다.
func _rebuild_locked_colliders() -> void:
	_clear_shapes(locked_body)
	for y: int in range(MainBoardModel.HEIGHT):
		for x: int in range(MainBoardModel.WIDTH):
			if controller.board.cells[y][x] == MainBoardModel.EMPTY:
				continue
			var center: Vector2 = Vector2( # 숨은 행 offset을 뺀 해당 셀의 픽셀 중심.
				(float(x) + 0.5) * CELL_SIZE,
				(float(y - MainBoardModel.HIDDEN_ROWS) + 0.5) * CELL_SIZE
			)
			_add_box_shape(locked_body, center, Vector2.ONE * CELL_SIZE)


## 상황: game_changed마다 움직일 수 있는 활성 피스 collision을 갱신할 때 호출한다.
## 순서: ① 이전 네 shape 제거 ② active_body 원점을 픽셀로 이동 ③ game over면 종료
##       ④ TetrominoData의 네 로컬 셀마다 shape 생성.
## 결과: StaticBody2D가 controller의 활성 타입·회전·원점과 일치한다.
func _sync_active_piece() -> void:
	_clear_shapes(active_body)
	active_body.position = Vector2(
		controller.active_origin.x * CELL_SIZE,
		(controller.active_origin.y - MainBoardModel.HIDDEN_ROWS) * CELL_SIZE
	)
	if controller.state == MainGameController.GameState.GAME_OVER:
		return

	for cell: Vector2i in controller.active_local_cells():
		_add_box_shape(
			active_body,
			(Vector2(cell) + Vector2.ONE * 0.5) * CELL_SIZE,
			Vector2.ONE * CELL_SIZE
		)


## 상황: body의 이전 셀 collision들을 새 모델로 교체하기 직전에 호출한다.
## 순서: 자식 snapshot 순회 → CollisionShape2D만 RTTI 검사 → 부모에서 제거 → 즉시 free.
## 결과: 대상 body 자체와 다른 종류 자식은 유지되고 shape 자식만 사라진다.
func _clear_shapes(body: CollisionObject2D) -> void:
	for child: Node in body.get_children():
		if child is CollisionShape2D:
			body.remove_child(child)
			child.free()


## 상황: 경계 또는 블록 한 칸에 대응하는 사각 collision이 필요할 때 호출한다.
## 순서: ① RectangleShape2D 생성/크기 설정 ② CollisionShape2D 생성
##       ③ shape와 중심 위치 대입 ④ body의 자식으로 추가.
## 결과: body가 새 사각 collision의 수명과 물리 동작을 소유한다.
func _add_box_shape(body: CollisionObject2D, center: Vector2, box_size: Vector2) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new() # 실제 사각 기하 정보 리소스.
	shape.size = box_size
	var collision: CollisionShape2D = CollisionShape2D.new() # shape를 물리 body에 연결하는 노드.
	collision.shape = shape
	collision.position = center
	body.add_child(collision)


## 상황: 고정 collider 재생성이 필요한지 빠르게 판별할 때 호출한다.
## 순서: seed 17에서 시작해 행 우선 모든 셀을 `hash*31 + value+2`로 누적.
## 결과: 보드를 바꾸지 않고 현재 셀 배열의 정수 signature를 반환한다.
func _board_signature() -> int:
	var signature: int = 17 # 31 기반 rolling hash의 초기 seed.
	for y: int in range(MainBoardModel.HEIGHT):
		for x: int in range(MainBoardModel.WIDTH):
			signature = signature * 31 + controller.board.cells[y][x] + 2
	return signature


## 상황: 새 collision이 물리 공간에 반영된 다음 frame 끝에서 deferred 호출된다.
## 순서: ① character 참조가 아직 유효한지 검사 ② `validate_position()` 호출.
## 결과: 비정상 보드 이탈만 무피해 안전 위치로 복구하며 삭제된 객체 호출은 피한다.
func _validate_character() -> void:
	if is_instance_valid(character):
		character.validate_position()
