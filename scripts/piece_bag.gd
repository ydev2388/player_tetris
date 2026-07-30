class_name Stage4PieceBag
extends RefCounted

## [역할 / C++ 대응]
## 테트리스의 7-bag 난수 생성기다. 각 묶음에는 7종이 정확히 한 번씩 들어간다.
## `_pieces`는 `std::vector<int>`, `_random`은 난수 엔진에 대응한다.
##
## [호출 관계]
## 생성/호출자: GameController.reset_game(), spawn_next_piece(), 단위 테스트.
## 호출 대상: Stage4TetrominoData.TYPE_COUNT와 Godot RandomNumberGenerator.

var _random: RandomNumberGenerator = RandomNumberGenerator.new() # bag 셔플에만 쓰는 난수 엔진.
var _pieces: Array[int] = [] # 아직 뽑히지 않은 타입들. 배열 뒤쪽에서 하나씩 꺼낸다.


## 상황: `Stage4PieceBag.new(seed)`로 객체를 만들 때 자동 호출되는 C++ 생성자 대응 함수다.
## 순서: ① seed가 0 이상인지 검사 ② 있으면 난수 seed 고정, 없으면 `randomize()`.
## 결과: 테스트에서는 재현 가능한 수열, 실제 게임에서는 실행마다 다른 수열을 준비한다.
func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_random.seed = seed_value
	else:
		_random.randomize()


## 상황: GameController가 현재 또는 다음 피스 한 개를 요구할 때 호출한다.
## 순서: ① `_pieces.is_empty()` 검사 ② 비었으면 `_refill()` ③ `pop_back()`으로 한 개 제거.
## 결과: 제거된 타입을 반환하고 bag의 남은 개수는 1 감소한다.
func next_piece() -> int:
	if _pieces.is_empty():
		_refill()
	return _pieces.pop_back()


## 상황: 테스트나 진단 코드가 현재 bag 잔량을 확인할 때 호출한다.
## 순서: `_pieces.size()`를 조회하는 한 단계뿐이다.
## 결과: 배열을 바꾸지 않고 남은 피스 개수를 반환한다.
func remaining_count() -> int:
	return _pieces.size()


## 상황: `next_piece()`가 빈 bag을 발견했을 때만 호출한다.
## 순서: ① 기존 배열 clear ② 0~TYPE_COUNT-1 삽입 ③ 뒤에서 앞으로 임의 index와 swap.
## 결과: 7종이 정확히 한 번씩 든 새 Fisher-Yates 셔플 bag이 만들어진다.
func _refill() -> void:
	_pieces.clear()
	for piece_type: int in range(Stage4TetrominoData.TYPE_COUNT):
		_pieces.append(piece_type)

	for index: int in range(_pieces.size() - 1, 0, -1):
		var swap_index: int = _random.randi_range(0, index) # 현재 index와 교환할 앞쪽 임의 위치.
		var temporary: int = _pieces[index] # swap 중 덮어쓰지 않도록 보관하는 임시 타입.
		_pieces[index] = _pieces[swap_index]
		_pieces[swap_index] = temporary
