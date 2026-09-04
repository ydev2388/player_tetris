class_name MainCharacterRuntimePort
extends RefCounted

## GameController가 CharacterController의 구체 구현이나 private 메서드를 알지 않게 하는
## 좁은 Scene 경계다. 캐릭터 물리 자체는 CharacterController에 남기되 게임은 필요한
## snapshot/명령만 이 Port를 통해 사용한다.

var _get_max_lives: Callable
var _get_collider_rect: Callable
var _get_bound: Callable
var _apply_binding: Callable
var _take_hazard_damage: Callable
var _clear_runtime: Callable


func _init(
	get_max_lives: Callable,
	get_collider_rect: Callable,
	get_bound: Callable,
	apply_binding: Callable,
	take_hazard_damage: Callable,
	clear_runtime: Callable
) -> void:
	_get_max_lives = get_max_lives
	_get_collider_rect = get_collider_rect
	_get_bound = get_bound
	_apply_binding = apply_binding
	_take_hazard_damage = take_hazard_damage
	_clear_runtime = clear_runtime


func max_lives(fallback: int) -> int:
	if not _get_max_lives.is_valid():
		return fallback
	return maxi(int(_get_max_lives.call()), 0)


func collider_rect() -> Variant:
	if not _get_collider_rect.is_valid():
		return null
	var value: Variant = _get_collider_rect.call()
	return value if value is Rect2 else null


func is_bound() -> bool:
	return _get_bound.is_valid() and bool(_get_bound.call())


func apply_binding(duration_seconds: float) -> void:
	if _apply_binding.is_valid():
		_apply_binding.call(maxf(duration_seconds, 0.0))


func take_hazard_damage(feedback_message: String) -> void:
	if _take_hazard_damage.is_valid():
		_take_hazard_damage.call(feedback_message)


func clear_runtime_state(reason: int) -> void:
	if _clear_runtime.is_valid():
		_clear_runtime.call(reason)
