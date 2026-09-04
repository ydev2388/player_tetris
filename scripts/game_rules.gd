class_name MainGameRules
extends RefCounted

## Scene이나 입력과 무관한 게임 규칙 상수다.
## 명령 호출자가 지속시간/최대 길이를 주입해 불변식을 우회하지 못하도록
## GameSession이 이 값을 직접 사용한다.

const PLAYING_STATE: int = 0
const DEFAULT_PLAYER_LIVES: int = 3

const FIREFIGHTER_WATER_MAX_STEPS: int = 3
const FIREFIGHTER_WATER_DURATION_SECONDS: float = 4.0
const SHIELD_BARRIER_DURATION_SECONDS: float = 2.0
const CLOCK_FREEZE_DURATION_SECONDS: float = 3.0
const NINJA_SHURIKEN_IMPACT_DURATION_SECONDS: float = 0.37
const TIMER_EPSILON_SECONDS: float = 0.000001


static func is_direction_valid(direction: int) -> bool:
	return direction == -1 or direction == 1
