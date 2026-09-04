class_name MainCommandResult
extends RefCounted

## 공개 게임 명령의 성공/실패와 커밋된 사건을 함께 반환하는 값 객체다.
## 실패 결과의 events는 항상 비어 있으며 호출자는 code로 분기하고 message는 진단에만 쓴다.

const OK: StringName = &"ok"
const GAME_NOT_PLAYING: StringName = &"game_not_playing"
const INVALID_START_CELL: StringName = &"invalid_start_cell"
const INVALID_DIRECTION: StringName = &"invalid_direction"
const PATH_BLOCKED: StringName = &"path_blocked"
const NO_ACTIVE_EFFECT: StringName = &"no_active_effect"
const INVALID_ABILITY: StringName = &"invalid_ability"
const NO_VALID_TARGET: StringName = &"no_valid_target"

var ok: bool:
	get:
		return _ok
var code: StringName:
	get:
		return _code
var message: String:
	get:
		return _message
var events: Array[MainGameEvent]:
	get:
		return _events.duplicate()

var _ok: bool
var _code: StringName
var _message: String
var _events: Array[MainGameEvent]


func _init(
	succeeded: bool,
	result_code: StringName,
	diagnostic_message: String,
	committed_events: Array[MainGameEvent] = []
) -> void:
	_ok = succeeded
	_code = result_code
	_message = diagnostic_message
	_events = committed_events.duplicate()


static func succeeded(committed_events: Array[MainGameEvent] = []) -> MainCommandResult:
	return MainCommandResult.new(true, OK, "", committed_events)


static func failed(result_code: StringName, diagnostic_message: String) -> MainCommandResult:
	return MainCommandResult.new(false, result_code, diagnostic_message)
