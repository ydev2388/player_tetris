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
const SPECIAL_BAR_RECT: Rect2 = Rect2(
	MainLayout.BOARD_ORIGIN + Vector2(0.0, MainLayout.BOARD_SIZE.y + 30.0),
	Vector2(MainLayout.BOARD_SIZE.x, 12.0)
)
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
const MUTED_TEXT_COLOR: Color = Color("#344158") # 조작법 같은 보조 설명.
const CYAN: Color = Color("#2c8fd6") # stamina/캐릭터 강조색.
const ORANGE: Color = Color("#e47719")

# sprite atlas와 piece 이름 -> atlas source Rect 매핑.
const BLOCK_TEXTURE: Texture2D = preload("res://assets/sprites/block_sprites.png")
const SPRINT_VFX: Texture2D = preload("res://assets/sprites/effects/normal/sprint_vfx.png")
const GUARD_BREAK_VFX: Texture2D = preload("res://assets/sprites/effects/boxer/guard_break_impact.png")
const SHIELD_BARRIER_VFX: Texture2D = preload("res://assets/sprites/effects/shield_guard/shield_barrier.png")
const HOSE_VFX: Texture2D = preload("res://assets/sprites/effects/firefighter/hose_overlay.png")
const WATER_PATH_VFX: Texture2D = preload("res://assets/sprites/effects/firefighter/water_path.png")
const WATER_PATH_SOURCE_FRAME_WIDTH: float = 48.0
const WATER_PATH_SOURCE_VISIBLE_Y: float = 21.0
const WATER_PATH_SOURCE_VISIBLE_HEIGHT: float = 6.0
const WATER_PATH_DISPLAY_HEIGHT: float = 14.0
const WATER_PATH_SURFACE_OVERLAP: float = 4.0
const CLEANUP_VFX: Texture2D = preload("res://assets/sprites/effects/cleaner/cleanup_dust.png")
const CLOCK_WAVE_VFX: Texture2D = preload("res://assets/sprites/effects/clockmaker/clock_wave.png")
const CLOCK_GEAR_VFX: Texture2D = preload("res://assets/sprites/effects/clockmaker/clock_gear_ring.png")
const SHURIKEN_SPIN_VFX: Texture2D = preload("res://assets/sprites/effects/ninja/shuriken_spin.png")
const SHURIKEN_IMPACT_VFX: Texture2D = preload("res://assets/sprites/effects/ninja/shuriken_impact.png")
const BLOCK_SPRITE_REGIONS: Dictionary = {
	"I": Rect2(80, 255, 210, 215),
	"O": Rect2(360, 255, 210, 215),
	"T": Rect2(640, 255, 210, 215),
	"S": Rect2(915, 255, 210, 215),
	"Z": Rect2(1190, 255, 210, 215),
	"J": Rect2(1470, 255, 210, 215),
	"L": Rect2(1745, 255, 210, 215),
}
const ICICLE_TEXTURE: Texture2D = preload("res://assets/sprites/boss/6_10_boss/icecle.png")
const THORN_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/grass_thron_sprite.png")
const THORN_SOURCE_REGION: Rect2 = Rect2(500.0, 64.0, 128.0, 104.0)
const ICE_BLOCK_TEXTURE: Texture2D = preload("res://assets/sprites/boss/6_10_boss/ice_block.png")
const ICE_BLOCK_SOURCE_REGION: Rect2 = Rect2(199.0, 25.0, 52.0, 42.0)
const THORN_DEPTH: float = 18.0
const THORN_EDGE_OVERLAP: float = 6.0
const BIND_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/grass_bind_sprite.png")
const BIND_SOURCE_REGION: Rect2 = Rect2(337.0, 65.0, 277.0, 364.0)
const BIND_HEIGHT_MARGIN: float = 12.0
const BIND_DISPLAY_SIZE: Vector2 = Vector2(78.0, 108.0)
const BOSS_NORMAL_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/grass_boss_normal_sprites.png")
const BOSS_BIND_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/grass_boss_bind_sprites.png")
const BOSS_THORN_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/grass_boss_thron_sprites.png")
const BOSS_DOWN_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/grass_boss_down_sprites.png")
const BOSS_FALLING_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/grass_boss_falling_sprites.png")
const BOSS_FALLEN_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/grass_boss_fallen_sprites.png")
const BOSS_SEED_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/grass_seed_sprite.png")
const HEART_TEXTURE: Texture2D = preload("res://assets/sprites/boss/heart.svg")
const BOSS_SOURCE_FRAME_SIZE: Vector2 = Vector2(384.0, 1024.0)
const BOSS_DOWN_SOURCE_FRAME_SIZE: Vector2 = Vector2(384.0, 983.0)
const BOSS_FALLEN_SOURCE_FRAME_SIZE: Vector2 = Vector2(384.0, 234.0)
const BOSS_DISPLAY_SIZE: Vector2 = MainGameController.BOSS_DISPLAY_SIZE
const BOSS_DOWN_DISPLAY_SIZE: Vector2 = MainGameController.BOSS_DOWN_DISPLAY_SIZE
const BOSS_FALLEN_DISPLAY_SIZE: Vector2 = Vector2(72.0, 43.875)
const ICE_BOSS_STAGE: int = 10
const ICE_BOSS_TEXTURE: Texture2D = preload("res://assets/sprites/boss/6_10_boss/ice_boss.png")
const ICE_BOSS_DIE_TEXTURE: Texture2D = preload("res://assets/sprites/boss/6_10_boss/ice_boss_die.png")
const ICE_HIT_TEXTURE: Texture2D = preload("res://assets/sprites/boss/6_10_boss/ice_hit.png")
const ICE_BOSS_SOURCE_FRAME_SIZE: Vector2 = Vector2(167.25, 373.0)
const ICE_BOSS_DISPLAY_SIZE: Vector2 = Vector2(86.0, 192.0)
const BOSS_FRAME_COUNT: int = 4
const ICE_HIT_FRAME_SEQUENCE: Array[int] = [0, 1, 2, 3, 2, 1, 0] # 얼음 보스 피격 7프레임 왕복(1→4→1).
const BOSS_FRAME_INTERVAL: float = 0.18
const ICE_HIT_FRAME_INTERVAL: float = 0.1 # 얼음 보스 피격 오버레이 프레임 간격.
const BOSS_VISUAL_OFFSET: Vector2 = Vector2(0.0, -18.0)
const BOSS_THORN_FRAME_INTERVAL: float = 0.1
const BOSS_THORN_FRAME_SEQUENCE: Array[int] = [0, 1, 2, 3, 3, 2, 1, 0]
const HEART_DISPLAY_SIZE: Vector2 = Vector2(16.0, 16.0)
const CHARACTER_SOURCE_RECT: Rect2 = Rect2(0.0, 0.0, 128.0, 128.0) # idle 0 frame.
const BOSS_SEED_DISPLAY_SIZE: Vector2 = MainGameController.BOSS_SEED_SIZE

# main.tscn의 자식 노드 참조. C++에서 scene dependency를 pointer로 캐시한 것과 같다.
@onready var controller: MainGameController = $GameController # 표시할 게임 상태의 소유자.
@onready var character: MainCharacterController = $BoardPhysics/Character # 표시할 캐릭터 상태.

# `_build_interface()`가 생성하고 `_refresh()`가 내용을 바꾸는 retained UI 노드.
var _title_label: Label # 고정 게임 제목.
var _lines_label: Label
var _lives_label: Label
var _timer_label: Label
var _next_label: Label # 다음 블록 preview 제목.
var _stats_label: Label # score/level/line 수치.
var _life_label: Label # 큰 하트로 표시하는 현재 목숨.
var _punch_label: Label # 보조 정보인 펀치 단계.
var _rotation_label: Label # 블록 플립 준비/남은 초.
var _status_label: Label # pause 또는 game-over 중앙 overlay 문구.
var _self_respawn_panel: Panel # hold 중 캐릭터·블록 위에 표시하는 진행 배경.
var _self_respawn_fill: ColorRect # 0~1 hold 비율만큼 넓어지는 주황색 막대.
var _binding_sprite: Sprite2D
var _boss_sprite: Sprite2D
var _boss_thorn_sprite: Sprite2D
var _boss_ice_hit_sprite: Sprite2D
var _boss_seed_sprites: Array[Sprite2D] = []
var _boss_hearts: Array[Sprite2D] = []
var _boss_frame: int = 0
var _boss_frame_timer: float = 0.0
var _boss_thorn_frame_index: int = 0
var _boss_thorn_frame_timer: float = 0.0
var _boss_ice_hit_frame_index: int = 0
var _boss_ice_hit_frame_timer: float = 0.0
var _boss_down_frame: int = 0
var _boss_down_frame_timer: float = 0.0
var _boss_falling_frame: int = 0
var _boss_falling_frame_timer: float = 0.0
var _boss_fallen_frame: int = 0
var _boss_fallen_frame_timer: float = 0.0
var _system_font: SystemFont # 위 Label과 draw_string이 공유할 한글 지원 폰트.
var _language: String = "english"


## 상황: main.tscn의 루트 View가 씬 트리에 들어올 때 Godot가 한 번 호출한다.
## 순서: SystemFont 생성/후보 지정 → `_build_interface()` → 세 signal 연결 → `_refresh()`.
## 결과: retained Label UI가 만들어지고 이후 상태 변경을 자동 반영한다.
func _ready() -> void:
	_apply_game_viewport_size()
	_language = String(get_meta("language", "english"))
	_system_font = SystemFont.new()
	_system_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	_build_interface()
	_create_binding_overlay()
	_create_boss_display()
	controller.game_changed.connect(_refresh)
	controller.boss_attacked.connect(_start_boss_thorn_attack)
	controller.boss_attacked.connect(_start_boss_ice_hit)
	character.stats_changed.connect(_refresh)
	character.binding_started.connect(_refresh)
	character.binding_ended.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_advance_boss_animation(delta)


## 상황: 최초 표시 또는 `queue_redraw()` 이후 Godot CanvasItem draw pass에서 호출된다.
## 순서: 배경 → 두 panel → 보드 → 명상효과 → next → 초상 → bars → 상태 overlay.
## 결과: 그 frame의 controller/character 상태가 즉시-mode draw 명령으로 화면에 표현된다.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	_draw_hud()
	_draw_panel(Rect2(BOARD_ORIGIN - Vector2(12.0, 12.0), BOARD_SIZE + Vector2(24.0, 24.0)))
	_draw_board()
	_draw_thorns()
	_draw_icicles()
	_draw_binding()
	_draw_character_skill_effects()
	_draw_meditation_effect()
	_draw_next_piece()
	_draw_skill_cooldown_bar()
	_draw_state_overlay()


## 상황: `_ready()`에서 값이 바뀌는 텍스트 UI를 최초 한 번 구성할 때 호출한다.
## 순서: 제목/next/줄 수/목숨/타이머/feedback/status Label 생성
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
## 결과: 데스크톱은 세로 게임 창으로 전환하고, Web은 고정 HTML canvas 안의 GameHost가
##       세로 게임 화면을 축소·중앙 정렬하므로 root viewport 크기를 바꾸지 않는다.
func _apply_game_viewport_size() -> void:
	if OS.get_name() == "Web" or OS.has_feature("web"):
		return
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
				var board_cell := Vector2i(x, y + MainBoardModel.HIDDEN_ROWS)
				if controller.board.is_ice_cell(board_cell):
					_draw_ice_cell_overlay(board_cell, cell_rect)

	if controller.state == MainGameController.GameState.GAME_OVER:
		return

	var ghost_position: Vector2i = controller.ghost_origin() # 활성 피스의 예상 착지 원점.
	for local_cell: Vector2i in controller.active_local_cells():
		var ghost_cell: Vector2i = ghost_position + local_cell # 고스트의 절대 보드 셀.
		if ghost_cell.y >= MainBoardModel.HIDDEN_ROWS:
			_draw_ghost(_cell_rect(ghost_cell), controller.active_type)

	for local_cell: Vector2i in controller.active_local_cells():
		var active_cell: Vector2i = controller.active_origin + local_cell # 활성 절대 보드 셀.
		if active_cell.y >= MainBoardModel.HIDDEN_ROWS:
			_draw_block(
				_cell_rect(active_cell),
				controller.active_type,
				1.0
			)

	for x: int in range(MainBoardModel.WIDTH + 1):
		var line_x: float = BOARD_ORIGIN.x + float(x) * CELL_SIZE
		draw_line(Vector2(line_x, BOARD_ORIGIN.y), Vector2(line_x, BOARD_ORIGIN.y + BOARD_SIZE.y), GRID_COLOR)
	for y: int in range(MainBoardModel.VISIBLE_HEIGHT + 1):
		var line_y: float = BOARD_ORIGIN.y + float(y) * CELL_SIZE
		draw_line(Vector2(BOARD_ORIGIN.x, line_y), Vector2(BOARD_ORIGIN.x + BOARD_SIZE.x, line_y), GRID_COLOR)


func _draw_character_skill_effects() -> void:
	var animated_frame: int = int(Time.get_ticks_msec() / 120)
	if controller.fall_freeze_remaining > 0.0:
		_draw_clock_freeze_effect(animated_frame)
	if not controller.water_path_cells.is_empty():
		var water_frame: int = animated_frame % 4
		for cell: Vector2i in controller.water_path_cells:
			if cell.y < MainBoardModel.HIDDEN_ROWS:
				continue
			draw_texture_rect_region(
				WATER_PATH_VFX,
				_water_path_display_rect(cell),
				_water_path_source_rect(water_frame)
			)

	if character.barrier_remaining() > 0.0 and not controller.transient_blocker_cells.is_empty():
		var pulse: float = 0.55 + 0.15 * sin(float(Time.get_ticks_msec()) / 85.0)
		var fade: float = clampf(character.barrier_remaining() / 0.25, 0.0, 1.0)
		for cell: Vector2i in controller.transient_blocker_cells:
			if cell.y < MainBoardModel.HIDDEN_ROWS:
				continue
			var barrier_rect: Rect2 = _cell_rect(cell).grow(-3.0)
			draw_rect(
				barrier_rect,
				Color(0.12, 0.55, 1.0, 0.16 * pulse * fade),
				true
			)
			draw_rect(
				barrier_rect,
				Color(0.30, 0.78, 1.0, 0.92 * fade),
				false,
				3.0
			)

	var character_center: Vector2 = BOARD_ORIGIN + character.position
	if character.sprint_remaining() > 0.0:
		var sprint_frame: int = animated_frame % 8
		draw_texture_rect_region(
			SPRINT_VFX,
			Rect2(character_center - Vector2(64.0, 64.0), Vector2(128.0, 128.0)),
			Rect2(sprint_frame * 128.0, 0.0, 128.0, 128.0)
		)

	if character.character_id == "ninja" and not character.ninja_special_result().is_empty():
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_ninja_shuriken_effect()
		return
	if not character.is_special_animating():
		return
	var local_facing: float = float(character.facing)
	draw_set_transform(character_center, 0.0, Vector2(local_facing, 1.0))
	match character.character_id:
		"clockmaker":
			_draw_clockmaker_cast_effect()
		"boxer":
			var frame: int = mini(character.special_visual_frame(8) / 2, 3)
			draw_texture_rect_region(
				GUARD_BREAK_VFX,
				Rect2(Vector2(34.0, -40.0), Vector2(64.0, 64.0)),
				Rect2(frame * 64.0, 0.0, 64.0, 64.0)
			)
		"firefighter":
			var frame: int = mini(character.special_visual_frame(8) / 2, 3)
			draw_texture_rect_region(
				HOSE_VFX,
				Rect2(Vector2(0.0, -34.0), Vector2(192.0, 64.0)),
				Rect2(frame * 192.0, 0.0, 192.0, 64.0)
			)
		"cleaner":
			var frame: int = mini(character.special_visual_frame(8) * 6 / 8, 5)
			draw_texture_rect_region(
				CLEANUP_VFX,
				Rect2(Vector2(-72.0, 28.0), Vector2(144.0, 48.0)),
				Rect2(frame * 144.0, 0.0, 144.0, 48.0)
			)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_clockmaker_cast_effect() -> void:
	var elapsed: float = character.special_visual_elapsed()
	if elapsed < 0.4:
		var gear_frame: int = mini(floori(elapsed / 0.4 * 4.0), 3)
		var wind_scale: float = lerpf(0.55, 1.0, elapsed / 0.4)
		draw_texture_rect_region(
			CLOCK_GEAR_VFX,
			Rect2(Vector2(-64.0, -89.0) * wind_scale, Vector2.ONE * 128.0 * wind_scale),
			Rect2(gear_frame * 128.0, 0.0, 128.0, 128.0),
			Color(1.0, 1.0, 1.0, 0.82)
		)
		return
	var wave_progress: float = clampf((elapsed - 0.4) / 0.4, 0.0, 1.0)
	var wave_frame: int = mini(floori(wave_progress * 6.0), 5)
	var wave_size: float = lerpf(160.0, 620.0, wave_progress)
	draw_texture_rect_region(
		CLOCK_WAVE_VFX,
		Rect2(Vector2(-wave_size * 0.5, -25.0 - wave_size * 0.5), Vector2.ONE * wave_size),
		Rect2(wave_frame * 192.0, 0.0, 192.0, 192.0),
		Color(1.0, 1.0, 1.0, 0.62 - wave_progress * 0.30)
	)


func _draw_clock_freeze_effect(animated_frame: int) -> void:
	var remaining_ratio: float = clampf(controller.fall_freeze_remaining / 3.0, 0.0, 1.0)
	var ending_factor: float = 1.0
	if controller.fall_freeze_remaining < 0.4:
		ending_factor = clampf(controller.fall_freeze_remaining / 0.4, 0.0, 1.0)
		ending_factor *= 0.62 + 0.38 * absf(sin(float(Time.get_ticks_msec()) / 48.0))
	var pulse: float = 0.08 + 0.025 * sin(float(Time.get_ticks_msec()) / 140.0)
	draw_rect(Rect2(BOARD_ORIGIN, BOARD_SIZE), Color(0.10, 0.68, 0.78, pulse * ending_factor))
	draw_rect(
		Rect2(BOARD_ORIGIN + Vector2.ONE * 3.0, BOARD_SIZE - Vector2.ONE * 6.0),
		Color(0.91, 0.68, 0.20, 0.78 * ending_factor),
		false,
		3.0
	)
	for tick_index: int in range(24):
		var ratio: float = float(tick_index) / 24.0
		var edge_point: Vector2
		var inward: Vector2
		if ratio < 0.25:
			edge_point = BOARD_ORIGIN + Vector2(BOARD_SIZE.x * ratio * 4.0, 5.0)
			inward = Vector2(0.0, 9.0)
		elif ratio < 0.5:
			edge_point = BOARD_ORIGIN + Vector2(BOARD_SIZE.x - 5.0, BOARD_SIZE.y * (ratio - 0.25) * 4.0)
			inward = Vector2(-9.0, 0.0)
		elif ratio < 0.75:
			edge_point = BOARD_ORIGIN + Vector2(BOARD_SIZE.x * (1.0 - (ratio - 0.5) * 4.0), BOARD_SIZE.y - 5.0)
			inward = Vector2(0.0, -9.0)
		else:
			edge_point = BOARD_ORIGIN + Vector2(5.0, BOARD_SIZE.y * (1.0 - (ratio - 0.75) * 4.0))
			inward = Vector2(9.0, 0.0)
		draw_line(edge_point, edge_point + inward, Color(1.0, 0.84, 0.38, 0.72 * ending_factor), 2.0)

	var active_cells: Array[Vector2i] = controller.active_board_cells()
	if active_cells.is_empty():
		return
	var minimum: Vector2i = active_cells[0]
	var maximum: Vector2i = active_cells[0]
	for cell: Vector2i in active_cells:
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	var bounds: Rect2 = _cell_rect(minimum)
	bounds = bounds.expand(_cell_rect(maximum).end)
	var ring_size: float = maxf(bounds.size.x, bounds.size.y) + 24.0
	var ring_center: Vector2 = bounds.get_center()
	var ring_radius: float = ring_size * 0.5
	ring_center.x = clampf(
		ring_center.x,
		BOARD_ORIGIN.x + ring_radius + 4.0,
		BOARD_ORIGIN.x + BOARD_SIZE.x - ring_radius - 4.0
	)
	ring_center.y = clampf(
		ring_center.y,
		BOARD_ORIGIN.y + ring_radius + 4.0,
		BOARD_ORIGIN.y + BOARD_SIZE.y - ring_radius - 4.0
	)
	var gear_frame: int = animated_frame % 4
	draw_set_transform(ring_center, float(Time.get_ticks_msec()) / 4200.0, Vector2.ONE)
	draw_texture_rect_region(
		CLOCK_GEAR_VFX,
		Rect2(Vector2.ONE * -ring_size * 0.5, Vector2.ONE * ring_size),
		Rect2(gear_frame * 128.0, 0.0, 128.0, 128.0),
		Color(1.0, 1.0, 1.0, 0.48 * ending_factor)
	)
	draw_arc(
		Vector2.ZERO,
		ring_size * 0.5 + 7.0,
		-PI * 0.5,
		-PI * 0.5 + TAU * remaining_ratio,
		48,
		Color(0.96, 0.82, 0.35, 0.92 * ending_factor),
		4.0
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ninja_shuriken_effect() -> void:
	var result: Dictionary = character.ninja_special_result()
	if result.is_empty():
		return
	if not result.has("position"):
		return
	var board_position: Vector2 = result["position"] as Vector2
	var center: Vector2 = ninja_shuriken_canvas_position(board_position)
	var direction_now: int = int(result.get("direction", character.facing))
	var spin_frame_now: int = posmod(
		floori(float(result.get("flight_elapsed", 0.0)) / 0.045),
		4
	)
	if bool(result.get("in_flight", false)):
		draw_texture_rect_region(
			SHURIKEN_SPIN_VFX,
			Rect2(center - Vector2.ONE * 16.0, Vector2.ONE * 32.0),
			Rect2(spin_frame_now * 32.0, 0.0, 32.0, 32.0),
			Color.WHITE,
			false
		)
		for trail_index: int in range(1, 4):
			var trail_center := center - Vector2(
				float(direction_now * trail_index) * 10.0,
				0.0
			)
			draw_texture_rect_region(
				SHURIKEN_SPIN_VFX,
				Rect2(trail_center - Vector2.ONE * 12.0, Vector2.ONE * 24.0),
				Rect2(spin_frame_now * 32.0, 0.0, 32.0, 32.0),
				Color(0.58, 0.86, 1.0, 0.28 / float(trail_index))
			)
		return
	var impact_progress_now: float = clampf(
		float(result.get("impact_elapsed", 0.0)) / MainCharacterController.SHURIKEN_IMPACT_DURATION,
		0.0,
		0.999
	)
	var impact_frame_now: int = floori(impact_progress_now * 4.0)
	var source_y_now: float = 0.0 if bool(result.get("success", false)) else 64.0
	draw_texture_rect_region(
		SHURIKEN_IMPACT_VFX,
		Rect2(center - Vector2.ONE * 32.0, Vector2.ONE * 64.0),
		Rect2(impact_frame_now * 64.0, source_y_now, 64.0, 64.0)
	)


func ninja_shuriken_canvas_position(board_position: Vector2) -> Vector2:
	return BOARD_ORIGIN + board_position


## 상황: `_draw()`가 우측 HUD에 다음 피스 미리보기를 표시할 때 호출한다.
## 순서: preview 배경/외곽선 → 24px cell 크기/원점 계산 → 회전 0의 네 셀 draw.
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


## 상황: `_draw()`가 우측 HUD 상단의 캐릭터 정적 카드를 그릴 때 호출한다.
## 순서: atlas의 초상 영역을 destination rect에 draw → 그 위에 캐릭터 제목 draw_string.
## 결과: 게임 상태와 무관한 캐릭터 식별 카드가 표시된다.
func _draw_character_card() -> void:
	var portrait_rect: Rect2 = Rect2(Vector2(696.0, 520.0), Vector2(108.0, 196.0))
	draw_texture_rect_region(
		MainCharacterAnimationData.texture_for_character(character.character_id),
		portrait_rect,
		CHARACTER_SOURCE_RECT
	)
	draw_string(
		_system_font,
		Vector2(662.0, 538.0),
		character.character_display_name(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		16,
		CYAN
	)


## 상황: 세 핵심 상태와 초상 영역을 좁은 패널 안에서 카드로 구분한다.
func _draw_hud_sections() -> void:
	var card_color: Color = Color("#f8fafc")
	var card_rects: Array[Rect2] = [
		Rect2(576.0, 318.0, 368.0, 190.0),
		Rect2(576.0, 516.0, 368.0, 224.0),
		Rect2(576.0, 754.0, 368.0, 70.0),
		Rect2(576.0, 832.0, 368.0, 64.0),
		Rect2(576.0, 902.0, 368.0, 42.0),
		Rect2(576.0, 950.0, 368.0, 70.0),
	]
	for card_rect: Rect2 in card_rects:
		draw_rect(card_rect, card_color)
		draw_rect(card_rect, Color("#b7c2d1"), false, 1.0)


## 상황: `_draw()`가 게임판 아래에 현재 캐릭터의 특수 스킬 준비도를 표시할 때 호출한다.
## 순서: 쿨타임 비율을 bar fill로 변환한다.
## 결과: 스테미나와 텍스트를 별도 HUD로 노출하지 않고 스킬 쿨타임 bar만 하단에 표시한다.
func _draw_skill_cooldown_bar() -> void:
	var cooldown_ratio: float = character.special_cooldown_ratio()
	_draw_bar(
		SPECIAL_BAR_RECT,
		1.0 - cooldown_ratio,
		ORANGE
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
	if (
		controller.state == MainGameController.GameState.PLAYING
		or controller.state == MainGameController.GameState.BOSS_FALLING
		or controller.state == MainGameController.GameState.BOSS_DYING
	):
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


## 물길 원본 프레임에서 실제 물 픽셀이 있는 6px 높이만 잘라 확대한다.
func _water_path_source_rect(frame: int) -> Rect2:
	return Rect2(
		float(posmod(frame, 4)) * WATER_PATH_SOURCE_FRAME_WIDTH,
		WATER_PATH_SOURCE_VISIBLE_Y,
		WATER_PATH_SOURCE_FRAME_WIDTH,
		WATER_PATH_SOURCE_VISIBLE_HEIGHT
	)


## 빈 물길 셀의 바닥선과 아래 고정 블록 윗면에 물줄기를 밀착시킨다.
func _water_path_display_rect(board_cell: Vector2i) -> Rect2:
	var cell_rect: Rect2 = _cell_rect(board_cell)
	return Rect2(
		Vector2(
			cell_rect.position.x,
			cell_rect.end.y - WATER_PATH_DISPLAY_HEIGHT + WATER_PATH_SURFACE_OVERLAP
		),
		Vector2(CELL_SIZE, WATER_PATH_DISPLAY_HEIGHT)
	)


## 상황: 최초 준비 또는 controller/character signal로 표시 데이터가 바뀔 때 호출한다.
## 순서: node ready 검사 → stats 문자열 → 생명 icon/cooldown 문자열 → character 문자열
##       → feedback → state별 status/visibility → `queue_redraw()`.
## 결과: retained Label과 다음 즉시-mode draw pass가 같은 최신 상태를 표시한다.
func _refresh() -> void:
	if not is_node_ready():
		return
	_refresh_boss_display()
	_lines_label.text = _text("삭제한 줄 %d", "LINES %d") % controller.total_lines
	_lives_label.text = _text("목숨: %d", "LIVES: %d") % character.lives
	var remaining_seconds: int = ceili(controller.stage_time_remaining)
	_timer_label.text = "%02d:%02d" % [remaining_seconds / 60, remaining_seconds % 60]
	_timer_label.visible = not controller.is_challenge_mode()
	var self_respawn_ratio: float = character.self_respawn_hold_ratio()
	_self_respawn_panel.visible = self_respawn_ratio > 0.0
	_self_respawn_fill.size.x = SELF_RESPAWN_BAR_RECT.size.x * self_respawn_ratio
	match controller.state:
		MainGameController.GameState.PAUSED:
			_status_label.text = _text("일시정지\n\nP로 계속 · Esc로 메뉴", "PAUSED\n\nP Resume · Esc Menu")
			_status_label.visible = true
		MainGameController.GameState.GAME_OVER:
			_status_label.text = _text("게임 오버\n\nR 키로 다시 시작\nEsc 키로 메뉴", "GAME OVER\n\nR Restart\nEsc Menu")
			_status_label.visible = true
		_:
			_status_label.visible = false
	queue_redraw()


func _text(korean: String, english: String) -> String:
	return MainLocalization.translated_for_language(korean, english, _language)


func _thorn_texture_for_stage(stage_number: int) -> Texture2D:
	return (
		ICE_BLOCK_TEXTURE
		if stage_number >= MainGameController.ICE_BLOCK_STAGE_START
		else THORN_TEXTURE
	)


func _thorn_source_region_for_stage(stage_number: int) -> Rect2:
	return (
		ICE_BLOCK_SOURCE_REGION
		if stage_number >= MainGameController.ICE_BLOCK_STAGE_START
		else THORN_SOURCE_REGION
	)


func _draw_thorns() -> void:
	if not controller.active_piece_has_visible_thorns():
		return
	var cells: Array[Vector2i] = MainTetrominoData.get_cells(controller.active_type, controller.active_rotation)
	var faces: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var angles: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]
	var thorn_texture: Texture2D = _thorn_texture_for_stage(controller.stage_number)
	var thorn_source_region: Rect2 = _thorn_source_region_for_stage(controller.stage_number)
	for local_cell: Vector2i in cells:
		var active_cell: Vector2i = controller.active_origin + local_cell
		if active_cell.y < MainBoardModel.HIDDEN_ROWS:
			continue
		var cell_rect: Rect2 = _cell_rect(active_cell)
		var cell_center: Vector2 = cell_rect.get_center()
		for index: int in range(faces.size()):
			if cells.has(local_cell + faces[index]):
				continue
			var face_center: Vector2 = cell_center + Vector2(faces[index]) * (CELL_SIZE * 0.5 + THORN_DEPTH * 0.5 - THORN_EDGE_OVERLAP)
			draw_set_transform(face_center, angles[index])
			draw_texture_rect_region(thorn_texture, Rect2(-CELL_SIZE * 0.5, -THORN_DEPTH * 0.5, CELL_SIZE, THORN_DEPTH), thorn_source_region)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_icicles() -> void:
	if controller.icicles.is_empty():
		return
	for icicle: Dictionary in controller.icicles:
		var pos: Vector2 = icicle["position"] as Vector2
		var warning: float = float(icicle.get("warning_remaining", 0.0))
		var canvas_pos: Vector2 = BOARD_ORIGIN + pos
		var half_h: float = MainGameController.ICICLE_SIZE.y * 0.5
		if warning > 0.0:
			var pulse: float = 0.55 + 0.35 * absf(sin(float(Time.get_ticks_msec()) * 0.008))
			var beam_color: Color = Color(1.0, 0.18, 0.18, 0.42 * pulse)
			var beam_rect: Rect2 = Rect2(
				Vector2(canvas_pos.x - 3.0, BOARD_ORIGIN.y),
				Vector2(6.0, BOARD_SIZE.y)
			)
			draw_rect(beam_rect, beam_color)
			draw_rect(beam_rect, Color(1.0, 0.22, 0.22, 0.78 * pulse), false, 1.5)
			var dot_color: Color = Color(1.0, 0.18, 0.18, 0.9 * pulse)
			var dot_y: float = BOARD_ORIGIN.y + BOARD_SIZE.y - 10.0
			draw_circle(Vector2(canvas_pos.x, dot_y), 5.0, dot_color)
		var dst: Rect2 = Rect2(canvas_pos - MainGameController.ICICLE_SIZE * 0.5, MainGameController.ICICLE_SIZE)
		var is_aiming: bool = warning > 0.0
		if is_aiming:
			var bob: float = sin(float(Time.get_ticks_msec()) * 0.01) * 2.5
			dst.position.y += bob
		draw_texture_rect(ICICLE_TEXTURE, dst, false)
		if is_aiming:
			var shadow_alpha: float = 0.18 + 0.08 * sin(float(Time.get_ticks_msec()) * 0.01)
			draw_rect(Rect2(Vector2(canvas_pos.x - 10.0, BOARD_ORIGIN.y + BOARD_SIZE.y - 6.0), Vector2(20.0, 6.0)), Color(1.0, 0.1, 0.1, shadow_alpha))


## 상황: 고정 얼음 셀 하나의 외곽 4면에 얼음 block overlay를 그릴 때 호출한다.
## 순서: 인접 셀(고정/활성)이 없는 면을 골라 활성 피스와 동일한 방식으로 그린다.
## 결과: 고정된 얼음 블록도 피스가 비활성화된 뒤에 얼음 외형을 유지한다.
func _draw_ice_cell_overlay(board_cell: Vector2i, cell_rect: Rect2) -> void:
	var faces: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var angles: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]
	var cell_center: Vector2 = cell_rect.get_center()
	for index: int in range(faces.size()):
		var neighbor: Vector2i = board_cell + faces[index]
		if controller.board.get_cell(neighbor) != MainBoardModel.EMPTY:
			continue
		if neighbor in controller.active_board_cells():
			continue
		var face_center: Vector2 = cell_center + Vector2(faces[index]) * (
			CELL_SIZE * 0.5 + THORN_DEPTH * 0.5 - THORN_EDGE_OVERLAP
		)
		draw_set_transform(face_center, angles[index])
		draw_texture_rect_region(
			ICE_BLOCK_TEXTURE,
			Rect2(-CELL_SIZE * 0.5, -THORN_DEPTH * 0.5, CELL_SIZE, THORN_DEPTH),
			ICE_BLOCK_SOURCE_REGION
		)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_binding() -> void:
	if _binding_sprite == null:
		return
	_sync_binding_overlay_transform()
	_binding_sprite.visible = character.is_bound


func _create_binding_overlay() -> void:
	_binding_sprite = Sprite2D.new()
	_binding_sprite.name = "BindingSprite"
	_binding_sprite.texture = BIND_TEXTURE
	_binding_sprite.region_enabled = true
	_binding_sprite.region_rect = MainCharacterAnimationData.opaque_region_for(
		BIND_TEXTURE,
		BIND_SOURCE_REGION
	)
	_binding_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_binding_sprite.z_index = 1
	_binding_sprite.visible = false
	character.add_child(_binding_sprite)
	_sync_binding_overlay_transform()


func _sync_binding_overlay_transform() -> void:
	if _binding_sprite == null or not is_instance_valid(character.sprite):
		return
	var bind_height: float = (
		MainCharacterAnimationData.visible_height_for(
			MainCharacterAnimationData.IDLE,
			character.character_id
		)
		+ BIND_HEIGHT_MARGIN
	)
	var uniform_scale: float = bind_height / maxf(_binding_sprite.region_rect.size.y, 1.0)
	_binding_sprite.scale = Vector2.ONE * uniform_scale
	_binding_sprite.position = character.sprite.position


func _create_boss_display() -> void:
	var board_physics: Node2D = $BoardPhysics
	_boss_sprite = Sprite2D.new()
	_boss_sprite.name = "BossSprite"
	_boss_sprite.texture = ICE_BOSS_TEXTURE if _is_ice_boss_stage() else BOSS_NORMAL_TEXTURE
	_boss_sprite.region_enabled = true
	_boss_sprite.scale = (
		ICE_BOSS_DISPLAY_SIZE / ICE_BOSS_SOURCE_FRAME_SIZE
		if _is_ice_boss_stage()
		else MainGameController.BOSS_DISPLAY_SIZE / BOSS_SOURCE_FRAME_SIZE
	)
	_boss_sprite.position = MainGameController.BOSS_POSITION + BOSS_VISUAL_OFFSET
	_boss_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_boss_sprite.z_index = 2
	board_physics.add_child(_boss_sprite)

	_boss_thorn_sprite = Sprite2D.new()
	_boss_thorn_sprite.name = "BossThornSprite"
	_boss_thorn_sprite.texture = BOSS_THORN_TEXTURE
	_boss_thorn_sprite.region_enabled = true
	_boss_thorn_sprite.scale = MainGameController.BOSS_DISPLAY_SIZE / BOSS_SOURCE_FRAME_SIZE
	_boss_thorn_sprite.position = MainGameController.BOSS_POSITION + BOSS_VISUAL_OFFSET
	_boss_thorn_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_boss_thorn_sprite.z_index = 3
	_boss_thorn_sprite.visible = false
	board_physics.add_child(_boss_thorn_sprite)

	_boss_ice_hit_sprite = Sprite2D.new()
	_boss_ice_hit_sprite.name = "BossIceHitSprite"
	_boss_ice_hit_sprite.texture = ICE_HIT_TEXTURE
	_boss_ice_hit_sprite.region_enabled = true
	_boss_ice_hit_sprite.scale = ICE_BOSS_DISPLAY_SIZE / ICE_BOSS_SOURCE_FRAME_SIZE
	_boss_ice_hit_sprite.position = MainGameController.BOSS_POSITION + BOSS_VISUAL_OFFSET
	_boss_ice_hit_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_boss_ice_hit_sprite.z_index = 3
	_boss_ice_hit_sprite.visible = false
	board_physics.add_child(_boss_ice_hit_sprite)

	for index: int in range(MainGameController.BOSS_SEED_COUNT):
		var seed_sprite: Sprite2D = Sprite2D.new()
		seed_sprite.name = "BossSeed%d" % (index + 1)
		seed_sprite.texture = BOSS_SEED_TEXTURE
		seed_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		seed_sprite.z_index = 4
		seed_sprite.visible = false
		board_physics.add_child(seed_sprite)
		_boss_seed_sprites.append(seed_sprite)

	for index: int in range(MainGameController.BOSS_MAX_HEALTH):
		var heart: Sprite2D = Sprite2D.new()
		heart.name = "BossHeart%d" % (index + 1)
		heart.texture = HEART_TEXTURE
		heart.scale = HEART_DISPLAY_SIZE / Vector2(24.0, 24.0)
		heart.position = MainGameController.BOSS_POSITION + BOSS_VISUAL_OFFSET + Vector2(
			float(index - 1) * 18.0,
			106.0
		)
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heart.z_index = 3
		board_physics.add_child(heart)
		_boss_hearts.append(heart)

	_apply_boss_frame()
	_apply_boss_thorn_frame()
	_apply_boss_ice_hit_frame()


func _is_ice_boss_stage() -> bool:
	return controller.stage_number == ICE_BOSS_STAGE


func _advance_ice_boss_animation(delta: float) -> void:
	_boss_thorn_sprite.visible = false
	if controller.is_boss_alive():
		_boss_frame_timer += maxf(delta, 0.0)
		while _boss_frame_timer >= BOSS_FRAME_INTERVAL:
			_boss_frame_timer -= BOSS_FRAME_INTERVAL
			_boss_frame = (_boss_frame + 1) % BOSS_FRAME_COUNT
			_apply_boss_frame()
	elif controller.is_boss_dying():
		_boss_down_frame_timer += maxf(delta, 0.0)
		while (
			_boss_down_frame_timer >= BOSS_FRAME_INTERVAL
			and _boss_down_frame < BOSS_FRAME_COUNT - 1
		):
			_boss_down_frame_timer -= BOSS_FRAME_INTERVAL
			_boss_down_frame += 1
			_apply_boss_down_frame()
		if _boss_down_frame >= BOSS_FRAME_COUNT - 1:
			_boss_down_frame_timer = 0.0


func _advance_boss_animation(delta: float) -> void:
	if _boss_sprite == null:
		return
	if _is_ice_boss_stage():
		_advance_ice_boss_animation(delta)
		_advance_boss_ice_hit_overlay(delta)
		return
	if controller.is_boss_alive():
		_boss_frame_timer += maxf(delta, 0.0)
		while _boss_frame_timer >= BOSS_FRAME_INTERVAL:
			_boss_frame_timer -= BOSS_FRAME_INTERVAL
			_boss_frame = (_boss_frame + 1) % BOSS_FRAME_COUNT
			_apply_boss_frame()
	elif controller.is_boss_down():
		_advance_boss_down_animation(delta)
	elif controller.is_boss_falling():
		_advance_boss_falling_animation(delta)
	elif controller.is_boss_fallen():
		_advance_boss_fallen_animation(delta)
	else:
		_boss_thorn_sprite.visible = false

	_advance_boss_thorn_overlay(delta)
	_advance_boss_ice_hit_overlay(delta)


func _advance_boss_thorn_overlay(delta: float) -> void:
	if not _boss_thorn_sprite.visible:
		return
	_boss_thorn_frame_timer += maxf(delta, 0.0)
	while _boss_thorn_frame_timer >= BOSS_THORN_FRAME_INTERVAL:
		_boss_thorn_frame_timer -= BOSS_THORN_FRAME_INTERVAL
		_boss_thorn_frame_index += 1
		if _boss_thorn_frame_index >= BOSS_THORN_FRAME_SEQUENCE.size():
			_boss_thorn_sprite.visible = false
			_boss_thorn_frame_timer = 0.0
			break
		_apply_boss_thorn_frame()


## 상황: 10층 얼음 보스 피격 오버레이(ice_hit)의 프레임을 진행할 때 호출한다.
## 순서: 타이머 누적 → 0.18초마다 시퀀스 인덱스 증가 → 끝나면 숨김.
## 결과: 1→2→3→4→3→2→1 왕복을 재생하고 자동으로 사라진다.
func _advance_boss_ice_hit_overlay(delta: float) -> void:
	if not _boss_ice_hit_sprite.visible:
		return
	_boss_ice_hit_frame_timer += maxf(delta, 0.0)
	while _boss_ice_hit_frame_timer >= ICE_HIT_FRAME_INTERVAL:
		_boss_ice_hit_frame_timer -= ICE_HIT_FRAME_INTERVAL
		_boss_ice_hit_frame_index += 1
		if _boss_ice_hit_frame_index >= ICE_HIT_FRAME_SEQUENCE.size():
			_boss_ice_hit_sprite.visible = false
			_boss_ice_hit_frame_timer = 0.0
			break
		_apply_boss_ice_hit_frame()


func _advance_boss_down_animation(delta: float) -> void:
	if _boss_down_frame >= BOSS_FRAME_COUNT - 1:
		return
	_boss_down_frame_timer += maxf(delta, 0.0)
	while (
		_boss_down_frame_timer >= BOSS_FRAME_INTERVAL
		and _boss_down_frame < BOSS_FRAME_COUNT - 1
	):
		_boss_down_frame_timer -= BOSS_FRAME_INTERVAL
		_boss_down_frame += 1
		_apply_boss_down_frame()
	if _boss_down_frame >= BOSS_FRAME_COUNT - 1:
		_boss_down_frame_timer = 0.0


func _advance_boss_falling_animation(delta: float) -> void:
	_boss_falling_frame_timer += maxf(delta, 0.0)
	while _boss_falling_frame_timer >= BOSS_FRAME_INTERVAL:
		_boss_falling_frame_timer -= BOSS_FRAME_INTERVAL
		_boss_falling_frame = (_boss_falling_frame + 1) % BOSS_FRAME_COUNT
		_apply_boss_falling_frame()


func _advance_boss_fallen_animation(delta: float) -> void:
	_boss_fallen_frame_timer += maxf(delta, 0.0)
	while _boss_fallen_frame_timer >= BOSS_FRAME_INTERVAL:
		_boss_fallen_frame_timer -= BOSS_FRAME_INTERVAL
		_boss_fallen_frame = (_boss_fallen_frame + 1) % BOSS_FRAME_COUNT
		_apply_boss_fallen_frame()


func _apply_boss_frame() -> void:
	_apply_boss_sheet_frame(
		_boss_frame,
		ICE_BOSS_SOURCE_FRAME_SIZE if _is_ice_boss_stage() else BOSS_SOURCE_FRAME_SIZE
	)


func _apply_boss_down_frame() -> void:
	if _is_ice_boss_stage():
		_apply_boss_sheet_frame(_boss_down_frame, ICE_BOSS_SOURCE_FRAME_SIZE)
		return
	_apply_boss_sheet_frame(_boss_down_frame, BOSS_DOWN_SOURCE_FRAME_SIZE)


func _apply_boss_falling_frame() -> void:
	if _is_ice_boss_stage():
		_apply_boss_sheet_frame(BOSS_FRAME_COUNT - 1, ICE_BOSS_SOURCE_FRAME_SIZE)
		return
	_apply_boss_sheet_frame(_boss_falling_frame, BOSS_SOURCE_FRAME_SIZE)


func _apply_boss_fallen_frame() -> void:
	if _is_ice_boss_stage():
		_apply_boss_sheet_frame(BOSS_FRAME_COUNT - 1, ICE_BOSS_SOURCE_FRAME_SIZE)
		return
	_apply_boss_sheet_frame(_boss_fallen_frame, BOSS_FALLEN_SOURCE_FRAME_SIZE)


func _apply_boss_sheet_frame(frame: int, source_frame_size: Vector2) -> void:
	_boss_sprite.region_rect = Rect2(
		float(frame) * source_frame_size.x,
		0.0,
		source_frame_size.x,
		source_frame_size.y
	)


func _apply_boss_thorn_frame() -> void:
	_boss_thorn_sprite.region_rect = Rect2(
		float(BOSS_THORN_FRAME_SEQUENCE[_boss_thorn_frame_index]) * BOSS_SOURCE_FRAME_SIZE.x,
		0.0,
		BOSS_SOURCE_FRAME_SIZE.x,
		BOSS_SOURCE_FRAME_SIZE.y
	)


func _start_boss_thorn_attack() -> void:
	if not controller.is_boss_alive():
		return
	_boss_thorn_frame_index = 0
	_boss_thorn_frame_timer = 0.0
	_boss_thorn_sprite.visible = true
	_apply_boss_thorn_frame()


## 상황: 플레이어가 10층 얼음 보스를 직접 때린 순간(boss_attacked) 호출한다.
## 순서: 보스 생존 확인 → ice_hit 프레임/타이머 초기화 → 오버레이 표시.
## 결과: 본체 sprite는 그대로 두고 1→2→3→4→3→2→1 왕복 오버레이가 시작된다.
func _start_boss_ice_hit() -> void:
	if not _is_ice_boss_stage() or not controller.is_boss_alive():
		return
	_boss_ice_hit_frame_index = 0
	_boss_ice_hit_frame_timer = 0.0
	_boss_ice_hit_sprite.visible = true
	_apply_boss_ice_hit_frame()


func _apply_boss_ice_hit_frame() -> void:
	_boss_ice_hit_sprite.region_rect = Rect2(
		float(ICE_HIT_FRAME_SEQUENCE[_boss_ice_hit_frame_index]) * ICE_BOSS_SOURCE_FRAME_SIZE.x,
		0.0,
		ICE_BOSS_SOURCE_FRAME_SIZE.x,
		ICE_BOSS_SOURCE_FRAME_SIZE.y
	)


func _refresh_boss_display() -> void:
	if _boss_sprite == null:
		return
	_refresh_boss_seed_display()
	var boss_alive: bool = controller.is_boss_alive()
	var boss_visible: bool = (
		boss_alive
		or controller.is_boss_down()
		or controller.is_boss_falling()
		or controller.is_boss_fallen()
		or controller.is_boss_dying()
	)
	_boss_sprite.visible = boss_visible
	for index: int in range(_boss_hearts.size()):
		_boss_hearts[index].visible = boss_alive and index < controller.boss_health
	if not boss_alive:
		_boss_thorn_sprite.visible = false
		_boss_ice_hit_sprite.visible = false

	if _is_ice_boss_stage():
		_refresh_ice_boss_display(boss_visible)
		return

	if controller.is_boss_down():
		if _boss_sprite.texture != BOSS_DOWN_TEXTURE:
			_boss_sprite.texture = BOSS_DOWN_TEXTURE
			_boss_sprite.region_enabled = true
			_boss_sprite.scale = BOSS_DOWN_DISPLAY_SIZE / BOSS_DOWN_SOURCE_FRAME_SIZE
			_boss_down_frame = 0
			_boss_down_frame_timer = 0.0
		_boss_sprite.position = Vector2(
			controller.boss_fall_position.x,
			controller.boss_fall_position.y - BOSS_DOWN_DISPLAY_SIZE.y * 0.5 + BOSS_VISUAL_OFFSET.y
			)
		_apply_boss_down_frame()
		return

	if controller.is_boss_falling():
		if _boss_sprite.texture != BOSS_FALLING_TEXTURE:
			_boss_sprite.texture = BOSS_FALLING_TEXTURE
			_boss_sprite.region_enabled = true
			_boss_sprite.scale = BOSS_DISPLAY_SIZE / BOSS_SOURCE_FRAME_SIZE
			_boss_falling_frame = 0
			_boss_falling_frame_timer = 0.0
		_boss_sprite.position = Vector2(
			controller.boss_fall_position.x,
			controller.boss_fall_position.y - BOSS_DISPLAY_SIZE.y * 0.5 + BOSS_VISUAL_OFFSET.y
		)
		_apply_boss_falling_frame()
		return

	if controller.is_boss_fallen():
		if _boss_sprite.texture != BOSS_FALLEN_TEXTURE:
			_boss_sprite.texture = BOSS_FALLEN_TEXTURE
			_boss_sprite.region_enabled = true
			_boss_sprite.scale = BOSS_FALLEN_DISPLAY_SIZE / BOSS_FALLEN_SOURCE_FRAME_SIZE
			_boss_fallen_frame = 0
			_boss_fallen_frame_timer = 0.0
		_boss_sprite.position = Vector2(
			controller.boss_fall_position.x,
			controller.boss_fall_position.y - BOSS_FALLEN_DISPLAY_SIZE.y * 0.5
		)
		_apply_boss_fallen_frame()
		return

	if not boss_visible:
		return

	var boss_texture: Texture2D = BOSS_BIND_TEXTURE if character.is_bound else BOSS_NORMAL_TEXTURE
	if _boss_sprite.texture != boss_texture or not _boss_sprite.region_enabled:
		_boss_sprite.texture = boss_texture
		_boss_sprite.region_enabled = true
		_boss_sprite.scale = MainGameController.BOSS_DISPLAY_SIZE / BOSS_SOURCE_FRAME_SIZE
		_boss_frame = 0
		_boss_frame_timer = 0.0
	_boss_sprite.position = MainGameController.BOSS_POSITION + BOSS_VISUAL_OFFSET
	_apply_boss_frame()


func _refresh_ice_boss_display(boss_visible: bool) -> void:
	if not boss_visible:
		return
	var is_dying: bool = not controller.is_boss_alive()
	var boss_texture: Texture2D = ICE_BOSS_DIE_TEXTURE if is_dying else ICE_BOSS_TEXTURE
	if _boss_sprite.texture != boss_texture or not _boss_sprite.region_enabled:
		_boss_sprite.texture = boss_texture
		_boss_sprite.region_enabled = true
		_boss_sprite.scale = ICE_BOSS_DISPLAY_SIZE / ICE_BOSS_SOURCE_FRAME_SIZE
		if is_dying:
			_boss_down_frame = 0
			_boss_down_frame_timer = 0.0
		else:
			_boss_frame = 0
			_boss_frame_timer = 0.0
	if controller.is_boss_dying():
		_boss_sprite.position = MainGameController.BOSS_POSITION + BOSS_VISUAL_OFFSET
		_apply_boss_down_frame()
		return
	_boss_sprite.position = MainGameController.BOSS_POSITION + BOSS_VISUAL_OFFSET
	_apply_boss_frame()


func _refresh_boss_seed_display() -> void:
	for index: int in range(_boss_seed_sprites.size()):
		var seed_sprite: Sprite2D = _boss_seed_sprites[index]
		if not controller.is_boss_alive() or index >= controller.boss_seeds.size():
			seed_sprite.visible = false
			continue
		var seed: Dictionary = controller.boss_seeds[index]
		seed_sprite.position = seed["position"] as Vector2
		seed_sprite.visible = true
