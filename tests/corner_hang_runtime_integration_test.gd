extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const CHARACTER_IDS: Array[String] = [
	"normal",
	"boxer",
	"shield_guard",
	"firefighter",
	"cleaner",
	"chef",
	"clockmaker",
	"ninja",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: MainGameView = GAME_SCENE.instantiate()
	game.set_meta("stage_number", 1)
	root.add_child(game)
	await process_frame
	await physics_frame
	var character: MainCharacterController = game.character
	var board_physics: MainBoardPhysics = game.get_node("BoardPhysics")
	var failures: Array[String] = []
	var normal_corner_frames: Dictionary = {}
	var normal_vertical_corner_frames: Dictionary = {}
	var normal_horizontal_corner_frames: Dictionary = {}
	var normal_right_visual_offsets: Dictionary = {}
	var normal_right_surface_offsets: Dictionary = {}
	var all_corner_frames: Dictionary = {}
	var all_right_visual_offsets: Dictionary = {}
	var all_right_surface_offsets: Dictionary = {}
	var normal_settle_observed: bool = false
	var vertical_frame_count: int = MainCharacterController.HANG_CORNER_VERTICAL_FRAME_COUNT
	var horizontal_frame_count: int = 8 - vertical_frame_count
	var milestone_thresholds: Array[float] = (
		MainCharacterController.HANG_CORNER_FRAME_PROGRESS_THRESHOLDS
	)
	for frame_index: int in range(milestone_thresholds.size()):
		var interval_end: float = 1.0
		if frame_index + 1 < milestone_thresholds.size():
			interval_end = milestone_thresholds[frame_index + 1]
		var milestone_sample: float = (
			milestone_thresholds[frame_index] + interval_end
		) * 0.5
		if (
			character._corner_climb_animation_frame_index(milestone_sample, 8)
			!= frame_index
		):
			failures.append("normal: corner milestone mismatch at %d" % frame_index)

	Input.action_press(&"character_grab")
	for character_id: String in CHARACTER_IDS:
		await _prepare_boundary_diagonal_fixture(game, board_physics, character, character_id)
		# Refresh the synthetic key for every fixture. Input.parse_input_event can be
		# observed one process iteration late on the first headless fixture.
		_set_up_pressed(false)
		await process_frame
		_set_up_pressed(true)
		await process_frame
		character._try_start_hang()
		if not character.is_hanging:
			failures.append("%s: boundary grab failed" % character_id)
			continue
		var start_y: float = character.global_position.y
		var anchor_x: float = character.global_position.x
		var max_x_error: float = 0.0
		for frame_index: int in range(30):
			character._handle_hanging(1.0 / 60.0)
			max_x_error = maxf(
				max_x_error,
				absf(character.global_position.x - anchor_x)
			)
		if (
			not character.is_hanging
			or character.global_position.y >= start_y - 20.0
			or max_x_error > 0.01
		):
			failures.append(
				"%s: diagonal boundary climb stalled/jittered start=%s end=%s x_error=%s"
				% [character_id, start_y, character.global_position.y, max_x_error]
			)

	await _prepare_boundary_diagonal_fixture(game, board_physics, character, "normal")
	character._try_start_hang()
	if not character.is_hanging:
		failures.append("normal: boundary top release fixture did not grab")
	else:
		character.global_position.y = character._hang_top_global_y + 0.5
		character._handle_hanging(1.0 / 60.0)
		if character.is_hanging or character.velocity.x >= 0.0:
			failures.append("normal: boundary top did not release inward")

	for character_id: String in CHARACTER_IDS:
		all_corner_frames[character_id] = {}
		all_right_visual_offsets[character_id] = {}
		all_right_surface_offsets[character_id] = {}
		await _prepare_locked_corner_fixture(game, board_physics, character, character_id)
		_set_up_pressed(false)
		await process_frame
		_set_up_pressed(true)
		await process_frame
		character._try_start_hang()
		if not character.is_hanging:
			failures.append("%s: locked block grab failed" % character_id)
			continue
		if character_id == "normal":
			character.set_passive_levels([0, 0, 0, 3, 0, 0])
		for approach_frame: int in range(120):
			character._handle_hanging(1.0 / 60.0)
			if character._hang_corner_climb_active:
				break
		if not character._hang_corner_climb_active:
			failures.append("%s: natural climb never entered the top transition" % character_id)
			continue
		if character_id == "normal":
			var minimum_pose_duration: float = (
				float(MainCharacterAnimationData.frame_count_for(
					MainCharacterAnimationData.CORNER_CLIMB,
					character_id
				))
				* float(MainCharacterAnimationData.FRAME_DURATIONS[
					MainCharacterAnimationData.CORNER_CLIMB
				])
			)
			if character._hang_corner_climb_duration < minimum_pose_duration:
				failures.append("normal: corner climb rushes its eight poses")
			var stamina_before_corner_frame: float = character.stamina
			character._handle_hanging(1.0 / 60.0)
			var expected_corner_drain: float = (
				MainCharacterController.HANG_STAMINA_DRAIN
				* MainCharacterData.stamina_drain_multiplier(
					character_id,
					character.passive_levels
				)
				/ 60.0
			)
			if not is_equal_approx(
				stamina_before_corner_frame - character.stamina,
				expected_corner_drain
			):
				failures.append(
					"normal: corner climb ignored stamina passive"
				)
			character.set_passive_levels([0, 0, 0, 0, 0, 0])
		for frame_index: int in range(120):
			if not character.is_hanging:
				break
			character._handle_hanging(1.0 / 60.0)
			character._advance_character_animation(1.0 / 60.0)
			if character._hang_corner_climb_active:
				if character._animation_state != MainCharacterAnimationData.CORNER_CLIMB:
					failures.append(
						"%s: corner climb did not select its dedicated animation"
						% character_id
					)
					break
				var corner_frame: int = int(character.sprite.region_rect.position.x / 128.0)
				var character_corner_frames: Dictionary = all_corner_frames[character_id]
				var character_visual_offsets: Dictionary = all_right_visual_offsets[character_id]
				var character_surface_offsets: Dictionary = all_right_surface_offsets[character_id]
				character_corner_frames[corner_frame] = true
				character_visual_offsets[corner_frame] = character.sprite.position.x
				character_surface_offsets[corner_frame] = (
					character.sprite.position.y
					- MainCharacterAnimationData.fixed_offset_for(character_id).y
				)
				if int(character.sprite.region_rect.position.y) != 768:
					failures.append(
						"%s: corner climb reused a non-climb atlas row" % character_id
					)
					break
				if character_id == "normal":
					normal_corner_frames[corner_frame] = true
					normal_right_visual_offsets[corner_frame] = character.sprite.position.x
					normal_right_surface_offsets[corner_frame] = (
						character.sprite.position.y
						- MainCharacterAnimationData.fixed_offset_for("normal").y
					)
					if (
						character._hang_corner_climb_progress
						< MainCharacterController.HANG_CORNER_VERTICAL_PATH_RATIO
					):
						normal_vertical_corner_frames[corner_frame] = true
						if corner_frame >= vertical_frame_count:
							failures.append("normal: top-entry pose appeared during vertical pull")
							break
					else:
						normal_horizontal_corner_frames[corner_frame] = true
						if corner_frame < vertical_frame_count:
							failures.append("normal: vertical-pull pose remained during top entry")
							break
					if (
						character._hang_corner_climb_progress
						>= MainCharacterController.HANG_CORNER_HORIZONTAL_MOTION_END_RATIO
					):
						normal_settle_observed = true
						if character.global_position.distance_to(
							character._hang_corner_climb_target_global
						) > 0.01:
							failures.append("normal: final standing pose still slides sideways")
							break
		var foot_y: float = (
			character.position.y
			+ MainCharacterController.CHARACTER_COLLIDER_OFFSET_Y
			+ MainCharacterController.CHARACTER_COLLIDER_HEIGHT * 0.5
		)
		var expected_top_y: float = float(10 - MainBoardModel.HIDDEN_ROWS) * MainLayout.CELL_SIZE
		if character.is_hanging or not is_equal_approx(foot_y, expected_top_y):
			failures.append(
				"%s: did not finish corner climb foot=%s expected=%s"
				% [character_id, foot_y, expected_top_y]
			)
		if not character.is_on_floor():
			failures.append(
				"%s: corner climb finished before refreshing floor contact"
				% character_id
			)
		if character._animation_state != MainCharacterAnimationData.IDLE:
			failures.append(
				"%s: corner climb inserted a transient %s pose before idle"
				% [character_id, character._animation_state]
			)
		var completed_character_frames: Dictionary = all_corner_frames[character_id]
		if completed_character_frames.size() != 8:
			failures.append(
				"%s: dedicated corner row did not advance through all 8 frames: %s"
				% [character_id, completed_character_frames.keys()]
			)
		var completed_visual_offsets: Dictionary = all_right_visual_offsets[character_id]
		for ledge_frame: int in [2, 3, 4]:
			if (
				not completed_visual_offsets.has(ledge_frame)
				or float(completed_visual_offsets[ledge_frame]) <= 0.0
			):
				failures.append(
					"%s: right-facing pose %d did not lead toward the ledge"
					% [character_id, ledge_frame]
				)
	if normal_corner_frames.size() != 8:
		failures.append(
			"normal: corner climb did not advance through all position poses: %s"
			% [normal_corner_frames.keys()]
		)
	if normal_vertical_corner_frames.size() != vertical_frame_count:
		failures.append(
			"normal: vertical pull did not stay within its poses: %s"
			% [normal_vertical_corner_frames.keys()]
		)
	if normal_horizontal_corner_frames.size() != horizontal_frame_count:
		failures.append(
			"normal: top entry did not use its poses: %s"
			% [normal_horizontal_corner_frames.keys()]
		)
	if not normal_settle_observed:
		failures.append("normal: corner climb never reached its settled top pose")
	for ledge_frame: int in [2, 3, 4]:
		if (
			not normal_right_visual_offsets.has(ledge_frame)
			or float(normal_right_visual_offsets[ledge_frame]) <= 0.0
		):
			failures.append(
				"normal: right-facing pose %d did not lead toward the ledge" % ledge_frame
			)
	for surface_frame: int in [2, 3]:
		if (
			not normal_right_surface_offsets.has(surface_frame)
			or float(normal_right_surface_offsets[surface_frame]) <= 1.0
		):
			failures.append(
				"normal: right-facing pose %d did not close its surface gap" % surface_frame
			)
	if not character.sprite.region_filter_clip_enabled:
		failures.append("character atlas region can sample pixels from an adjacent frame")

	# 낙하 중인 피스도 상단이 비어 있으면 같은 모서리 오르기로 연결되어야 한다.
	# 피스가 한 칸 내려갈 때 물리 위치와 최종 착지점이 함께 내려가는지도 확인한다.
	await _prepare_active_corner_fixture(game, board_physics, character)
	_set_up_pressed(false)
	await process_frame
	_set_up_pressed(true)
	await process_frame
	character._try_start_hang()
	if not character.is_hanging:
		print(
			"ACTIVE_GRAB_DEBUG position=", character.position,
			" ray=", character.right_ray.is_colliding(),
			" collider=", character.right_ray.get_collider(),
			" active_position=", board_physics.active_body.position,
			" active_origin=", game.controller.active_origin,
			" grab=", Input.is_action_pressed(&"character_grab"),
			" support=", character._has_fixed_support_underfoot()
		)
		failures.append("normal: active piece grab failed")
	else:
		for approach_frame: int in range(120):
			character._handle_hanging(1.0 / 60.0)
			if character._hang_corner_climb_active:
				break
		if not character._hang_corner_climb_active:
			failures.append("normal: active piece never entered the top transition")
		else:
			var active_target_before_drop: Vector2 = character._hang_corner_climb_target_global
			game.controller.active_origin += Vector2i.DOWN
			board_physics.active_body.position += Vector2(0.0, MainLayout.CELL_SIZE)
			character._handle_hanging(1.0 / 60.0)
			if not character._hang_corner_climb_active:
				failures.append("normal: active piece descent cancelled the top transition")
			elif not character._hang_corner_climb_target_global.is_equal_approx(
				active_target_before_drop + Vector2(0.0, MainLayout.CELL_SIZE)
			):
				failures.append("normal: active piece descent left the mantle target behind")
			for local_cell: Vector2i in game.controller.active_local_cells():
				var active_cell: Vector2i = game.controller.active_origin + local_cell
				game.controller.board.cells[active_cell.y][active_cell.x] = (
					MainTetrominoData.Type.O
				)
			var target_before_lock: Vector2 = character._hang_corner_climb_target_global
			game.controller.active_origin = Vector2i(3, 0)
			character._handle_hanging(1.0 / 60.0)
			if (
				not character._hang_corner_climb_active
				or not is_instance_valid(character._hang_body)
				or character._hang_body.name != &"LockedBlocks"
				or not character._hang_corner_climb_target_global.is_equal_approx(
					target_before_lock
				)
			):
				failures.append("normal: locking active piece did not preserve the mantle")
			var expected_active_target: Vector2 = character._hang_corner_climb_target_global
			for frame_index: int in range(120):
				if not character.is_hanging:
					break
				character._handle_hanging(1.0 / 60.0)
			var active_completed_global: Vector2 = character.global_position
			if (
				character.is_hanging
				or not active_completed_global.is_equal_approx(expected_active_target)
			):
				failures.append(
					"normal: active piece corner climb did not finish on its moving target"
				)

	# 줄 삭제로 고정 발판이 한 칸 내려가면 진행 중인 오르기 경로도 함께 내려간다.
	await _prepare_locked_corner_fixture(game, board_physics, character, "normal")
	character._try_start_hang()
	if character.is_hanging:
		for approach_frame: int in range(120):
			character._handle_hanging(1.0 / 60.0)
			if character._hang_corner_climb_active:
				break
	if not character._hang_corner_climb_active:
		failures.append("normal: locked support shift fixture did not start mantle")
	else:
		var locked_target_before_shift: Vector2 = character._hang_corner_climb_target_global
		game.controller.board.cells[10][5] = MainBoardModel.EMPTY
		game.controller.board.cells[11][5] = MainTetrominoData.Type.J
		character._handle_hanging(1.0 / 60.0)
		if (
			not character._hang_corner_climb_active
			or not character._hang_corner_climb_target_global.is_equal_approx(
				locked_target_before_shift + Vector2(0.0, MainLayout.CELL_SIZE)
			)
		):
			failures.append("normal: collapsed locked support left the mantle target behind")

	# 시작 후 착지 공간이 막히면 블록 안으로 들어가지 않고 즉시 매달림을 끝낸다.
	await _prepare_locked_corner_fixture(game, board_physics, character, "normal")
	character._try_start_hang()
	if character.is_hanging:
		for approach_frame: int in range(120):
			character._handle_hanging(1.0 / 60.0)
			if character._hang_corner_climb_active:
				break
	if not character._hang_corner_climb_active:
		failures.append("normal: blocked landing fixture did not start mantle")
	else:
		game.controller.board.cells[9][5] = MainTetrominoData.Type.T
		character._handle_hanging(1.0 / 60.0)
		if character.is_hanging:
			failures.append("normal: newly blocked landing kept the mantle active")

	# 반대쪽 면에서도 같은 단일 Sprite2D가 정확히 반전되고 같은 8프레임을 쓰는지
	# 별도로 검증한다. 방향별로 visual node를 나누면 경계에서 한쪽이 사라지는 회귀가 생긴다.
	await _prepare_locked_corner_fixture(game, board_physics, character, "normal", -1)
	_set_up_pressed(false)
	await process_frame
	_set_up_pressed(true)
	await process_frame
	character._try_start_hang()
	if not character.is_hanging:
		failures.append("normal: left-facing locked block grab failed")
	else:
		for approach_frame: int in range(120):
			character._handle_hanging(1.0 / 60.0)
			if character._hang_corner_climb_active:
				break
		if not character._hang_corner_climb_active:
			failures.append("normal: left natural climb never entered the top transition")
		var left_corner_frames: Dictionary = {}
		var left_visual_offsets: Dictionary = {}
		var left_surface_offsets: Dictionary = {}
		var left_flip_changed: bool = false
		var flip_disturbance_injected: bool = false
		for frame_index: int in range(120):
			if not character.is_hanging:
				break
			character._handle_hanging(1.0 / 60.0)
			if character._hang_corner_climb_active and not flip_disturbance_injected:
				# 외부에서 잘못된 flip이 들어와도 이번 animation 적용에서 즉시 복구해야 한다.
				character.sprite.flip_h = false
				flip_disturbance_injected = true
			character._advance_character_animation(1.0 / 60.0)
			if character._hang_corner_climb_active:
				var left_corner_frame: int = int(
					character.sprite.region_rect.position.x / 128.0
				)
				left_corner_frames[left_corner_frame] = true
				left_visual_offsets[left_corner_frame] = character.sprite.position.x
				left_surface_offsets[left_corner_frame] = (
					character.sprite.position.y
					- MainCharacterAnimationData.fixed_offset_for("normal").y
				)
				left_flip_changed = left_flip_changed or not character.sprite.flip_h
		if left_corner_frames.size() != 8:
			failures.append(
				"normal: left-facing corner climb lost atlas frames: %s"
				% [left_corner_frames.keys()]
			)
		if left_flip_changed:
			failures.append("normal: left-facing corner climb changed sprite side mid-motion")
		for ledge_frame: int in [2, 3, 4]:
			if (
				not left_visual_offsets.has(ledge_frame)
				or float(left_visual_offsets[ledge_frame]) >= 0.0
			):
				failures.append(
					"normal: left-facing pose %d did not lead toward the ledge" % ledge_frame
				)
		for surface_frame: int in [2, 3]:
			if (
				not left_surface_offsets.has(surface_frame)
				or float(left_surface_offsets[surface_frame]) <= 1.0
			):
				failures.append(
					"normal: left-facing pose %d did not close its surface gap" % surface_frame
				)
		if character.sprite != character.get_node_or_null("Sprite"):
			failures.append("normal: corner climb unexpectedly replaced its single character sprite")

	_set_up_pressed(false)
	Input.action_release(&"character_grab")
	print("CORNER_HANG_RUNTIME_RESULT failures=", failures)
	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	game.free()
	# 빠른 캐릭터 교체로 예약된 wall-climb playback이 Dummy audio driver에서
	# 해제될 시간을 주어 테스트 종료 시 오디오 리소스가 남지 않게 한다.
	for cleanup_frame: int in range(6):
		await process_frame
		await physics_frame
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _prepare_boundary_diagonal_fixture(
	game: MainGameView,
	board_physics: MainBoardPhysics,
	character: MainCharacterController,
	character_id: String
) -> void:
	character._exit_hang()
	game.controller.board.reset()
	game.controller.board.cells[14][8] = MainTetrominoData.Type.O
	game.controller.board.cells[15][8] = MainTetrominoData.Type.O
	game.controller.state = MainGameController.GameState.PLAYING
	board_physics._sync_from_model()
	# AnimatableBody2D의 sync_to_physics transform과 RayCast가 같은 tick에
	# 갱신되는 순서는 실행 환경마다 달라질 수 있어 두 physics tick을 기다린다.
	await physics_frame
	await physics_frame
	character.set_character_id(character_id)
	character.position = Vector2(MainCharacterController.BOARD_MAX_X, 584.0)
	character.velocity = Vector2.ZERO
	character.facing = 1
	character.stamina = MainCharacterController.MAX_STAMINA
	character._hang_regrab_remaining = 0.0
	character.right_ray.force_raycast_update()


func _prepare_locked_corner_fixture(
	game: MainGameView,
	board_physics: MainBoardPhysics,
	character: MainCharacterController,
	character_id: String,
	direction: int = 1
) -> void:
	character._exit_hang()
	game.controller.board.reset()
	game.controller.active_type = MainTetrominoData.Type.I
	game.controller.active_rotation = 0
	game.controller.active_origin = Vector2i(3, 0)
	var block_x: int = 5 if direction > 0 else 4
	game.controller.board.cells[10][block_x] = MainTetrominoData.Type.J
	game.controller.state = MainGameController.GameState.PLAYING
	board_physics._sync_from_model()
	await physics_frame
	character.set_character_id(character_id)
	character.position = Vector2(216.0 if direction > 0 else 264.0, 440.0)
	character.velocity = Vector2.ZERO
	character._update_facing(float(direction))
	character.stamina = MainCharacterController.MAX_STAMINA
	character._hang_regrab_remaining = 0.0
	var hang_ray: RayCast2D = character.right_ray if direction > 0 else character.left_ray
	hang_ray.force_raycast_update()


func _prepare_active_corner_fixture(
	game: MainGameView,
	board_physics: MainBoardPhysics,
	character: MainCharacterController
) -> void:
	character._exit_hang()
	game.controller.board.reset()
	game.controller.active_type = MainTetrominoData.Type.O
	game.controller.active_rotation = 0
	game.controller.active_origin = Vector2i(4, 8)
	game.controller.active_cell_indices = [0, 1, 2, 3]
	game.controller._fall_accumulator = 0.0
	game.controller._lock_accumulator = 0.0
	game.controller._lock_resets = 0
	game.controller.fall_freeze_remaining = 0.0
	game.controller.state = MainGameController.GameState.PLAYING
	board_physics._sync_from_model()
	# ActivePiece is an AnimatableBody2D with sync_to_physics, so wait for both
	# its transform commit and the following query update before forcing the ray.
	await physics_frame
	await physics_frame
	character.set_character_id("normal")
	character.position = Vector2(216.0, 400.0)
	character.velocity = Vector2.ZERO
	character._update_facing(1.0)
	character.stamina = MainCharacterController.MAX_STAMINA
	character._hang_regrab_remaining = 0.0
	character.right_ray.force_raycast_update()


func _set_up_pressed(pressed: bool) -> void:
	# 이 테스트는 등반 상태 전이를 검증한다. OS key event의 frame 전달 시점에
	# 의존하지 않도록 이미 별도 테스트가 보장하는 action을 직접 구동한다.
	if pressed:
		Input.action_press(&"character_climb_up")
	else:
		Input.action_release(&"character_climb_up")
