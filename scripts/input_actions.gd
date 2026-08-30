class_name MainInputActions
extends RefCounted

## [역할 / C++ 대응]
## Main에서 쓰는 입력 action의 메타데이터와 InputMap 등록을 한곳에서 관리한다.
## `Dictionary`는 `std::unordered_map<Variant, Variant>`, `StringName`(`&"..."`)은
## Godot이 빠르게 비교하도록 intern한 문자열에 가깝다.
##
## [호출 관계]
## 호출자: GameController/CharacterController의 `_ready()`, 시작 화면의 키 설정 모듈, 테스트.
## 호출 대상: Godot 전역 싱글턴 `InputMap`과 `InputEventKey`.
##
## 각 Dictionary는 action 식별자, 화면 표시명, 기본 물리 키, 허용 슬롯 수를 담는다.
## action: Input singleton에서 조회할 내부 이름, label: 설정 화면 표시문,
## defaults: 최초 물리 keycode 목록, slots: 사용자가 지정할 수 있는 키 개수다.
const DEFINITIONS: Array[Dictionary] = [
	{
		"action": &"character_left",
		"label": "왼쪽 이동",
		"label_english": "Move Left",
		"label_chinese": "向左移动",
		"defaults": [KEY_LEFT, KEY_A],
		"slots": 2,
	},
	{
		"action": &"character_right",
		"label": "오른쪽 이동",
		"label_english": "Move Right",
		"label_chinese": "向右移动",
		"defaults": [KEY_RIGHT, KEY_D],
		"slots": 2,
	},
	{
		"action": &"character_climb_up",
		"label": "오르기",
		"label_english": "Climb Up",
		"label_chinese": "向上攀爬",
		"defaults": [KEY_UP],
		"slots": 1,
	},
	{
		"action": &"character_meditate",
		"label": "명상",
		"label_english": "Meditate",
		"label_chinese": "冥想",
		"defaults": [KEY_DOWN],
		"slots": 1,
	},
	{
		"action": &"character_jump",
		"label": "점프",
		"label_english": "Jump",
		"label_chinese": "跳跃",
		"defaults": [KEY_Z, KEY_SPACE],
		"slots": 2,
	},
	{
		"action": &"character_punch",
		"label": "기본 밀치기",
		"label_english": "Push",
		"label_chinese": "普通推击",
		"defaults": [KEY_X],
		"slots": 1,
	},
	{
		"action": &"character_special",
		"label": "특수 스킬",
		"label_english": "Special Skill",
		"label_chinese": "特殊技能",
		"defaults": [KEY_V],
		"slots": 1,
	},
	{
		"action": &"character_grab",
		"label": "매달리기",
		"label_english": "Grab",
		"label_chinese": "攀附",
		"defaults": [KEY_C],
		"slots": 1,
	},
	{
		"action": &"character_rotation_kick",
		"label": "블록 플립",
		"label_english": "Block Flip",
		"label_chinese": "方块翻转",
		"defaults": [KEY_S],
		"slots": 1,
	},
	{
		"action": &"character_self_respawn",
		"label": "자력 재스폰",
		"label_english": "Self Respawn",
		"label_chinese": "自救重生",
		"defaults": [KEY_Q],
		"slots": 1,
	},
	{
		"action": &"pause_game",
		"label": "일시정지",
		"label_english": "Pause",
		"label_chinese": "暂停",
		"defaults": [KEY_P],
		"slots": 1,
	},
	{
		"action": &"restart_game",
		"label": "다시 시작",
		"label_english": "Restart",
		"label_chinese": "重新开始",
		"defaults": [KEY_R],
		"slots": 1,
	},
]


## 상황: 시작 화면/테스트가 전체 action 정의를 열거할 때 호출한다.
## 순서: `duplicate(true)`로 Dictionary 내부 배열까지 깊은 복사를 한 번 수행한다.
## 결과: 호출자가 수정해도 DEFINITIONS 원본이 변하지 않는 새 배열을 반환한다.
static func get_definitions() -> Array[Dictionary]:
	return DEFINITIONS.duplicate(true)


## 상황: `get_default_keys()`나 설정 UI가 action 하나의 메타데이터를 요구할 때 호출한다.
## 순서: ① DEFINITIONS를 앞에서부터 순회 ② action key 비교 ③ 일치 즉시 반환.
## 결과: 찾으면 해당 Dictionary, 없으면 빈 Dictionary를 반환한다.
static func get_definition(action_name: StringName) -> Dictionary:
	for definition: Dictionary in DEFINITIONS:
		if definition["action"] == action_name:
			return definition
	return {}


## 상황: 기본 키 등록 또는 설정 초기화가 특정 action의 기본 키를 요구할 때 호출한다.
## 순서: ① `get_definition()` ② defaults를 Variant로 조회 ③ 각 값을 int로 변환·append.
## 결과: 타입이 보장된 `Array[int]`를 반환한다. 정의가 없으면 빈 배열이다.
static func get_default_keys(action_name: StringName) -> Array[int]:
	var result: Array[int] = [] # Variant 기본 키들을 int로 정규화해 반환할 배열.
	var definition: Dictionary = get_definition(action_name) # 요청 action의 메타데이터.
	for key_code: Variant in definition.get("defaults", []):
		result.append(int(key_code))
	return result


## 상황: GameController/CharacterController가 시작되어 필수 action을 보장해야 할 때 호출한다.
## 순서: ① 모든 정의 순회 ② action별 기본 키 계산 ③ `_ensure_action()`로 빈 항목만 보충.
## 결과: 기존 사용자 키는 유지하면서 비어 있는 action에만 기본 키를 추가한다.
static func ensure_defaults() -> void:
	for definition: Dictionary in DEFINITIONS:
		_ensure_action(definition["action"], get_default_keys(definition["action"]))


## 상황: 시작 화면에서 저장된 사용자 bindings를 실제 InputMap에 적용할 때 호출한다.
## 순서: action 보장 → 기존 event 전부 삭제 → `_typed_keys()` 변환 → KEY_NONE 제외 → event 추가.
## 결과: 각 action의 실제 키가 전달받은 설정으로 완전히 교체된다.
static func apply_bindings(bindings: Dictionary) -> void:
	for definition: Dictionary in DEFINITIONS:
		var action_name: StringName = definition["action"] # 현재 교체 중인 InputMap action 이름.
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		for key_code: int in _typed_keys(bindings.get(action_name, [])):
			if key_code != KEY_NONE:
				InputMap.action_add_event(action_name, _key_event(key_code))


## 상황: `ensure_defaults()`가 action 하나의 존재와 기본 키를 보장할 때 호출한다.
## 순서: ① action이 이미 있으면 종료 ② 없으면 생성 ③ 기본 키를 추가.
## 결과: 사용자 키 또는 의도적인 미지정 상태의 action에는 기본 event가 섞이지 않는다.
static func _ensure_action(action_name: StringName, key_codes: Array[int]) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for key_code: int in key_codes:
		InputMap.action_add_event(action_name, _key_event(key_code))


## 상황: 저장 데이터처럼 정적 타입이 없는 Variant를 키 배열로 사용하기 전에 호출한다.
## 순서: ① 값이 Array인지 검사 ② 배열이면 각 원소를 int로 변환해 결과에 append.
## 결과: 배열이 아니면 빈 배열, 배열이면 타입이 보장된 `Array[int]`를 반환한다.
static func _typed_keys(values: Variant) -> Array[int]:
	var result: Array[int] = [] # 변환에 성공한 물리 keycode를 순서대로 담는 배열.
	if values is Array:
		for value: Variant in values:
			result.append(int(value))
	return result


## 상황: 정수 keycode를 InputMap에 등록 가능한 객체로 바꿔야 할 때 호출한다.
## 순서: ① InputEventKey 생성 ② physical_keycode 대입.
## 결과: 새 InputEventKey 객체를 반환한다.
static func _key_event(key_code: int) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new() # InputMap이 소유하게 될 새 키 이벤트.
	event.physical_keycode = key_code
	return event
