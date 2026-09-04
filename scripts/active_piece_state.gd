class_name MainActivePieceState
extends RefCounted

## Logical falling-piece state. It deliberately contains no Node, transform, or physics object.
var piece_type: int = MainTetrominoData.Type.T
var rotation: int = 0
var origin: Vector2i = Vector2i(3, 1)
var cell_indices: Array[int] = [0, 1, 2, 3]
var has_thorns: bool = false
var thorn_visible: bool = false
var thorn_phase_timer: float = 0.0
var fall_accumulator: float = 0.0
var lock_accumulator: float = 0.0
var lock_resets: int = 0


func create_snapshot(next_piece_type: int) -> Dictionary:
	return {
		"type": piece_type,
		"rotation": rotation,
		"origin": origin,
		"cell_indices": cell_indices.duplicate(),
		"next_type": next_piece_type,
	}
