extends SceneTree

## [역할 / C++ 대응]
## headless Godot에서 입력 정의와 메인 게임의 핵심 계약을 검증하는 통합 test runner다.
## C++로 보면 `main()`을 가진 작은 테스트 실행 파일과 assertion helper의 조합에 가깝다.
## SceneTree를 상속해 frame/physics frame을 기다리고 실제 scene 수명을 직접 관리한다.

const INPUT_ACTIONS: Script = preload("res://scripts/input_actions.gd") # static 입력 API 의존성.
const GAME_CONTROLLER: Script = preload("res://scripts/game_controller.gd") # 단독 controller 생성용 class resource.
const ANIMATION_DATA: Script = preload("res://scripts/character_animation_data.gd")
const CHARACTER_DATA: Script = preload("res://scripts/character_data.gd")
const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn") # 펀치 통합 테스트용 object graph factory.
const CLOCK_WAVE_VFX: Texture2D = preload("res://assets/sprites/effects/clockmaker/clock_wave.png")
const CLOCK_GEAR_VFX: Texture2D = preload("res://assets/sprites/effects/clockmaker/clock_gear_ring.png")
const SHURIKEN_SPIN_VFX: Texture2D = preload("res://assets/sprites/effects/ninja/shuriken_spin.png")
const SHURIKEN_IMPACT_VFX: Texture2D = preload("res://assets/sprites/effects/ninja/shuriken_impact.png")
const SPRINT_VFX: Texture2D = preload("res://assets/sprites/effects/normal/sprint_vfx.png")
const GUARD_BREAK_VFX: Texture2D = preload("res://assets/sprites/effects/boxer/guard_break_impact.png")
const SHIELD_BARRIER_VFX: Texture2D = preload("res://assets/sprites/effects/shield_guard/shield_barrier.png")
const HOSE_VFX: Texture2D = preload("res://assets/sprites/effects/firefighter/hose_overlay.png")
const WATER_PATH_VFX: Texture2D = preload("res://assets/sprites/effects/firefighter/water_path.png")
const CLEANUP_VFX: Texture2D = preload("res://assets/sprites/effects/cleaner/cleanup_dust.png")
const PAN_TOSS_UP_VFX: Texture2D = preload("res://assets/sprites/effects/chef/pan_toss_up.png")
const PAN_TOSS_DOWN_VFX: Texture2D = preload("res://assets/sprites/effects/chef/pan_toss_down.png")
const PAN_TOSS_FAILURE_VFX: Texture2D = preload("res://assets/sprites/effects/chef/pan_toss_failure.png")
const BOSS_NORMAL_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/boss_normal_sprites.png")
const BOSS_BIND_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/boss_bind_sprites.png")
const BOSS_THORN_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/boss_thron_sprites.png")
const BOSS_DOWN_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/boss_down_sprites.png")
const BOSS_FALLING_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/boss_falling_sprites.png")
const BOSS_FALLEN_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/boss_fallen_sprites.png")

var _checks: int = 0 # 수행한 assertion 총수.
var _failures: int = 0 # false였던 assertion 수이자 process exit code.


## 상황: SceneTree test runner가 생성될 때 자동 호출된다.
## 결과: 엔진 초기화가 끝난 뒤 async 테스트를 시작하도록 `_run`을 deferred 예약한다.
func _init() -> void:
	call_deferred("_run")


## 상황: test runner의 단일 진입점으로 입력·수식·scene 통합 계약을 순서대로 검증한다.
## 순서: 사용자 키 보존 → 기본 정의/수식 → controller loop → tutorial/SFX
##       → spawn 좌우 여백/벽 옆 fallback → release punch.
## 결과: 임시 입력 객체를 정리하고 실패 수를 프로세스 종료 코드로 반환한다.
func _run() -> void:
	INPUT_ACTIONS.ensure_defaults()
	InputMap.action_erase_events(&"character_punch")
	var custom_event: InputEventKey = InputEventKey.new() # 기본값 보장이 사용자 event를 덮지 않는지 볼 fixture.
	custom_event.physical_keycode = KEY_F8
	InputMap.action_add_event(&"character_punch", custom_event)
	INPUT_ACTIONS.ensure_defaults()
	var custom_events: Array[InputEvent] = InputMap.action_get_events(&"character_punch") # 적용 후 snapshot.
	_expect(
		custom_events.size() == 1
			and custom_events[0] is InputEventKey
			and (custom_events[0] as InputEventKey).physical_keycode == KEY_F8,
		"사용자 키가 기본값으로 오염되지 않는다."
	)
	_expect(
		INPUT_ACTIONS.get_default_keys(&"character_rotation_kick") == [KEY_S],
		"블록 플립 기본 키는 S다."
	)
	_expect(
		INPUT_ACTIONS.get_default_keys(&"pause_game") == [KEY_P],
		"일시정지는 P 하나만 사용한다."
	)
	_expect(
		INPUT_ACTIONS.get_definition(&"character_pull").is_empty(),
		"최종 입력 목록에 당기기 동작은 없다."
	)
	_expect(
		INPUT_ACTIONS.get_default_keys(&"character_special") == [KEY_V],
		"특수 스킬 기본 키는 V다."
	)
	var controller: MainGameController = GAME_CONTROLLER.new() # scene 없이 process API만 검사할 임시 객체.
	controller.reset_game(20260801)
	controller.board.reset()
	var spawn_cells_valid: bool = true
	for piece_type: int in range(MainTetrominoData.TYPE_COUNT):
		var cells: Array[Vector2i] = MainTetrominoData.get_cells(piece_type, 0)
		var minimum_x: int = cells[0].x
		var maximum_x: int = cells[0].x
		for cell: Vector2i in cells:
			minimum_x = mini(minimum_x, cell.x)
			maximum_x = maxi(maximum_x, cell.x)
		var candidates: Array[Vector2i] = controller._valid_spawn_origins(piece_type)
		var expected_count: int = MainBoardModel.WIDTH - 2 - (maximum_x - minimum_x)
		spawn_cells_valid = spawn_cells_valid and candidates.size() == expected_count
		for origin: Vector2i in candidates:
			for cell: Vector2i in cells:
				var board_cell: Vector2i = origin + cell
				spawn_cells_valid = (
					spawn_cells_valid
					and board_cell.x >= 1
					and board_cell.x <= MainBoardModel.WIDTH - 2
				)
	_expect(
		spawn_cells_valid,
		"모든 테트로미노 spawn 후보는 양쪽 경계 열을 비운다."
	)
	_expect(
		controller.has_method("_physics_process")
			and not controller.has_method("_process"),
		"게임 진행은 현재 physics process 경로를 사용한다."
	)
	controller.free()
	_expect(
		StartScreenTutorialCanvas.PAGE_DURATIONS.size() == 5,
		"메인 애니메이션 튜토리얼은 5페이지다."
	)
	_expect(
		FileAccess.file_exists("res://assets/sfx/08_select.wav"),
		"현재 선택 효과음 리소스를 유지한다."
	)
	_expect(
		ANIMATION_DATA.has_character("normal")
			and ANIMATION_DATA.display_name_for("normal") == "일반인",
		"일반인 animation profile이 기본 캐릭터로 등록된다."
	)
	var normal_atlas: Texture2D = ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "normal")
	_expect(
		normal_atlas.get_width() == 1024 and normal_atlas.get_height() == 768,
		"일반인 atlas는 1024×768 균일 격자다."
	)
	var boxer_atlas: Texture2D = ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "boxer")
	_expect(
		ANIMATION_DATA.has_character("boxer")
			and ANIMATION_DATA.display_name_for("boxer") == "복서"
			and boxer_atlas.get_width() == 1024
			and boxer_atlas.get_height() == 768
			and boxer_atlas != normal_atlas,
		"복서 profile은 독립된 1024×768 atlas를 사용한다."
	)
	var shield_guard_atlas: Texture2D = ANIMATION_DATA.texture_for(
		ANIMATION_DATA.IDLE,
		"shield_guard"
	)
	_expect(
		ANIMATION_DATA.has_character("shield_guard")
			and ANIMATION_DATA.display_name_for("shield_guard") == "방패병"
			and shield_guard_atlas.get_width() == 1024
			and shield_guard_atlas.get_height() == 768
			and shield_guard_atlas != normal_atlas
			and shield_guard_atlas != boxer_atlas,
		"방패병 profile은 독립된 1024×768 atlas를 사용한다."
	)
	var firefighter_atlas: Texture2D = ANIMATION_DATA.texture_for(
		ANIMATION_DATA.IDLE,
		"firefighter"
	)
	_expect(
		ANIMATION_DATA.has_character("firefighter")
			and ANIMATION_DATA.display_name_for("firefighter") == "소방관"
			and firefighter_atlas.get_width() == 1024
			and firefighter_atlas.get_height() == 768
			and firefighter_atlas != normal_atlas
			and firefighter_atlas != boxer_atlas
			and firefighter_atlas != shield_guard_atlas,
		"소방관 profile은 독립된 1024×768 atlas를 사용한다."
	)
	var cleaner_atlas: Texture2D = ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "cleaner")
	_expect(
		ANIMATION_DATA.has_character("cleaner")
			and ANIMATION_DATA.display_name_for("cleaner") == "청소부"
			and cleaner_atlas.get_width() == 1024
			and cleaner_atlas.get_height() == 768
			and cleaner_atlas != normal_atlas
			and cleaner_atlas != boxer_atlas
			and cleaner_atlas != shield_guard_atlas
			and cleaner_atlas != firefighter_atlas,
		"청소부 profile은 독립된 1024×768 atlas를 사용한다."
	)
	var chef_atlas: Texture2D = ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "chef")
	_expect(
		ANIMATION_DATA.has_character("chef")
			and ANIMATION_DATA.display_name_for("chef") == "요리사"
			and chef_atlas.get_width() == 1024
			and chef_atlas.get_height() == 768
			and chef_atlas != normal_atlas
			and chef_atlas != boxer_atlas
			and chef_atlas != shield_guard_atlas
			and chef_atlas != firefighter_atlas
			and chef_atlas != cleaner_atlas,
		"요리사 profile은 독립된 1024×768 atlas를 사용한다."
	)
	for beta_id: String in CHARACTER_DATA.CHARACTER_ORDER:
		var beta_atlas: Texture2D = ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, beta_id)
		_expect(
			ANIMATION_DATA.has_character(beta_id)
				and CHARACTER_DATA.has_character(beta_id)
				and beta_atlas.get_width() == 1024
				and beta_atlas.get_height() == 768,
			"%s 선택 캐릭터는 데이터와 1024×768 atlas를 함께 가진다." % beta_id
		)
	_expect(
		CHARACTER_DATA.jump_cells("normal") == 2
			and CHARACTER_DATA.jump_cells("chef") == 2
			and CHARACTER_DATA.jump_cells("ninja") == 4
			and is_equal_approx(CHARACTER_DATA.rotation_cooldown("boxer"), 1.7)
			and is_equal_approx(CHARACTER_DATA.rotation_cooldown("ninja"), 1.3)
			and is_equal_approx(CHARACTER_DATA.special_cooldown("chef"), 7.38)
			and is_equal_approx(CHARACTER_DATA.special_cooldown("clockmaker"), 10.56)
			and is_equal_approx(CHARACTER_DATA.special_cooldown("ninja"), 4.85)
			and not CHARACTER_DATA.profile_for("normal").has("special_cost"),
		"점프·공속·특수스킬 능력치가 지정된 칸 수와 쿨다운으로 변환된다."
	)
	_expect(
		ANIMATION_DATA.REGIONS[ANIMATION_DATA.IDLE].size() == 4
			and ANIMATION_DATA.REGIONS[ANIMATION_DATA.ATTACK].size() == 4
			and ANIMATION_DATA.REGIONS[ANIMATION_DATA.HANG].size() == 4
			and ANIMATION_DATA.REGIONS[ANIMATION_DATA.JUMP].size() == 8
			and ANIMATION_DATA.REGIONS[ANIMATION_DATA.ROTATION_KICK].size() == 8
			and ANIMATION_DATA.REGIONS[ANIMATION_DATA.SPECIAL].size() == 8,
		"일반인 상태별 frame 수가 4·4·4·8·8·8 규격을 지킨다."
	)
	_expect(
		CLOCK_WAVE_VFX.get_width() == 1152
			and CLOCK_WAVE_VFX.get_height() == 192
			and CLOCK_GEAR_VFX.get_width() == 512
			and CLOCK_GEAR_VFX.get_height() == 128
			and SHURIKEN_SPIN_VFX.get_width() == 128
			and SHURIKEN_SPIN_VFX.get_height() == 32
			and SHURIKEN_IMPACT_VFX.get_width() == 256
			and SHURIKEN_IMPACT_VFX.get_height() == 128,
		"시계공·닌자 VFX 시트가 지정된 frame 크기와 행 구성을 지킨다."
	)
	_test_sprite_atlas_contracts()
	_test_spawn_side_margin()
	await _test_release_punch()
	await _test_beta_specials()
	await _test_fixed_support_grab()
	await _test_hang_face_bounds()
	InputMap.action_erase_events(&"character_punch")
	custom_events.clear()
	custom_event = null
	await process_frame
	if _failures == 0:
		print("성공: 메인 게임 테스트 %d개 통과" % _checks)
	else:
		push_error("실패: 최종 방향 통합 테스트 %d/%d개 실패" % [_failures, _checks])
	quit(_failures)


## 상황: 새 피스가 벽에서 한 칸 떨어져 spawn하되 중앙이 막히면 벽 옆으로 fallback하는지 검사한다.
## 순서: 7종 빈 보드 후보 수/실제 셀 여백 검사 → 선택 함수의 안전 후보 우선 검사
##       → I 피스 중앙 차단 fallback → 전체 차단 GAME_OVER 검사.
## 결과: 스폰 여백의 정상 경로와 예외 경로가 모두 설계 계약을 지키는지 assertion으로 기록한다.
func _test_spawn_side_margin() -> void:
	var controller: MainGameController = GAME_CONTROLLER.new() # scene 없이 spawn 규칙만 검증할 임시 controller.
	controller.reset_game(20260804)
	controller.board.reset()
	var expected_counts: PackedInt32Array = [5, 6, 6, 7, 6, 6, 6] # I/J/L/O/S/T/Z 안전 후보 수.
	for piece_type: int in range(MainTetrominoData.TYPE_COUNT):
		var candidates: Array[Vector2i] = controller._valid_spawn_origins(
			piece_type,
			MainGameController.SPAWN_SIDE_MARGIN_CELLS
		)
		_expect(
			candidates.size() == expected_counts[piece_type],
			"%s 피스의 한 칸 여백 spawn 후보 수가 %d개다."
				% [MainTetrominoData.get_display_name(piece_type), expected_counts[piece_type]]
		)
		var all_candidates_safe: bool = true # 네 실제 셀 중 하나라도 x=0/9면 false가 된다.
		for origin: Vector2i in candidates:
			for local_cell: Vector2i in MainTetrominoData.get_cells(piece_type, 0):
				var occupied_x: int = origin.x + local_cell.x
				if (
					occupied_x < MainGameController.SPAWN_SIDE_MARGIN_CELLS
					or occupied_x
					>= MainBoardModel.WIDTH - MainGameController.SPAWN_SIDE_MARGIN_CELLS
				):
					all_candidates_safe = false
		_expect(
			all_candidates_safe,
			"%s 피스의 모든 우선 spawn 실제 셀이 좌우 한 칸 여백을 지킨다."
				% MainTetrominoData.get_display_name(piece_type)
		)
		var chosen_origin: Variant = controller._choose_random_spawn_origin(piece_type)
		_expect(
			chosen_origin != null and candidates.has(chosen_origin as Vector2i),
			"%s 피스는 안전 후보가 있으면 벽 옆 후보를 선택하지 않는다."
				% MainTetrominoData.get_display_name(piece_type)
		)

	# 회전 0 I 피스는 SPAWN_Y+1 행에 가로 4칸을 차지한다. 가운데 x=4,5를 막으면
	# 한 칸 여백 후보는 모두 막히지만 x=0..3과 x=6..9의 벽 접촉 후보는 남는다.
	controller.board.reset()
	var i_spawn_row: int = MainGameController.SPAWN_Y + 1
	controller.board.cells[i_spawn_row][4] = MainTetrominoData.Type.T
	controller.board.cells[i_spawn_row][5] = MainTetrominoData.Type.T
	_expect(
		controller._valid_spawn_origins(
			MainTetrominoData.Type.I,
			MainGameController.SPAWN_SIDE_MARGIN_CELLS
		).is_empty(),
		"I 피스의 중앙 안전 spawn 영역을 완전히 막을 수 있다."
	)
	var fallback_origin: Variant = controller._choose_random_spawn_origin(MainTetrominoData.Type.I)
	var fallback_x: int = (fallback_origin as Vector2i).x if fallback_origin != null else -1
	_expect(
		fallback_origin != null and (fallback_x == 0 or fallback_x == 6),
		"안전 후보가 없으면 I 피스가 벽 옆의 유효 후보로 fallback한다."
	)

	controller.board.reset()
	for x: int in range(MainBoardModel.WIDTH):
		controller.board.cells[i_spawn_row][x] = MainTetrominoData.Type.T
	controller.next_type = MainTetrominoData.Type.I
	_expect(
		not controller.spawn_next_piece()
			and controller.state == MainGameController.GameState.GAME_OVER,
		"여백 후보와 벽 옆 후보가 모두 없을 때만 GAME_OVER가 된다."
	)
	controller.free()


## 상황: 각 테스트 조건을 기록하고 사람이 읽는 결과를 stdout/stderr에 출력할 때 호출된다.
## 결과: check는 항상 1 증가하고, 실패 조건에서만 failure를 증가시킨다.
func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  [통과] %s" % description)
	else:
		_failures += 1
		push_error("  [실패] %s" % description)


## 상황: 실제 main scene에서 X press/release와 hitbox 기반 피스 이동을 검증할 때 호출된다.
## 순서: scene 생성/정지 → 맞는 위치의 hit → 빗나가는 위치의 miss → audio/node 정리.
## 결과: release 전에는 움직이지 않고 release 판정 창에서만 피스가 이동한다는 계약을 검사한다.
func _test_sprite_atlas_contracts() -> void:
	var profiles_match_selection: bool = ANIMATION_DATA.PROFILES.size() == CHARACTER_DATA.CHARACTER_ORDER.size()
	var character_frames_valid: bool = true
	for character_id: String in CHARACTER_DATA.CHARACTER_ORDER:
		profiles_match_selection = profiles_match_selection and ANIMATION_DATA.has_character(character_id)
		var texture: Texture2D = ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, character_id)
		var image: Image = texture.get_image()
		character_frames_valid = (
			character_frames_valid
			and texture.get_width() == 1024
			and texture.get_height() == 768
		)
		for state: String in ANIMATION_DATA.REGIONS:
			var frames: Array = ANIMATION_DATA.REGIONS[state]
			for frame_index: int in range(frames.size()):
				var frame_region: Rect2 = frames[frame_index] as Rect2
				var elapsed: float = (
					float(frame_index) * float(ANIMATION_DATA.FRAME_DURATIONS[state])
					+ 0.001
				)
				var visible_region: Rect2 = ANIMATION_DATA.visible_region_for(
					state,
					elapsed,
					character_id
				)
				character_frames_valid = (
					character_frames_valid
					and visible_region.size.x > 0.0
					and visible_region.size.y > 0.0
					and frame_region.encloses(visible_region)
					and _image_region_has_alpha(image, visible_region)
				)

	_expect(
		profiles_match_selection,
		"캐릭터 선택 목록과 animation profile 목록이 정확히 일치한다."
	)
	_expect(
		character_frames_valid,
		"모든 캐릭터 atlas의 사용 frame이 규격 안에 있고 불투명 픽셀을 가진다."
	)

	var effect_specs: Array = [
		[SPRINT_VFX, Vector2i(128, 128), 8, 1],
		[GUARD_BREAK_VFX, Vector2i(64, 64), 4, 1],
		[SHIELD_BARRIER_VFX, Vector2i(48, 144), 6, 1],
		[HOSE_VFX, Vector2i(192, 64), 4, 1],
		[WATER_PATH_VFX, Vector2i(48, 48), 4, 1],
		[CLEANUP_VFX, Vector2i(144, 48), 6, 1],
		[PAN_TOSS_UP_VFX, Vector2i(96, 96), 4, 1],
		[PAN_TOSS_DOWN_VFX, Vector2i(96, 96), 4, 1],
		[PAN_TOSS_FAILURE_VFX, Vector2i(48, 48), 3, 1],
		[CLOCK_GEAR_VFX, Vector2i(128, 128), 4, 1],
		[CLOCK_WAVE_VFX, Vector2i(192, 192), 6, 1],
		[SHURIKEN_SPIN_VFX, Vector2i(32, 32), 4, 1],
		[SHURIKEN_IMPACT_VFX, Vector2i(64, 64), 4, 2],
	]
	var effect_frames_valid: bool = true
	for spec: Array in effect_specs:
		var texture: Texture2D = spec[0] as Texture2D
		var frame_size: Vector2i = spec[1] as Vector2i
		var columns: int = spec[2] as int
		var rows: int = spec[3] as int
		var image: Image = texture.get_image()
		var current_effect_valid: bool = (
			texture.get_width() == frame_size.x * columns
			and texture.get_height() == frame_size.y * rows
		)
		var current_effect_has_alpha: bool = false
		for row: int in range(rows):
			for column: int in range(columns):
				var frame_region: Rect2 = Rect2(
					Vector2(float(column * frame_size.x), float(row * frame_size.y)),
					Vector2(frame_size)
				)
				current_effect_has_alpha = (
					current_effect_has_alpha
					or _image_region_has_alpha(image, frame_region)
				)
		current_effect_valid = current_effect_valid and current_effect_has_alpha
		effect_frames_valid = effect_frames_valid and current_effect_valid
	_expect(
		effect_frames_valid,
		"모든 캐릭터 특수효과 시트의 크기·행·열과 불투명 픽셀이 사용 규격과 일치한다."
	)

	var board_sprites_valid: bool = true
	var block_image: Image = MainGameView.BLOCK_TEXTURE.get_image()
	var block_texture_rect := Rect2(
		Vector2.ZERO,
		Vector2(MainGameView.BLOCK_TEXTURE.get_width(), MainGameView.BLOCK_TEXTURE.get_height())
	)
	for source_region: Rect2 in MainGameView.BLOCK_SPRITE_REGIONS.values():
		board_sprites_valid = (
			board_sprites_valid
			and block_texture_rect.encloses(source_region)
			and _image_region_has_alpha(block_image, source_region)
		)
	var thorn_image: Image = MainGameView.THORN_TEXTURE.get_image()
	var thorn_texture_rect := Rect2(
		Vector2.ZERO,
		Vector2(MainGameView.THORN_TEXTURE.get_width(), MainGameView.THORN_TEXTURE.get_height())
	)
	board_sprites_valid = (
		board_sprites_valid
		and thorn_texture_rect.encloses(MainGameView.THORN_SOURCE_REGION)
		and _image_region_has_alpha(thorn_image, MainGameView.THORN_SOURCE_REGION)
	)
	_expect(
		board_sprites_valid,
		"모든 블록·가시 source 영역이 atlas 안에 있고 실제 불투명 픽셀을 가진다."
	)

	var boss_specs: Array = [
		[BOSS_NORMAL_TEXTURE, Vector2i(384, 1024)],
		[BOSS_BIND_TEXTURE, Vector2i(384, 1024)],
		[BOSS_THORN_TEXTURE, Vector2i(384, 1024)],
		[BOSS_DOWN_TEXTURE, Vector2i(384, 983)],
		[BOSS_FALLING_TEXTURE, Vector2i(384, 1024)],
		[BOSS_FALLEN_TEXTURE, Vector2i(384, 234)],
	]
	var boss_sheets_valid: bool = true
	for spec: Array in boss_specs:
		var texture: Texture2D = spec[0] as Texture2D
		var frame_size: Vector2i = spec[1] as Vector2i
		var image: Image = texture.get_image()
		boss_sheets_valid = (
			boss_sheets_valid
			and texture.get_width() == frame_size.x * MainGameView.BOSS_FRAME_COUNT
			and texture.get_height() == frame_size.y
		)
		for frame: int in range(MainGameView.BOSS_FRAME_COUNT):
			boss_sheets_valid = (
				boss_sheets_valid
				and _image_region_has_alpha(
					image,
					Rect2(frame * frame_size.x, 0, frame_size.x, frame_size.y)
				)
			)
	_expect(
		boss_sheets_valid,
		"보스의 일반·속박·가시·다운·낙하 시트가 모두 4 frame 규격을 지킨다."
	)

	var controller: MainGameController = GAME_CONTROLLER.new()
	var boss_hitbox: Rect2 = controller.boss_hitbox()
	controller.free()
	var boss_scale: float = (
		MainGameController.BOSS_DISPLAY_SIZE.x / MainGameView.BOSS_SOURCE_FRAME_SIZE.x
	)
	var boss_display_rect: Rect2 = Rect2(
		MainGameController.BOSS_POSITION - MainGameController.BOSS_DISPLAY_SIZE * 0.5,
		MainGameController.BOSS_DISPLAY_SIZE
	)
	var source_hitbox: Rect2 = Rect2(
		(boss_hitbox.position - boss_display_rect.position) / boss_scale,
		boss_hitbox.size / boss_scale
	)
	var boss_hitbox_excludes_padding: bool = true
	for texture: Texture2D in [BOSS_NORMAL_TEXTURE, BOSS_BIND_TEXTURE]:
		for frame: int in range(MainGameView.BOSS_FRAME_COUNT):
			var frame_source := Rect2(
				frame * MainGameView.BOSS_SOURCE_FRAME_SIZE.x,
				0.0,
				MainGameView.BOSS_SOURCE_FRAME_SIZE.x,
				MainGameView.BOSS_SOURCE_FRAME_SIZE.y
			)
			var opaque_region: Rect2 = ANIMATION_DATA.opaque_region_for(texture, frame_source)
			var local_opaque_region := Rect2(
				Vector2(
					opaque_region.position.x - frame_source.position.x,
					opaque_region.position.y
				),
				opaque_region.size
			)
			boss_hitbox_excludes_padding = (
				boss_hitbox_excludes_padding
				and local_opaque_region.encloses(source_hitbox)
			)
	_expect(
		boss_hitbox_excludes_padding,
		"보스 공격 판정은 일반·속박 모든 frame의 투명 바깥 여백 안으로 들어오지 않는다."
	)


func _image_region_has_alpha(image: Image, region: Rect2) -> bool:
	for pixel_y: int in range(int(region.position.y), int(region.end.y)):
		for pixel_x: int in range(int(region.position.x), int(region.end.x)):
			if image.get_pixel(pixel_x, pixel_y).a >= ANIMATION_DATA.FRAME_ALPHA_THRESHOLD:
				return true
	return false


func _test_release_punch() -> void:
	var scene: MainGameView = GAME_SCENE.instantiate() # 테스트가 소유해 마지막에 free할 실제 scene 인스턴스.
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED

	var controller: MainGameController = scene.get_node("GameController") # 논리 피스 상태 관찰 대상.
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character") # 입력·hitbox 실행 대상.
	_test_character_frame_normalization(controller, character)
	_test_binding_overlay_alignment(scene, character)
	_expect(
		character.character_id == "normal"
			and not character.set_character_id("missing_character"),
		"알 수 없는 캐릭터 ID는 기본 profile을 바꾸지 않는다."
	)
	character._animation_image_cache["stale"] = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	_expect(
		character.set_character_id("boxer")
			and character.character_id == "boxer"
			and character.sprite.texture
			== ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "boxer")
			and character._animation_image_cache.size() == 1
			and character._frame_alpha_bounds_cache.size() == 1,
		"복서 전환은 atlas를 즉시 교체하고 새 frame 표시 cache만 유지한다."
	)
	character._animation_image_cache["boxer_stale"] = Image.create(
		1,
		1,
		false,
		Image.FORMAT_RGBA8
	)
	_expect(
		character.set_character_id("shield_guard")
			and character.character_id == "shield_guard"
			and character.sprite.texture
			== ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "shield_guard")
			and character._animation_image_cache.size() == 1
			and character._frame_alpha_bounds_cache.size() == 1,
		"방패병 전환은 atlas를 즉시 교체하고 새 frame 표시 cache만 유지한다."
	)
	character._animation_image_cache["shield_guard_stale"] = Image.create(
		1,
		1,
		false,
		Image.FORMAT_RGBA8
	)
	_expect(
		character.set_character_id("firefighter")
			and character.character_id == "firefighter"
			and character.sprite.texture
			== ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "firefighter")
			and character._animation_image_cache.size() == 1
			and character._frame_alpha_bounds_cache.size() == 1,
		"소방관 전환은 atlas를 즉시 교체하고 새 frame 표시 cache만 유지한다."
	)
	character._animation_image_cache["firefighter_stale"] = Image.create(
		1,
		1,
		false,
		Image.FORMAT_RGBA8
	)
	_expect(
		character.set_character_id("cleaner")
			and character.character_id == "cleaner"
			and character.sprite.texture
			== ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "cleaner")
			and character._animation_image_cache.size() == 1
			and character._frame_alpha_bounds_cache.size() == 1,
		"청소부 전환은 atlas를 즉시 교체하고 새 frame 표시 cache만 유지한다."
	)
	character._animation_image_cache["cleaner_stale"] = Image.create(
		1,
		1,
		false,
		Image.FORMAT_RGBA8
	)
	_expect(
		character.set_character_id("chef")
			and character.character_id == "chef"
			and character.sprite.texture
			== ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "chef")
			and character._animation_image_cache.size() == 1
			and character._frame_alpha_bounds_cache.size() == 1,
		"요리사 전환은 atlas를 즉시 교체하고 새 frame 표시 cache만 유지한다."
	)
	var crush_results: Array[bool] = []
	for character_id: String in CHARACTER_DATA.CHARACTER_ORDER:
		character.set_character_id(character_id)
		crush_results.append(character._crush_mask_overlaps_active_piece(Vector2i(4, 18)))
	var shared_crush_result: bool = true
	for result: bool in crush_results:
		if result != crush_results[0]:
			shared_crush_result = false
			break
	_expect(
		shared_crush_result,
		"모든 캐릭터는 외형 알파와 무관한 동일한 압사 충돌체를 사용한다."
	)
	character.play_special_animation()
	_expect(
		character._get_animation_state() == ANIMATION_DATA.SPECIAL
			and character._special_animation_remaining
			== MainCharacterController.SPECIAL_ANIMATION_DURATION,
		"특수 스킬 호출은 8 frame SPECIAL 상태를 시작한다."
	)
	character._special_animation_remaining = 0.0
	character.position = Vector2(240.0, 912.0)
	character.facing = 1
	var body_rect: Rect2 = character._character_collider_rect()
	var right_attack_rect: Rect2 = character._punch_hitbox_rect()
	character.facing = -1
	var left_attack_rect: Rect2 = character._punch_hitbox_rect()
	_expect(
		is_equal_approx(right_attack_rect.size.x, MainCharacterController.CELL_SIZE)
			and is_equal_approx(right_attack_rect.size.y, body_rect.size.y)
			and is_equal_approx(right_attack_rect.position.x, body_rect.end.x)
			and is_equal_approx(left_attack_rect.end.x, body_rect.position.x)
			and left_attack_rect.size.is_equal_approx(right_attack_rect.size),
		"기본 공격은 무기 sprite와 무관하게 좌우 전방 한 칸·캐릭터 전체 높이를 판정한다."
	)
	character.facing = 1
	controller.state = MainGameController.GameState.PLAYING
	controller.active_cell_indices.clear()
	controller.board.reset()
	controller.board.cells[20][6] = MainTetrominoData.Type.J
	var upper_target: Variant = character._basic_attack_target_cell()
	controller.board.reset()
	controller.board.cells[21][6] = MainTetrominoData.Type.J
	var lower_target: Variant = character._basic_attack_target_cell()
	controller.board.reset()
	controller.board.cells[19][6] = MainTetrominoData.Type.J
	var outside_target: Variant = character._basic_attack_target_cell()
	_expect(
		upper_target != null
			and (upper_target as Vector2i) == Vector2i(6, 20)
			and lower_target != null
			and (lower_target as Vector2i) == Vector2i(6, 21),
		"기본 공격은 캐릭터 높이에 걸친 위·아래 전방 블록을 모두 대상으로 찾는다."
	)
	_expect(
		outside_target == null,
		"기본 공격은 캐릭터 고정 높이 밖의 블록까지 판정을 넓히지 않는다."
	)
	_prepare_punch(controller, character, Vector2i(4, 19), Vector2(165.0, 912.0))
	var start_origin: Vector2i = controller.active_origin # release 전후를 비교할 immutable 기준값.
	Input.action_release(&"character_punch")
	Input.action_press(&"character_punch")
	character._handle_charge(0.2)
	_expect(
		not character._charging
			and character._pending_punch_stage == 1
			and controller.active_origin == start_origin,
		"X를 누르면 즉시 공통 1칸 밀치기 판정이 예약된다."
	)
	character._resolve_pending_punch(0.0)
	_expect(
		controller.active_origin == start_origin + Vector2i.RIGHT,
		"전방 hitbox에 닿은 블록은 정확히 1칸 이동한다."
	)
	Input.action_release(&"character_punch")

	_prepare_punch(controller, character, Vector2i(7, 1), Vector2(24.0, 912.0))
	Input.action_press(&"character_punch")
	character._handle_charge(0.2)
	character._resolve_pending_punch(0.1)
	_expect(
		controller.active_origin == Vector2i(7, 1),
		"전방 hitbox 밖의 블록은 놓아도 이동하지 않는다."
	)
	Input.action_release(&"character_punch")
	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._charge_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	character._charge_loop_player.stream = null
	await create_timer(0.12).timeout
	scene.free()
	await process_frame


func _test_beta_specials() -> void:
	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var controller: MainGameController = scene.get_node("GameController")
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)
	character.velocity = Vector2(0.0, 10.0)
	await physics_frame
	await physics_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	character.facing = 1
	_expect(character.is_on_floor(), "특수 스킬 테스트 캐릭터를 물리 바닥에 명시적으로 정착시킨다.")

	character.set_character_id("normal")
	var normal_speed: float = MainCharacterData.move_speed("normal") * MainCharacterController.GIT_GRID_SCALE
	var stamina_before: float = character.stamina
	_expect(
		character._attempt_special_skill()
			and is_equal_approx(character.stamina, stamina_before)
			and is_equal_approx(character.current_move_speed(), normal_speed * 1.6),
		"일반인 전력 질주는 스태미나를 쓰지 않고 2초 동안 이동속도를 60% 높인다."
	)

	controller.board.reset()
	character.set_character_id("boxer")
	controller.board.cells[20][6] = MainTetrominoData.Type.T
	stamina_before = character.stamina
	var boxer_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	_expect(
		boxer_started
			and is_equal_approx(character.stamina, stamina_before)
			and controller.board.get_cell(Vector2i(9, 20)) == MainTetrominoData.Type.T,
		"복서 가드 브레이크는 전방 노출 고정 블록을 최대 3칸 밀고 스태미나를 쓰지 않는다."
	)
	controller.board.reset()
	character.special_cooldown_remaining = 0.0
	var boxer_failed_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	_expect(
		boxer_failed_started
			and is_equal_approx(
				character.special_cooldown_remaining,
				character.current_special_cooldown() * 0.5
			),
		"복서 가드 브레이크만 0칸 이동 실패 시 특수 쿨다운의 50%를 적용한다."
	)

	controller.board.reset()
	character.set_character_id("shield_guard")
	var shield_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	_expect(
		shield_started
			and character.barrier_remaining() > 0.0
			and controller.transient_blocker_cells.size() == 3,
		"방패병은 시전 방향 앞에 세로 3칸의 임시 보호벽을 만든다."
	)
	character._cancel_character_skill_effects()

	controller.board.reset()
	character.set_character_id("firefighter")
	character.special_cooldown_remaining = 0.0
	var firefighter_started: bool = character._attempt_special_skill()
	if firefighter_started:
		character._resolve_pending_special()
	_expect(
		firefighter_started and not controller.water_path_cells.is_empty(),
		"소방관은 고정 지형을 따라 최대 4단계 중력 물길을 만든다."
	)
	character._cancel_character_skill_effects()

	controller.board.reset()
	character.set_character_id("cleaner")
	character.special_cooldown_remaining = 0.0
	for x: int in range(4, 7):
		controller.board.cells[MainBoardModel.HEIGHT - 1][x] = MainTetrominoData.Type.T
	var cleaner_started: bool = character._attempt_special_skill()
	if cleaner_started:
		character._resolve_pending_special()
	_expect(
		cleaner_started
			and controller.board.get_cell(Vector2i(4, MainBoardModel.HEIGHT - 1)) == MainBoardModel.EMPTY
			and controller.board.get_cell(Vector2i(5, MainBoardModel.HEIGHT - 1)) == MainBoardModel.EMPTY
			and controller.board.get_cell(Vector2i(6, MainBoardModel.HEIGHT - 1)) == MainBoardModel.EMPTY,
		"청소부 대청소는 캐릭터 발밑 중심의 노출 고정 블록을 최대 세 개 제거한다."
	)

	controller.board.reset()
	character.set_character_id("chef")
	character.special_cooldown_remaining = 0.0
	controller.board.cells[20][6] = MainTetrominoData.Type.L
	var chef_started: bool = character._attempt_special_skill()
	if chef_started:
		character._resolve_pending_special()
	_expect(
		chef_started
			and controller.board.get_cell(Vector2i(6, 20)) == MainBoardModel.EMPTY
			and controller.board.get_cell(Vector2i(7, 19)) == MainTetrominoData.Type.L,
		"요리사 팬 토스는 전방 고정 블록을 기본 위 대각선으로 옮긴다."
	)

	controller.board.reset()
	controller.active_type = MainTetrominoData.Type.T
	controller.active_rotation = 0
	controller.active_origin = Vector2i(6, 18)
	controller.active_cell_indices = [0, 1, 2, 3]
	var split_success: bool = controller.pan_toss(Vector2i(7, 18), Vector2i(1, -1))
	_expect(
		split_success
			and controller.active_cell_indices.size() == 3
			and controller.board.get_cell(Vector2i(8, 17)) == MainTetrominoData.Type.T
			and controller.try_rotate(1),
		"팬 토스는 활성 미노 한 칸을 고정하고 남은 3칸 도형의 회전을 유지한다."
	)

	controller.board.reset()
	character.set_character_id("clockmaker")
	character.special_cooldown_remaining = 0.0
	stamina_before = character.stamina
	var frozen_origin: Vector2i = controller.active_origin
	var clockmaker_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	controller._physics_process(1.0)
	_expect(
		clockmaker_started
			and is_equal_approx(character.stamina, stamina_before)
			and controller.active_origin == frozen_origin
			and is_equal_approx(controller.fall_freeze_remaining, 2.0),
		"시계공 정지 태엽은 3초 동안 활성 블록의 낙하와 고정 시간을 멈춘다."
	)
	character._cancel_character_skill_effects()
	_expect(
		is_zero_approx(controller.fall_freeze_remaining),
		"시계공의 시간 정지는 캐릭터 변경·피격용 임시 효과 정리에서 해제된다."
	)

	controller.board.reset()
	controller.active_type = MainTetrominoData.Type.O
	controller.active_rotation = 0
	controller.active_origin = Vector2i(6, 19)
	controller.active_cell_indices = [0, 1, 2, 3]
	character.set_character_id("ninja")
	character.special_cooldown_remaining = 0.0
	stamina_before = character.stamina
	var ninja_origin_before: Vector2i = controller.active_origin
	var ninja_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	_expect(
		ninja_started
			and is_equal_approx(character.stamina, stamina_before)
			and controller.active_origin == ninja_origin_before + Vector2i.RIGHT,
		"닌자 표창은 활성 미노에 명중하면 도형 전체를 정확히 1칸 민다."
	)

	controller.board.reset()
	controller.active_type = MainTetrominoData.Type.O
	controller.active_rotation = 0
	controller.active_origin = Vector2i(6, 10)
	controller.active_cell_indices = [0, 1, 2, 3]
	var range_six_origin: Vector2i = controller.active_origin
	var range_six_result: Dictionary = controller.throw_shuriken_at_active_piece(
		Vector2i(1, 10),
		1,
		6
	)
	_expect(
		bool(range_six_result["success"])
			and range_six_result["contact"] == MainGameController.SHURIKEN_CONTACT_ACTIVE
			and int(range_six_result["travel_cells"]) == 6
			and range_six_result["impact_cell"] == Vector2i(7, 10)
			and controller.active_origin == range_six_origin + Vector2i.RIGHT,
		"닌자 표창은 정확히 6칸 거리의 활성 블록 명중 위치를 결과에 기록한다."
	)

	controller.board.reset()
	controller.active_origin = Vector2i(6, 10)
	controller.board.cells[10][4] = MainTetrominoData.Type.Z
	var blocked_origin: Vector2i = controller.active_origin
	var fixed_result: Dictionary = controller.throw_shuriken_at_active_piece(
		Vector2i(1, 10),
		1,
		6
	)
	_expect(
		not bool(fixed_result["success"])
			and fixed_result["contact"] == MainGameController.SHURIKEN_CONTACT_FIXED
			and int(fixed_result["travel_cells"]) == 3
			and fixed_result["impact_cell"] == Vector2i(4, 10)
			and controller.active_origin == blocked_origin
			and controller.board.get_cell(Vector2i(4, 10)) == MainTetrominoData.Type.Z,
		"닌자 표창은 첫 고정 블록의 충돌 위치를 기록하고 그 블록을 이동시키지 않는다."
	)

	controller.board.reset()
	controller.active_origin = Vector2i(6, 10)
	controller.board.cells[10][9] = MainTetrominoData.Type.J
	var destination_blocked: Dictionary = controller.throw_shuriken_at_active_piece(
		Vector2i(1, 10),
		1,
		6
	)
	controller.board.reset()
	var forbidden_blocked: Dictionary = controller.throw_shuriken_at_active_piece(
		Vector2i(1, 10),
		1,
		6,
		[Vector2i(9, 11)]
	)
	_expect(
		not bool(destination_blocked["success"])
			and destination_blocked["contact"] == MainGameController.SHURIKEN_CONTACT_ACTIVE
			and not bool(forbidden_blocked["success"])
			and forbidden_blocked["contact"] == MainGameController.SHURIKEN_CONTACT_ACTIVE
			and controller.active_origin == Vector2i(6, 10),
		"닌자 표창은 목적지의 고정 블록·금지 셀·캐릭터 충돌에 활성 도형을 이동하지 않는다."
	)

	controller.board.reset()
	controller.active_origin = Vector2i(3, 1)
	character.special_cooldown_remaining = 0.0
	var ninja_miss_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	_expect(
		ninja_miss_started
			and not character.last_special_succeeded()
			and character.ninja_special_result()["contact"] == MainGameController.SHURIKEN_CONTACT_NONE
			and int(character.ninja_special_result()["travel_cells"]) == 4
			and is_equal_approx(
				character.special_cooldown_remaining,
				character.current_special_cooldown()
			),
		"닌자 표창은 대상이 없어 실패해도 계산된 특수 쿨다운의 100%를 적용한다."
	)
	character._update_timers(1.0)
	_expect(
		character.ninja_special_result().is_empty(),
		"닌자 표창 판정 결과는 0.8초 특수 애니메이션 종료 후 정리된다."
	)

	character.set_character_id("normal")
	character.rotation_cooldown_remaining = 0.0
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)
	character._attempt_rotation_kick()
	_expect(
		is_equal_approx(character.rotation_cooldown_remaining, character.current_rotation_cooldown()),
		"회전킥은 대상이 없어 실패해도 성공과 동일한 100% 쿨다운을 적용한다."
	)

	character.rotation_cooldown_remaining = 0.0
	character.is_meditating = true
	character._attempt_rotation_kick()
	_expect(
		is_zero_approx(character.rotation_cooldown_remaining),
		"명상처럼 회전킥 입력 자체가 차단된 상태에서는 쿨다운을 시작하지 않는다."
	)
	character.is_meditating = false

	controller.board.reset()
	controller.active_type = MainTetrominoData.Type.T
	controller.active_rotation = 0
	controller.active_origin = Vector2i(4, 19)
	controller.active_cell_indices = [0, 1, 2, 3]
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)
	for y: int in range(16, MainBoardModel.HEIGHT):
		for x: int in range(2, 9):
			var blocking_cell := Vector2i(x, y)
			if blocking_cell not in controller.active_board_cells():
				controller.board.cells[y][x] = MainTetrominoData.Type.J
	character.rotation_cooldown_remaining = 0.0
	character._attempt_rotation_kick()
	_expect(
		is_equal_approx(character.rotation_cooldown_remaining, character.current_rotation_cooldown()),
		"회전 공간과 금지 셀 때문에 실패한 회전킥도 성공과 동일한 100% 쿨다운을 적용한다."
	)

	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._charge_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	character._charge_loop_player.stream = null
	scene.free()
	await process_frame


func _test_fixed_support_grab() -> void:
	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame

	var controller: MainGameController = scene.get_node("GameController")
	var board_physics: MainBoardPhysics = scene.get_node("BoardPhysics")
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	controller.board.reset()
	for x: int in range(MainBoardModel.WIDTH):
		controller.board.cells[18][x] = MainTetrominoData.Type.J
	controller.board.cells[17][5] = MainTetrominoData.Type.J
	board_physics._sync_from_model()
	await physics_frame

	character.position = Vector2(216.0, 721.0)
	character._exit_hang()
	character.facing = 1
	character.stamina = MainCharacterController.MAX_STAMINA
	character._hang_regrab_remaining = 0.0
	character.right_ray.force_raycast_update()
	Input.action_release(&"character_grab")
	Input.action_press(&"character_grab")
	_expect(
		character._has_fixed_support_underfoot(),
		"고정 지지면 위 C-grab 회귀 테스트가 발밑 지지를 확인한다."
	)
	_expect(
		character.right_ray.is_colliding(),
		"고정 지지면 위 C-grab 회귀 테스트가 옆 벽을 감지한다."
	)
	character._try_start_hang()
	_expect(
		not character.is_hanging
			and character._hang_body == null,
		"고정 지지면 위 C-grab은 매달림 상태로 전환되지 않는다."
	)
	Input.action_release(&"character_grab")
	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._charge_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	character._charge_loop_player.stream = null
	scene.free()
	await process_frame


func _test_hang_face_bounds() -> void:
	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame

	var controller: MainGameController = scene.get_node("GameController")
	var board_physics: MainBoardPhysics = scene.get_node("BoardPhysics")
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8)],
		Vector2(216.0, 312.0)
	)
	var grab_y: float = character.global_position.y
	character._try_start_hang()
	_expect(
		character.is_hanging
			and character._hang_body != null
			and character.global_position.y == grab_y,
		"노출된 옆면 가까이의 C-grab은 세로 위치를 바꾸지 않고 성공한다."
	)
	character._exit_hang()
	controller.board.reset()
	board_physics._sync_from_model()
	await physics_frame
	character.position = Vector2(24.0, 312.0)
	character.facing = -1
	character.left_ray.force_raycast_update()
	character._try_start_hang()
	_expect(
		character.is_hanging
			and character._hang_body == board_physics.get_node("Boundaries")
			and character._hang_top_global_y <= character.global_position.y
			and character.global_position.y <= character._hang_bottom_global_y,
		"보드 경계벽은 바닥 collision과 같은 body여도 잡을 수 있다."
	)
	character._exit_hang()

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8)],
		Vector2(195.0, 312.0)
	)
	character._try_start_hang()
	_expect(
		not character.is_hanging,
		"옆면에서 수평으로 먼 위치의 C-grab은 성공하지 않는다."
	)

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8)],
		Vector2(216.0, 350.0)
	)
	character._try_start_hang()
	_expect(
		not character.is_hanging,
		"몸체가 세로로 겹쳐도 옆면 밖의 ray 높이에서는 C-grab하지 않는다."
	)

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8), Vector2i(5, 9)],
		Vector2(216.0, 360.0)
	)
	character._try_start_hang()
	_expect(
		character.is_hanging
			and is_equal_approx(character._hang_top_global_y, 400.0)
			and is_equal_approx(character._hang_bottom_global_y, 496.0),
		"세로로 이어진 노출 옆면은 손 위치 기준 매달림 범위를 공유한다."
	)
	var upper_bound: float = character._hang_top_global_y
	character.global_position.y = upper_bound + 1.0
	var up_event: InputEventKey = InputEventKey.new()
	up_event.keycode = KEY_UP
	up_event.pressed = true
	Input.parse_input_event(up_event)
	character._move_while_hanging()
	var up_release_event: InputEventKey = InputEventKey.new()
	up_release_event.keycode = KEY_UP
	Input.parse_input_event(up_release_event)
	_expect(
		character.global_position.y >= upper_bound,
		"매달린 중 상승 입력은 저장된 상단 범위를 넘지 않는다."
	)
	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8), Vector2i(5, 9)],
		Vector2(216.0, 360.0)
	)
	character._try_start_hang()
	var lower_bound: float = character._hang_bottom_global_y
	character.global_position.y = lower_bound - 1.0
	Input.action_press(&"character_meditate")
	character._move_while_hanging()
	Input.action_release(&"character_meditate")
	_expect(
		character.global_position.y <= lower_bound,
		"매달린 중 하강 입력은 저장된 하단 범위를 넘지 않는다."
	)
	var active_piece: AnimatableBody2D = board_physics.active_body
	var bounds_top: float = 368.0
	var bounds_bottom: float = 464.0
	character._hang_top_global_y = bounds_top
	character._hang_bottom_global_y = bounds_bottom
	character._hang_body = active_piece
	character._hang_last_global_position = active_piece.global_position - Vector2(
		0.0,
		MainLayout.CELL_SIZE
	)
	character._follow_hang_body()
	_expect(
		is_equal_approx(character._hang_top_global_y, bounds_top + MainLayout.CELL_SIZE)
			and is_equal_approx(character._hang_bottom_global_y, bounds_bottom + MainLayout.CELL_SIZE),
		"활성 피스의 수직 이동은 저장된 매달림 범위를 함께 이동시킨다."
	)
	Input.action_release(&"character_meditate")
	character.is_hanging = true
	character._move_while_hanging()
	_expect(
		character.is_hanging,
		"입력 없이 내려오는 활성 피스를 잡고 있으면 ray 갱신 frame에도 매달림을 유지한다."
	)
	character._exit_hang()
	_expect(
		is_zero_approx(character._hang_top_global_y)
			and is_zero_approx(character._hang_bottom_global_y),
		"매달림 종료는 저장된 매달림 범위를 비운다."
	)
	character._hang_top_global_y = 1.0
	character._hang_bottom_global_y = 2.0
	character._reset_character()
	_expect(
		is_zero_approx(character._hang_top_global_y)
			and is_zero_approx(character._hang_bottom_global_y),
		"캐릭터 reset은 저장된 매달림 범위를 비운다."
	)

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8), Vector2i(5, 10)],
		Vector2(216.0, 408.0)
	)
	character._try_start_hang()
	_expect(
		character.is_hanging
			and is_equal_approx(character._hang_top_global_y, 496.0)
			and is_equal_approx(character._hang_bottom_global_y, 544.0),
		"세로 틈이 있는 옆면은 틈을 건너 범위를 확장하지 않는다."
	)
	character._exit_hang()

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8), Vector2i(6, 9)],
		Vector2(216.0, 312.0)
	)
	character._try_start_hang()
	_expect(
		character.is_hanging
			and is_equal_approx(character._hang_top_global_y, 400.0)
			and is_equal_approx(character._hang_bottom_global_y, 448.0),
		"수평으로 꺾인 step은 다른 face를 같은 범위로 합치지 않는다."
	)
	character._exit_hang()

	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._charge_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	character._charge_loop_player.stream = null
	scene.free()
	await process_frame


func _prepare_hang_fixture(
	controller: MainGameController,
	board_physics: MainBoardPhysics,
	character: MainCharacterController,
	cells: Array[Vector2i],
	character_position: Vector2
) -> void:
	character._exit_hang()
	controller.board.reset()
	for cell: Vector2i in cells:
		controller.board.cells[cell.y][cell.x] = MainTetrominoData.Type.J
	controller.state = MainGameController.GameState.PLAYING
	board_physics._sync_from_model()
	await physics_frame
	character.position = character_position
	character.velocity = Vector2.ZERO
	character.facing = 1
	character.stamina = MainCharacterController.MAX_STAMINA
	character._hang_regrab_remaining = 0.0


## 상황: 여러 펀치 사례가 동일한 보드·캐릭터 초기조건을 재사용할 때 호출된다.
## 순서: 빈 보드/활성 T 설정 → piece timer reset → 캐릭터 위치·방향·stamina·private flag 초기화.
## 결과: 이전 사례의 cooldown/예약 판정이 다음 사례에 섞이지 않는 test fixture가 된다.
func _test_character_frame_normalization(
	controller: MainGameController,
	character: MainCharacterController
) -> void:
	var states: Array[String] = [
		ANIMATION_DATA.IDLE,
		ANIMATION_DATA.ATTACK,
		ANIMATION_DATA.HANG,
		ANIMATION_DATA.JUMP,
		ANIMATION_DATA.ROTATION_KICK,
		ANIMATION_DATA.SPECIAL,
	]
	var transforms_are_stable: bool = true
	var collision_is_frame_independent: bool = true
	var transparent_padding_is_excluded: bool = true
	controller.active_type = MainTetrominoData.Type.O
	controller.active_rotation = 0
	controller.active_cell_indices = [0, 1, 2, 3]
	character.position = Vector2(240.0, 912.0)
	character.sprite.flip_h = false
	character.sprite.rotation = 0.0

	for profile_id: String in CHARACTER_DATA.CHARACTER_ORDER:
		character.set_character_id(profile_id)
		character._animation_state = ANIMATION_DATA.IDLE
		character._animation_time = 0.0
		character._apply_animation_frame()
		var expected_scale: Vector2 = character.sprite.scale
		var expected_position: Vector2 = character.sprite.position
		var reference_region: Rect2 = character.sprite.region_rect
		var reference_bounds: Rect2 = character._frame_alpha_bounds(reference_region)
		transparent_padding_is_excluded = (
			transparent_padding_is_excluded
			and reference_bounds.size.x < reference_region.size.x
			and reference_bounds.size.y < reference_region.size.y
			and is_equal_approx(
				reference_bounds.size.y * expected_scale.y,
				ANIMATION_DATA.visible_height_for(ANIMATION_DATA.IDLE, profile_id)
			)
		)
		for state: String in states:
			var frames: Array = ANIMATION_DATA.REGIONS[state]
			for frame_index: int in range(frames.size()):
				character._animation_state = state
				character._animation_time = (
					float(frame_index) * float(ANIMATION_DATA.FRAME_DURATIONS[state])
					+ 0.001
				)
				character._apply_animation_frame()
				if (
					not character.sprite.scale.is_equal_approx(expected_scale)
					or not character.sprite.position.is_equal_approx(expected_position)
					or not is_equal_approx(character.sprite.scale.x, character.sprite.scale.y)
				):
					transforms_are_stable = false
				if (
					not character._crush_mask_overlaps_active_piece(Vector2i(3, 19))
					or character._crush_mask_overlaps_active_piece(Vector2i(7, 1))
				):
					collision_is_frame_independent = false

	_expect(
		transforms_are_stable,
		"모든 캐릭터는 모션이 바뀌어도 동일한 스케일과 기준 위치를 유지한다."
	)
	_expect(
		transparent_padding_is_excluded,
		"모든 캐릭터의 기준 크기는 128px 투명 여백을 제외한 실제 픽셀로 계산한다."
	)
	_expect(
		collision_is_frame_independent,
		"압사 판정은 캐릭터 sprite의 투명 공백과 animation frame에 영향받지 않는다."
	)
	character.set_character_id(ANIMATION_DATA.DEFAULT_CHARACTER_ID)
	character._animation_state = ANIMATION_DATA.IDLE
	character._animation_time = 0.0
	character._apply_animation_frame()


func _test_binding_overlay_alignment(
	scene: MainGameView,
	character: MainCharacterController
) -> void:
	var overlay_is_aligned: bool = true
	var binding_sprite: Sprite2D = scene._binding_sprite
	var visible_bind_region: Rect2 = ANIMATION_DATA.opaque_region_for(
		MainGameView.BIND_TEXTURE,
		MainGameView.BIND_SOURCE_REGION
	)
	for profile_id: String in CHARACTER_DATA.CHARACTER_ORDER:
		character.set_character_id(profile_id)
		scene._sync_binding_overlay_transform()
		var expected_height: float = (
			ANIMATION_DATA.visible_height_for(ANIMATION_DATA.IDLE, profile_id)
			+ MainGameView.BIND_HEIGHT_MARGIN
		)
		overlay_is_aligned = (
			overlay_is_aligned
			and binding_sprite.region_rect == visible_bind_region
			and binding_sprite.position.is_equal_approx(character.sprite.position)
			and is_equal_approx(binding_sprite.scale.x, binding_sprite.scale.y)
			and is_equal_approx(
				binding_sprite.region_rect.size.y * binding_sprite.scale.y,
				expected_height
			)
		)
	_expect(
		overlay_is_aligned,
		"stage-system 덩쿨 속박은 모든 캐릭터의 실제 표시 위치·높이에 균일 비율로 맞는다."
	)
	_expect(
		binding_sprite.get_parent() == character and binding_sprite.get_child_count() == 0,
		"덩쿨 속박의 투명 영역은 시각 overlay일 뿐 캐릭터 판정에 추가되지 않는다."
	)
	character.set_character_id(ANIMATION_DATA.DEFAULT_CHARACTER_ID)


func _prepare_punch(
	controller: MainGameController,
	character: MainCharacterController,
	origin: Vector2i,
	character_position: Vector2
) -> void:
	controller.board.reset()
	controller.state = MainGameController.GameState.PLAYING
	controller.active_type = MainTetrominoData.Type.T
	controller.active_rotation = 0
	controller.active_origin = origin
	controller.active_cell_indices = [0, 1, 2, 3]
	controller._reset_piece_timers()
	character.position = character_position
	character.velocity = Vector2.ZERO
	character.facing = 1
	character.stamina = MainCharacterController.MAX_STAMINA
	character._charging = false
	character.charge_time = 0.0
	character._attack_cooldown_remaining = 0.0
	character._attack_animation_remaining = 0.0
	character._pending_punch_stage = 0
	character._pending_punch_hit_remaining = 0.0
