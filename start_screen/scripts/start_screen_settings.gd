class_name StartScreenSettings
extends Node

## [역할 / C++ 대응]
## 시작 화면의 키 바인딩과 BGM/SFX 볼륨을 메모리, InputMap, 설정 파일 사이에서 동기화한다.
## C++로 보면 설정 DTO와 영속화 서비스, 입력 매핑 어댑터를 한 객체에 모은 클래스에 가깝다.
## `Dictionary`는 키 형식이 런타임에 결정되는 `std::unordered_map<Variant, Variant>`와 비슷하고,
## signal은 여러 UI가 설정 변경을 구독하는 observer callback 목록에 대응한다.
##
## 호출자: KungFuTetrisStartScreen, GameController/CharacterController, UI 통합 테스트.
## 호출 대상: MainInputActions, ConfigFile, InputMap, AudioServer.

signal bindings_changed # 키 배열이 바뀌어 버튼·튜토리얼 표시를 다시 그려야 함을 알린다.
signal audio_changed # BGM/SFX 퍼센트가 바뀌었음을 알린다.
signal settings_error(message: String) # 파일·중복 설정 문제를 사용자 UI에 전달한다.

const DEFAULT_SETTINGS_PATH: String = "user://start_screen_settings.cfg" # 배포판의 사용자별 저장 위치.
const MUSIC_BUS: StringName = &"BGM" # AudioServer에서 음악 볼륨을 찾는 bus 식별자.
const SFX_BUS: StringName = &"SFX" # 효과음 볼륨을 찾는 bus 식별자.
const INPUT_ACTIONS: Script = preload("res://scripts/input_actions.gd") # 입력 정의 static 유틸리티.
const ACTION_DEFINITIONS: Array[Dictionary] = INPUT_ACTIONS.DEFINITIONS # 전체 action 메타데이터의 읽기 전용 별칭.
const SELF_RESPAWN_ACTION: StringName = &"character_self_respawn" # 구버전 설정 migration 대상 action.
const SELF_RESPAWN_MIGRATION_KEYS: Array[int] = [KEY_Q, KEY_K, KEY_BACKSPACE] # 충돌 시 차례로 시험할 후보.

var settings_path: String = DEFAULT_SETTINGS_PATH # 현재 인스턴스가 읽고 쓸 cfg 경로. 테스트에서 교체 가능하다.
var music_percent: float = 100.0 # 0~100 범위의 BGM 선형 볼륨.
var sfx_percent: float = 100.0 # 0~100 범위의 효과음 선형 볼륨.

var _bindings: Dictionary = {} # StringName action → Array[int] 물리 키 슬롯의 authoritative 설정.


## 상황: `StartScreenSettings.new(path)`로 객체를 만들 때 C++ 생성자처럼 자동 호출된다.
## 순서: 인자로 받은 저장 경로를 멤버에 복사한다.
## 결과: 실제 사용자 파일과 테스트용 임시 파일을 같은 코드로 처리할 수 있다.
func _init(custom_settings_path: String = DEFAULT_SETTINGS_PATH) -> void:
	settings_path = custom_settings_path


## 상황: 설정 노드가 scene tree에 들어온 뒤 초기 상태를 실제 엔진에 반영할 때 호출된다.
## 순서: 파일 load → InputMap 적용 → AudioServer 적용 순으로 실행한다.
## 결과: 첫 화면이 나타나기 전에 저장된 키와 볼륨이 활성화된다.
func _ready() -> void:
	load_settings()
	apply_bindings()
	apply_audio()


## 상황: 키 설정 UI가 표시할 action 메타데이터 전체를 요구할 때 호출된다.
## 결과: 원본 상수와 저장소를 공유하지 않는 깊은 복사 배열을 반환한다.
func get_action_definitions() -> Array[Dictionary]:
	return INPUT_ACTIONS.get_definitions()


## 상황: 충돌 메시지나 설정 행이 내부 action 이름의 한글 표시명을 요구할 때 호출된다.
## 순서: 정의 검색 → `label` 조회 → 없으면 내부 이름을 fallback으로 사용한다.
## 결과: 항상 화면에 표시 가능한 String을 반환한다.
func get_action_label(action_name: StringName) -> String:
	var definition: Dictionary = _definition_for(action_name) # action 하나의 메타데이터 snapshot.
	return String(definition.get("label", String(action_name)))


## 상황: UI 표시·저장·충돌 검사가 action 하나의 현재 키 슬롯을 읽을 때 호출된다.
## 순서: Variant 배열 조회 → 각 원소를 int로 명시 변환해 typed 배열에 복사한다.
## 결과: 호출자가 수정해도 `_bindings` 원본을 바꾸지 않는 `Array[int]`를 반환한다.
func get_action_keys(action_name: StringName) -> Array[int]:
	var result: Array[int] = [] # C++의 지역 `std::vector<int>`에 해당하는 반환 버퍼.
	var values: Array = _bindings.get(action_name, []) # Dictionary에서 얻은 동적 타입 원본.
	for value: Variant in values:
		result.append(int(value))
	return result


## 상황: 튜토리얼이 한 동작의 모든 지정 키를 `Z / Space` 형식으로 표시할 때 호출된다.
## 순서: KEY_NONE 제외 → 각 keycode를 사람이 읽는 텍스트로 변환 → 구분자로 join.
## 결과: 지정 키가 없으면 빈 문자열, 있으면 슬래시로 연결된 문자열을 반환한다.
func get_binding_text(action_name: StringName) -> String:
	var parts: PackedStringArray = [] # 변환된 키 이름을 모으는 연속 문자열 버퍼.
	for key_code: int in get_action_keys(action_name):
		if key_code != KEY_NONE:
			parts.append(keycode_to_text(key_code))
	return " / ".join(parts)


## 상황: 주 키·보조 키 버튼 하나가 자기 슬롯의 표시문을 요구할 때 호출된다.
## 순서: 현재 키 배열 조회 → 범위/KEY_NONE 검사 → 유효하면 텍스트 변환.
## 결과: 비어 있으면 `미지정`, 아니면 해당 키 이름을 반환한다.
func get_slot_text(action_name: StringName, slot_index: int) -> String:
	var keys: Array[int] = get_action_keys(action_name) # 검사 중 원본 변경을 피하는 typed 복사본.
	if slot_index < 0 or slot_index >= keys.size() or keys[slot_index] == KEY_NONE:
		return "미지정"
	return keycode_to_text(keys[slot_index])


## 상황: 사용자가 키 캡처 overlay에서 새 키 하나를 입력했을 때 호출된다.
## 순서: action/slot/예약키 검사 → 전역 중복 검사 → 슬롯 갱신 → InputMap·파일·signal 반영.
## 결과: 성공 여부와 사용자 메시지를 담은 Dictionary를 반환하며 실패 시 기존 설정은 유지된다.
func set_binding(action_name: StringName, slot_index: int, key_code: int) -> Dictionary:
	var definition: Dictionary = _definition_for(action_name) # 허용 슬롯 수와 표시명을 가진 action 정의.
	if definition.is_empty():
		return _failure("알 수 없는 입력 동작입니다.")

	var slot_count: int = int(definition.get("slots", 1)) # C++ 배열 bounds 검사에 쓰는 논리 크기.
	if slot_index < 0 or slot_index >= slot_count:
		return _failure("변경할 수 없는 키 슬롯입니다.")
	if key_code == KEY_NONE:
		return _failure("주 키는 비워둘 수 없습니다.")
	if key_code == KEY_ESCAPE:
		return _failure("Esc는 메뉴 복귀 전용 키입니다.")

	var conflict: Dictionary = find_conflict(key_code, action_name, slot_index) # 자기 슬롯을 제외한 중복 정보.
	if not conflict.is_empty():
		return _failure(
			"%s 키는 이미 '%s'에 사용 중입니다."
			% [keycode_to_text(key_code), String(conflict.get("label", ""))]
		)

	var keys: Array[int] = get_action_keys(action_name) # commit 전에 수정할 지역 복사본.
	while keys.size() < slot_count:
		keys.append(KEY_NONE)
	keys[slot_index] = key_code
	_bindings[action_name] = keys
	apply_bindings()
	save_settings()
	bindings_changed.emit()
	return {"ok": true, "message": "%s 키가 변경되었습니다." % get_action_label(action_name)}


## 상황: 두 슬롯을 가진 동작의 보조 키를 `지우기` 버튼으로 해제할 때 호출된다.
## 순서: action/슬롯 수 검사 → 두 번째 슬롯 KEY_NONE → InputMap·파일·signal 반영.
## 결과: 주 키는 보존되며 성공/실패 메시지 Dictionary를 반환한다.
func clear_secondary_binding(action_name: StringName) -> Dictionary:
	var definition: Dictionary = _definition_for(action_name)
	if definition.is_empty() or int(definition.get("slots", 1)) < 2:
		return _failure("보조 키가 없는 동작입니다.")

	var keys: Array[int] = get_action_keys(action_name)
	while keys.size() < 2:
		keys.append(KEY_NONE)
	keys[1] = KEY_NONE
	_bindings[action_name] = keys
	apply_bindings()
	save_settings()
	bindings_changed.emit()
	return {"ok": true, "message": "%s 보조 키를 지웠습니다." % get_action_label(action_name)}


## 상황: 새 keycode가 다른 action/slot과 충돌하는지 선형 탐색할 때 호출된다.
## 순서: 모든 정의와 현재 슬롯을 순회 → 무시 대상 건너뜀 → 같은 keycode에서 즉시 반환.
## 결과: 충돌하면 action·slot·label Dictionary, 없으면 빈 Dictionary를 반환한다.
func find_conflict(
	key_code: int,
	ignored_action: StringName = &"",
	ignored_slot: int = -1
) -> Dictionary:
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = definition["action"]
		var keys: Array[int] = get_action_keys(action_name)
		for slot_index: int in range(keys.size()):
			if action_name == ignored_action and slot_index == ignored_slot:
				continue
			if keys[slot_index] == key_code:
				return {
					"action": action_name,
					"slot": slot_index,
					"label": definition["label"],
				}
	return {}


## 상황: 사용자가 `기본값 복원`을 선택했을 때 호출된다.
## 순서: 메모리 기본값 복원 → InputMap 적용 → 파일 저장 → UI signal emit.
## 결과: 모든 action이 현재 버전의 기본 키로 원자적으로 되돌아간다.
func reset_bindings_to_defaults() -> void:
	_load_default_bindings()
	apply_bindings()
	save_settings()
	bindings_changed.emit()


## 상황: 메모리 `_bindings`를 Godot 전역 InputMap과 동기화할 때 호출된다.
## 결과: MainInputActions가 기존 event를 현재 설정 배열로 교체한다.
func apply_bindings() -> void:
	INPUT_ACTIONS.apply_bindings(_bindings)


## 상황: BGM slider 값이 바뀌었을 때 호출된다.
## 순서: 0~100 clamp → bus 반영 → 파일 저장 → audio_changed emit.
## 결과: 잘못된 범위 입력도 안전하게 제한되고 즉시 들리는 볼륨이 바뀐다.
func set_music_percent(value: float) -> void:
	music_percent = clampf(value, 0.0, 100.0)
	_apply_bus_volume(MUSIC_BUS, music_percent)
	save_settings()
	audio_changed.emit()


## 상황: SFX slider 값이 바뀌었을 때 호출되며 BGM setter와 같은 계약을 가진다.
## 결과: 0~100으로 제한된 값이 SFX bus와 설정 파일에 반영된다.
func set_sfx_percent(value: float) -> void:
	sfx_percent = clampf(value, 0.0, 100.0)
	_apply_bus_volume(SFX_BUS, sfx_percent)
	save_settings()
	audio_changed.emit()


## 상황: 프로젝트에 BGM/SFX bus가 없는 초기 실행이나 테스트 환경에서 호출된다.
## 결과: 이미 있는 bus는 유지하고 누락된 이름만 AudioServer 끝에 추가한다.
func ensure_audio_buses() -> void:
	_ensure_audio_bus(MUSIC_BUS)
	_ensure_audio_bus(SFX_BUS)


## 상황: 파일을 읽은 뒤 저장된 두 볼륨을 AudioServer에 한 번에 적용할 때 호출된다.
## 순서: bus 존재 보장 → BGM 적용 → SFX 적용.
## 결과: 엔진의 실제 mute/dB 상태가 멤버 퍼센트와 일치한다.
func apply_audio() -> void:
	ensure_audio_buses()
	_apply_bus_volume(MUSIC_BUS, music_percent)
	_apply_bus_volume(SFX_BUS, sfx_percent)


## 상황: 시작 화면 초기화 시 cfg 파일을 메모리 설정으로 역직렬화할 때 호출된다.
## 순서: 기본값 seed → 파일 load → 입력 parsing/migration → audio load → 중복 복구.
## 결과: 파일 없음은 정상 기본값, 손상·구버전 데이터는 가능한 범위에서 안전하게 복원된다.
func load_settings() -> void:
	_reset_settings_to_defaults()

	var config: ConfigFile = ConfigFile.new() # C++의 임시 parser/DTO 객체와 같은 지역 저장소.
	var load_error: Error = config.load(settings_path) # 예외 대신 반환되는 Godot 오류 코드.
	if load_error != OK:
		if load_error != ERR_FILE_NOT_FOUND:
			settings_error.emit("설정 파일을 읽지 못했습니다: %s" % error_string(load_error))
		return

	_load_bindings_from_config(config)
	_restore_escape_bindings()
	_migrate_rotation_kick_binding()
	if not config.has_section_key("input", String(SELF_RESPAWN_ACTION)):
		_migrate_self_respawn_binding()
	_load_audio_from_config(config)
	_restore_defaults_for_duplicate_keys()


## 상황: 파일 load 전 또는 잘못된 설정 전체를 폐기해야 할 때 호출된다.
## 결과: 키와 두 볼륨 멤버를 현재 버전 기본값으로 되돌린다.
func _reset_settings_to_defaults() -> void:
	_load_default_bindings()
	music_percent = 100.0
	sfx_percent = 100.0


## 상황: ConfigFile의 `input` section을 `_bindings`에 옮길 때 호출된다.
## 순서: action별 저장 Variant 조회 → 슬롯 수에 맞게 parse → 유효한 배열만 commit.
## 결과: 잘못된 action 하나가 다른 정상 action의 로드를 방해하지 않는다.
func _load_bindings_from_config(config: ConfigFile) -> void:
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = definition["action"]
		var slot_count: int = int(definition.get("slots", 1))
		var stored_value: Variant = config.get_value(
			"input",
			String(action_name),
			_bindings[action_name]
		)
		var parsed: Array[int] = _parse_key_array(
			stored_value,
			slot_count,
			action_name == SELF_RESPAWN_ACTION
		)
		if not parsed.is_empty():
			_bindings[action_name] = parsed


## 상황: Esc가 저장된 이전 키 설정을 불러올 때 호출한다.
## 결과: Esc만 제거하고 다른 유효 키는 유지하며, 남은 키가 없을 때만 기본값을 쓴다.
func _restore_escape_bindings() -> void:
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = definition["action"]
		var keys: Array[int] = get_action_keys(action_name)
		if KEY_ESCAPE not in keys:
			continue
		var filtered_keys: Array[int] = []
		for key_code: int in keys:
			if key_code != KEY_ESCAPE:
				filtered_keys.append(key_code)
		var has_valid_key: bool = false
		for key_code: int in filtered_keys:
			if key_code != KEY_NONE:
				has_valid_key = true
				break
		_bindings[action_name] = (
			filtered_keys
			if has_valid_key
			else INPUT_ACTIONS.get_default_keys(action_name)
		)


## 상황: 기존 설정 파일에 새 자력 재스폰 동작이 아직 없을 때 한 번 계산한다.
## 순서: Q→K→Backspace 중 다른 동작이 쓰지 않는 첫 키 선택, 모두 충돌하면 미지정.
## 결과: 기존 사용자 키 전체를 기본값으로 되돌리지 않고 새 동작만 안전하게 보충한다.
func _migrate_self_respawn_binding() -> void:
	for key_code: int in SELF_RESPAWN_MIGRATION_KEYS:
		if find_conflict(key_code, SELF_RESPAWN_ACTION, 0).is_empty():
			_bindings[SELF_RESPAWN_ACTION] = [key_code]
			return
	_bindings[SELF_RESPAWN_ACTION] = [KEY_NONE]


## 상황: 블록 플립의 기존 기본키 V를 새 기본키 S로 옮길 때 호출한다.
## 결과: 기존 기본값만 S로 옮기고, 사용자가 지정한 다른 키는 유지한다.
func _migrate_rotation_kick_binding() -> void:
	var rotation_action: StringName = &"character_rotation_kick"
	var rotation_keys: Array[int] = get_action_keys(rotation_action)
	if rotation_keys.size() == 1 and rotation_keys[0] == KEY_V:
		_bindings[rotation_action] = [KEY_S]


## 상황: cfg의 `audio` section을 두 퍼센트 멤버로 역직렬화할 때 호출된다.
## 결과: 누락 값은 100, 범위 밖 값은 0~100으로 제한된다.
func _load_audio_from_config(config: ConfigFile) -> void:
	music_percent = clampf(
		float(config.get_value("audio", "music_percent", 100.0)),
		0.0,
		100.0
	)
	sfx_percent = clampf(
		float(config.get_value("audio", "sfx_percent", 100.0)),
		0.0,
		100.0
	)


## 상황: 파일에서 읽은 전체 키에 중복이 남아 있는지 최종 검증할 때 호출된다.
## 결과: 중복이면 전체 키를 기본값으로 복구하고 오류 signal을 한 번 보낸다.
func _restore_defaults_for_duplicate_keys() -> void:
	if _has_duplicate_keys():
		_load_default_bindings()
		settings_error.emit("저장된 키 설정에 중복이 있어 기본값으로 복원했습니다.")


## 상황: 설정 변경 직후 현재 메모리 상태를 cfg로 직렬화할 때 호출된다.
## 순서: action 키 배열 기록 → 두 audio 값 기록 → 지정 경로 save → 오류 signal.
## 결과: 성공이면 OK, 실패면 원인 Error를 반환해 테스트·호출자가 확인할 수 있다.
func save_settings() -> Error:
	var config: ConfigFile = ConfigFile.new() # 이번 저장만 소유하는 직렬화 버퍼.
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = definition["action"]
		config.set_value("input", String(action_name), get_action_keys(action_name))
	config.set_value("audio", "music_percent", music_percent)
	config.set_value("audio", "sfx_percent", sfx_percent)
	var save_error: Error = config.save(settings_path)
	if save_error != OK:
		settings_error.emit("설정을 저장하지 못했습니다: %s" % error_string(save_error))
	return save_error


## 상황: 정수 물리 keycode를 UI에 표시할 짧은 문자열로 바꿀 때 호출된다.
## 순서: 방향/Space/Esc 특수 표기 → 나머지는 OS 이름 조회 → 비면 숫자 fallback.
## 결과: 설정 상태를 바꾸지 않는 C++의 static formatting 함수처럼 동작한다.
static func keycode_to_text(key_code: int) -> String:
	match key_code:
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_SPACE:
			return "Space"
		KEY_ESCAPE:
			return "Esc"
		_:
			var text_value: String = OS.get_keycode_string(key_code)
			return text_value if not text_value.is_empty() else "Key %d" % key_code


## 상황: 여러 public 함수가 action 정의 하나를 검색할 때 사용하는 얇은 private wrapper다.
## 결과: MainInputActions 검색 결과를 그대로 반환한다.
func _definition_for(action_name: StringName) -> Dictionary:
	return INPUT_ACTIONS.get_definition(action_name)


## 상황: 초기화·reset·중복 복구에서 현재 버전 기본 키 전체가 필요할 때 호출된다.
## 순서: 기존 Dictionary clear → 정의 순회 → action별 기본 배열 복사.
## 결과: `_bindings`가 정의 목록과 정확히 같은 key 집합을 갖는다.
func _load_default_bindings() -> void:
	_bindings.clear()
	for definition: Dictionary in ACTION_DEFINITIONS:
		_bindings[definition["action"]] = INPUT_ACTIONS.get_default_keys(
			definition["action"]
		)


## 상황: ConfigFile에서 얻은 동적 Variant를 신뢰 가능한 키 배열로 바꿀 때 호출된다.
## 순서: Array/숫자 타입 검사 → primary 정책 검사 → 부족한 슬롯 채움 → 초과 슬롯 절단.
## 결과: 유효하면 정확한 slot_count 배열, 잘못되면 빈 배열을 반환한다.
func _parse_key_array(
	stored_value: Variant,
	slot_count: int,
	allow_unassigned_primary: bool = false
) -> Array[int]:
	var parsed: Array[int] = []
	if not (stored_value is Array):
		return parsed
	for value: Variant in stored_value:
		if not (value is int or value is float):
			return []
		parsed.append(int(value))
	if parsed.is_empty():
		return []
	if parsed[0] == KEY_NONE:
		return [KEY_NONE] if allow_unassigned_primary else []
	while parsed.size() < slot_count:
		parsed.append(KEY_NONE)
	if parsed.size() > slot_count:
		parsed.resize(slot_count)
	return parsed


## 상황: 로드 완료 뒤 서로 다른 동작이 같은 유효 키를 공유하는지 검사할 때 호출된다.
## 순서: KEY_NONE 제외 → 사용 key 집합에 이미 있으면 true → 아니면 집합에 기록.
## 결과: `_bindings`는 변경하지 않고 첫 중복에서 즉시 true를 반환한다.
func _has_duplicate_keys() -> bool:
	var used: Dictionary = {} # keycode를 set처럼 저장하는 hash table.
	for definition: Dictionary in ACTION_DEFINITIONS:
		for key_code: int in get_action_keys(definition["action"]):
			if key_code == KEY_NONE:
				continue
			if used.has(key_code):
				return true
			used[key_code] = true
	return false


## 상황: 볼륨 적용 전에 이름으로 찾을 Audio bus가 존재해야 할 때 호출된다.
## 결과: 이미 있으면 조기 반환하고 없으면 마지막 index에 같은 이름의 bus를 만든다.
func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


## 상황: 0~100 퍼센트를 AudioServer의 mute와 decibel 표현으로 변환할 때 호출된다.
## 순서: bus index 검색 → 0 이하면 mute → 아니면 선형 비율을 dB로 변환.
## 결과: 존재하는 bus 하나의 실제 출력 크기가 갱신된다.
func _apply_bus_volume(bus_name: StringName, percent: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name) # 이름을 AudioServer 배열 index로 변환한 값.
	if bus_index < 0:
		return
	var muted: bool = percent <= 0.0 # log(0)을 피하면서 완전 무음을 표현하는 flag.
	AudioServer.set_bus_mute(bus_index, muted)
	AudioServer.set_bus_volume_db(
		bus_index,
		-80.0 if muted else linear_to_db(percent / 100.0)
	)


## 상황: validation 실패 public API가 동일한 반환 형식을 만들 때 호출된다.
## 결과: `ok=false`와 설명 문자열을 담은 새 Dictionary를 반환한다.
func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
