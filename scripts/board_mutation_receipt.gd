class_name MainBoardMutationReceipt
extends RefCounted

## Board 변경 경계가 실제로 커밋한 셀을 전달하는 읽기 전용 영수증이다.
## 시도한 후보가 아니라 이 영수증의 셀만 사건 payload로 사용할 수 있다.

var cells: Array[Vector2i]:
	get:
		return _cells.duplicate()
var count: int:
	get:
		return _cells.size()

var _cells: Array[Vector2i]


func _init(committed_cells: Array[Vector2i] = []) -> void:
	_cells = committed_cells.duplicate()


func is_empty() -> bool:
	return _cells.is_empty()
