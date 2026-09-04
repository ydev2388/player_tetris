class_name BlockFighterScreenView
extends RefCounted

var screen_id: int
var root: Control
var _on_enter: Callable
var _focus_candidates: Array[Control] = []
var _preferred_focus_index: Callable


func _init(id: int, target_root: Control, on_enter: Callable = Callable()) -> void:
	screen_id = id
	root = target_root
	_on_enter = on_enter


func set_active(active: bool) -> void:
	if is_instance_valid(root):
		root.visible = active


func configure_focus(
	candidates: Array,
	preferred_focus_index: Callable = Callable()
) -> void:
	_focus_candidates.clear()
	for candidate: Variant in candidates:
		if candidate is Control:
			_focus_candidates.append(candidate as Control)
	_preferred_focus_index = preferred_focus_index


func enter() -> void:
	set_active(true)
	if _on_enter.is_valid():
		_on_enter.call()
	_focus_preferred_control()


func _focus_preferred_control() -> void:
	if _focus_candidates.is_empty():
		return
	var preferred_index: int = 0
	if _preferred_focus_index.is_valid():
		preferred_index = clampi(
			int(_preferred_focus_index.call()), 0, _focus_candidates.size() - 1
		)
	var preferred: Control = _focus_candidates[preferred_index]
	if _can_receive_focus(preferred):
		preferred.grab_focus.call_deferred()
		return
	for candidate: Control in _focus_candidates:
		if _can_receive_focus(candidate):
			candidate.grab_focus.call_deferred()
			return


func _can_receive_focus(candidate: Control) -> bool:
	if not is_instance_valid(candidate) or not candidate.visible:
		return false
	if candidate is BaseButton and (candidate as BaseButton).disabled:
		return false
	return candidate.focus_mode != Control.FOCUS_NONE
