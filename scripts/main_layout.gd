class_name MainLayout
extends RefCounted

## Main의 화면·물리 픽셀 배율을 한 곳에서 공유한다.
const BASE_CELL_SIZE: float = 32.0
const DISPLAY_SCALE: float = 1.5
const CELL_SIZE: float = BASE_CELL_SIZE * DISPLAY_SCALE
const BOARD_SIZE: Vector2 = Vector2(10.0, 20.0) * CELL_SIZE
const GAME_VIEWPORT_SIZE: Vector2i = Vector2i(560, 1140)
const BOARD_ORIGIN: Vector2 = Vector2(40.0, 120.0)


static func scaled(value: float) -> float:
	return value * DISPLAY_SCALE
