extends Node2D

const BOARD_COLUMNS := 10
const BOARD_ROWS := 20
const CELL_SIZE := 28
const BOARD_ORIGIN := Vector2(96, 72)
const FALL_INTERVAL := 0.7

const PLAYER_SIZE := Vector2(CELL_SIZE, CELL_SIZE * 2)
const PLAYER_SPEED := 150.0
const PLAYER_GRAVITY := 1000.0
const JUMP_VELOCITY := -335.0
const WALL_JUMP_SPEED := 185.0
const CLIMB_SPEED := 78.0
const GRAB_DURATION := 3.0
const ATTACK_DURATION := 0.12
const ATTACK_COOLDOWN := 0.28

const EMPTY_CELL := Color(0.075, 0.09, 0.14)
const GRID_LINE := Color(0.16, 0.19, 0.27)
const TETROMINOES := {
	"I": {"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], "color": Color("4ddcff")},
	"O": {"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "color": Color("ffd84d")},
	"T": {"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)], "color": Color("ba6cff")},
	"S": {"cells": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)], "color": Color("62df77")},
	"Z": {"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)], "color": Color("ff5b6e")},
	"J": {"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], "color": Color("5c8dff")},
	"L": {"cells": [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], "color": Color("ff9b4d")},
}

var board: Array = []
var bag: Array[String] = []
var active_piece_name := ""
var next_piece_name := ""
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
var attack_timer := 0.0
var attack_cooldown := 0.0


func _ready() -> void:
	randomize()
	reset_game()


func _process(delta: float) -> void:
	if game_over:
		return

	_update_player(delta)
	if _active_overlaps_player():
		_trigger_game_over()
		queue_redraw()
		return

	drop_timer += delta
	if drop_timer >= FALL_INTERVAL:
		drop_timer -= FALL_INTERVAL
		if _can_place(active_piece_name, active_position + Vector2i.DOWN):
			active_position += Vector2i.DOWN
		else:
			_lock_active_piece()

	if _active_overlaps_player():
		_trigger_game_over()
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
	score = 0
	cleared_lines = 0
	drop_timer = 0.0
	game_over = false
	next_piece_name = _take_piece_name()
	_spawn_piece()
	player_position = Vector2(CELL_SIZE * 4, CELL_SIZE * (BOARD_ROWS - 2))
	player_velocity = Vector2.ZERO
	player_facing = 1
	is_grabbing = false
	grab_timer = 0.0
	grab_exhausted = false
	attack_timer = 0.0
	attack_cooldown = 0.0
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
		grab_exhausted = false

	if is_grabbing:
		_update_grab(delta)
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

	if Input.is_key_pressed(KEY_C) and not grab_exhausted:
		var side := _find_grab_side()
		if side != 0:
			is_grabbing = true
			grab_side = side
			grab_timer = 0.0
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
		player_velocity = Vector2(-grab_side * WALL_JUMP_SPEED, JUMP_VELOCITY)
		is_grabbing = false
		grab_exhausted = false
		return
	if _is_player_grounded():
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
	var cell_rect := Rect2(Vector2(board_cell) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
	return rect.intersects(cell_rect)


func _find_grab_side() -> int:
	var player_rect := Rect2(player_position, PLAYER_SIZE)
	var left_probe := Rect2(player_rect.position + Vector2(-1.0, 0.0), player_rect.size)
	if _rect_hits_solid(left_probe):
		return -1
	var right_probe := Rect2(player_rect.position + Vector2(1.0, 0.0), player_rect.size)
	if _rect_hits_solid(right_probe):
		return 1
	return 0


func _punch_hits_active_piece() -> bool:
	var fist_x := player_position.x + (PLAYER_SIZE.x if player_facing > 0 else -CELL_SIZE * 0.45)
	var fist_rect := Rect2(Vector2(fist_x, player_position.y + CELL_SIZE * 0.8), Vector2(CELL_SIZE * 0.45, CELL_SIZE * 0.45))
	for cell: Vector2i in TETROMINOES[active_piece_name]["cells"]:
		if fist_rect.intersects(Rect2(Vector2(active_position + cell) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))):
			return true
	return false


func _active_overlaps_player() -> bool:
	var player_rect := Rect2(player_position, PLAYER_SIZE)
	for cell: Vector2i in TETROMINOES[active_piece_name]["cells"]:
		if player_rect.intersects(Rect2(Vector2(active_position + cell) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))):
			return true
	return false


func _trigger_game_over() -> void:
	game_over = true
	is_grabbing = false
	player_velocity = Vector2.ZERO


func _spawn_piece() -> void:
	active_piece_name = next_piece_name
	next_piece_name = _take_piece_name()
	active_position = Vector2i(BOARD_COLUMNS / 2 - 2, 0)
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
	var color: Color = TETROMINOES[active_piece_name]["color"]
	for cell: Vector2i in TETROMINOES[active_piece_name]["cells"]:
		var board_cell := active_position + cell
		board[board_cell.y][board_cell.x] = color

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
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("10131d"))
	for row in BOARD_ROWS:
		for column in BOARD_COLUMNS:
			var color: Color = board[row][column] if board.size() > row and board[row][column] != null else EMPTY_CELL
			_draw_cell(Vector2i(column, row), color)

	if not active_piece_name.is_empty() and not game_over:
		var active_color: Color = TETROMINOES[active_piece_name]["color"]
		for cell: Vector2i in TETROMINOES[active_piece_name]["cells"]:
			_draw_cell(active_position + cell, active_color)

	_draw_player()
	_draw_hud()


func _draw_cell(board_cell: Vector2i, color: Color) -> void:
	var rect := Rect2(BOARD_ORIGIN + Vector2(board_cell) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
	draw_rect(rect, color)
	draw_rect(rect, GRID_LINE, false, 1.0)


func _draw_player() -> void:
	if game_over:
		return
	var origin := BOARD_ORIGIN + player_position
	var robe := Color("d8e1e8")
	var sleeve := Color("b6c3cf")
	var hat := Color("3f3424")
	draw_rect(Rect2(origin + Vector2(3, 6), Vector2(CELL_SIZE - 6, CELL_SIZE - 7)), robe)
	draw_rect(Rect2(origin + Vector2(3, CELL_SIZE), Vector2(CELL_SIZE - 6, CELL_SIZE - 4)), sleeve)
	draw_rect(Rect2(origin + Vector2(2, CELL_SIZE + 8), Vector2(CELL_SIZE - 4, 4)), Color("28303b"))
	draw_rect(Rect2(origin + Vector2(8, 12), Vector2(CELL_SIZE - 16, 10)), Color("d5a07b"))
	draw_rect(Rect2(origin + Vector2(1, 4), Vector2(CELL_SIZE - 2, 5)), hat)
	draw_rect(Rect2(origin + Vector2(7, 0), Vector2(CELL_SIZE - 14, 5)), hat)
	if is_grabbing:
		var hand_x := 0.0 if grab_side < 0 else CELL_SIZE - 5.0
		draw_rect(Rect2(origin + Vector2(hand_x, CELL_SIZE + 2), Vector2(6, 6)), Color("d5a07b"))
	elif attack_timer > 0.0:
		var hand_x := CELL_SIZE - 2.0 if player_facing > 0 else -8.0
		draw_rect(Rect2(origin + Vector2(hand_x, CELL_SIZE + 4), Vector2(10, 8)), Color("d5a07b"))


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var panel_x := BOARD_ORIGIN.x + BOARD_COLUMNS * CELL_SIZE + 42
	draw_string(font, Vector2(panel_x, 112), "KUNGFU TETRIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("f4f6ff"))
	draw_string(font, Vector2(panel_x, 162), "SCORE  %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d8def5"))
	draw_string(font, Vector2(panel_x, 194), "LINES  %d" % cleared_lines, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d8def5"))
	draw_string(font, Vector2(panel_x, 230), "ARROWS move / climb", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("aeb8d8"))
	draw_string(font, Vector2(panel_x, 250), "Z jump   X punch", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("aeb8d8"))
	draw_string(font, Vector2(panel_x, 270), "C grab  %.1fs" % maxf(0.0, GRAB_DURATION - grab_timer), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("aeb8d8"))
	draw_string(font, Vector2(panel_x, 310), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d8def5"))

	var preview_origin := Vector2i(BOARD_COLUMNS + 2, 9)
	var preview_color: Color = TETROMINOES[next_piece_name]["color"]
	for cell: Vector2i in TETROMINOES[next_piece_name]["cells"]:
		var rect := Rect2(BOARD_ORIGIN + Vector2(preview_origin + cell) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
		draw_rect(rect, preview_color)
		draw_rect(rect, GRID_LINE, false, 1.0)

	if game_over:
		draw_rect(Rect2(BOARD_ORIGIN + Vector2(0, 230), Vector2(BOARD_COLUMNS * CELL_SIZE, 100)), Color(0.02, 0.03, 0.06, 0.88))
		draw_string(font, BOARD_ORIGIN + Vector2(56, 272), "GAME OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ff8090"))
		draw_string(font, BOARD_ORIGIN + Vector2(69, 302), "Press R to restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f4f6ff"))
