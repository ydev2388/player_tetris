class_name StartScreenTutorialCanvas
extends Control

## [역할 / C++ 대응]
## 게임 설명 5페이지를 12FPS 즉시-mode drawing으로 반복 재생하는 튜토리얼 renderer다.
## C++로 보면 `update(delta)`와 `render(Canvas&)`를 가진 작은 animation state machine에 가깝다.
## 별도 GIF 파일을 재생하지 않고 누적 시간에서 위치·frame·alpha를 계산해 매 draw pass에 다시 그린다.
##
## 호출자: KungFuTetrisStartScreen의 TUTORIAL 화면.
## 호출 대상: MainCharacterAnimationData, StartScreenSettings, CanvasItem draw API.

const ANIMATION_DATA: Script = preload("res://scripts/character_animation_data.gd") # sprite frame table utility.
const BLOCK_TEXTURE: Texture2D = preload("res://assets/sprites/block_sprites.png") # tetromino cell atlas.
const BLOCK_SPRITE_REGIONS: Dictionary = {
	"cyan": Rect2(80.0, 255.0, 210.0, 215.0),
	"orange": Rect2(1745.0, 255.0, 210.0, 215.0),
	"purple": Rect2(640.0, 255.0, 210.0, 215.0),
	"red": Rect2(1190.0, 255.0, 210.0, 215.0),
}

const PANEL: Color = Color("#ffffff") # 전체 canvas와 밝은 modal 배경.
const PANEL_DARK: Color = Color("#eef2f7") # 각 설명 card 배경.
const BORDER: Color = Color("#8390a3") # card/grid 외곽선.
const TEXT: Color = Color("#152033") # 제목과 주요 설명.
const MUTED: Color = Color("#344158") # 보조 설명.
const CYAN: Color = Color("#2c8fd6") # 이동·명상·재스폰 강조.
const ORANGE: Color = Color("#e47719") # 점프·펀치·재시작 강조.
const PURPLE: Color = Color("#6f57c9") # 블록 플립·일시정지 강조.
const RED: Color = Color("#d9485f") # 위험 블록·메뉴 종료 강조.

const ANIMATION_FPS: float = 12.0 # 논리 animation update 빈도.
const ANIMATION_FRAME_INTERVAL: float = 1.0 / ANIMATION_FPS # accumulator가 소비할 고정 timestep.
const LOOP_FADE_SECONDS: float = 0.2 # 반복 끝에서 시작 frame으로 튀는 현상을 감출 fade 길이.
const PAGE_DURATIONS: Array[float] = [3.0, 2.4, 4.0, 2.0, 3.2] # page index별 loop 초.
const ROTATION_KICK_DURATION: float = 0.42 # 실제 캐릭터 블록 플립 한 바퀴 시간과 맞춘 값.

var page: int = 0 # 현재 draw할 0~4 page index.
var settings: StartScreenSettings # 실제 사용자 키 이름을 조회할 non-owning 설정 참조.
var _font: SystemFont # 모든 draw_string이 공유하는 한글 font resource.
var _animation_time: float = 0.0 # 현재 page loop 안의 정규화되지 않은 경과 초.
var _animation_accumulator: float = 0.0 # 가변 render delta를 12FPS 고정 step으로 바꾸는 잔여 시간.


## 상황: TutorialCanvas가 scene tree에 들어올 때 Godot가 한 번 호출한다.
## 순서: mouse 입력 통과 → 한글 font 후보 지정 → 매-frame process 활성화.
## 결과: 입력은 아래 버튼에 전달되고 animation time 갱신 준비가 끝난다.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	set_process(true)


## 상황: canvas가 보이는 동안 매 render frame 호출되어 논리 12FPS 시간을 진행한다.
## 순서: visibility guard → delta 누적 → fixed interval씩 소비/fmod loop → 변경 시 redraw.
## 결과: frame rate와 무관하게 page duration 안에서 일정한 animation 속도를 유지한다.
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


## 상황: StartScreen이 canvas를 만들고 authoritative 설정 객체를 주입할 때 호출된다.
## 순서: 참조 저장 → binding 변경 signal을 redraw에 한 번만 연결 → 즉시 redraw.
## 결과: 사용자 키가 바뀌면 설명의 key chip도 자동 갱신된다.
func set_settings(value: StartScreenSettings) -> void:
	settings = value
	if settings != null and not settings.bindings_changed.is_connected(queue_redraw):
		settings.bindings_changed.connect(queue_redraw)
	queue_redraw()


## 상황: 이전/다음 버튼으로 설명 page가 바뀔 때 호출된다.
## 순서: 유효 index clamp → 두 animation 시간 0 → redraw.
## 결과: 새 페이지 loop가 항상 첫 frame부터 재생된다.
func set_page(value: int) -> void:
	page = clampi(value, 0, PAGE_DURATIONS.size() - 1)
	_animation_time = 0.0
	_animation_accumulator = 0.0
	queue_redraw()


## 상황: 최초 표시 또는 queue_redraw 이후 CanvasItem draw pass에서 호출된다.
## 순서: 공통 panel → page enum에 대응하는 전용 draw 함수 하나.
## 결과: 한 frame에는 선택된 설명 페이지의 draw 명령만 기록된다.
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


## 상황: page 0에서 좌우 이동과 가변 높이 점프를 그릴 때 호출된다.
## 순서: 두 card/설명 → 왕복 위치·방향 계산 → 캐릭터/화살표/key chip
##       → 두 높이 jump 곡선과 상태 문구.
## 결과: 입력 키와 시간에 따른 위치를 한 화면에서 반복 시각화한다.
func _draw_movement_page() -> void:
	# 왼쪽 card는 왕복 이동을, 오른쪽 card는 짧은/긴 점프 두 cycle을 담당한다.
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


## 상황: page 1에서 공통 1칸 밀치기와 블록 플립의 시간 순서를 그릴 때 호출된다.
## 순서: punch stage/release 계산 → 캐릭터·블록·화살표 → flip 진행률/잔상/회전 블록.
## 결과: 두 액션의 key, 효과 범위, cooldown 정보를 반복 animation으로 보여준다.
func _draw_block_action_page() -> void:
	# 두 card는 서로 같은 `_animation_time`을 읽지만 독립적인 timeline helper를 사용한다.
	_draw_page_heading("2. 블록 조작", "밀치기와 플립으로 길을 만드세요")
	var cards: Array[Rect2] = [
		Rect2(20.0, 70.0, 380.0, 382.0),
		Rect2(420.0, 70.0, 380.0, 382.0),
	]
	for card: Rect2 in cards:
		_draw_card(card)

	_draw_step_badge(Vector2(44.0, 104.0), 1, ORANGE)
	_text(Vector2(80.0, 113.0), "기본 밀치기", 19, TEXT)
	var punch_stage: int = _punch_stage(_animation_time)
	var punch_releasing: bool = _punch_releasing(_animation_time)
	_key_chip(
		Vector2(322.0, 96.0),
		_binding(&"character_punch"),
		ORANGE,
		0.85 if punch_releasing else 0.2
	)
	_draw_floor(Vector2(42.0, 360.0), 336.0)
	_draw_animated_character(
		Rect2(70.0, 241.0, 64.0, 106.0),
		ANIMATION_DATA.ATTACK if punch_releasing else ANIMATION_DATA.IDLE,
		fmod(maxf(_animation_time - 0.25, 0.0), 0.4) if punch_releasing else _animation_time,
		_loop_alpha(2.4)
	)
	var punch_block_x: float = 180.0 + float(punch_stage) * 24.0
	_draw_tetromino(
		Vector2(punch_block_x, 284.0),
		CYAN,
		_loop_alpha(2.4)
	)
	_draw_arrow(
		Vector2(205.0, 275.0),
		Vector2(342.0, 275.0),
		ORANGE,
		4.0,
		0.85 if punch_releasing else 0.15
	)
	_text(
		Vector2(306.0, 205.0),
		"1칸" if punch_stage > 0 else "준비",
		15,
		ORANGE if punch_releasing else MUTED
	)
	_text(Vector2(44.0, 392.0), "X를 누르면 전방 블록을 정확히 1칸 밀기", 13, MUTED)
	_text(Vector2(44.0, 415.0), "캐릭터별 무기 모션만 다르고 결과는 동일", 13, MUTED)

	_draw_step_badge(Vector2(444.0, 104.0), 2, PURPLE)
	_text(Vector2(480.0, 113.0), "블록 플립", 19, TEXT)
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
	_draw_floor(Vector2(442.0, 360.0), 336.0)
	if kick_active:
		for trail_index: int in range(2, 0, -1):
			var trail_elapsed: float = maxf(
				kick_frame_elapsed - float(trail_index) * 0.08,
				0.0
			)
			_draw_animated_character(
				Rect2(
					500.0 - float(trail_index) * 5.0,
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
			500.0 + sin(kick_ratio * PI) * 10.0,
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
		Vector2(650.0, 279.0 - sin(kick_ratio * PI) * 22.0),
		RED,
		kick_loop_alpha,
		-kick_ratio * PI * 0.5
	)
	if kick_impact > 0.0:
		draw_circle(
			Vector2(645.0, 289.0),
			8.0 + kick_impact * 15.0,
			Color(1.0, 0.72, 0.2, kick_impact * 0.32),
			false,
			3.0,
			true
		)
	_draw_arc_arrow(
		Vector2(638.0, 260.0),
		Vector2(748.0, 246.0),
		Vector2(704.0, 205.0),
		PURPLE,
		0.25 + 0.75 * sin(kick_ratio * PI)
	)
	var rotation_label_alpha: float = (
		_smooth_ratio(_animation_time, 0.88, 1.12) * kick_loop_alpha
	)
	_text(
		Vector2(650.0, 190.0),
		"90° 플립",
		14,
		Color(PURPLE.r, PURPLE.g, PURPLE.b, rotation_label_alpha)
	)
	_text(Vector2(444.0, 392.0), "지상·공중 모두 사용", 13, MUTED)
	_text(Vector2(444.0, 415.0), "쿨타임 2초", 13, MUTED)


## 상황: page 2에서 매달리기→벽 점프→원래 벽 재매달리기 경로를 그릴 때 호출된다.
## 순서: 벽/바닥 → stage와 Bezier 위치 → 캐릭터 상태 → 세 단계 badge/키/화살표.
## 결과: 4초 loop 안에서 벽 액션의 입력 순서와 이동 궤적을 설명한다.
func _draw_wall_page() -> void:
	# wall_stage는 강조할 안내 단계, wall_position은 실제 캐릭터 draw 좌표를 분리한다.
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


## 상황: page 3에서 명상과 P/R/Q 시스템 키 요약을 그릴 때 호출된다.
## 순서: 명상 pulse/ring/느린 블록 → 우측 shortcut 세 행 → 주의 문구.
## 결과: 상태를 실제로 바꾸지 않고 시간 배율과 시스템 기능을 시각적으로 설명한다.
func _draw_system_page() -> void:
	# 명상 ring과 낙하 블록은 같은 2초 ratio를 공유해 효과의 인과관계를 보여준다.
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


## 상황: page 4에서 pause/restart/self-respawn/Esc 메뉴 흐름을 네 card에 그릴 때 호출된다.
## 순서: 각 기능별 trigger 시간을 공통 3.2초 loop에 배치하고 상태 전후를 교차 표시한다.
## 결과: 정적인 키 목록이 아니라 게임 상태가 어떻게 바뀌는지 움직이는 예시로 보여준다.
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
	_text(Vector2(444.0, 238.0), "점수·보드·목숨을 처음부터 시작합니다.", 13, MUTED)

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
		_text(Vector2(548.0, 365.0), "PLAYING", 23, CYAN)
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


## 상황: 이동 예시의 3초 loop 시간을 좌→우→좌 위치 비율로 바꿀 때 호출된다.
## 순서: 출발 정지 → smooth 증가 → 도착 정지 → smooth 감소 → 출발 정지 구간 분기.
## 결과: 항상 0~1 범위의 왕복 위치 ratio를 반환한다.
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


## 상황: 기본 밀치기 예시에서 공격 동작 구간인지 결정할 때 호출된다.
## 결과: 준비 중에는 0, 공격 중에는 항상 1을 반환한다.
func _punch_stage(time_value: float) -> int:
	return 1 if _punch_releasing(time_value) else 0


## 상황: 펀치 예시가 idle 대신 ATTACK frame을 보여줄 release 구간인지 검사할 때 호출된다.
## 결과: 세 release window 중 하나에 포함되면 true를 반환한다.
func _punch_releasing(time_value: float) -> bool:
	return (
		(time_value >= 0.45 and time_value < 0.75)
		or (time_value >= 1.25 and time_value < 1.55)
		or time_value >= 1.95
	)


## 상황: 벽 액션 4초 loop에서 현재 강조할 입력 단계를 선택할 때 호출된다.
## 결과: 0=매달리기, 1=벽 점프, 2=원래 벽 복귀를 반환한다.
func _wall_stage(time_value: float) -> int:
	if time_value < 1.2:
		return 0
	if time_value < 2.4:
		return 1
	return 2


## 상황: 벽 액션의 현재 시간에 대응하는 캐릭터 2D 위치를 계산할 때 호출된다.
## 순서: 초기 벽 오르기 linear 보간 → 바깥쪽 점프 Bezier → 원래 벽 복귀 Bezier.
## 결과: draw 함수가 상태와 독립적으로 사용할 canvas 좌표를 반환한다.
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


## 상황: 여러 demo가 시간 구간을 0~1의 부드러운 진행률로 바꿀 때 호출된다.
## 순서: `(value-start)/(end-start)` → clamp → cubic smoothstep.
## 결과: 시작/끝 속도가 0인 보간 ratio를 반환하는 C++ math helper처럼 동작한다.
func _smooth_ratio(value: float, start: float, end: float) -> float:
	var ratio: float = clampf((value - start) / (end - start), 0.0, 1.0) # 선형 정규화 값.
	return ratio * ratio * (3.0 - 2.0 * ratio)


## 상황: 블록 플립 예시의 경과시간을 캐릭터 draw transform 각도로 바꿀 때 호출된다.
## 순서: 0~1 clamp → smoothstep → 음의 한 바퀴(-TAU) 곱.
## 결과: 0.42초 동안 가속·감속하는 회전 radians를 반환한다.
func _rotation_demo_angle(elapsed: float) -> float:
	var progress: float = clampf(elapsed / ROTATION_KICK_DURATION, 0.0, 1.0)
	var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)
	return -TAU * eased_progress


## 상황: 벽 점프처럼 직선이 아닌 포물선형 안내 궤적의 위치를 구할 때 호출된다.
## 순서: `(1-t)^2 start + 2(1-t)t control + t^2 end` 공식을 계산한다.
## 결과: 세 점과 ratio를 변경하지 않고 새 Vector2 위치를 반환한다.
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


## 상황: page loop 마지막 0.2초에 모든 demo 요소를 부드럽게 지울 때 호출된다.
## 결과: 일반 구간은 1, fade 구간은 남은 시간 비율 1→0을 반환한다.
func _loop_alpha(duration: float) -> float:
	if _animation_time <= duration - LOOP_FADE_SECONDS:
		return 1.0
	return clampf(
		(duration - _animation_time) / LOOP_FADE_SECONDS,
		0.0,
		1.0
	)


## 상황: 각 페이지 상단에 제목과 동적 위치의 부제를 그릴 때 호출된다.
## 순서: 제목 draw → font metric으로 폭 측정 → 겹치지 않을 subtitle x 계산 → subtitle draw.
## 결과: 제목 길이가 달라도 두 문자열이 최소 간격을 유지한다.
func _draw_page_heading(title: String, subtitle: String) -> void:
	_text(Vector2(24.0, 32.0), title, 24, TEXT)
	var title_width: float = _font.get_string_size( # subtitle 배치에만 쓰는 실제 glyph 폭.
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		24
	).x
	var subtitle_x: float = maxf(252.0, 24.0 + title_width + 28.0)
	_text(Vector2(subtitle_x, 32.0), subtitle, 14, MUTED)


## 상황: 설명 요소 묶음을 공통 배경 card로 감쌀 때 호출된다.
## 결과: 고정 색·border·radius를 `_draw_round_panel()`에 전달한다.
func _draw_card(rect: Rect2) -> void:
	_draw_round_panel(rect, PANEL_DARK, BORDER, 8.0)


## 상황: card, key chip, modal처럼 둥근 배경과 테두리를 즉시-mode로 그릴 때 호출된다.
## 순서: StyleBoxFlat 생성 → 색/width/radius 설정 → 지정 rect에 draw.
## 결과: scene node를 추가하지 않고 이번 draw pass에 panel 픽셀을 기록한다.
func _draw_round_panel(
	rect: Rect2,
	background: Color,
	border: Color,
	radius: float
) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new() # 호출 한 번에만 쓰이는 지역 draw style.
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)


## 상황: 벽 액션처럼 순서가 있는 단계 번호와 현재 강조도를 표시할 때 호출된다.
## 순서: alpha 적용 색 → 활성 halo → badge 원 → 중앙 숫자.
## 결과: 0~1 alpha로 활성/비활성 단계를 같은 helper에서 표현한다.
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


## 상황: 캐릭터와 블록이 접촉할 지면을 card 안에 그릴 때 호출된다.
## 순서: 바닥 rect/상단선 → 28px 간격의 사선 pattern.
## 결과: origin과 width만으로 공통 지면 모양을 만든다.
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


## 상황: gameplay과 같은 sprite sheet frame을 임의 tutorial bounds에 그릴 때 호출된다.
## 순서: state texture/region 조회 → aspect-fit 크기 → 하단 중앙 위치 → 선택적 transform → region draw/복원.
## 결과: 원본 비율을 보존한 캐릭터 한 frame을 alpha와 rotation으로 표시한다.
func _draw_animated_character(
	bounds: Rect2,
	state: String,
	elapsed: float,
	alpha: float,
	rotation_radians: float = 0.0
) -> void:
	var texture: Texture2D = ANIMATION_DATA.texture_for(state) # state가 선택한 sprite atlas.
	var source_region: Rect2 = ANIMATION_DATA.region_for(state, elapsed) # elapsed에 해당하는 source frame.
	var source_aspect: float = source_region.size.x / source_region.size.y # 찌그러짐 방지 비율.
	var target_size: Vector2 = bounds.size # aspect-fit 계산으로 줄어들 destination 크기.
	if target_size.x / target_size.y > source_aspect:
		target_size.x = target_size.y * source_aspect
	else:
		target_size.y = target_size.x / source_aspect
	var target_position: Vector2 = Vector2( # bounds 하단 중앙에 맞춘 destination 좌상단.
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


## 상황: 펀치·플립·시스템 예시에서 L 테트로미노를 블록 atlas로 그릴 때 호출된다.
## 순서: 네 cell/색 source 결정 → 선택적 중심 회전 transform → cell별 texture region → transform 복원.
## 결과: origin·색·alpha·angle만으로 재사용 가능한 네 칸 블록을 그린다.
func _draw_tetromino(
	origin: Vector2,
	color: Color,
	alpha: float = 1.0,
	rotation_radians: float = 0.0
) -> void:
	var cells: Array[Vector2i] = [ # L 모양을 이루는 지역 좌표 네 개.
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(2, 0),
	]
	var source_key: String = "cyan" # color 값을 atlas Dictionary key로 변환한 결과.
	if color == ORANGE:
		source_key = "orange"
	elif color == PURPLE:
		source_key = "purple"
	elif color == RED:
		source_key = "red"
	var source_region: Rect2 = BLOCK_SPRITE_REGIONS[source_key]
	var center: Vector2 = Vector2(33.0, 22.0) # 네 cell 묶음의 시각적 회전 중심.
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


## 상황: 직선 이동·낙하·피스 밀기 방향을 선과 삼각형 머리로 표시할 때 호출된다.
## 순서: 선 draw → 단위 방향/수직 벡터 → end 기준 삼각형 세 점 → polygon draw.
## 결과: 임의 start/end에서도 일정한 크기의 화살표를 그린다.
func _draw_arrow(
	start: Vector2,
	end: Vector2,
	color: Color,
	width: float = 4.0,
	alpha: float = 1.0
) -> void:
	var arrow_color: Color = Color(color.r, color.g, color.b, alpha) # alpha가 합성된 최종 선/머리 색.
	draw_line(start, end, arrow_color, width, true)
	var direction: Vector2 = (end - start).normalized()
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var points: PackedVector2Array = PackedVector2Array([
		end,
		end - direction * 17.0 + perpendicular * 8.0,
		end - direction * 17.0 - perpendicular * 8.0,
	])
	draw_colored_polygon(points, arrow_color)


## 상황: 점프·회전처럼 곡선 운동 방향을 quadratic Bezier 화살표로 표시할 때 호출된다.
## 순서: 25개 sample point 생성 → polyline → 마지막 segment 방향으로 삼각형 머리.
## 결과: start/control/end를 통과하는 부드러운 방향 안내가 그려진다.
func _draw_arc_arrow(
	start: Vector2,
	end: Vector2,
	control: Vector2,
	color: Color,
	alpha: float = 1.0
) -> void:
	var points: PackedVector2Array = [] # draw_polyline에 전달할 연속 sample buffer.
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


## 상황: 현재 binding 이름을 키캡 모양과 활성 강조도로 표시할 때 호출된다.
## 순서: 문자열 길이 기반 width → emphasis clamp/배경 혼합 → 선택적 halo → panel/text.
## 결과: 짧고 긴 키 이름 모두 잘리지 않는 key chip을 그린다.
func _key_chip(
	position_value: Vector2,
	text_value: String,
	color: Color,
	emphasis: float = 0.0
) -> void:
	var width: float = maxf(58.0, float(text_value.length()) * 10.0 + 24.0) # 글자 수 기반 최소 폭.
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


## 상황: 시스템 키 page가 key chip과 한 줄 설명을 같은 간격으로 반복할 때 호출된다.
## 결과: 지정 위치에 chip을 그리고 54px 아래에 description을 배치한다.
func _draw_shortcut_row(
	position_value: Vector2,
	key_text: String,
	description: String,
	color: Color
) -> void:
	_key_chip(position_value, key_text, color)
	_text(position_value + Vector2(0.0, 54.0), description, 15, TEXT)


## 상황: tutorial의 모든 한글 문자열을 공통 font로 그릴 때 호출된다.
## 순서: newline 포함 시 줄별 y 증가 draw, 아니면 한 번 draw_string.
## 결과: Label node 없이 단일·다중 행 텍스트를 즉시-mode로 표시한다.
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


## 상황: page draw 함수가 action 하나의 현재 사용자 키 문자열을 요구할 때 호출된다.
## 결과: settings 미주입 시 `-`, 있으면 Settings의 결합 문자열을 반환한다.
func _binding(action_name: StringName) -> String:
	if settings == null:
		return "-"
	return settings.get_binding_text(action_name)


## 상황: 좌/우처럼 두 action의 binding을 한 구절에 함께 표시할 때 호출된다.
## 결과: 두 `_binding()` 결과를 ` / `로 연결한 문자열을 반환한다.
func _keys(first_action: StringName, second_action: StringName) -> String:
	return "%s / %s" % [_binding(first_action), _binding(second_action)]
