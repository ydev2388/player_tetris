class_name StartScreenTutorialCanvas
extends Control

const ANIMATION_DATA: Script = preload("res://scripts/character_animation_data.gd")
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

const ANIMATION_FPS: float = 12.0
const ANIMATION_FRAME_INTERVAL: float = 1.0 / ANIMATION_FPS
const LOOP_FADE_SECONDS: float = 0.2
const PAGE_DURATIONS: Array[float] = [3.0, 2.4, 4.0, 2.0, 3.2]
const ROTATION_KICK_DURATION: float = 0.42

var page: int = 0
var settings: StartScreenSettings
var _font: SystemFont
var _animation_time: float = 0.0
var _animation_accumulator: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	set_process(true)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_animation_accumulator += delta
	var advanced: bool = false
	while _animation_accumulator >= ANIMATION_FRAME_INTERVAL:
		_animation_accumulator -= ANIMATION_FRAME_INTERVAL
		_animation_time = fmod(
			_animation_time + ANIMATION_FRAME_INTERVAL,
			PAGE_DURATIONS[page]
		)
		advanced = true
	if advanced:
		queue_redraw()


func set_settings(value: StartScreenSettings) -> void:
	settings = value
	if settings != null and not settings.bindings_changed.is_connected(queue_redraw):
		settings.bindings_changed.connect(queue_redraw)
	queue_redraw()


func set_page(value: int) -> void:
	page = clampi(value, 0, PAGE_DURATIONS.size() - 1)
	_animation_time = 0.0
	_animation_accumulator = 0.0
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
		4:
			_draw_special_keys_page()


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
	var movement_ratio: float = _movement_ratio(_animation_time)
	var movement_x: float = lerpf(85.0, 277.0, movement_ratio)
	var moving_right: bool = _animation_time < 1.65
	var movement_alpha: float = _loop_alpha(3.0)
	var movement_arrow_start: Vector2 = (
		Vector2(158.0, 295.0) if moving_right else Vector2(265.0, 295.0)
	)
	var movement_arrow_end: Vector2 = (
		Vector2(265.0, 295.0) if moving_right else Vector2(158.0, 295.0)
	)
	_draw_animated_character(
		Rect2(movement_x, 237.0, 61.0, 116.0),
		ANIMATION_DATA.IDLE,
		_animation_time,
		movement_alpha
	)
	_draw_arrow(
		movement_arrow_start,
		movement_arrow_end,
		CYAN,
		5.0,
		0.45 + 0.45 * absf(sin(_animation_time * 4.0))
	)
	_key_chip(
		Vector2(150.0, 394.0),
		_binding(&"character_left"),
		CYAN,
		0.95 if not moving_right else 0.1
	)
	_key_chip(
		Vector2(235.0, 394.0),
		_binding(&"character_right"),
		CYAN,
		0.95 if moving_right else 0.1
	)

	_draw_step_badge(Vector2(454.0, 108.0), 2, ORANGE)
	_text(Vector2(490.0, 116.0), "점프", 21, TEXT)
	_text(
		Vector2(454.0, 148.0),
		"[%s]를 짧게/길게 눌러 높이를 조절합니다." % _binding(&"character_jump"),
		15,
		MUTED
	)
	_draw_floor(Vector2(456.0, 365.0), 310.0)
	var jump_cycle: int = 0 if _animation_time < 1.4 else 1
	var jump_local_time: float = (
		_animation_time
		if jump_cycle == 0
		else _animation_time - 1.4
	)
	var jump_ratio: float = clampf(jump_local_time / 1.2, 0.0, 1.0)
	var jump_height: float = 66.0 if jump_cycle == 0 else 132.0
	var jump_y: float = 237.0 - sin(jump_ratio * PI) * jump_height
	_draw_animated_character(
		Rect2(572.0, jump_y, 68.0, 116.0),
		ANIMATION_DATA.JUMP,
		jump_ratio * 0.7,
		_loop_alpha(3.0)
	)
	_draw_arc_arrow(
		Vector2(540.0, 280.0),
		Vector2(665.0, 222.0),
		Vector2(610.0, 145.0),
		ORANGE,
		0.34
	)
	_key_chip(
		Vector2(574.0, 390.0),
		_binding(&"character_jump"),
		ORANGE,
		0.45 + 0.5 * sin(jump_ratio * PI)
	)
	_text(
		Vector2(510.0, 438.0),
		"빠르게 놓기: 낮게",
		14,
		ORANGE if jump_cycle == 0 else MUTED
	)
	_text(
		Vector2(650.0, 438.0),
		"유지: 높게",
		14,
		ORANGE if jump_cycle == 1 else MUTED
	)


func _draw_block_action_page() -> void:
	_draw_page_heading("2. 블록 조작", "일반 공격과 블록 플립으로 길을 만드세요")
	_draw_card(Rect2(20.0, 70.0, 780.0, 382.0))
	_draw_step_badge(Vector2(44.0, 104.0), 1, PURPLE)
	_text(Vector2(80.0, 113.0), "블록 플립", 19, TEXT)
	_text(
		Vector2(80.0, 145.0),
		"[%s] 일반 공격: 가까운 블록을 1칸 밀기" % _binding(&"character_punch"),
		15,
		MUTED
	)
	var kick_ratio: float = _smooth_ratio(_animation_time, 0.25, 1.05)
	var kick_frame_elapsed: float = kick_ratio * 0.42
	var kick_active: bool = _animation_time >= 0.25 and _animation_time <= 1.25
	var kick_impact: float = 1.0 - clampf(
		absf(_animation_time - 1.05) / 0.18,
		0.0,
		1.0
	)
	var kick_loop_alpha: float = _loop_alpha(2.4)
	_key_chip(
		Vector2(722.0, 96.0),
		_binding(&"character_rotation_kick"),
		PURPLE,
		clampf(sin(kick_ratio * PI) + kick_impact * 0.5, 0.0, 1.0)
	)
	_draw_floor(Vector2(180.0, 360.0), 440.0)
	if kick_active:
		for trail_index: int in range(2, 0, -1):
			var trail_elapsed: float = maxf(
				kick_frame_elapsed - float(trail_index) * 0.08,
				0.0
			)
			_draw_animated_character(
				Rect2(
					300.0 - float(trail_index) * 5.0,
					236.0,
					88.0,
					111.0
				),
				ANIMATION_DATA.ROTATION_KICK,
				trail_elapsed,
				kick_loop_alpha * (0.2 / float(trail_index)),
				_rotation_demo_angle(trail_elapsed)
			)
	var kick_character_state: String = (
		ANIMATION_DATA.ROTATION_KICK if kick_active else ANIMATION_DATA.IDLE
	)
	var kick_character_elapsed: float = (
		kick_frame_elapsed if kick_active else _animation_time
	)
	_draw_animated_character(
		Rect2(
			300.0 + sin(kick_ratio * PI) * 10.0,
			236.0,
			88.0,
			111.0
		),
		kick_character_state,
		kick_character_elapsed,
		kick_loop_alpha,
		_rotation_demo_angle(kick_character_elapsed) if kick_active else 0.0
	)
	_draw_tetromino(
		Vector2(450.0, 279.0 - sin(kick_ratio * PI) * 22.0),
		RED,
		kick_loop_alpha,
		-kick_ratio * PI * 0.5
	)
	if kick_impact > 0.0:
		draw_circle(
			Vector2(445.0, 289.0),
			8.0 + kick_impact * 15.0,
			Color(1.0, 0.72, 0.2, kick_impact * 0.32),
			false,
			3.0,
			true
		)
	_draw_arc_arrow(
		Vector2(438.0, 260.0),
		Vector2(548.0, 246.0),
		Vector2(504.0, 205.0),
		PURPLE,
		0.25 + 0.75 * sin(kick_ratio * PI)
	)
	var rotation_label_alpha: float = (
		_smooth_ratio(_animation_time, 0.88, 1.12) * kick_loop_alpha
	)
	_text(
		Vector2(450.0, 190.0),
		"90° 플립",
		14,
		Color(PURPLE.r, PURPLE.g, PURPLE.b, rotation_label_alpha)
	)
	_text(Vector2(230.0, 392.0), "지상·공중 모두 사용", 13, MUTED)
	_text(Vector2(230.0, 415.0), "성공 뒤 2초, 실패 뒤 1초 대기", 13, MUTED)


func _draw_wall_page() -> void:
	_draw_page_heading("3. 매달리기와 벽 점프", "화살표 순서대로 입력하면 더 높은 위치에 재매달립니다")
	_draw_card(Rect2(20.0, 70.0, 780.0, 382.0))
	var floor_y: float = 396.0
	draw_rect(Rect2(80.0, 126.0, 34.0, floor_y - 126.0), Color("#c8d1dd"))
	draw_rect(Rect2(80.0, 126.0, 34.0, floor_y - 126.0), BORDER, false, 2.0)
	_draw_floor(Vector2(80.0, floor_y), 650.0)

	var wall_stage: int = _wall_stage(_animation_time)
	var wall_position: Vector2 = _wall_character_position(_animation_time)
	var wall_state: String = (
		ANIMATION_DATA.HANG
		if wall_stage == 0 or _animation_time >= 3.45
		else ANIMATION_DATA.JUMP
	)
	var wall_state_time: float = (
		_animation_time
		if wall_stage == 0
		else maxf(_animation_time - 1.2, 0.0)
	)
	_draw_animated_character(
		Rect2(wall_position, Vector2(64.0, 108.0)),
		wall_state,
		wall_state_time,
		_loop_alpha(4.0)
	)
	_draw_step_badge(
		Vector2(145.0, 238.0),
		1,
		CYAN,
		1.0 if wall_stage == 0 else 0.35
	)
	_key_chip(
		Vector2(190.0, 354.0),
		_binding(&"character_grab"),
		CYAN,
		1.0 if wall_stage == 0 else 0.15
	)
	_text(Vector2(190.0, 440.0), "C 유지 중 ↑/↓로 벽 이동", 13, MUTED)

	_draw_arc_arrow(
		Vector2(174.0, 265.0),
		Vector2(320.0, 218.0),
		Vector2(245.0, 135.0),
		ORANGE,
		0.9 if wall_stage == 1 else 0.25
	)
	_draw_step_badge(
		Vector2(347.0, 154.0),
		2,
		ORANGE,
		1.0 if wall_stage == 1 else 0.35
	)
	_key_chip(
		Vector2(281.0, 300.0),
		"%s + %s" % [_binding(&"character_grab"), _binding(&"character_jump")],
		ORANGE,
		1.0 if wall_stage == 1 else 0.15
	)
	_text(Vector2(285.0, 342.0), "벽 반대 방향으로 점프", 13, MUTED)

	_draw_arc_arrow(
		Vector2(340.0, 176.0),
		Vector2(193.0, 176.0),
		Vector2(267.0, 82.0),
		PURPLE,
		0.9 if wall_stage == 2 else 0.25
	)
	_draw_step_badge(
		Vector2(187.0, 122.0),
		3,
		PURPLE,
		1.0 if wall_stage == 2 else 0.35
	)
	_key_chip(
		Vector2(442.0, 113.0),
		_binding(&"character_left"),
		PURPLE,
		1.0 if wall_stage == 2 else 0.15
	)
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
	var meditation_ratio: float = _animation_time / 2.0
	var meditation_pulse: float = 0.5 + 0.5 * sin(meditation_ratio * TAU)
	_key_chip(
		Vector2(147.0, 96.0),
		_binding(&"character_meditate"),
		CYAN,
		0.45 + meditation_pulse * 0.5
	)
	_draw_floor(Vector2(48.0, 368.0), 408.0)
	_draw_animated_character(
		Rect2(72.0, 248.0, 64.0, 108.0),
		ANIMATION_DATA.IDLE,
		_animation_time,
		_loop_alpha(2.0)
	)
	for ring_index: int in range(3):
		var ring_phase: float = fmod(
			meditation_ratio + float(ring_index) / 3.0,
			1.0
		)
		draw_arc(
			Vector2(101.0, 297.0),
			48.0 + ring_phase * 38.0,
			-2.3,
			-0.8,
			18,
			Color(0.22, 0.85, 1.0, (1.0 - ring_phase) * 0.62),
			2.0
		)
	var fall_ratio: float = _smooth_ratio(_animation_time, 0.15, 1.75)
	_draw_tetromino(Vector2(370.0, 168.0), RED, 0.18)
	_draw_tetromino(
		Vector2(370.0, lerpf(168.0, 292.0, fall_ratio)),
		RED,
		_loop_alpha(2.0)
	)
	_draw_arrow(
		Vector2(408.0, 216.0),
		Vector2(408.0, 278.0),
		CYAN,
		5.0,
		0.45 + meditation_pulse * 0.45
	)
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


func _draw_special_keys_page() -> void:
	_draw_page_heading("5. 특수 키 모션", "게임 흐름을 멈추거나 다시 시작하고 안전하게 메뉴로 돌아가요")
	var cards: Array[Rect2] = [
		Rect2(20.0, 70.0, 380.0, 180.0),
		Rect2(420.0, 70.0, 380.0, 180.0),
		Rect2(20.0, 268.0, 380.0, 184.0),
		Rect2(420.0, 268.0, 380.0, 184.0),
	]
	for card: Rect2 in cards:
		_draw_card(card)

	# P: 떨어지던 블록이 멈췄다가 다시 움직여 일시정지를 설명한다.
	_text(Vector2(44.0, 105.0), "일시정지", 19, TEXT)
	_key_chip(Vector2(286.0, 86.0), _binding(&"pause_game"), PURPLE, 0.9)
	var pause_fall_ratio: float = 0.0
	if _animation_time < 0.8:
		pause_fall_ratio = _smooth_ratio(_animation_time, 0.05, 0.8)
	elif _animation_time < 2.05:
		pause_fall_ratio = 1.0
	else:
		pause_fall_ratio = 1.0 + _smooth_ratio(_animation_time, 2.05, 3.0) * 0.65
	_draw_tetromino(Vector2(58.0, 125.0 + pause_fall_ratio * 32.0), PURPLE)
	_draw_animated_character(
		Rect2(146.0, 126.0, 55.0, 91.0),
		ANIMATION_DATA.IDLE,
		_animation_time,
		1.0
	)
	var pause_badge_alpha: float = (
		_smooth_ratio(_animation_time, 0.7, 0.95)
		* (1.0 - _smooth_ratio(_animation_time, 2.0, 2.25))
	)
	_draw_round_panel(
		Rect2(220.0, 143.0, 142.0, 46.0),
		Color(0.43, 0.34, 0.79, 0.12 + pause_badge_alpha * 0.18),
		Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.3 + pause_badge_alpha * 0.7),
		7.0
	)
	_text(
		Vector2(243.0, 173.0),
		"PAUSED",
		17,
		Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.25 + pause_badge_alpha * 0.75)
	)
	_text(Vector2(44.0, 232.0), "다시 누르면 게임이 이어집니다.", 13, MUTED)

	# R: 쌓인 블록과 캐릭터가 번쩍이며 시작 상태로 초기화된다.
	_text(Vector2(444.0, 105.0), "즉시 재시작", 19, TEXT)
	_key_chip(Vector2(720.0, 86.0), _binding(&"restart_game"), ORANGE, 0.9)
	var restart_triggered: bool = _animation_time >= 1.25
	var restart_flash: float = 1.0 - clampf(
		absf(_animation_time - 1.25) / 0.28,
		0.0,
		1.0
	)
	_draw_floor(Vector2(446.0, 203.0), 328.0)
	if not restart_triggered:
		_draw_tetromino(Vector2(616.0, 149.0), RED)
		_draw_tetromino(Vector2(688.0, 127.0), CYAN)
	_draw_animated_character(
		Rect2(474.0 if not restart_triggered else 570.0, 111.0, 55.0, 91.0),
		ANIMATION_DATA.IDLE,
		_animation_time,
		_loop_alpha(3.2)
	)
	_draw_arc_arrow(
		Vector2(542.0, 158.0),
		Vector2(596.0, 117.0),
		Vector2(555.0, 95.0),
		ORANGE,
		0.25 + restart_flash * 0.75
	)
	if restart_flash > 0.0:
		draw_circle(
			Vector2(610.0, 153.0),
			18.0 + restart_flash * 34.0,
			Color(1.0, 0.55, 0.12, restart_flash * 0.25),
			false,
			4.0,
			true
		)
	_text(Vector2(444.0, 238.0), "보드·목숨을 처음부터 시작합니다.", 13, MUTED)

	# Q: 1초 홀드 진행도 뒤 목숨을 하나 쓰고 상단에 재등장한다.
	_text(Vector2(44.0, 303.0), "자력 재스폰", 19, TEXT)
	_key_chip(Vector2(326.0, 284.0), _binding(&"character_self_respawn"), CYAN, 0.9)
	var respawn_ratio: float = _smooth_ratio(_animation_time, 0.15, 1.15)
	var respawn_triggered: bool = _animation_time >= 1.15
	_draw_animated_character(
		Rect2(58.0, 337.0, 52.0, 90.0),
		ANIMATION_DATA.IDLE,
		_animation_time,
		(1.0 - respawn_ratio) * _loop_alpha(3.2)
	)
	_draw_animated_character(
		Rect2(302.0, 317.0, 52.0, 90.0),
		ANIMATION_DATA.JUMP,
		_animation_time,
		respawn_ratio * _loop_alpha(3.2)
	)
	_draw_arrow(Vector2(122.0, 371.0), Vector2(286.0, 344.0), CYAN, 4.0, respawn_ratio)
	draw_rect(Rect2(122.0, 395.0, 164.0, 13.0), Color("#d7dee8"))
	draw_rect(Rect2(122.0, 395.0, 164.0 * respawn_ratio, 13.0), CYAN)
	_text(Vector2(122.0, 388.0), "1초 유지", 12, MUTED)
	_text(
		Vector2(146.0, 432.0),
		"목숨 3 → 2" if respawn_triggered else "목숨 3",
		14,
		ORANGE if respawn_triggered else TEXT
	)

	# 게임 중 Esc: Yes/No 확인 뒤 GAME START 메뉴로 돌아가는 흐름을 반복한다.
	_text(Vector2(444.0, 303.0), "게임 중 → 메뉴", 19, TEXT)
	_key_chip(Vector2(720.0, 284.0), "Esc", RED, 0.9)
	if _animation_time < 0.85:
		_text(Vector2(535.0, 365.0), "GAME OVER", 23, RED)
		_text(Vector2(516.0, 407.0), "Esc를 눌러 메뉴 선택", 13, MUTED)
	elif _animation_time < 2.25:
		_draw_round_panel(Rect2(456.0, 326.0, 308.0, 102.0), PANEL, RED, 7.0)
		_text(Vector2(507.0, 354.0), "메뉴로 나가겠습니까?", 15, TEXT)
		_draw_round_panel(Rect2(492.0, 374.0, 94.0, 37.0), PANEL_DARK, CYAN, 5.0)
		_draw_round_panel(Rect2(628.0, 374.0, 94.0, 37.0), PANEL_DARK, RED, 5.0)
		_text(Vector2(523.0, 399.0), "Yes", 14, CYAN)
		_text(Vector2(661.0, 399.0), "No", 14, RED)
	else:
		_draw_round_panel(Rect2(486.0, 333.0, 246.0, 82.0), PANEL, CYAN, 7.0)
		_text(Vector2(548.0, 365.0), "GAME START", 18, TEXT)
		_text(Vector2(534.0, 397.0), "↑/↓ 선택 · Z 확인 · X 취소", 13, CYAN)


func _movement_ratio(time_value: float) -> float:
	if time_value < 0.25:
		return 0.0
	if time_value < 1.25:
		return _smooth_ratio(time_value, 0.25, 1.25)
	if time_value < 1.65:
		return 1.0
	if time_value < 2.65:
		return 1.0 - _smooth_ratio(time_value, 1.65, 2.65)
	return 0.0


func _wall_stage(time_value: float) -> int:
	if time_value < 1.2:
		return 0
	if time_value < 2.4:
		return 1
	return 2


func _wall_character_position(time_value: float) -> Vector2:
	if time_value < 1.2:
		var climb_ratio: float = _smooth_ratio(time_value, 0.15, 1.05)
		return Vector2(112.0, lerpf(252.0, 220.0, climb_ratio))
	if time_value < 2.4:
		return _quadratic_bezier(
			Vector2(112.0, 220.0),
			Vector2(245.0, 135.0),
			Vector2(330.0, 174.0),
			_smooth_ratio(time_value, 1.2, 2.4)
		)
	return _quadratic_bezier(
		Vector2(330.0, 174.0),
		Vector2(267.0, 82.0),
		Vector2(130.0, 137.0),
		_smooth_ratio(time_value, 2.4, 3.65)
	)


func _smooth_ratio(value: float, start: float, end: float) -> float:
	var ratio: float = clampf((value - start) / (end - start), 0.0, 1.0)
	return ratio * ratio * (3.0 - 2.0 * ratio)


func _rotation_demo_angle(elapsed: float) -> float:
	var progress: float = clampf(elapsed / ROTATION_KICK_DURATION, 0.0, 1.0)
	var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)
	return -TAU * eased_progress


func _quadratic_bezier(
	start: Vector2,
	control: Vector2,
	end: Vector2,
	ratio: float
) -> Vector2:
	var inverse: float = 1.0 - ratio
	return (
		inverse * inverse * start
		+ 2.0 * inverse * ratio * control
		+ ratio * ratio * end
	)


func _loop_alpha(duration: float) -> float:
	if _animation_time <= duration - LOOP_FADE_SECONDS:
		return 1.0
	return clampf(
		(duration - _animation_time) / LOOP_FADE_SECONDS,
		0.0,
		1.0
	)


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


func _draw_step_badge(
	center: Vector2,
	number: int,
	color: Color,
	alpha: float = 1.0
) -> void:
	var badge_color: Color = Color(color.r, color.g, color.b, alpha)
	if alpha > 0.9:
		draw_circle(center, 19.0, Color(color.r, color.g, color.b, 0.13))
	draw_circle(center, 15.0, badge_color)
	draw_string(
		_font,
		center + Vector2(-5.0, 6.0),
		str(number),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		15,
		Color(1.0, 1.0, 1.0, alpha)
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


func _draw_animated_character(
	bounds: Rect2,
	state: String,
	elapsed: float,
	alpha: float,
	rotation_radians: float = 0.0
) -> void:
	var texture: Texture2D = ANIMATION_DATA.texture_for(state)
	var source_region: Rect2 = ANIMATION_DATA.region_for(state, elapsed)
	var source_aspect: float = source_region.size.x / source_region.size.y
	var target_size: Vector2 = bounds.size
	if target_size.x / target_size.y > source_aspect:
		target_size.x = target_size.y * source_aspect
	else:
		target_size.y = target_size.x / source_aspect
	var target_position: Vector2 = Vector2(
		bounds.position.x + (bounds.size.x - target_size.x) * 0.5,
		bounds.end.y - target_size.y
	)
	if not is_zero_approx(rotation_radians):
		var center: Vector2 = bounds.position + bounds.size * 0.5
		target_position -= center
		draw_set_transform(center, rotation_radians, Vector2.ONE)
	draw_texture_rect_region(
		texture,
		Rect2(target_position, target_size),
		source_region,
		Color(1.0, 1.0, 1.0, alpha)
	)
	if not is_zero_approx(rotation_radians):
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tetromino(
	origin: Vector2,
	color: Color,
	alpha: float = 1.0,
	rotation_radians: float = 0.0
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
	var center: Vector2 = Vector2(33.0, 22.0)
	if not is_zero_approx(rotation_radians):
		draw_set_transform(origin + center, rotation_radians, Vector2.ONE)
	for cell: Vector2i in cells:
		var cell_position: Vector2 = origin + Vector2(cell) * 22.0
		if not is_zero_approx(rotation_radians):
			cell_position = Vector2(cell) * 22.0 - center
		var rect: Rect2 = Rect2(cell_position, Vector2(20.0, 20.0))
		draw_texture_rect_region(
			BLOCK_TEXTURE,
			rect,
			source_region,
			Color(1.0, 1.0, 1.0, alpha)
		)
	if not is_zero_approx(rotation_radians):
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_arrow(
	start: Vector2,
	end: Vector2,
	color: Color,
	width: float = 4.0,
	alpha: float = 1.0
) -> void:
	var arrow_color: Color = Color(color.r, color.g, color.b, alpha)
	draw_line(start, end, arrow_color, width, true)
	var direction: Vector2 = (end - start).normalized()
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var points: PackedVector2Array = PackedVector2Array([
		end,
		end - direction * 17.0 + perpendicular * 8.0,
		end - direction * 17.0 - perpendicular * 8.0,
	])
	draw_colored_polygon(points, arrow_color)


func _draw_arc_arrow(
	start: Vector2,
	end: Vector2,
	control: Vector2,
	color: Color,
	alpha: float = 1.0
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
	var arrow_color: Color = Color(color.r, color.g, color.b, alpha)
	draw_polyline(points, arrow_color, 4.0, true)
	var previous: Vector2 = points[points.size() - 2]
	var direction: Vector2 = (end - previous).normalized()
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	draw_colored_polygon(
		PackedVector2Array([
			end,
			end - direction * 17.0 + perpendicular * 8.0,
			end - direction * 17.0 - perpendicular * 8.0,
		]),
		arrow_color
	)


func _key_chip(
	position_value: Vector2,
	text_value: String,
	color: Color,
	emphasis: float = 0.0
) -> void:
	var width: float = maxf(58.0, float(text_value.length()) * 10.0 + 24.0)
	var rect: Rect2 = Rect2(position_value, Vector2(width, 31.0))
	var emphasis_ratio: float = clampf(emphasis, 0.0, 1.0)
	var chip_background: Color = Color.WHITE.lerp(color, emphasis_ratio * 0.18)
	if emphasis_ratio > 0.75:
		_draw_round_panel(
			rect.grow(3.0),
			Color(color.r, color.g, color.b, 0.08),
			Color(color.r, color.g, color.b, 0.22),
			8.0
		)
	_draw_round_panel(rect, chip_background, color, 6.0)
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
