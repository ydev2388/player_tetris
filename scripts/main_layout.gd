class_name MainLayout
extends RefCounted

## [역할 / C++ 대응]
## 게임 화면의 좌표계와 공용 배치 상수를 한곳에서 제공하는 static layout namespace다.
## C++로 보면 인스턴스를 만들지 않는 `struct MainLayout`의 `static constexpr` 값에 가깝다.
## 호출자: GameView, BoardPhysics, CharacterController.

const BASE_CELL_SIZE: float = 32.0 # 원본 설계 좌표계에서 블록 한 칸의 길이.
const DISPLAY_SCALE: float = 1.5 # 원본 좌표를 실제 게임 화면으로 확대하는 비율.
const CELL_SIZE: float = BASE_CELL_SIZE * DISPLAY_SCALE # 실제 화면/물리에서 쓰는 48px 셀 길이.
const BOARD_SIZE: Vector2 = Vector2(10.0, 20.0) * CELL_SIZE # 숨은 행을 제외한 보드 표시 크기.
const GAME_VIEWPORT_SIZE: Vector2i = Vector2i(560, 1140) # feat/stage-system 게임 화면 규격.
const BOARD_ORIGIN: Vector2 = Vector2(40.0, 120.0) # 상단 스테이지 HUD 아래 보드 좌표.


## 상황: 32px 기준 scalar를 5차 표시 좌표로 바꿀 때 호출된다.
## 순서: 입력값에 DISPLAY_SCALE을 곱한다.
## 결과: 전역 상태를 바꾸지 않고 확대된 float 값을 반환하는 C++ inline 함수처럼 동작한다.
static func scaled(value: float) -> float:
	return value * DISPLAY_SCALE
