class_name StartScreenTutorialCanvas
extends Control

const PORTRAIT: Texture2D = preload("res://assets/sprites/player_animations.png")
const PORTRAIT_SOURCE: Rect2 = Rect2(45.0, 55.0, 165.0, 270.0)
const BLOCK_TEXTURE: Texture2D = preload("res://assets/sprites/block_sprites.png")
const BLOCK_SPRITE_REGIONS: Dictionary = {
	"cyan": Rect2(80.0, 255.0, 210.0, 215.0),
	"orange": Rect2(1745.0, 255.0, 210.0, 215.0),
	"purple": Rect2(640.0, 255.0, 210.0, 215.0),
	"red": Rect2(1190.0, 255.0, 210.0, 215.0),
}

const PANEL: Color = Color("#ffffff")
const PANEL_DARK: Color = Color("#eef2f7")
const BORDER: Color = Color("#8390a3")
const TEXT: Color = Color("#152033")
const MUTED: Color = Color("#344158")
const CYAN: Color = Color("#2c8fd6")
const ORANGE: Color = Color("#e47719")
const PURPLE: Color = Color("#6f57c9")
const RED: Color = Color("#d9485f")

var page: int = 0
var settings: StartScreenSettings
var _font: SystemFont


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])


func set_settings(value: StartScreenSettings) -> void:
	settings = value
	if settings != null and not settings.bindings_changed.is_connected(queue_redraw):
		settings.bindings_changed.connect(queue_redraw)
	queue_redraw()


func set_page(value: int) -> void:
	page = clampi(value, 0, 3)
	queue_redraw()


func _draw() -> void:
	_draw_round_panel(Rect2(Vector2.ZERO, size), PANEL, BORDER, 12.0)
	match page:
		0:
			_draw_movement_page()
		1:
			_draw_block_action_page()
		2:
			_draw_wall_page()
		3:
			_draw_system_page()


func _draw_movement_page() -> void:
	_draw_page_heading("1. 이동과 점프", "기본 이동부터 높이 조절 점프까지")
	var left_card: Rect2 = Rect2(22.0, 70.0, 374.0, 382.0)
	var right_card: Rect2 = Rect2(424.0, 70.0, 374.0, 382.0)
	_draw_card(left_card)
	_draw_card(right_card)

	_draw_step_badge(Vector2(52.0, 108.0), 1, CYAN)
	_text(Vector2(88.0, 116.0), "좌우 이동", 21, TEXT)
	_text(
		Vector2(52.0, 148.0),
		"[%s] 키로 블록 사이를 이동합니다." % _keys(&"character_left", &"character_right"),
		15,
		MUTED
	)
	_draw_floor(Vector2(54.0, 365.0), 310.0)
	_draw_character(Rect2(85.0, 237.0, 61.0, 116.0), 1.0)
	_draw_character(Rect2(277.0, 237.0, 61.0, 116.0), 0.35)
	_draw_arrow(Vector2(158.0, 295.0), Vector2(265.0, 295.0), CYAN, 5.0)
	_key_chip(Vector2(150.0, 318.0), _binding(&"character_left"), CYAN)
	_key_chip(Vector2(235.0, 318.0), _binding(&"character_right"), CYAN)

	_draw_step_badge(Vector2(454.0, 108.0), 2, ORANGE)
	_text(Vector2(490.0, 116.0), "점프", 21, TEXT)
	_text(
		Vector2(454.0, 148.0),
		"[%s]를 짧게/길게 눌러 높이를 조절합니다." % _binding(&"character_jump"),
		15,
		MUTED
	)
	_draw_floor(Vector2(456.0, 365.0), 310.0)
	_draw_character(Rect2(470.0, 237.0, 61.0, 116.0), 1.0)
	_draw_character(Rect2(675.0, 170.0, 61.0, 116.0), 0.38)
	_draw_arc_arrow(
		Vector2(540.0, 280.0),
		Vector2(665.0, 222.0),
		Vector2(610.0, 145.0),
		ORANGE
	)
	_key_chip(Vector2(574.0, 316.0), _binding(&"character_jump"), ORANGE)
	_text(Vector2(510.0, 411.0), "빠르게 놓기: 낮게   ·   유지: 높게", 14, MUTED)


func _draw_block_action_page() -> void:
	_draw_page_heading("2. 블록 조작", "밀고, 당기고, 회전시켜 길을 만드세요")
	var cards: Array[Rect2] = [
		Rect2(20.0, 70.0, 246.0, 382.0),
		Rect2(287.0, 70.0, 246.0, 382.0),
		Rect2(554.0, 70.0, 246.0, 382.0),
	]
	for card: Rect2 in cards:
		_draw_card(card)

	_draw_step_badge(Vector2(44.0, 104.0), 1, ORANGE)
	_text(Vector2(80.0, 113.0), "차지 펀치", 19, TEXT)
	_key_chip(Vector2(170.0, 96.0), _binding(&"character_punch"), ORANGE)
	_draw_floor(Vector2(42.0, 360.0), 202.0)
	_draw_character(Rect2(47.0, 241.0, 55.0, 106.0), 1.0)
	_draw_tetromino(Vector2(125.0, 284.0), CYAN)
	_draw_arrow(Vector2(155.0, 275.0), Vector2(213.0, 275.0), ORANGE, 4.0)
	_text(Vector2(44.0, 392.0), "즉시 1칸 · 0.4초 2칸", 13, MUTED)
	_text(Vector2(44.0, 415.0), "0.9초 3칸 밀기", 13, MUTED)

	_draw_step_badge(Vector2(311.0, 104.0), 2, CYAN)
	_text(Vector2(347.0, 113.0), "블록 당기기", 19, TEXT)
	_key_chip(Vector2(455.0, 96.0), _binding(&"character_pull"), CYAN)
	_draw_floor(Vector2(309.0, 360.0), 202.0)
	_draw_character(Rect2(445.0, 241.0, 55.0, 106.0), 1.0)
	_draw_tetromino(Vector2(324.0, 284.0), PURPLE)
	_draw_arrow(Vector2(400.0, 275.0), Vector2(438.0, 275.0), CYAN, 4.0)
	_text(Vector2(311.0, 392.0), "지상 · 4블록 이내", 13, MUTED)
	_text(Vector2(311.0, 415.0), "성공 시 스태미나 10", 13, MUTED)

	_draw_step_badge(Vector2(578.0, 104.0), 3, PURPLE)
	_text(Vector2(614.0, 113.0), "회전 킥", 19, TEXT)
	_key_chip(Vector2(722.0, 96.0), _binding(&"character_rotation_kick"), PURPLE)
	_draw_floor(Vector2(576.0, 360.0), 202.0)
	_draw_character(Rect2(579.0, 241.0, 55.0, 106.0), 1.0)
	_draw_tetromino(Vector2(682.0, 279.0), RED)
	_draw_arc_arrow(
		Vector2(675.0, 260.0),
		Vector2(748.0, 246.0),
		Vector2(718.0, 205.0),
		PURPLE
	)
	_text(Vector2(578.0, 392.0), "지상·공중 모두 사용", 13, MUTED)
	_text(Vector2(578.0, 415.0), "스태미나 25 · 쿨타임 2초", 13, MUTED)


func _draw_wall_page() -> void:
	_draw_page_heading("3. 매달리기와 벽 점프", "화살표 순서대로 입력하면 더 높은 위치에 재매달립니다")
	_draw_card(Rect2(20.0, 70.0, 780.0, 382.0))
	var floor_y: float = 396.0
	draw_rect(Rect2(80.0, 126.0, 34.0, floor_y - 126.0), Color("#c8d1dd"))
	draw_rect(Rect2(80.0, 126.0, 34.0, floor_y - 126.0), BORDER, false, 2.0)
	_draw_floor(Vector2(80.0, floor_y), 650.0)

	_draw_character(Rect2(112.0, 252.0, 56.0, 108.0), 1.0)
	_draw_step_badge(Vector2(145.0, 238.0), 1, CYAN)
	_key_chip(Vector2(190.0, 354.0), _binding(&"character_grab"), CYAN)
	_text(Vector2(190.0, 440.0), "C 유지 중 ↑/↓로 벽 이동", 13, MUTED)

	_draw_character(Rect2(330.0, 174.0, 56.0, 108.0), 0.55)
	_draw_arc_arrow(
		Vector2(174.0, 265.0),
		Vector2(320.0, 218.0),
		Vector2(245.0, 135.0),
		ORANGE
	)
	_draw_step_badge(Vector2(347.0, 154.0), 2, ORANGE)
	_key_chip(
		Vector2(281.0, 300.0),
		"%s + %s" % [_binding(&"character_grab"), _binding(&"character_jump")],
		ORANGE
	)
	_text(Vector2(285.0, 342.0), "벽 반대 방향으로 점프", 13, MUTED)

	_draw_character(Rect2(130.0, 137.0, 56.0, 108.0), 0.72)
	_draw_arc_arrow(
		Vector2(340.0, 176.0),
		Vector2(193.0, 176.0),
		Vector2(267.0, 82.0),
		PURPLE
	)
	_draw_step_badge(Vector2(187.0, 122.0), 3, PURPLE)
	_key_chip(Vector2(442.0, 113.0), _binding(&"character_left"), PURPLE)
	_text(Vector2(442.0, 158.0), "원래 벽 방향으로 직접 조향", 14, TEXT)
	_text(
		Vector2(442.0, 190.0),
		"%s를 유지하면 높은 위치에 다시 매달립니다." % _binding(&"character_grab"),
		14,
		MUTED
	)
	_text(
		Vector2(442.0, 232.0),
		"%s를 놓은 뒤 0.15초 안에\n%s를 눌러도 벽 점프가 이어집니다."
		% [_binding(&"character_grab"), _binding(&"character_jump")],
		14,
		MUTED
	)
	_text(Vector2(442.0, 328.0), "※ 오른쪽 벽에서는 좌우 방향이 반대입니다.", 13, ORANGE)


func _draw_system_page() -> void:
	_draw_page_heading("4. 명상과 시스템 키", "테트리스의 흐름을 조절하고 언제든 다시 시작할 수 있습니다")
	var left_card: Rect2 = Rect2(20.0, 70.0, 470.0, 382.0)
	var right_card: Rect2 = Rect2(510.0, 70.0, 290.0, 382.0)
	_draw_card(left_card)
	_draw_card(right_card)

	_draw_step_badge(Vector2(46.0, 104.0), 1, CYAN)
	_text(Vector2(82.0, 113.0), "명상", 20, TEXT)
	_key_chip(Vector2(147.0, 96.0), _binding(&"character_meditate"), CYAN)
	_draw_floor(Vector2(48.0, 368.0), 408.0)
	_draw_character(Rect2(72.0, 248.0, 57.0, 108.0), 1.0)
	for ring_index: int in range(3):
		draw_arc(
			Vector2(101.0, 297.0),
			52.0 + ring_index * 12.0,
			-2.3,
			-0.8,
			18,
			Color(0.22, 0.85, 1.0, 0.55 - ring_index * 0.12),
			2.0
		)
	_draw_tetromino(Vector2(370.0, 168.0), RED)
	_draw_tetromino(Vector2(370.0, 292.0), RED, 0.35)
	_draw_arrow(Vector2(408.0, 216.0), Vector2(408.0, 278.0), CYAN, 5.0)
	_text(Vector2(178.0, 143.0), "바닥에서 키 유지", 15, TEXT)
	_text(Vector2(178.0, 179.0), "캐릭터 행동 정지", 14, MUTED)
	_text(Vector2(178.0, 211.0), "블록 낙하·잠금 시간 ×2", 14, CYAN)
	_text(Vector2(178.0, 243.0), "스태미나 회복 없음", 14, MUTED)
	_text(Vector2(178.0, 411.0), "키를 놓거나 발판을 잃으면 즉시 종료", 13, ORANGE)

	_text(Vector2(536.0, 112.0), "SYSTEM", 18, TEXT)
	_draw_shortcut_row(
		Vector2(536.0, 157.0),
		_binding(&"pause_game"),
		"일시정지",
		PURPLE
	)
	_draw_shortcut_row(
		Vector2(536.0, 227.0),
		_binding(&"restart_game"),
		"다시 시작",
		ORANGE
	)
	_draw_shortcut_row(
		Vector2(536.0, 297.0),
		_binding(&"character_self_respawn"),
		"1초 유지: 목숨 -1 후 상단 재스폰",
		CYAN
	)
	_text(Vector2(536.0, 376.0), "마지막 목숨이거나 안전한 칸이 없으면\n게임 오버입니다.", 13, MUTED)
	_text(Vector2(536.0, 438.0), "착지 시 100 · 공중/벽 충전 없음", 11, CYAN)


func _draw_page_heading(title: String, subtitle: String) -> void:
	_text(Vector2(24.0, 32.0), title, 24, TEXT)
	var title_width: float = _font.get_string_size(
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		24
	).x
	var subtitle_x: float = maxf(252.0, 24.0 + title_width + 28.0)
	_text(Vector2(subtitle_x, 32.0), subtitle, 14, MUTED)


func _draw_card(rect: Rect2) -> void:
	_draw_round_panel(rect, PANEL_DARK, BORDER, 8.0)


func _draw_round_panel(
	rect: Rect2,
	background: Color,
	border: Color,
	radius: float
) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)


func _draw_step_badge(center: Vector2, number: int, color: Color) -> void:
	draw_circle(center, 15.0, color)
	draw_string(
		_font,
		center + Vector2(-5.0, 6.0),
		str(number),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		15,
		Color.WHITE
	)


func _draw_floor(origin: Vector2, width: float) -> void:
	draw_rect(Rect2(origin, Vector2(width, 16.0)), Color("#c8d1dd"))
	draw_line(origin, origin + Vector2(width, 0.0), CYAN, 2.0)
	for x_value: int in range(int(origin.x), int(origin.x + width), 28):
		draw_line(
			Vector2(float(x_value), origin.y),
			Vector2(float(x_value) + 14.0, origin.y + 16.0),
			Color("#8390a3"),
			1.0
		)


func _draw_character(rect: Rect2, alpha: float) -> void:
	var modulation: Color = Color(1.0, 1.0, 1.0, alpha)
	draw_texture_rect_region(PORTRAIT, rect, PORTRAIT_SOURCE, modulation)


func _draw_tetromino(
	origin: Vector2,
	color: Color,
	alpha: float = 1.0
) -> void:
	var cells: Array[Vector2i] = [
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(2, 0),
	]
	var source_key: String = "cyan"
	if color == ORANGE:
		source_key = "orange"
	elif color == PURPLE:
		source_key = "purple"
	elif color == RED:
		source_key = "red"
	var source_region: Rect2 = BLOCK_SPRITE_REGIONS[source_key]
	for cell: Vector2i in cells:
		var rect: Rect2 = Rect2(origin + Vector2(cell) * 22.0, Vector2(20.0, 20.0))
		draw_texture_rect_region(
			BLOCK_TEXTURE,
			rect,
			source_region,
			Color(1.0, 1.0, 1.0, alpha)
		)


func _draw_arrow(
	start: Vector2,
	end: Vector2,
	color: Color,
	width: float = 4.0
) -> void:
	draw_line(start, end, color, width, true)
	var direction: Vector2 = (end - start).normalized()
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var points: PackedVector2Array = PackedVector2Array([
		end,
		end - direction * 17.0 + perpendicular * 8.0,
		end - direction * 17.0 - perpendicular * 8.0,
	])
	draw_colored_polygon(points, color)


func _draw_arc_arrow(
	start: Vector2,
	end: Vector2,
	control: Vector2,
	color: Color
) -> void:
	var points: PackedVector2Array = []
	for index: int in range(25):
		var ratio: float = float(index) / 24.0
		var inverse: float = 1.0 - ratio
		points.append(
			inverse * inverse * start
			+ 2.0 * inverse * ratio * control
			+ ratio * ratio * end
		)
	draw_polyline(points, color, 4.0, true)
	var previous: Vector2 = points[points.size() - 2]
	var direction: Vector2 = (end - previous).normalized()
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	draw_colored_polygon(
		PackedVector2Array([
			end,
			end - direction * 17.0 + perpendicular * 8.0,
			end - direction * 17.0 - perpendicular * 8.0,
		]),
		color
	)


func _key_chip(position_value: Vector2, text_value: String, color: Color) -> void:
	var width: float = maxf(58.0, float(text_value.length()) * 10.0 + 24.0)
	var rect: Rect2 = Rect2(position_value, Vector2(width, 31.0))
	_draw_round_panel(rect, Color("#ffffff"), color, 6.0)
	draw_string(
		_font,
		position_value + Vector2(12.0, 22.0),
		text_value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		TEXT
	)


func _draw_shortcut_row(
	position_value: Vector2,
	key_text: String,
	description: String,
	color: Color
) -> void:
	_key_chip(position_value, key_text, color)
	_text(position_value + Vector2(0.0, 54.0), description, 15, TEXT)


func _text(
	position_value: Vector2,
	text_value: String,
	font_size: int,
	color: Color
) -> void:
	if "\n" in text_value:
		var line_position: Vector2 = position_value
		for line: String in text_value.split("\n"):
			draw_string(
				_font,
				line_position,
				line,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				color
			)
			line_position.y += font_size + 7.0
	else:
		draw_string(
			_font,
			position_value,
			text_value,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			color
		)


func _binding(action_name: StringName) -> String:
	if settings == null:
		return "-"
	return settings.get_binding_text(action_name)


func _keys(first_action: StringName, second_action: StringName) -> String:
	return "%s / %s" % [_binding(first_action), _binding(second_action)]
