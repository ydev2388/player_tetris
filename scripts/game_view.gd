class_name MainGameView
extends Control

## [역할 / C++ 대응]
## main.tscn의 루트 Control이며 게임 상태를 읽어 보드/HUD를 그리는 View다.
## 규칙을 변경하지 않고 Controller/Character의 public state를 표시한다.
##
## [호출 관계]
## Godot: `_ready()`, redraw 요청 때 `_draw()`.
## GameController.game_changed 및 CharacterController의 두 signal: `_refresh()`.
## 호출 대상: GameController(ghost_origin 등), TetrominoData, CharacterController getter,
##           Godot CanvasItem의 draw_* API.
##
## `@onready var x = $Path`는 노드가 씬 트리에 준비된 뒤 child pointer를 캐시한다.
## `queue_redraw()`는 즉시 그리지 않고 다음 draw pass에 `_draw()` 호출을 예약한다.

const DISPLAY_SCALE: float = MainLayout.DISPLAY_SCALE
const CELL_SIZE: float = MainLayout.CELL_SIZE
const GAME_VIEWPORT_SIZE: Vector2i = MainLayout.GAME_VIEWPORT_SIZE
const BOARD_ORIGIN: Vector2 = MainLayout.BOARD_ORIGIN
const BOARD_SIZE: Vector2 = MainLayout.BOARD_SIZE
const HUD_RECT: Rect2 = Rect2(Vector2(40.0, 10.0), Vector2(480.0, 96.0))
const NEXT_CARD_RECT: Rect2 = Rect2(Vector2(366.0, 14.0), Vector2(144.0, 88.0))
const SELF_RESPAWN_BAR_RECT: Rect2 = Rect2(
	MainLayout.BOARD_ORIGIN + Vector2(84.0, MainLayout.BOARD_SIZE.y - 78.0),
	Vector2(312.0, 12.0)
)
const SELF_RESPAWN_PANEL_RECT: Rect2 = Rect2(
	MainLayout.BOARD_ORIGIN + Vector2(48.0, MainLayout.BOARD_SIZE.y - 94.0),
	Vector2(384.0, 76.0)
)

# 고정 UI theme 색상.
const BACKGROUND_COLOR: Color = Color("#f7f8fb") # 전체 창 배경.
const BOARD_COLOR: Color = Color("#dce3ed") # 빈 보드와 다음 피스 preview 배경.
const GRID_COLOR: Color = Color("#8390a3") # 셀·bar 외곽선.
const PANEL_COLOR: Color = Color("#ffffff") # 보드/HUD panel 표면.
const TEXT_COLOR: Color = Color("#152033") # 주요 제목과 수치.
const CYAN: Color = Color("#2c8fd6") # stamina/캐릭터 강조색.
const ORANGE: Color = Color("#e47719") # feedback 강조색.

# sprite atlas와 piece 이름 -> atlas source Rect 매핑.
const BLOCK_TEXTURE: Texture2D = preload("res://assets/sprites/block_sprites.png")
const BLOCK_SPRITE_REGIONS: Dictionary = {
	"I": Rect2(80, 255, 210, 215),
	"O": Rect2(360, 255, 210, 215),
	"T": Rect2(640, 255, 210, 215),
	"S": Rect2(915, 255, 210, 215),
	"Z": Rect2(1190, 255, 210, 215),
	"J": Rect2(1470, 255, 210, 215),
	"L": Rect2(1745, 255, 210, 215),
}

const THORN_TEXTURE: Texture2D = preload("res://assets/sprites/thron_sprite.png")
const THORN_SOURCE_REGION: Rect2 = Rect2(500.0, 64.0, 128.0, 104.0)
const THORN_DEPTH: float = 18.0
const THORN_EDGE_OVERLAP: float = 6.0
const BIND_TEXTURE: Texture2D = preload("res://assets/sprites/bind_sprite.png")
const BIND_SOURCE_REGION: Rect2 = Rect2(337.0, 65.0, 277.0, 364.0)
const BIND_DISPLAY_SIZE: Vector2 = Vector2(78.0, 108.0)

# main.tscn의 자식 노드 참조. C++에서 scene dependency를 pointer로 캐시한 것과 같다.
@onready var controller: MainGameController = $GameController # 표시할 게임 상태의 소유자.
@onready var character: MainCharacterController = $BoardPhysics/Character # 표시할 캐릭터 상태.

# `_build_interface()`가 생성하고 `_refresh()`가 내용을 바꾸는 retained UI 노드.
var _lines_label: Label
var _lives_label: Label
var _next_label: Label
var _timer_label: Label
var _feedback_label: Label # 최근 캐릭터 행동 성공/실패 메시지.
var _status_label: Label # pause 또는 game-over 중앙 overlay 문구.
var _self_respawn_panel: Panel # hold 중 캐릭터·블록 위에 표시하는 진행 배경.
var _self_respawn_fill: ColorRect # 0~1 hold 비율만큼 넓어지는 주황색 막대.
var _binding_sprite: Sprite2D # 캐릭터 위에 표시하는 속박 덩굴 overlay.
var _system_font: SystemFont # 위 Label과 draw_string이 공유할 한글 지원 폰트.


## 상황: main.tscn의 루트 View가 씬 트리에 들어올 때 Godot가 한 번 호출한다.
## 순서: SystemFont 생성/후보 지정 → `_build_interface()` → 세 signal 연결 → `_refresh()`.
## 결과: retained Label UI가 만들어지고 이후 상태 변경을 자동 반영한다.
func _ready() -> void:
	_apply_game_viewport_size()
	_system_font = SystemFont.new()
	_system_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	_build_interface()
	_create_binding_overlay()
	controller.game_changed.connect(_refresh)
	character.stats_changed.connect(_refresh)
	character.feedback_changed.connect(_refresh)
	character.binding_started.connect(_refresh)
	character.binding_ended.connect(_refresh)
	_refresh()


## 상황: 최초 표시 또는 `queue_redraw()` 이후 Godot CanvasItem draw pass에서 호출된다.
## 순서: 배경 → 상단 HUD → 보드 panel → 보드 → 명상효과 → next → 상태 overlay.
## 결과: 그 frame의 controller/character 상태가 즉시-mode draw 명령으로 화면에 표현된다.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	_draw_hud()
	_draw_panel(Rect2(BOARD_ORIGIN - Vector2(12.0, 12.0), BOARD_SIZE + Vector2(24.0, 24.0)))
	_draw_board()
	_draw_meditation_effect()
	_draw_binding()
	_draw_next_piece()
	_draw_state_overlay()


## 상황: `_ready()`에서 값이 바뀌는 텍스트 UI를 최초 한 번 구성할 때 호출한다.
## 순서: 파괴 줄/next/feedback/status Label 생성
##       → 각 Label별 shadow/alignment/z-index/line spacing을 설정.
## 결과: 이후 `_refresh()`가 참조할 멤버 Label들이 모두 유효해진다.
func _build_interface() -> void:
	_lines_label = _create_label("", Vector2(80.0, 24.0), Vector2(150.0, 24.0), 18, Color("#b4233b"))
	_lines_label.name = "LinesLabel"
	_lines_label.add_theme_constant_override("outline_size", 1)
	_lines_label.add_theme_color_override("font_outline_color", Color("#b4233b"))
	_lives_label = _create_label("", Vector2(205.0, 42.0), Vector2(150.0, 34.0), 22, TEXT_COLOR)
	_lives_label.name = "LivesLabel"
	_lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lives_label.add_theme_constant_override("outline_size", 1)
	_lives_label.add_theme_color_override("font_outline_color", TEXT_COLOR)
	_next_label = _create_label("NEXT", Vector2(380.0, 23.0), Vector2(72.0, 20.0), 14, TEXT_COLOR)
	_next_label.name = "NextLabel"
	_next_label.z_index = 5
	_timer_label = _create_label("", Vector2(82.0, 55.0), Vector2(128.0, 38.0), 32, TEXT_COLOR)
	_timer_label.name = "TimerLabel"
	_timer_label.add_theme_constant_override("outline_size", 1)
	_timer_label.add_theme_color_override("font_outline_color", TEXT_COLOR)
	_timer_label.z_index = 5

	_feedback_label = _create_label(
		"",
		BOARD_ORIGIN + Vector2(18.0, BOARD_SIZE.y - 58.0),
		Vector2(BOARD_SIZE.x - 36.0, 42.0),
		17,
		ORANGE
	)
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.z_index = 10
	_build_self_respawn_progress()

	_status_label = _create_label(
		"",
		BOARD_ORIGIN + Vector2(30.0, 380.0),
		Vector2(BOARD_SIZE.x - 60.0, 200.0),
		32,
		TEXT_COLOR
	)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.z_index = 10
	_status_label.visible = false


## 상황: 시작 화면 안에서 게임 장면이 열린 순간 게임 전용 논리·창 크기를 적용한다.
## 결과: 메뉴의 960×800 배치는 유지되고 게임 화면만 1000×1080으로 확장된다.
func _apply_game_viewport_size() -> void:
	var window: Window = get_window()
	window.content_scale_size = GAME_VIEWPORT_SIZE
	if not DisplayServer.get_name().contains("headless"):
		window.size = GAME_VIEWPORT_SIZE


## 상황: `_build_interface()`가 공통 스타일의 Label 하나를 필요로 할 때 호출한다.
## 순서: Label 생성 → text/position/size/mouse 설정 → font/size/color override → add_child.
## 결과: View가 소유하고 화면에 배치된 새 Label 참조를 반환한다.
func _create_label(
	text_value: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label: Label = Label.new() # 공통 속성을 채운 뒤 호출자에게 돌려줄 새 UI 노드.
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _system_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


## 상황: `_build_interface()`에서 자력 재스폰 진행 UI를 한 번 준비한다.
## 결과: 캐릭터·블록보다 높은 z-index의 패널과 배경/채움 막대가 숨김 상태로 생성된다.
func _build_self_respawn_progress() -> void:
	_self_respawn_panel = Panel.new()
	_self_respawn_panel.position = SELF_RESPAWN_PANEL_RECT.position
	_self_respawn_panel.size = SELF_RESPAWN_PANEL_RECT.size
	_self_respawn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_self_respawn_panel.z_index = 8
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.08, 0.14, 0.92)
	panel_style.border_color = ORANGE
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	_self_respawn_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_self_respawn_panel)

	var bar_background: ColorRect = ColorRect.new()
	bar_background.position = (
		SELF_RESPAWN_BAR_RECT.position - SELF_RESPAWN_PANEL_RECT.position
	)
	bar_background.size = SELF_RESPAWN_BAR_RECT.size
	bar_background.color = Color("#c8d1dd")
	bar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_self_respawn_panel.add_child(bar_background)

	_self_respawn_fill = ColorRect.new()
	_self_respawn_fill.size = Vector2(0.0, SELF_RESPAWN_BAR_RECT.size.y)
	_self_respawn_fill.color = ORANGE
	_self_respawn_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_background.add_child(_self_respawn_fill)
	_self_respawn_panel.visible = false


## 상황: `_draw()`가 보드 또는 HUD 뒤의 둥근 panel을 그릴 때 호출한다.
## 순서: StyleBoxFlat 생성 → 배경/테두리/모서리/shadow 설정 → rect에 draw_style_box.
## 결과: 노드를 추가하지 않고 현재 draw pass에 panel 픽셀만 기록한다.
func _draw_panel(rect: Rect2) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new() # 이번 panel draw에만 쓰는 모양/색 정의.
	style.bg_color = PANEL_COLOR
	style.border_color = Color("#8390a3")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.08, 0.13, 0.20, 0.18)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0.0, 2.0)
	draw_style_box(style, rect)


func _draw_hud() -> void:
	_draw_panel(HUD_RECT)
	_draw_panel(NEXT_CARD_RECT)
	var clock_center: Vector2 = Vector2(62.0, 75.0)
	draw_circle(clock_center, 10.0, TEXT_COLOR, false, 2.0, true)
	draw_line(clock_center, clock_center + Vector2(0.0, -5.0), TEXT_COLOR, 2.0, true)
	draw_line(clock_center, clock_center + Vector2(4.0, 2.0), TEXT_COLOR, 2.0, true)


## 상황: `_draw()`가 플레이 영역의 현재 셀 상태를 표현할 때 호출한다.
## 순서: 배경 → 20×10 grid/고정 셀 → game over 조기 종료
##       → ghost 원점의 네 셀 → 활성 원점의 네 셀.
## 결과: 고정 블록 위에 ghost, 그 위에 활성 피스가 그려져 시각 우선순위가 보장된다.
func _draw_board() -> void:
	draw_rect(Rect2(BOARD_ORIGIN, BOARD_SIZE), BOARD_COLOR)

	for y: int in range(MainBoardModel.VISIBLE_HEIGHT):
		for x: int in range(MainBoardModel.WIDTH):
			var cell_rect: Rect2 = _cell_rect(Vector2i(x, y + MainBoardModel.HIDDEN_ROWS)) # 현재 화면 셀 사각형.
			var piece_type: int = controller.board.cells[y + MainBoardModel.HIDDEN_ROWS][x] # 고정 타입/EMPTY.
			if piece_type != MainBoardModel.EMPTY:
				_draw_block(cell_rect, piece_type, 1.0)

	if controller.state == MainGameController.GameState.GAME_OVER:
		return

	var ghost_position: Vector2i = controller.ghost_origin() # 활성 피스의 예상 착지 원점.
	for local_cell: Vector2i in MainTetrominoData.get_cells(
		controller.active_type,
		controller.active_rotation
	):
		var ghost_cell: Vector2i = ghost_position + local_cell # 고스트의 절대 보드 셀.
		if ghost_cell.y >= MainBoardModel.HIDDEN_ROWS:
			_draw_ghost(_cell_rect(ghost_cell), controller.active_type)

	for local_cell: Vector2i in MainTetrominoData.get_cells(
		controller.active_type,
		controller.active_rotation
	):
		var active_cell: Vector2i = controller.active_origin + local_cell # 활성 절대 보드 셀.
		if active_cell.y >= MainBoardModel.HIDDEN_ROWS:
			_draw_block(
				_cell_rect(active_cell),
				controller.active_type,
				1.0
			)
	_draw_thorns()

	for x: int in range(MainBoardModel.WIDTH + 1):
		var line_x: float = BOARD_ORIGIN.x + float(x) * CELL_SIZE
		draw_line(Vector2(line_x, BOARD_ORIGIN.y), Vector2(line_x, BOARD_ORIGIN.y + BOARD_SIZE.y), GRID_COLOR)
	for y: int in range(MainBoardModel.VISIBLE_HEIGHT + 1):
		var line_y: float = BOARD_ORIGIN.y + float(y) * CELL_SIZE
		draw_line(Vector2(BOARD_ORIGIN.x, line_y), Vector2(BOARD_ORIGIN.x + BOARD_SIZE.x, line_y), GRID_COLOR)


func _draw_thorns() -> void:
	if not controller.active_piece_has_visible_thorns():
		return
	var cells: Array[Vector2i] = MainTetrominoData.get_cells(
		controller.active_type,
		controller.active_rotation
	)
	var faces: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var angles: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]
	# overlay는 셀 경계에 6px 겹쳐 틈을 없애고, 블록의 48×48 rect는 건드리지 않는다.
	for local_cell: Vector2i in cells:
		var active_cell: Vector2i = controller.active_origin + local_cell
		if active_cell.y < MainBoardModel.HIDDEN_ROWS:
			continue
		var cell_rect: Rect2 = _cell_rect(active_cell)
		var cell_center: Vector2 = cell_rect.get_center()
		for index: int in range(faces.size()):
			if cells.has(local_cell + faces[index]):
				continue
			var face_center: Vector2 = cell_center + Vector2(faces[index]) * (
				CELL_SIZE * 0.5 + THORN_DEPTH * 0.5 - THORN_EDGE_OVERLAP
			)
			draw_set_transform(face_center, angles[index])
			draw_texture_rect_region(
				THORN_TEXTURE,
				Rect2(-CELL_SIZE * 0.5, -THORN_DEPTH * 0.5, CELL_SIZE, THORN_DEPTH),
				THORN_SOURCE_REGION
			)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_binding() -> void:
	if _binding_sprite == null:
		return
	_binding_sprite.visible = character.is_bound


func _create_binding_overlay() -> void:
	_binding_sprite = Sprite2D.new()
	_binding_sprite.name = "BindingSprite"
	_binding_sprite.texture = BIND_TEXTURE
	_binding_sprite.region_enabled = true
	_binding_sprite.region_rect = BIND_SOURCE_REGION
	_binding_sprite.scale = BIND_DISPLAY_SIZE / BIND_SOURCE_REGION.size
	_binding_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_binding_sprite.z_index = 1
	_binding_sprite.visible = false
	character.add_child(_binding_sprite)


## 상황: `_draw()`가 상단 HUD 카드에 다음 피스 미리보기를 표시할 때 호출한다.
## 순서: 피스 외곽 크기 계산 → 카드 중심 원점 계산 → 회전 0의 네 셀 draw.
## 결과: controller.next_type이 실제 spawn 전에 사용자에게 보인다.
func _draw_next_piece() -> void:
	var cells: Array[Vector2i] = MainTetrominoData.get_cells(controller.next_type, 0)
	var minimum_cell: Vector2i = cells[0]
	var maximum_cell: Vector2i = cells[0]
	for local_cell: Vector2i in cells:
		minimum_cell = minimum_cell.min(local_cell)
		maximum_cell = maximum_cell.max(local_cell)
	var footprint: Vector2i = maximum_cell - minimum_cell + Vector2i.ONE
	var preview_cell_size: float = minf(
		18.0,
		minf(120.0 / float(footprint.x), 42.0 / float(footprint.y))
	)
	var preview_size: Vector2 = Vector2(footprint) * preview_cell_size
	var preview_center: Vector2 = Vector2(438.0, 71.0)
	var preview_origin: Vector2 = preview_center - preview_size * 0.5 - Vector2(minimum_cell) * preview_cell_size
	for local_cell: Vector2i in cells:
		var cell_rect: Rect2 = Rect2( # 이번 local cell의 preview 픽셀 영역.
			preview_origin + Vector2(local_cell) * preview_cell_size,
			Vector2.ONE * preview_cell_size
		)
		_draw_block(cell_rect, controller.next_type, 1.0)


## 상황: `_draw()`가 명상 중임을 보드 전체 효과로 알려야 할 때 호출한다.
## 순서: 비명상이면 종료 → 시간 기반 phase/pulse 계산 → 반투명 배경
##       → 7개 하강선 → 안쪽 pulse 테두리.
## 결과: 게임 상태를 바꾸지 않고 명상 중인 frame마다 움직이는 청색 효과를 그린다.
func _draw_meditation_effect() -> void:
	if not character.is_meditating:
		return

	var board_rect: Rect2 = Rect2(BOARD_ORIGIN, BOARD_SIZE) # 효과를 제한할 보드 전체 영역.
	var phase: float = fmod(float(Time.get_ticks_msec()) * 0.22, 144.0)
	var pulse: float = (sin(float(Time.get_ticks_msec()) * 0.007) + 1.0) * 0.5 # 0~1 밝기.
	draw_rect(board_rect, Color(0.17, 0.56, 0.84, 0.04 + pulse * 0.03))
	for index: int in range(7):
		var line_x: float = BOARD_ORIGIN.x + 36.0 + float(index) * 67.5
		var line_end_y: float = ( # phase에 따라 아래로 순환하는 선 끝 y.
			BOARD_ORIGIN.y
			+ fmod(phase + float(index) * 124.5, BOARD_SIZE.y)
		)
		var line_start_y: float = maxf(BOARD_ORIGIN.y, line_end_y - 72.0)
		draw_line(
			Vector2(line_x, line_start_y),
			Vector2(line_x, line_end_y),
			Color(0.17, 0.56, 0.84, 0.20 + pulse * 0.10),
			2.0
		)
	draw_rect(
		board_rect.grow(-4.0),
		Color(0.17, 0.56, 0.84, 0.48 + pulse * 0.22),
		false,
		2.0 + pulse
	)


## 상황: 세 핵심 상태와 초상 영역을 좁은 패널 안에서 카드로 구분한다.
## 상황: `_draw()` 마지막에 현재 게임이 PLAYING이 아닐 때 호출한다.
## 순서: PLAYING이면 조기 종료, 아니면 보드 전체에 반투명 검정 rect draw.
## 결과: 아래 게임 화면은 유지하면서 pause/game-over 상태를 시각적으로 분리한다.
func _draw_state_overlay() -> void:
	if controller.state == MainGameController.GameState.PLAYING:
		return
	draw_rect(Rect2(BOARD_ORIGIN, BOARD_SIZE), Color(0.01, 0.02, 0.04, 0.80))


## 상황: 고정/활성/다음/ghost 셀 하나를 블록 sprite로 그릴 때 호출한다.
## 순서: 타입→문자 이름 → atlas source Rect 조회 → 없으면 종료
##       → destination을 1px 줄이고 alpha modulation과 함께 texture draw.
## 결과: enum 순서와 무관하게 이름 기반 올바른 블록 이미지가 그려진다.
func _draw_block(rect: Rect2, piece_type: int, alpha: float) -> void:
	var piece_name: String = MainTetrominoData.get_display_name(piece_type) # atlas Dictionary key.
	var source_region: Rect2 = BLOCK_SPRITE_REGIONS.get(piece_name, Rect2()) # 원본 sprite 영역.
	if source_region == Rect2():
		return
	draw_texture_rect_region(
		BLOCK_TEXTURE,
		rect.grow(-1.0),
		source_region,
		Color(1.0, 1.0, 1.0, alpha)
	)


## 상황: `_draw_board()`가 예상 착지 셀 하나를 활성 피스와 구분해 그릴 때 호출한다.
## 순서: 2px 줄인 반투명 블록 draw → 4px 줄인 청색 외곽선 draw.
## 결과: 실제 블록보다 옅지만 모양과 경계가 식별되는 ghost가 표시된다.
func _draw_ghost(rect: Rect2, piece_type: int) -> void:
	_draw_block(rect.grow(-2.0), piece_type, 0.22)
	draw_rect(rect.grow(-4.0), Color(0.17, 0.56, 0.84, 0.65), false, 2.0)


## 상황: 고정/활성/ghost의 논리 보드 셀을 그리기 직전에 호출한다.
## 순서: hidden rows를 y에서 제거 → x/y에 CELL_SIZE 곱함 → BOARD_ORIGIN 더함.
## 결과: 보드 좌표에 대응하는 48×48 View 로컬 Rect2를 반환한다.
func _cell_rect(board_cell: Vector2i) -> Rect2:
	var visible_y: int = board_cell.y - MainBoardModel.HIDDEN_ROWS # 화면 기준 0~19 y.
	return Rect2(
		BOARD_ORIGIN + Vector2(board_cell.x * CELL_SIZE, visible_y * CELL_SIZE),
		Vector2.ONE * CELL_SIZE
	)


## 상황: 최초 준비 또는 controller/character signal로 표시 데이터가 바뀔 때 호출한다.
## 순서: node ready 검사 → stats 문자열 → 생명 icon/cooldown 문자열 → character 문자열
##       → feedback → state별 status/visibility → `queue_redraw()`.
## 결과: retained Label과 다음 즉시-mode draw pass가 같은 최신 상태를 표시한다.
func _refresh() -> void:
	if not is_node_ready():
		return
	_lines_label.text = "파괴한 줄: %d" % controller.total_lines
	_lives_label.text = "목숨: %d" % character.lives
	var remaining_seconds: int = ceili(controller.stage_time_remaining)
	_timer_label.text = "%02d:%02d" % [remaining_seconds / 60, remaining_seconds % 60]
	_timer_label.visible = controller.is_survival_stage()
	var self_respawn_ratio: float = character.self_respawn_hold_ratio()
	_self_respawn_panel.visible = self_respawn_ratio > 0.0
	_self_respawn_fill.size.x = SELF_RESPAWN_BAR_RECT.size.x * self_respawn_ratio
	_feedback_label.text = (
		"자력 재스폰 준비 중  %d%%" % roundi(self_respawn_ratio * 100.0)
		if self_respawn_ratio > 0.0
		else character.feedback_text
	)

	match controller.state:
		MainGameController.GameState.PAUSED:
			_status_label.text = "일시정지\n\nP로 계속 · Esc로 메뉴"
			_status_label.visible = true
		MainGameController.GameState.GAME_OVER:
			_status_label.text = "게임 오버\n\nR 키로 다시 시작\nEsc 키로 메뉴"
			_status_label.visible = true
		_:
			_status_label.visible = false

	queue_redraw()
