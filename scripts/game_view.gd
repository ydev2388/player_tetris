class_name Stage4GameView
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

const CELL_SIZE: float = 32.0 # 논리 셀 한 칸을 화면에 그릴 픽셀 크기.
const BOARD_ORIGIN: Vector2 = Vector2(60.0, 80.0) # 보드 좌상단의 View 로컬 픽셀 좌표.
const BOARD_SIZE: Vector2 = Vector2(
	Stage4BoardModel.WIDTH * CELL_SIZE,
	Stage4BoardModel.VISIBLE_HEIGHT * CELL_SIZE
) # 화면에 보이는 10×20 보드의 픽셀 크기.
const PANEL_RECT: Rect2 = Rect2(Vector2(410.0, 80.0), Vector2(490.0, 640.0)) # 우측 HUD 영역.

# 고정 UI theme 색상.
const BACKGROUND_COLOR: Color = Color("#f7f8fb") # 전체 창 배경.
const BOARD_COLOR: Color = Color("#dce3ed") # 빈 보드와 다음 피스 preview 배경.
const GRID_COLOR: Color = Color("#8390a3") # 셀·bar 외곽선.
const PANEL_COLOR: Color = Color("#ffffff") # 보드/HUD panel 표면.
const TEXT_COLOR: Color = Color("#152033") # 주요 제목과 수치.
const MUTED_TEXT_COLOR: Color = Color("#344158") # 조작법 같은 보조 설명.
const CYAN: Color = Color("#2c8fd6") # stamina/캐릭터 강조색.
const ORANGE: Color = Color("#e47719") # charge/feedback 강조색.

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
const CHARACTER_TEXTURE: Texture2D = preload("res://assets/sprites/player_animations.png") # HUD 초상화 시트.
const CHARACTER_SOURCE_RECT: Rect2 = Rect2(45.0, 55.0, 165.0, 270.0) # 초상 원본 영역.

# main.tscn의 자식 노드 참조. C++에서 scene dependency를 pointer로 캐시한 것과 같다.
@onready var controller: Stage4GameController = $GameController # 표시할 게임 상태의 소유자.
@onready var character: Stage4CharacterController = $BoardPhysics/Character # 표시할 캐릭터 상태.

# `_build_interface()`가 생성하고 `_refresh()`가 내용을 바꾸는 retained UI 노드.
var _title_label: Label # 고정 게임 제목.
var _next_label: Label # 다음 블록 preview 제목.
var _stats_label: Label # score/level/line 수치.
var _character_label: Label # 생명/stamina/charge/cooldown 텍스트.
var _controls_label: Label # 키 조작법.
var _feedback_label: Label # 최근 캐릭터 행동 성공/실패 메시지.
var _status_label: Label # pause 또는 game-over 중앙 overlay 문구.
var _system_font: SystemFont # 위 Label과 draw_string이 공유할 한글 지원 폰트.


## 상황: main.tscn의 루트 View가 씬 트리에 들어올 때 Godot가 한 번 호출한다.
## 순서: SystemFont 생성/후보 지정 → `_build_interface()` → 세 signal 연결 → `_refresh()`.
## 결과: retained Label UI가 만들어지고 이후 상태 변경을 자동 반영한다.
func _ready() -> void:
	_system_font = SystemFont.new()
	_system_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	_build_interface()
	controller.game_changed.connect(_refresh)
	character.stats_changed.connect(_refresh)
	character.feedback_changed.connect(_refresh)
	_refresh()


## 상황: 최초 표시 또는 `queue_redraw()` 이후 Godot CanvasItem draw pass에서 호출된다.
## 순서: 배경 → 두 panel → 보드 → 명상효과 → next → 초상 → bars → 상태 overlay.
## 결과: 그 frame의 controller/character 상태가 즉시-mode draw 명령으로 화면에 표현된다.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	_draw_panel(Rect2(BOARD_ORIGIN - Vector2(12.0, 12.0), BOARD_SIZE + Vector2(24.0, 24.0)))
	_draw_panel(PANEL_RECT)
	_draw_board()
	_draw_meditation_effect()
	_draw_next_piece()
	_draw_character_card()
	_draw_character_bars()
	_draw_state_overlay()


## 상황: `_ready()`에서 값이 바뀌는 텍스트 UI를 최초 한 번 구성할 때 호출한다.
## 순서: 제목/next/stats/character/controls/feedback/status Label을 순서대로 생성
##       → 각 Label별 shadow/alignment/z-index/line spacing을 설정.
## 결과: 이후 `_refresh()`가 참조할 멤버 Label들이 모두 유효해진다.
func _build_interface() -> void:
	_title_label = _create_label(
		"KUNG FU TETRIS : STAGE 4",
		Vector2(60.0, 22.0),
		Vector2(840.0, 42.0),
		28,
		TEXT_COLOR
	)
	_title_label.add_theme_color_override("font_shadow_color", Color(0.17, 0.56, 0.84, 0.24))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)

	_next_label = _create_label(
		"다음 블록",
		Vector2(438.0, 104.0),
		Vector2(180.0, 32.0),
		18,
		TEXT_COLOR
	)
	_stats_label = _create_label(
		"",
		Vector2(438.0, 292.0),
		Vector2(180.0, 190.0),
		19,
		TEXT_COLOR
	)
	_stats_label.add_theme_constant_override("line_spacing", 5)

	_character_label = _create_label(
		"",
		Vector2(646.0, 310.0),
		Vector2(226.0, 150.0),
		16,
		TEXT_COLOR
	)
	_character_label.add_theme_constant_override("line_spacing", 5)

	_controls_label = _create_label(
		"캐릭터 조작\n← → / A D  이동\n↓ 유지  명상 ×2\nZ / Space  점프\nC + ↑↓  매달려 이동\nC + Z/Space  벽 점프\nX 즉시 / 유지  연속 펀치\nS  블록 당기기\nV  회전 킥\nP / Esc  일시정지\nR  다시 시작",
		Vector2(646.0, 495.0),
		Vector2(226.0, 210.0),
		12,
		MUTED_TEXT_COLOR
	)
	_controls_label.add_theme_constant_override("line_spacing", 1)

	_feedback_label = _create_label(
		"",
		BOARD_ORIGIN + Vector2(14.0, BOARD_SIZE.y - 46.0),
		Vector2(BOARD_SIZE.x - 28.0, 34.0),
		15,
		ORANGE
	)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.z_index = 8

	_status_label = _create_label(
		"",
		BOARD_ORIGIN + Vector2(20.0, 245.0),
		Vector2(BOARD_SIZE.x - 40.0, 150.0),
		28,
		TEXT_COLOR
	)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.z_index = 10
	_status_label.visible = false


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
	style.shadow_size = 8
	draw_style_box(style, rect)


## 상황: `_draw()`가 플레이 영역의 현재 셀 상태를 표현할 때 호출한다.
## 순서: 배경 → 20×10 grid/고정 셀 → game over 조기 종료
##       → ghost 원점의 네 셀 → 활성 원점의 네 셀.
## 결과: 고정 블록 위에 ghost, 그 위에 활성 피스가 그려져 시각 우선순위가 보장된다.
func _draw_board() -> void:
	draw_rect(Rect2(BOARD_ORIGIN, BOARD_SIZE), BOARD_COLOR)

	for y: int in range(Stage4BoardModel.VISIBLE_HEIGHT):
		for x: int in range(Stage4BoardModel.WIDTH):
			var cell_rect: Rect2 = _cell_rect(Vector2i(x, y + Stage4BoardModel.HIDDEN_ROWS)) # 현재 화면 셀 사각형.
			draw_rect(cell_rect, GRID_COLOR, false, 1.0)
			var piece_type: int = controller.board.cells[y + Stage4BoardModel.HIDDEN_ROWS][x] # 고정 타입/EMPTY.
			if piece_type != Stage4BoardModel.EMPTY:
				_draw_block(cell_rect, piece_type, 1.0)

	if controller.state == Stage4GameController.GameState.GAME_OVER:
		return

	var ghost_position: Vector2i = controller.ghost_origin() # 활성 피스의 예상 착지 원점.
	for local_cell: Vector2i in Stage4TetrominoData.get_cells(
		controller.active_type,
		controller.active_rotation
	):
		var ghost_cell: Vector2i = ghost_position + local_cell # 고스트의 절대 보드 셀.
		if ghost_cell.y >= Stage4BoardModel.HIDDEN_ROWS:
			_draw_ghost(_cell_rect(ghost_cell), controller.active_type)

	for local_cell: Vector2i in Stage4TetrominoData.get_cells(
		controller.active_type,
		controller.active_rotation
	):
		var active_cell: Vector2i = controller.active_origin + local_cell # 활성 절대 보드 셀.
		if active_cell.y >= Stage4BoardModel.HIDDEN_ROWS:
			_draw_block(
				_cell_rect(active_cell),
				controller.active_type,
				1.0
			)


## 상황: `_draw()`가 우측 HUD에 다음 피스 미리보기를 표시할 때 호출한다.
## 순서: preview 배경/외곽선 → 24px cell 크기/원점 계산 → 회전 0의 네 셀 draw.
## 결과: controller.next_type이 실제 spawn 전에 사용자에게 보인다.
func _draw_next_piece() -> void:
	var preview_rect: Rect2 = Rect2(Vector2(438.0, 142.0), Vector2(180.0, 126.0)) # 미리보기 영역.
	draw_rect(preview_rect, BOARD_COLOR)
	draw_rect(preview_rect, GRID_COLOR, false, 1.0)

	var preview_cell_size: float = 24.0 # 본 보드보다 작게 그릴 한 셀 크기.
	var preview_origin: Vector2 = preview_rect.position + Vector2(42.0, 16.0) # 피스 로컬 (0,0).
	for local_cell: Vector2i in Stage4TetrominoData.get_cells(controller.next_type, 0):
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
	var phase: float = fmod(float(Time.get_ticks_msec()) * 0.22, 96.0) # 하강선 순환 위치.
	var pulse: float = (sin(float(Time.get_ticks_msec()) * 0.007) + 1.0) * 0.5 # 0~1 밝기.
	draw_rect(board_rect, Color(0.17, 0.56, 0.84, 0.04 + pulse * 0.03))
	for index: int in range(7):
		var line_x: float = BOARD_ORIGIN.x + 24.0 + float(index) * 45.0 # 각 세로선 x.
		var line_end_y: float = ( # phase에 따라 아래로 순환하는 선 끝 y.
			BOARD_ORIGIN.y
			+ fmod(phase + float(index) * 83.0, BOARD_SIZE.y)
		)
		var line_start_y: float = maxf(BOARD_ORIGIN.y, line_end_y - 48.0) # 보드 위를 넘지 않는 시작 y.
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


## 상황: `_draw()`가 우측 HUD 상단의 캐릭터 정적 카드를 그릴 때 호출한다.
## 순서: atlas의 초상 영역을 destination rect에 draw → 그 위에 캐릭터 제목 draw_string.
## 결과: 게임 상태와 무관한 캐릭터 식별 카드가 표시된다.
func _draw_character_card() -> void:
	var portrait_rect: Rect2 = Rect2(Vector2(706.0, 106.0), Vector2(104.0, 190.0)) # 초상 목적 영역.
	draw_texture_rect_region(CHARACTER_TEXTURE, portrait_rect, CHARACTER_SOURCE_RECT)
	draw_string(
		_system_font,
		Vector2(652.0, 126.0),
		"KUNG FU FIGHTER",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		16,
		CYAN
	)


## 상황: `_draw()`가 캐릭터의 연속 수치를 bar 세 개로 표시할 때 호출한다.
## 순서: stamina/MAX → charge_ratio → 1-cooldown_ratio를 각각 `_draw_bar()`에 전달.
## 결과: stamina/charge/회전 사용 가능도가 같은 frame의 캐릭터 상태와 일치한다.
func _draw_character_bars() -> void:
	_draw_bar(
		Rect2(Vector2(646.0, 424.0), Vector2(220.0, 12.0)),
		character.stamina / Stage4CharacterController.MAX_STAMINA,
		CYAN
	)
	_draw_bar(
		Rect2(Vector2(646.0, 452.0), Vector2(220.0, 10.0)),
		character.charge_ratio(),
		ORANGE
	)
	_draw_bar(
		Rect2(Vector2(646.0, 476.0), Vector2(220.0, 8.0)),
		1.0 - character.rotation_cooldown_ratio(),
		Color("#6f57c9")
	)


## 상황: 캐릭터 수치 하나를 동일한 모양의 가로 bar로 그릴 때 호출한다.
## 순서: 배경 draw → ratio를 0~1 clamp해 fill 폭 계산 → fill draw → 외곽선 draw.
## 결과: 범위를 벗어난 입력도 영역 밖으로 넘치지 않는 bar가 그려진다.
func _draw_bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, Color("#c8d1dd"))
	var fill_rect: Rect2 = rect # 전체 rect를 복사한 뒤 x 폭만 비율에 맞출 채움 영역.
	fill_rect.size.x *= clampf(ratio, 0.0, 1.0)
	draw_rect(fill_rect, color)
	draw_rect(rect, GRID_COLOR, false, 1.0)


## 상황: `_draw()` 마지막에 현재 게임이 PLAYING이 아닐 때 호출한다.
## 순서: PLAYING이면 조기 종료, 아니면 보드 전체에 반투명 검정 rect draw.
## 결과: 아래 게임 화면은 유지하면서 pause/game-over 상태를 시각적으로 분리한다.
func _draw_state_overlay() -> void:
	if controller.state == Stage4GameController.GameState.PLAYING:
		return
	draw_rect(Rect2(BOARD_ORIGIN, BOARD_SIZE), Color(0.01, 0.02, 0.04, 0.80))


## 상황: 고정/활성/다음/ghost 셀 하나를 블록 sprite로 그릴 때 호출한다.
## 순서: 타입→문자 이름 → atlas source Rect 조회 → 없으면 종료
##       → destination을 1px 줄이고 alpha modulation과 함께 texture draw.
## 결과: enum 순서와 무관하게 이름 기반 올바른 블록 이미지가 그려진다.
func _draw_block(rect: Rect2, piece_type: int, alpha: float) -> void:
	var piece_name: String = Stage4TetrominoData.get_display_name(piece_type) # atlas Dictionary key.
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
## 결과: 보드 좌표에 대응하는 32×32 View 로컬 Rect2를 반환한다.
func _cell_rect(board_cell: Vector2i) -> Rect2:
	var visible_y: int = board_cell.y - Stage4BoardModel.HIDDEN_ROWS # 화면 기준 0~19 y.
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
	_stats_label.text = (
		"점수\n%08d\n\n레벨\n%02d\n\n삭제한 줄\n%03d"
		% [controller.score, controller.level, controller.total_lines]
	)

	var life_icons: String = "♥".repeat(character.lives) + "♡".repeat( # 남은/잃은 생명을 한 문자열로 표현.
		Stage4CharacterController.MAX_LIVES - character.lives
	)
	var cooldown_text: String = ( # 회전 킥이 가능하면 "준비", 아니면 남은 초.
		"준비"
		if character.rotation_cooldown_remaining <= 0.0
		else "%.1f초" % character.rotation_cooldown_remaining
	)
	_character_label.text = (
		"목숨  %s\n스태미나  %03d / 100\n펀치 단계  %d / 3\n회전 킥  %s"
		% [
			life_icons,
			roundi(character.stamina),
			character.charge_level(),
			cooldown_text,
		]
	)
	_feedback_label.text = character.feedback_text

	match controller.state:
		Stage4GameController.GameState.PAUSED:
			_status_label.text = "일시정지\n\nP 또는 Esc로 계속"
			_status_label.visible = true
		Stage4GameController.GameState.GAME_OVER:
			_status_label.text = "게임 오버\n\nR 키로 다시 시작"
			_status_label.visible = true
		_:
			_status_label.visible = false

	queue_redraw()
