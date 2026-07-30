extends Node2D

const BOARD_COLUMNS := 10
const BOARD_ROWS := 20
const CELL_SIZE := 28
const BOARD_ORIGIN := Vector2(96, 72)
const FALL_INTERVAL := 0.7
const BLOCK_COLLISION_HORIZONTAL_INSET := 1.0
const BLOCK_COLLISION_VERTICAL_INSET := 2.0

const PLAYER_SIZE := Vector2(CELL_SIZE, CELL_SIZE * 2)
const PLAYER_SPEED := 150.0
const PLAYER_GRAVITY := 1000.0
const JUMP_VELOCITY := -350.0
const WALL_JUMP_SPEED := 185.0
const CLIMB_SPEED := 78.0
const GRAB_DURATION := 3.0
const ATTACK_DURATION := 0.4
const ATTACK_COOLDOWN := 0.48

const BACKGROUND_COLOR := Color("f7f8fb")
const EMPTY_CELL := Color("dce3ed")
const GRID_LINE := Color("8390a3")
const HUD_PRIMARY := Color("152033")
const HUD_TEXT := Color("344158")
const BLOCK_SPRITES := preload("res://assets/sprites/block_sprites.png")
const PLAYER_SPRITES := preload("res://assets/sprites/player_sprites.png")
const PLAYER_ANIMATIONS := preload("res://assets/sprites/player_animations.png")
const PLAYER_HANG_ANIMATIONS := preload("res://assets/sprites/player_hang_animations.png")
const PLAYER_ATTACK_ANIMATIONS := preload("res://assets/sprites/player_attack_animations.png")
const PLAYER_JUMP_ANIMATIONS := preload("res://assets/sprites/player_jump_animations.png")
const BLOCK_SPRITE_REGIONS := {
	"I": Rect2(80, 255, 210, 215),
	"O": Rect2(360, 255, 210, 215),
	"T": Rect2(640, 255, 210, 215),
	"S": Rect2(915, 255, 210, 215),
	"Z": Rect2(1190, 255, 210, 215),
	"J": Rect2(1470, 255, 210, 215),
	"L": Rect2(1745, 255, 210, 215),
}
const PLAYER_SPRITE_REGIONS := {
	"idle": Rect2(170, 180, 240, 620),
	"pull_legacy": Rect2(525, 205, 440, 590),
	"attack": Rect2(1000, 225, 485, 570),
}
const PLAYER_ANIMATION_REGIONS := {
	"idle": [Rect2(45, 55, 165, 270), Rect2(255, 55, 165, 270), Rect2(455, 55, 165, 270), Rect2(655, 55, 165, 270)],
	"hang": [Rect2(30, 80, 365, 700), Rect2(470, 80, 365, 700), Rect2(910, 80, 365, 700), Rect2(1350, 80, 365, 700)],
	"pull": [Rect2(25, 770, 200, 285), Rect2(235, 770, 200, 285), Rect2(435, 770, 200, 285), Rect2(635, 770, 200, 285)],
	"attack": [Rect2(30, 180, 380, 550), Rect2(465, 180, 380, 550), Rect2(900, 180, 380, 550), Rect2(1335, 180, 380, 550)],
	"jump": [Rect2(20, 260, 240, 390), Rect2(270, 310, 250, 340), Rect2(530, 370, 225, 280), Rect2(780, 180, 220, 420), Rect2(1015, 140, 220, 400), Rect2(1260, 115, 200, 360), Rect2(1490, 190, 230, 460), Rect2(1750, 320, 220, 330)],
}
const PLAYER_ANIMATION_FRAME_DURATIONS := {
	"idle": 0.18,
	"hang": 0.16,
	"pull": 0.16,
	"attack": ATTACK_DURATION / 4.0,
	"jump": 0.0875,
}
const TETROMINOES := {
	"I": {"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
	"O": {"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	"T": {"cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
	"S": {"cells": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	"Z": {"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]},
	"J": {"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
	"L": {"cells": [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
}

var board: Array = []
var bag: Array[String] = []
var active_piece_name := ""
var next_piece_names: Array[String] = []
var active_position := Vector2i.ZERO
var score := 0
var cleared_lines := 0
var drop_timer := 0.0
var game_over := false

var player_position := Vector2.ZERO
var player_velocity := Vector2.ZERO
var player_facing := 1
var is_grabbing := false
var grab_side := 0
var grab_timer := 0.0
var grab_exhausted := false
var grab_requires_release := false
var was_player_grounded := false
var attack_timer := 0.0
var attack_cooldown := 0.0
var player_animation_state := "idle"
var player_animation_time := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	randomize()
	reset_game()


func _process(delta: float) -> void:
	if game_over:
		return

	_update_player(delta)
	_update_player_animation(delta)

	drop_timer += delta
	if drop_timer >= FALL_INTERVAL:
		drop_timer -= FALL_INTERVAL
		var next_position := active_position + Vector2i.DOWN
		var follows_active_piece := is_grabbing and _is_grabbing_active_piece()
		if _can_place(active_piece_name, next_position):
			if _active_overlaps_player_at(next_position):
				if is_grabbing:
					_release_grab_from_falling_block()
				elif _is_player_supported_by_board():
					_trigger_game_over()
			else:
				active_position = next_position
				if follows_active_piece:
					_move_with_active_piece()
		else:
			_lock_active_piece()

	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_R:
		reset_game()
		return
	if game_over:
		return
	if key_event.keycode == KEY_Z:
		_try_jump()
	elif key_event.keycode == KEY_X:
		_start_attack()


func reset_game() -> void:
	board.clear()
	for _row in BOARD_ROWS:
		var empty_row: Array = []
		empty_row.resize(BOARD_COLUMNS)
		empty_row.fill(null)
		board.append(empty_row)

	bag.clear()
	next_piece_names.clear()
	score = 0
	cleared_lines = 0
	drop_timer = 0.0
	game_over = false
	next_piece_names.append(_take_piece_name())
	next_piece_names.append(_take_piece_name())
	_spawn_piece()
	player_position = Vector2(CELL_SIZE * 4, CELL_SIZE * (BOARD_ROWS - 2))
	player_velocity = Vector2.ZERO
	player_facing = 1
	is_grabbing = false
	grab_timer = 0.0
	grab_exhausted = false
	grab_requires_release = false
	was_player_grounded = false
	attack_timer = 0.0
	attack_cooldown = 0.0
	player_animation_state = "idle"
	player_animation_time = 0.0
	queue_redraw()


# Future player attacks call this with -1 (left) or 1 (right).
func try_push_active(direction: int) -> bool:
	if game_over or direction == 0:
		return false

	var offset := Vector2i(signi(direction), 0)
	if not _can_place(active_piece_name, active_position + offset):
		return false

	active_position += offset
	queue_redraw()
	return true


func _update_player(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if not Input.is_key_pressed(KEY_C):
		grab_requires_release = false

	if is_grabbing:
		_update_grab(delta)
		_refresh_grab_stamina_on_landing()
		return

	var movement := 0.0
	if Input.is_key_pressed(KEY_LEFT):
		movement -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		movement += 1.0
	if movement != 0.0:
		player_facing = int(movement)
	player_velocity.x = move_toward(player_velocity.x, movement * PLAYER_SPEED, PLAYER_SPEED * 12.0 * delta)
	player_velocity.y += PLAYER_GRAVITY * delta
	_move_player(Vector2(player_velocity.x * delta, 0.0))
	_move_player(Vector2(0.0, player_velocity.y * delta))
	_refresh_grab_stamina_on_landing()

	if Input.is_key_pressed(KEY_C) and not grab_exhausted and not grab_requires_release:
		var side := _find_grab_side()
		if side != 0:
			is_grabbing = true
			grab_side = side
			player_velocity = Vector2.ZERO


func _update_grab(delta: float) -> void:
	if not Input.is_key_pressed(KEY_C) or grab_timer >= GRAB_DURATION:
		_release_grab()
		return

	grab_timer += delta
	if grab_timer >= GRAB_DURATION:
		grab_exhausted = true
		_release_grab()
		return

	var climb_direction := 0.0
	if Input.is_key_pressed(KEY_UP):
		climb_direction -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		climb_direction += 1.0
	_move_player(Vector2(0.0, climb_direction * CLIMB_SPEED * delta))

	var side := _find_grab_side()
	if side == 0:
		_release_grab()
	else:
		grab_side = side


func _try_jump() -> void:
	if is_grabbing:
		_start_jump_animation()
		player_velocity = Vector2(-grab_side * WALL_JUMP_SPEED, JUMP_VELOCITY)
		is_grabbing = false
		grab_requires_release = true
		return
	if _is_player_grounded():
		_start_jump_animation()
		player_velocity.y = JUMP_VELOCITY


func _start_attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_timer = ATTACK_DURATION
	attack_cooldown = ATTACK_COOLDOWN
	if _punch_hits_active_piece():
		try_push_active(player_facing)


func _release_grab() -> void:
	is_grabbing = false
	player_velocity.y = 0.0


func _release_grab_from_falling_block() -> void:
	_release_grab()
	grab_requires_release = true
	player_velocity.y = PLAYER_GRAVITY * 0.1


func _move_player(motion: Vector2) -> void:
	if motion.x != 0.0:
		_move_player_axis(motion.x, true)
	if motion.y != 0.0:
		_move_player_axis(motion.y, false)


func _move_player_axis(amount: float, horizontal: bool) -> void:
	var remaining := absf(amount)
	var direction := signf(amount)
	while remaining > 0.0:
		var step := minf(1.0, remaining) * direction
		var candidate := player_position + (Vector2(step, 0.0) if horizontal else Vector2(0.0, step))
		if _player_collides(candidate):
			if horizontal:
				player_velocity.x = 0.0
			else:
				player_velocity.y = 0.0
			return
		player_position = candidate
		remaining -= absf(step)


func _is_player_grounded() -> bool:
	return _player_collides(player_position + Vector2(0.0, 1.0))


func _is_player_supported_by_board() -> bool:
	var foot_rect := Rect2(player_position + Vector2(0.0, 1.0), PLAYER_SIZE)
	if foot_rect.end.y > BOARD_ROWS * CELL_SIZE:
		return true
	for row in BOARD_ROWS:
		for column in BOARD_COLUMNS:
			if board[row][column] != null and _rect_overlaps_cell(foot_rect, Vector2i(column, row)):
				return true
	return false


func _refresh_grab_stamina_on_landing() -> void:
	var is_grounded := _is_player_grounded()
	if is_grounded and not was_player_grounded:
		grab_timer = 0.0
		grab_exhausted = false
	was_player_grounded = is_grounded


func _player_collides(position: Vector2) -> bool:
	return _rect_hits_solid(Rect2(position, PLAYER_SIZE))


func _rect_hits_solid(rect: Rect2) -> bool:
	var board_width := BOARD_COLUMNS * CELL_SIZE
	var board_height := BOARD_ROWS * CELL_SIZE
	if rect.position.x < 0.0 or rect.end.x > board_width or rect.position.y < 0.0 or rect.end.y > board_height:
		return true

	for row in BOARD_ROWS:
		for column in BOARD_COLUMNS:
			if board[row][column] != null and _rect_overlaps_cell(rect, Vector2i(column, row)):
				return true
	if not active_piece_name.is_empty():
		for cell: Vector2i in TETROMINOES[active_piece_name]["cells"]:
			if _rect_overlaps_cell(rect, active_position + cell):
				return true
	return false


func _rect_overlaps_cell(rect: Rect2, board_cell: Vector2i) -> bool:
	var collision_inset := Vector2(BLOCK_COLLISION_HORIZONTAL_INSET, BLOCK_COLLISION_VERTICAL_INSET)
	var collision_size := Vector2(CELL_SIZE - BLOCK_COLLISION_HORIZONTAL_INSET * 2.0, CELL_SIZE - BLOCK_COLLISION_VERTICAL_INSET * 2.0)
	var cell_rect := Rect2(Vector2(board_cell) * CELL_SIZE + collision_inset, collision_size)
	return rect.intersects(cell_rect)


func _find_grab_side() -> int:
	var player_rect := Rect2(player_position, PLAYER_SIZE)
	var probe_distance := BLOCK_COLLISION_HORIZONTAL_INSET + 1.0
	var left_probe := Rect2(player_rect.position + Vector2(-probe_distance, 0.0), player_rect.size)
	if _rect_hits_solid(left_probe):
		return -1
	var right_probe := Rect2(player_rect.position + Vector2(probe_distance, 0.0), player_rect.size)
	if _rect_hits_solid(right_probe):
		return 1
	return 0


func _punch_hits_active_piece() -> bool:
	var fist_x := player_position.x + (PLAYER_SIZE.x if player_facing > 0 else -CELL_SIZE * 0.45)
	var fist_rect := Rect2(Vector2(fist_x, player_position.y + CELL_SIZE * 0.8), Vector2(CELL_SIZE * 0.45, CELL_SIZE * 0.45))
	for cell: Vector2i in TETROMINOES[active_piece_name]["cells"]:
		if _rect_overlaps_cell(fist_rect, active_position + cell):
			return true
	return false


func _active_overlaps_player() -> bool:
	return _active_overlaps_player_at(active_position)


func _active_overlaps_player_at(piece_position: Vector2i) -> bool:
	var player_rect := Rect2(player_position, PLAYER_SIZE)
	for cell: Vector2i in TETROMINOES[active_piece_name]["cells"]:
		if _rect_overlaps_cell(player_rect, piece_position + cell):
			return true
	return false


func _is_grabbing_active_piece() -> bool:
	if grab_side == 0:
		return false
	var grab_probe := Rect2(player_position + Vector2(grab_side * (BLOCK_COLLISION_HORIZONTAL_INSET + 1.0), 0.0), PLAYER_SIZE)
	for cell: Vector2i in TETROMINOES[active_piece_name]["cells"]:
		if _rect_overlaps_cell(grab_probe, active_position + cell):
			return true
	return false


func _move_with_active_piece() -> void:
	var candidate := player_position + Vector2(0.0, CELL_SIZE)
	if _player_collides(candidate):
		_release_grab()
		return
	player_position = candidate
	player_velocity = Vector2.ZERO


func _start_jump_animation() -> void:
	player_animation_state = "jump"
	player_animation_time = 0.0


func _update_player_animation(delta: float) -> void:
	var next_state := _get_player_animation_state()
	if next_state != player_animation_state:
		player_animation_state = next_state
		player_animation_time = 0.0
	else:
		player_animation_time += delta


func _get_player_animation_state() -> String:
	if attack_timer > 0.0:
		return "attack"
	if is_grabbing:
		return "hang"
	if not _is_player_grounded():
		return "jump"
	return "idle"


func _player_animation_region(state: String) -> Rect2:
	var frames: Array = PLAYER_ANIMATION_REGIONS[state]
	var frame_duration: float = PLAYER_ANIMATION_FRAME_DURATIONS[state]
	var frame_index := int(player_animation_time / frame_duration)
	if state == "attack" or state == "jump":
		frame_index = mini(frame_index, frames.size() - 1)
	else:
		frame_index %= frames.size()
	return frames[frame_index]


func _player_animation_texture(state: String) -> Texture2D:
	if state == "hang":
		return PLAYER_HANG_ANIMATIONS
	if state == "attack":
		return PLAYER_ATTACK_ANIMATIONS
	if state == "jump":
		return PLAYER_JUMP_ANIMATIONS
	return PLAYER_ANIMATIONS


func _trigger_game_over() -> void:
	game_over = true
	is_grabbing = false
	player_velocity = Vector2.ZERO


func _spawn_piece() -> void:
	active_piece_name = next_piece_names.pop_front()
	next_piece_names.append(_take_piece_name())
	var leftmost_cell := 0
	var rightmost_cell := 0
	for cell: Vector2i in TETROMINOES[active_piece_name]["cells"]:
		leftmost_cell = mini(leftmost_cell, cell.x)
		rightmost_cell = maxi(rightmost_cell, cell.x)
	active_position = Vector2i(randi_range(-leftmost_cell, BOARD_COLUMNS - rightmost_cell - 1), 0)
	if not _can_place(active_piece_name, active_position):
		_trigger_game_over()


func _take_piece_name() -> String:
	if bag.is_empty():
		bag.assign(["I", "O", "T", "S", "Z", "J", "L"])
		bag.shuffle()
	return bag.pop_back()


func _can_place(piece_name: String, position: Vector2i) -> bool:
	for cell: Vector2i in TETROMINOES[piece_name]["cells"]:
		var board_cell := position + cell
		if board_cell.x < 0 or board_cell.x >= BOARD_COLUMNS or board_cell.y < 0 or board_cell.y >= BOARD_ROWS:
			return false
		if board[board_cell.y][board_cell.x] != null:
			return false
	return true


func _lock_active_piece() -> void:
	for cell: Vector2i in TETROMINOES[active_piece_name]["cells"]:
		var board_cell := active_position + cell
		board[board_cell.y][board_cell.x] = active_piece_name

	var removed := _clear_full_rows()
	if removed > 0:
		cleared_lines += removed
		score += [0, 100, 300, 500, 800][removed]
	_spawn_piece()


func _clear_full_rows() -> int:
	var removed := 0
	var remaining_rows: Array = []
	for row: Array in board:
		if _is_row_full(row):
			removed += 1
		else:
			remaining_rows.append(row)

	if removed > 0:
		var new_board: Array = []
		for _row in removed:
			var empty_row: Array = []
			empty_row.resize(BOARD_COLUMNS)
			empty_row.fill(null)
			new_board.append(empty_row)
		new_board.append_array(remaining_rows)
		board = new_board
	return removed


func _is_row_full(row: Array) -> bool:
	for cell in row:
		if cell == null:
			return false
	return true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BACKGROUND_COLOR)
	for row in BOARD_ROWS:
		for column in BOARD_COLUMNS:
			var piece_name: String = board[row][column] if board.size() > row and board[row][column] != null else ""
			_draw_cell(Vector2i(column, row), piece_name)

	if not active_piece_name.is_empty() and not game_over:
		for cell: Vector2i in TETROMINOES[active_piece_name]["cells"]:
			_draw_cell(active_position + cell, active_piece_name)

	_draw_player()
	_draw_hud()


func _draw_cell(board_cell: Vector2i, piece_name: String) -> void:
	var rect := Rect2(BOARD_ORIGIN + Vector2(board_cell) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
	if piece_name.is_empty():
		draw_rect(rect, EMPTY_CELL)
	else:
		draw_texture_rect_region(BLOCK_SPRITES, rect, BLOCK_SPRITE_REGIONS[piece_name])
	draw_rect(rect, GRID_LINE, false, 1.0)


func _draw_player() -> void:
	if game_over:
		return
	var origin := BOARD_ORIGIN + player_position
	var state := player_animation_state
	var size := Vector2(CELL_SIZE * 1.25, CELL_SIZE * 2)
	var facing := player_facing
	if is_grabbing:
		facing = grab_side
	elif attack_timer > 0.0:
		size.x = CELL_SIZE * 1.8

	draw_set_transform(origin + Vector2(CELL_SIZE * 0.5, 0.0), 0.0, Vector2(facing, 1.0))
	draw_texture_rect_region(_player_animation_texture(state), Rect2(Vector2(-size.x * 0.5, 0.0), size), _player_animation_region(state))
	draw_set_transform(Vector2.ZERO)


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(BOARD_ORIGIN.x, 36), "SCORE  %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, HUD_PRIMARY)
	draw_string(font, Vector2(BOARD_ORIGIN.x + 156, 36), "LINES  %d" % cleared_lines, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, HUD_PRIMARY)

	var preview_x := BOARD_ORIGIN.x + BOARD_COLUMNS * CELL_SIZE + 42
	draw_string(font, Vector2(preview_x, 108), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, HUD_TEXT)
	_draw_piece_preview(next_piece_names[0], Vector2(preview_x, 122))
	_draw_piece_preview(next_piece_names[1], Vector2(preview_x, 232))

	var stamina_rect := Rect2(BOARD_ORIGIN + Vector2(0.0, BOARD_ROWS * CELL_SIZE + 14.0), Vector2(BOARD_COLUMNS * CELL_SIZE, 14.0))
	var stamina_ratio := maxf(0.0, GRAB_DURATION - grab_timer) / GRAB_DURATION
	draw_rect(stamina_rect, Color("c8d1dd"))
	draw_rect(Rect2(stamina_rect.position + Vector2(2.0, 2.0), Vector2((stamina_rect.size.x - 4.0) * stamina_ratio, stamina_rect.size.y - 4.0)), Color("2c8fd6"))
	draw_rect(stamina_rect, HUD_PRIMARY, false, 2.0)

	if game_over:
		draw_rect(Rect2(BOARD_ORIGIN + Vector2(0, 230), Vector2(BOARD_COLUMNS * CELL_SIZE, 100)), Color(0.02, 0.03, 0.06, 0.88))
		draw_string(font, BOARD_ORIGIN + Vector2(56, 272), "GAME OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ff8090"))
		draw_string(font, BOARD_ORIGIN + Vector2(69, 302), "Press R to restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f4f6ff"))


func _draw_piece_preview(piece_name: String, origin: Vector2) -> void:
	for cell: Vector2i in TETROMINOES[piece_name]["cells"]:
		var rect := Rect2(origin + Vector2(cell) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
		draw_texture_rect_region(BLOCK_SPRITES, rect, BLOCK_SPRITE_REGIONS[piece_name])
		draw_rect(rect, GRID_LINE, false, 1.0)
