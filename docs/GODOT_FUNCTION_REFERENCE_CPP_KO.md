# Block Fighter 5차 Godot 함수 보고서 — C++ 학습자용

이 문서는 5차 프로젝트의 GDScript 함수를 파일별로 분리해 설명한다. 변수는
`GODOT_VARIABLE_REFERENCE_CPP_KO.md`에서 별도로 다룬다.

## 1. GDScript 함수를 C++ 관점에서 읽는 법

| GDScript | C++에서 가까운 개념 |
| --- | --- |
| `func _ready()` | object graph 연결이 끝난 뒤 호출되는 lifecycle callback |
| `func _physics_process(delta)` | 고정 timestep game loop callback |
| `func _process(delta)` | 가변 render timestep update callback |
| `static func` | 인스턴스 상태를 읽지 않는 `static` 멤버 함수 |
| `signal.connect(callable)` | observer에 callback을 등록하는 동작 |
| `emit()` | 등록된 observer callback 호출 |
| `call_deferred()` | 현재 call stack이 끝난 뒤 실행할 작업 queue 등록 |
| `Variant` | `std::variant`/type-erased value와 유사한 런타임 타입 값 |
| `as Type` | 런타임 검사 뒤 downcast한 typed 참조 |
| `queue_free()` | 즉시 `delete`가 아니라 안전한 시점에 파괴 예약 |

## 2. 전체 호출 흐름

1. `BlockFighterStartScreen._ready()`가 설정·화면·overlay를 구성한다.
2. `start_game()`이 `main.tscn`을 instantiate한다.
3. `MainGameController._physics_process()`가 피스 중력과 lock delay를 진행한다.
4. `MainCharacterController._physics_process()`가 캐릭터 상태 기계를 진행한다.
5. controller/character signal이 `MainGameView._refresh()`와 `MainBoardPhysics._sync_from_model()`을 호출한다.
6. View의 `_draw()`와 TutorialCanvas의 `_draw()`는 상태를 읽어 화면만 그린다.

## 3. 데이터·배치 유틸리티

### `scripts/main_layout.gd`

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `scaled(value)` | 32px 기준 scalar에 `DISPLAY_SCALE`을 곱한다. | 5차 화면·물리 좌표계의 float를 반환한다. |

### `scripts/tetromino_data.gd`

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `get_cells(type, rotation)` | 기준 네 셀을 복사하고 O가 아니면 `rotation mod 4`회 회전한다. | 원점 기준 네 `Vector2i`를 반환한다. |
| `get_display_name(type)` | enum을 `match`로 I/J/L/O/S/T/Z에 대응시킨다. | atlas key 또는 잘못된 타입의 `?`를 반환한다. |
| `_base_cells(type)` | 타입별 회전 0 좌표 네 개를 새 배열로 만든다. | 호출자가 바꿔도 공유 상수가 손상되지 않는 배열을 반환한다. |
| `_rotate_clockwise(cells, is_i)` | I는 반 칸 중심, 나머지는 `(1,1)` 중심으로 좌표를 90도 회전한다. | 회전된 새 좌표 배열을 반환한다. |

### `scripts/piece_bag.gd`

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_init(seed)` | 난수 seed를 고정하거나 randomize하고 bag을 채운다. | 테스트용 재현 수열 또는 실제 무작위 수열을 준비한다. |
| `next_piece()` | bag이 비면 `_refill()`하고 배열 끝 원소를 제거한다. | 7종 중 다음 타입 하나를 반환한다. |
| `_refill()` | 0~6 타입을 채운 뒤 Fisher–Yates 방식으로 교환한다. | 각 타입이 정확히 한 번 든 새 bag을 만든다. |

### `scripts/input_actions.gd`

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `get_definitions()` | 입력 정의 전체를 deep copy한다. | UI가 안전하게 순회할 메타데이터를 반환한다. |
| `get_definition(action)` | 정의 배열을 앞에서부터 검색한다. | 일치 Dictionary 또는 빈 Dictionary를 반환한다. |
| `get_default_keys(action)` | 정의의 Variant 기본 배열을 `Array[int]`로 변환한다. | action별 typed 기본 키를 반환한다. |
| `ensure_defaults()` | 모든 action을 순회해 누락된 action/event만 보충한다. | 사용자 커스텀 event를 지우지 않는다. |
| `apply_bindings(bindings)` | action event를 지우고 전달된 유효 키만 다시 등록한다. | InputMap을 설정 Dictionary와 동일하게 만든다. |
| `_ensure_action(action, keys)` | action 존재 보장 뒤 각 기본 키 중 없는 것만 추가한다. | 중복 없는 기본 action을 만든다. |
| `_typed_keys(values)` | Variant가 Array인지 확인하고 각 원소를 int로 변환한다. | 동적 타입 경계 밖으로 typed 배열을 반환한다. |
| `_key_event(key)` | `InputEventKey`를 생성하고 `physical_keycode`를 대입한다. | InputMap에 등록할 새 event를 반환한다. |

### `scripts/character_animation_data.gd`

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `texture_for_character(character_id)` | 캐릭터 ID를 해당 캐릭터의 단일 통합 atlas에 대응시킨다. | 모든 animation 상태가 함께 들어 있는 `Texture2D` 한 장을 반환한다. |
| `region_for(state, elapsed)` | 시간/프레임 길이로 index를 만들고 반복 상태는 modulo, 일회성은 clamp한다. | atlas에서 잘라낼 `Rect2`를 반환한다. |

## 4. 보드 모델과 물리 동기화

### `scripts/board_model.gd`

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_init()` | 생성 직후 `reset()`을 호출한다. | 빈 22×10 보드를 준비한다. |
| `reset()` | 기존 행을 지우고 `_empty_row()`를 22번 추가한다. | 이전 고정 블록을 모두 제거한다. |
| `can_place(type, rotation, origin)` | 네 로컬 셀에 origin을 더해 경계와 점유를 검사한다. | 전부 비어 있을 때만 `true`다. |
| `get_drop_distance(...)` | 한 칸 아래 후보가 가능한 동안 거리를 증가시킨다. | 충돌 직전까지의 정수 낙하 거리를 반환한다. |
| `lock_piece(...)` | 네 셀을 보드 좌표로 바꿔 type 값을 기록한다. | 활성 피스를 고정 셀로 전환한다. |
| `clear_full_lines()` | 찬 행은 세고, 생존 행은 보존한 뒤 위쪽 빈 행을 보충한다. | 삭제 행 수와 압축된 보드를 남긴다. |
| `has_blocks_in_hidden_rows()` | 숨은 두 행을 순회해 첫 점유에서 반환한다. | top-out 여부를 bool로 반환한다. |
| `is_inside(cell)` | x/y 하한과 상한을 AND로 검사한다. | 안전한 배열 접근 가능 여부를 반환한다. |
| `get_cell(cell)` | 경계 밖이면 EMPTY, 안이면 `cells[y][x]`를 읽는다. | 안전한 셀 값을 반환한다. |
| `_is_row_full(y)` | 행에서 EMPTY를 찾으면 즉시 실패한다. | 행 완성 여부를 반환한다. |
| `_empty_row()` | 폭 10의 `PackedInt32Array`를 만들고 EMPTY로 채운다. | 다른 행과 저장소를 공유하지 않는 새 행을 반환한다. |

### `scripts/board_physics.gd`

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_ready()` | 경계 생성, controller signal 연결, 첫 모델 동기화를 수행한다. | 물리 object graph가 논리 모델을 구독한다. |
| `_sync_from_model()` | 보드 signature가 바뀌면 고정 collider를 재구성하고 활성 collider는 항상 갱신한다. | 논리 셀과 물리 충돌체를 일치시킨다. |
| `_on_game_restarted()` | signature cache를 sentinel로 바꾸고 동기화한다. | 같은 모양의 새 보드도 강제로 재구성한다. |
| `_build_boundaries()` | 바닥·좌벽·우벽 box shape를 추가한다. | 캐릭터가 보드 외곽을 통과하지 못한다. |
| `_rebuild_locked_colliders()` | 이전 shape 제거 뒤 모든 점유 셀에 box를 만든다. | 고정 보드 body가 최신 상태가 된다. |
| `_sync_active_piece()` | 이전 네 shape를 제거하고 active 원점·회전의 네 셀을 만든다. | 이동 가능한 AnimatableBody2D가 controller와 일치한다. |
| `_clear_shapes(body)` | 자식 snapshot 중 `CollisionShape2D`만 제거한다. | body와 다른 자식은 보존한다. |
| `_add_box_shape(body, center, size)` | RectangleShape2D와 CollisionShape2D를 조립해 child로 연결한다. | body가 새 충돌 사각형의 수명을 소유한다. |
| `_board_signature()` | 행 우선으로 `hash*31 + value`를 누적한다. | 보드 변경 감지용 정수를 반환한다. |
| `_validate_character()` | character가 유효하면 위치 검사를 위임한다. | deferred 호출 시 삭제된 객체 접근을 피한다. |

## 5. 게임 컨트롤러

### `scripts/game_controller.gd`

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_ready()` | 입력 기본값을 보장하고 `reset_game()`을 호출한다. | 첫 피스가 있는 PLAYING 상태가 된다. |
| `_physics_process(delta)` | pause/restart 상태를 검사하고 명상 배율 delta로 중력→lock 순서 진행한다. | 물리 timestep 기준 게임 시간이 진행된다. |
| `_advance_gravity(delta)` | accumulator가 중력 간격을 넘는 동안 한 칸씩 내린다. | 이동할 때 descent signal, 막히면 잔여 시간을 정리한다. |
| `_advance_lock_delay(delta)` | 접지 중 시간을 누적하고 0.5초면 lock, 공중이면 초기화한다. | 활성 피스의 고정 시점을 결정한다. |
| `reset_game(seed)` | 보드/점수/level/timer/random/bag을 초기화하고 첫 피스를 생성한다. | 완전히 새 게임 상태와 restart signal을 만든다. |
| `spawn_next_piece()` | next를 active로 옮기고 유효 원점 중 하나를 선택한다. | 성공 true, 후보가 없으면 GAME_OVER와 false다. |
| `set_meditation_active(active)` | PLAYING일 때만 flag를 갱신한다. | 테트리스 시간 배율을 1 또는 2로 만든다. |
| `_valid_spawn_origins(type, side_margin)` | 피스의 실제 min/max x에 좌우 여백을 적용하고 `can_place()` 가능한 origin을 수집한다. | 원점 기준 오차 없이 지정 여백을 지킨 생성 후보를 반환한다. |
| `_choose_random_spawn_origin(type)` | 한 칸 여백 후보를 우선하고, 전부 막혔을 때만 여백 0 후보로 fallback한 뒤 전용 RNG로 선택한다. | 평소에는 벽과 한 칸 떨어지고 조기 게임오버 상황에서는 벽 옆을 허용한 origin 또는 null을 반환한다. |
| `push_active_piece(direction, distance)` | 방향 정규화 뒤 모든 중간 위치를 검사하고 마지막에 한 번 이동한다. | 전 경로가 비었을 때만 true와 원자적 이동을 남긴다. |
| `try_rotate(direction, forbidden)` | 목표 회전과 SRS 후보를 만들고 보드/외부 금지 셀을 순서대로 검사한다. | 첫 성공 후보만 적용하고 bool을 반환한다. |
| `_piece_overlaps_forbidden_cells(...)` | 후보 피스 네 셀을 외부 점유 배열과 비교한다. | 하나라도 겹치면 true다. |
| `lock_active_piece()` | 고정→줄 삭제→점수/level→top-out→다음 spawn 순서로 실행한다. | 한 피스 수명을 끝내고 다음 상태를 결정한다. |
| `toggle_pause()` | GAME_OVER는 무시하고 PLAYING/PAUSED를 토글한다. | 명상 정리와 change signal을 동반한다. |
| `end_game()` | state를 GAME_OVER로 바꾸고 명상을 해제한다. | 시간 진행을 멈추고 View 갱신을 요청한다. |
| `is_grounded()` | 현재 원점 한 칸 아래의 `can_place()`를 부정한다. | 접지 bool을 반환한다. |
| `ghost_origin()` | board의 drop distance를 active origin에 더한다. | 실제 상태를 바꾸지 않는 예상 착지 원점을 반환한다. |
| `gravity_interval()` | level별 감소식을 적용하고 0.08초 하한을 둔다. | 셀당 낙하 간격을 반환한다. |
| `line_clear_score(lines, level)` | 1~4줄 표를 조회하고 최소 level 1을 곱한다. | 잘못된 줄 수는 0, 정상 점수를 반환한다. |
| `level_for_lines(lines)` | 음수를 0으로 제한하고 `lines/10 + 1`을 계산한다. | 누적 줄 수의 level을 반환한다. |
| `_reset_piece_timers()` | fall/lock/reset count를 0으로 만든다. | 이전 피스 시간 상태를 제거한다. |
| `_reset_lock_after_transform(was_grounded)` | 변형 전후 접지와 reset 상한을 검사한다. | 최대 15회 안에서 lock delay를 연장한다. |

## 6. 캐릭터 컨트롤러

### 프레임과 이동

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_ready()` | 입력·signal·SFX player를 준비하고 캐릭터를 reset한다. | 첫 physics frame 전 모든 상태가 유효하다. |
| `_physics_process(delta)` | 비활성→timer→재스폰→명상→펀치→매달림/이동을 우선순위로 실행한다. | 한 frame에 배타적 상태 하나가 진행된다. |
| `_stop_for_inactive_game()` | 명상 loop를 정리하고 속도를 0으로 만든다. | PAUSED/GAME_OVER에서 행동이 멈춘다. |
| `_handle_self_respawn_input(delta)` | hold/release latch와 1초 임계값을 관리한다. | 짧은 입력은 취소, 완료 입력은 생명을 사용한다. |
| `_reset_self_respawn_input()` | hold time과 release latch를 초기화한다. | 다음 입력이 0초부터 시작한다. |
| `_can_start_meditating()` | 아래키·접지·비매달림을 AND 검사한다. | 상태를 바꾸지 않고 진입 가능 bool을 반환한다. |
| `_finish_physics_frame(delta)` | visual update 후 위치 유효성을 검사한다. | 모든 활성 branch가 같은 후처리를 공유한다. |
| `_handle_meditation(delta)` | 유지 조건을 재검사하고 정지·중력·접지를 처리한다. | 발판을 잃거나 키를 놓으면 즉시 종료한다. |
| `_handle_movement(delta)` | 입력→방향→수평속도→중력→행동→grab→move_and_slide 순서다. | 일반 캐릭터 이동을 한곳에서 조정한다. |
| `_update_facing(input)` | 0이 아닌 축의 부호를 facing과 sprite 반전에 반영한다. | 액션 방향과 화면 방향이 동기화된다. |
| `_update_ground_contact(grounded)` | 접지면 coyote timer를 갱신하고 벽 점프 보정을 끝낸다. | 지상 점프 여유 시간을 만든다. |
| `_apply_horizontal_movement(input, grounded, delta)` | 목표 속도와 가속도를 선택해 `move_toward`한다. | 지상/공중/벽 복귀 조향이 다른 가속도를 쓴다. |
| `_apply_gravity(grounded, delta)` | 공중에서 상승/하강 배율 중력을 더하고 최대 낙하를 제한한다. | 안정된 수직 속도를 만든다. |
| `_handle_action_input()` | InputMap을 bool snapshot으로 바꿔 dispatcher에 전달한다. | 테스트와 실입력이 같은 결정 함수를 쓴다. |
| `_dispatch_action_input(flip, jump)` | flip을 jump보다 우선하고 선택된 함수만 호출한다. | 같은 frame 중복 행동을 막는다. |
| `_cancel_jump_intent()` | buffer/grace/variable jump/벽 조향을 초기화한다. | flip과 이전 jump 의도가 겹치지 않는다. |
| `_handle_jump_input(pressed)` | hang grace 벽점프, buffer, coyote 순서로 검사한다. | 조건에 맞으면 즉시 점프하거나 buffer를 남긴다. |
| `_start_ground_jump()` | 위쪽 속도와 관련 timer/flag를 설정한다. | 가변 높이 지상 점프가 시작된다. |
| `_apply_variable_jump_cut()` | 상승 중 release면 속도를 0.45배, 정점 이후 flag를 해제한다. | 짧게/길게 누른 점프 높이가 달라진다. |
| `_handle_stamina_landing()` | 비접지→접지 전환만 찾아 stamina를 100으로 만든다. | 연속 접지 frame의 반복 충전을 막는다. |

### 매달리기와 벽 점프

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_handle_hanging(delta)` | 종료조건→body 추적→발판→상하 이동→stamina/점프 순서다. | 일반 중력 branch와 분리된 hang 상태를 유지한다. |
| `_handle_hang_exit_conditions()` | stamina, grab release, 같은 frame jump를 검사한다. | hang을 끝냈으면 true를 반환한다. |
| `_follow_hang_body()` | collider의 frame 위치 차이를 character에 더한다. | 움직이는 활성 피스를 따라간다. |
| `_move_while_hanging()` | 상하 속도를 적용하고 RayCast를 강제 갱신한다. | 벽 접촉을 잃으면 false와 hang 종료다. |
| `_hang_climb_direction()` | 위=-1, 아래 action=+1을 합산한다. | -1/0/+1 수직 입력을 반환한다. |
| `_finish_hanging_frame(delta)` | 속도 정지, stamina 감소, jump, signal을 처리한다. | 정지 hang도 자원을 소비한다. |
| `_perform_wall_jump()` | 벽 방향 snapshot 뒤 hang 종료·재잡기/조향 timer·반대 속도를 설정한다. | 벽 반대 위쪽으로 점프한다. |
| `_try_start_hang()` | facing 방향 Ray 우선, 반대 Ray fallback, collider/stamina를 검사한다. | 유효한 벽/피스에 hang body를 저장한다. |
| `_exit_hang()` | flag와 body 참조를 비운다. | 다음 frame부터 일반 이동으로 돌아간다. |
| `_cancel_wall_jump_control()` | 관련 countdown을 0으로 만든다. | 특수 공중 조향을 즉시 끝낸다. |

### 펀치·명상·블록 플립

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_handle_punch()` | X press를 확인해 기본 공격을 호출한다. | 입력 즉시 한 칸 펀치 판정을 예약한다. |
| `_perform_tap_punch()` | attack animation/cooldown/SFX와 1칸 판정을 예약한다. | 짧은 입력의 일반 펀치를 만든다. |
| `_start_attack_animation()` | animation state와 시간을 ATTACK 첫 frame으로 바꾼다. | 다른 이동 frame을 공격 모션이 잠시 덮는다. |
| `_begin_punch_hit_confirmation(stage)` | stage와 0.1초 판정 시간을 멤버에 기록한다. | 이후 frame hitbox 검사를 예약한다. |
| `_resolve_pending_punch(delta)` | hit면 피스 이동/비용/cue, miss면 timeout 감소/feedback을 처리한다. | 한 공격이 정확히 한 번 성공 또는 만료된다. |
| `_set_meditating(active)` | 실제 가능 조건을 재검사하고 다른 행동을 정리해 controller 배율과 SFX를 바꾼다. | 명상 진입/종료가 원자적으로 적용된다. |
| `_attempt_rotation_kick()` | cooldown→spin→근접→SRS 회전→상승 예약/실패 처리를 한다. | stamina 없이 블록 플립과 feedback을 만든다. |
| `_apply_pending_rotation_launch(delta)` | 새 collider와 swept rect 겹침을 검사한다. | 안전한 다음 frame에만 상승 속도를 적용한다. |
| `_rotation_forbidden_cells()` | 캐릭터 collider와 양의 면적으로 겹치는 보드 셀을 수집한다. | SRS가 캐릭터 몸을 덮지 못하게 한다. |
| `_character_collider_rect()` | position과 고정 크기/offset으로 Rect를 만든다. | sprite 회전에 독립적인 몸체 영역을 반환한다. |
| `_active_piece_overlaps_rect(rect)` | 활성 피스 네 셀 rect와 대상 rect를 비교한다. | 하나라도 겹치면 true다. |
| `_start_rotation_spin()` | spin timer/elapsed/direction과 sprite 각도를 초기화한다. | 0.42초 한 바퀴 연출을 시작한다. |

### 압착·피해·재스폰·기하 helper

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `handle_active_piece_descended(prev, current)` | 한 칸 하강, 이전 비접촉, 현재 `CrushSensor` 접촉, 위에서 통과, 고정 지지면 순서를 검사한다. | 자연 낙하 압착이면 피해를 준다. |
| `_crush_sensor_rect()` | 씬의 `30×12` RectangleShape2D를 캐릭터 전역 Rect로 변환한다. | sprite와 무관한 공통 머리 압착 영역을 반환한다. |
| `_active_piece_overlaps_crush_sensor(origin, sensor_rect)` | active 네 셀과 고정 센서 Rect의 양의 면적 교차를 검사한다. | 센서에 피스가 겹치면 true다. |
| `_active_piece_crossed_crush_sensor_from_above(prev, current, sensor_rect)` | 이전·현재 셀 Rect의 수직 통과 방향과 수평 겹침을 검사한다. | 위에서 센서를 통과했으면 true다. |
| `_has_fixed_support_underfoot()` | 발밑 표본 위치의 고정 보드 셀을 검사한다. | hang 중 고정 바닥 지지 여부를 반환한다. |
| `validate_position()` | 보드 아래 이탈과 안전 위치를 검사한다. | 비정상 이탈을 무피해 복구한다. |
| `_is_below_board()` | character y와 복구 경계를 비교한다. | 화면 아래 이탈 bool을 반환한다. |
| `take_damage()` | 무적 guard 뒤 공통 생명 감소 함수를 호출한다. | 연속 피해를 막는다. |
| `_lose_life_and_respawn(message)` | 생명 감소·행동 정리→게임오버 또는 안전 상단 재스폰을 실행한다. | 피해와 자력 재스폰의 공통 결과를 적용한다. |
| `self_respawn_hold_ratio()` | hold time/필요 시간을 clamp한다. | View용 0~1 진행률을 반환한다. |
| `_punch_hits_active_piece()` | 현재 punch rect와 active piece 근접 검사를 위임한다. | release 판정의 bool을 반환한다. |
| `_punch_hitbox_rect()` | facing 방향으로 character 앞 Rect를 계산한다. | 주먹 판정 영역을 반환한다. |
| `_is_near_active_piece(horizontal, radial)` | 네 active 셀 중심과 character/방향 거리를 검사한다. | 액션 범위 안의 셀이 있으면 true다. |
| `_find_safe_position()` | 아래→위, 중앙→바깥 셀을 검색하고 공간·발판을 검사한다. | 이탈 복구 위치 또는 null을 반환한다. |
| `_find_top_respawn_position()` | 상단 후보 중 전용 RNG index를 선택한다. | 피해 재스폰 위치 또는 null을 반환한다. |
| `_top_respawn_candidates()` | 각 열 중심의 몸체 rect가 블록과 겹치는지 검사한다. | 안전 후보 배열을 반환한다. |
| `_respawn_overlaps_any_block(pos)` | 고정 220셀과 활성 4셀의 양의 면적 교차를 검사한다. | 재스폰 불가 여부를 반환한다. |
| `_respawn_rect_at(pos)` | 중심 좌표를 고정 몸체 크기의 Rect로 바꾼다. | frame과 무관한 재스폰 검사 영역을 반환한다. |
| `_rects_overlap_with_area(a,b)` | 두 축의 겹침 길이가 모두 양수인지 검사한다. | 경계 접촉을 제외한 교차 bool을 반환한다. |
| `_cell_is_solid(cell)` | 고정 셀과 active 네 셀을 조회한다. | 안전 위치 검색용 점유 bool을 반환한다. |
| `_board_cell_rect(cell)` | hidden row를 제거하고 cell을 화면 Rect로 변환한다. | 물리/기하 검사에 쓸 Rect를 반환한다. |

### timer·animation·audio·reset

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_update_timers(delta)` | 모든 countdown을 0 아래로 가지 않게 줄이고 feedback 만료를 알린다. | frame 상태 timer가 최신화된다. |
| `_update_visual_state(delta)` | spin→modulation→blink→frame 순서로 호출한다. | 시각 효과 합성 순서를 고정한다. |
| `_update_spin_visual(delta)` | elapsed smoothstep으로 한 바퀴 각도를 계산하고 완료 시 seed한다. | 누적 오차 없는 flip 회전을 만든다. |
| `_seed_post_spin_animation()` | 접지면 idle, 공중이면 속도별 jump frame을 선택한다. | flip 뒤 animation이 자연스럽게 이어진다. |
| `_update_sprite_modulation()` | 명상 pulse 또는 기본색을 계산한다. | 행동 상태를 색으로 표시한다. |
| `_update_damage_blink()` | 무적 중 12Hz phase로 visible을 토글한다. | 피해 무적 피드백을 만든다. |
| `_advance_character_animation(delta)` | 상태 우선순위와 시간 진행 뒤 frame을 적용한다. | 반복/일회 animation을 갱신한다. |
| `_get_animation_state()` | flip→attack→hang→jump→idle 순서로 첫 상태를 반환한다. | 배타적인 animation key를 결정한다. |
| `_apply_animation_frame()` | texture/region/target size를 조회해 sprite에 적용한다. | 원본 frame 크기와 무관한 화면 크기를 만든다. |
| `_animation_target_size(state)` | flip/attack/일반 상태별 목표 크기를 선택한다. | sprite scaling 기준 Vector2를 반환한다. |
| `_create_sfx_player()` | player 생성, SFX bus 설정, child 연결을 한다. | 캐릭터 수명에 묶인 audio channel을 반환한다. |
| `_play_sfx(stream)` | 주 channel stream을 교체하고 재생한다. | 일반 단발음을 낸다. |
| `_play_sfx_cue(stream)` | 보조 channel을 사용한다. | 주 효과음을 끊지 않는 cue를 낸다. |
| `_play_block_elimination_sfx()` | 줄 삭제 stream을 cue helper에 전달한다. | signal adapter 역할을 한다. |
| `_start_meditation_loop()` / `_stop_meditation_loop()` / `_restart_meditation_loop()` | 명상 지속 player를 상태에 맞게 시작·정지·재개한다. | pause와 상태 전환에도 loop를 일관되게 관리한다. |
| `_reset_character()` | 모든 public/private 상태·audio·position·sprite를 초기화한다. | 이전 게임 상태가 남지 않는 캐릭터를 만든다. |

## 7. 게임 View

### `scripts/game_view.gd`

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_ready()` | viewport 크기 적용→font/UI 생성→signal 연결→첫 refresh 순서로 실행한다. | 게임 HUD와 redraw 구독이 준비된다. |
| `_draw()` | 배경→panel→board→명상→next→캐릭터 card→bar→overlay 순서로 그린다. | 레이어 순서가 고정된 한 frame을 만든다. |
| `_build_interface()` | 제목·수치·목숨·stamina·punch·flip·feedback·status Label을 만든다. | 이후 갱신할 retained UI 참조를 보관한다. |
| `_apply_game_viewport_size()` | content scale을 게임 해상도로 바꾸고 headless가 아니면 window도 조정한다. | 메뉴 안에서 게임 전용 1000×1080 화면을 사용한다. |
| `_create_label(...)` | Label 생성·배치·theme·parent 연결을 한다. | View가 소유하는 Label을 반환한다. |
| `_build_self_respawn_progress()` | 높은 z-index panel과 배경/채움 bar를 숨김 상태로 만든다. | Q hold 진행 UI를 준비한다. |
| `_draw_panel(rect)` | StyleBoxFlat으로 배경·테두리·그림자를 그린다. | 보드/HUD 공통 panel을 만든다. |
| `_draw_board()` | 빈 grid/고정 셀→ghost→active 순서로 그린다. | 논리 보드를 숨은 행 없이 표시한다. |
| `_draw_next_piece()` | next type의 회전 0 네 셀을 작은 cell size로 그린다. | 다음 피스 preview를 표시한다. |
| `_draw_meditation_effect()` | 비명상이면 반환, 아니면 시간 pulse·ring·문구를 그린다. | gameplay 상태를 바꾸지 않는 청색 효과를 만든다. |
| `_draw_character_bars()` | stamina/charge/flip 비율을 공통 bar helper에 전달한다. | 세 연속 수치를 같은 규격으로 표시한다. |
| `_draw_bar(rect,ratio,color)` | ratio clamp→채움 폭→배경/채움/외곽선을 그린다. | 범위 밖 값도 넘치지 않는 bar를 만든다. |
| `_draw_state_overlay()` | PLAYING이면 반환, 아니면 반투명 배경과 상태 문구를 그린다. | PAUSED/GAME_OVER를 아래 화면과 분리한다. |
| `_draw_block(rect,type,alpha)` | type 이름으로 atlas region을 찾아 texture 또는 fallback rect를 그린다. | 모든 고정/활성/next 셀을 공통 표시한다. |
| `_draw_ghost(rect,type)` | 반투명 block과 내부 outline을 그린다. | 실제 active와 구별되는 착지 예측을 만든다. |
| `_cell_rect(cell)` | hidden rows를 빼고 cell size와 board origin을 적용한다. | 논리 셀의 View 좌표 Rect를 반환한다. |
| `_refresh()` | controller/character 수치를 Label과 progress panel에 반영하고 redraw를 요청한다. | retained UI와 즉시-mode draw가 같은 최신 상태를 읽는다. |

## 8. 시작 화면 설정과 UI factory

### `start_screen/scripts/start_screen_settings.gd`

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_init(path)` | 저장 경로를 멤버에 복사한다. | 사용자/테스트 cfg를 같은 클래스가 처리한다. |
| `_ready()` | load→InputMap 적용→audio 적용 순서다. | 첫 화면 전에 설정이 활성화된다. |
| `get_action_definitions()` | 입력 메타데이터를 deep copy한다. | UI가 안전하게 순회한다. |
| `get_action_label(action)` | 정의의 label을 조회하고 없으면 내부 이름을 쓴다. | 항상 표시 가능한 String을 반환한다. |
| `get_action_keys(action)` | Dictionary Variant 배열을 `Array[int]`로 복사한다. | 외부 수정이 원본에 전파되지 않는다. |
| `get_binding_text(action)` | KEY_NONE을 제외하고 키 이름을 `/`로 join한다. | 튜토리얼용 결합 문자열을 반환한다. |
| `get_slot_text(action,slot)` | 범위/미지정 검사 뒤 키 이름을 변환한다. | 버튼용 이름 또는 `미지정`을 반환한다. |
| `set_binding(action,slot,key)` | action/slot/예약키/충돌 검사→메모리/InputMap/파일/signal commit 순서다. | 성공/실패 Dictionary를 반환한다. |
| `clear_secondary_binding(action)` | 두 슬롯 action인지 확인하고 두 번째를 KEY_NONE으로 만든다. | 주 키를 보존한 채 보조 키를 지운다. |
| `find_conflict(key,ignored_action,ignored_slot)` | 모든 action/slot을 선형 탐색한다. | 충돌 정보 또는 빈 Dictionary를 반환한다. |
| `reset_bindings_to_defaults()` | 기본값→InputMap→save→signal 순서다. | 모든 키를 현재 버전 기본값으로 돌린다. |
| `apply_bindings()` | `_bindings`를 MainInputActions에 위임한다. | Godot 전역 InputMap을 동기화한다. |
| `set_music_percent(value)` / `set_sfx_percent(value)` | 0~100 clamp→bus→save→signal 순서다. | slider 값이 실제 출력과 파일에 반영된다. |
| `ensure_audio_buses()` | BGM/SFX 이름의 bus 존재를 보장한다. | 테스트·초기 프로젝트에서도 audio 적용이 가능하다. |
| `apply_audio()` | bus 보장 뒤 두 퍼센트를 적용한다. | AudioServer 상태가 멤버와 일치한다. |
| `load_settings()` | 기본값→ConfigFile load→입력 migration→audio→중복 복구 순서다. | 파일 없음/구버전/손상 데이터를 안전하게 처리한다. |
| `_reset_settings_to_defaults()` | 기본 키와 볼륨 100을 설정한다. | load 실패 fallback을 만든다. |
| `_load_bindings_from_config(config)` | action별 Variant를 slot 정책에 맞게 parse한다. | 유효한 action만 교체한다. |
| `_restore_escape_bindings()` | 저장 키에서 Esc만 제거하고 비면 기본값을 쓴다. | 메뉴 전용 Esc를 보호한다. |
| `_migrate_self_respawn_binding()` | Q→K→Backspace 중 충돌 없는 첫 키를 선택한다. | 기존 사용자 키를 보존하며 새 action을 보충한다. |
| `_migrate_rotation_kick_binding()` | 이전 기본 V 하나만 가진 경우 S로 바꾼다. | 사용자 지정 다른 키는 유지한다. |
| `_load_audio_from_config(config)` | 두 값을 읽어 0~100으로 clamp한다. | 누락 값은 100을 사용한다. |
| `_restore_defaults_for_duplicate_keys()` | 중복 검사가 true면 전체 키를 기본값으로 돌린다. | 잘못된 저장 파일을 일관된 상태로 복구한다. |
| `save_settings()` | 입력 배열과 audio 값을 ConfigFile에 기록한다. | `Error`를 반환하고 실패 signal을 보낸다. |
| `keycode_to_text(key)` | 특수 키 고정 표기→OS 이름→숫자 fallback 순서다. | UI용 키 문자열을 반환한다. |
| `_definition_for(action)` | MainInputActions 조회를 감싼다. | action 정의를 반환한다. |
| `_load_default_bindings()` | Dictionary를 비우고 모든 action 기본 배열을 저장한다. | 정의와 같은 key 집합을 만든다. |
| `_parse_key_array(value,slots,allow_none)` | Array/숫자/primary 정책을 검사하고 크기를 slots에 맞춘다. | 유효 typed 배열 또는 빈 배열을 반환한다. |
| `_has_duplicate_keys()` | KEY_NONE 제외 keycode를 set처럼 기록한다. | 첫 중복에서 true다. |
| `_ensure_audio_bus(name)` | index가 없을 때 bus를 추가하고 이름을 설정한다. | 동일 이름 bus가 하나 이상 존재한다. |
| `_apply_bus_volume(name,percent)` | 0이면 mute, 아니면 `linear_to_db`로 변환한다. | 실제 bus 출력이 갱신된다. |
| `_failure(message)` | 공통 실패 Dictionary를 만든다. | `{ok:false,message}`를 반환한다. |

### `start_screen/scripts/start_screen_ui.gd`

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_init(font,panel,border,text)` | 공통 theme 의존성을 멤버에 저장한다. | 재사용 factory를 준비한다. |
| `create_panel(...)` | Panel→StyleBoxFlat→parent 연결 순서다. | 둥근 panel을 반환한다. |
| `create_label(...)` | text/rect/정렬/theme를 적용해 child로 연결한다. | 갱신 가능한 Label을 반환한다. |
| `create_button(...)` | focus/mouse/theme와 5개 상태 style을 구성한다. | signal 연결 전 Button을 반환한다. |
| `create_slider(...)` | 0~100, step 1, focus 가능한 HSlider를 만든다. | parent가 소유하는 Slider를 반환한다. |
| `_button_style(...)` | 색·테두리·radius·여백을 StyleBoxFlat에 기록한다. | 상태별 독립 style을 반환한다. |

## 9. 튜토리얼 renderer

### lifecycle·페이지

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_ready()` | mouse 통과, font 후보, process를 설정한다. | animation 준비가 끝난다. |
| `_process(delta)` | 보일 때만 delta를 누적하고 1/12초씩 소비해 loop time을 갱신한다. | frame rate 독립 12FPS redraw를 만든다. |
| `set_settings(settings)` | 참조 저장과 binding signal 연결을 한다. | 키 변경 시 자동 redraw한다. |
| `set_page(index)` | index clamp와 두 timer reset을 수행한다. | 새 page를 첫 frame부터 재생한다. |
| `_draw()` | 공통 panel 뒤 현재 page 함수 하나만 호출한다. | 선택된 page frame을 그린다. |
| `_draw_movement_page()` | 왕복 이동과 두 높이 점프 위치/arrow/key를 계산한다. | page 1을 그린다. |
| `_draw_block_action_page()` | punch stage/release와 flip ratio/rotation을 계산한다. | page 2를 그린다. |
| `_draw_wall_page()` | 세 wall stage와 Bezier 위치를 계산한다. | page 3을 그린다. |
| `_draw_system_page()` | 명상 pulse·낙하와 P/R/Q shortcut을 그린다. | page 4를 그린다. |
| `_draw_special_keys_page()` | pause/restart/respawn/Esc의 상태 전후를 3.2초 loop에 배치한다. | page 5를 그린다. |

### 시간·수학 helper

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_movement_ratio(time)` | 정지/증가/정지/감소 구간을 나눈다. | 좌우 왕복 0~1 ratio다. |
| `_punch_stage(time)` | timeline 구간을 0~3 단계에 대응시킨다. | 블록 이동 표시 단계다. |
| `_punch_releasing(time)` | 세 release window 포함 여부를 검사한다. | 공격 frame 표시 bool이다. |
| `_wall_stage(time)` | 1.2/2.4초 경계로 세 단계를 나눈다. | 강조 단계 0~2다. |
| `_wall_character_position(time)` | 직선 상승과 두 quadratic Bezier를 연결한다. | 현재 캐릭터 canvas 좌표다. |
| `_smooth_ratio(value,start,end)` | normalize→clamp→cubic smoothstep 순서다. | 시작/끝 속도 0인 0~1 ratio다. |
| `_rotation_demo_angle(elapsed)` | 0.42초 진행률을 smoothstep하고 -TAU를 곱한다. | 캐릭터 회전 radians다. |
| `_quadratic_bezier(start,control,end,t)` | 표준 2차 Bezier 공식을 계산한다. | 곡선 위 Vector2를 반환한다. |
| `_loop_alpha(duration)` | 마지막 0.2초만 남은 시간 비율을 계산한다. | loop 전환 fade 0~1이다. |

### draw helper

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_draw_page_heading(title,subtitle)` | 제목 폭을 측정해 겹치지 않는 subtitle x를 계산한다. | 공통 page header를 그린다. |
| `_draw_card(rect)` | 고정 색을 round panel helper에 전달한다. | 설명 card 배경을 그린다. |
| `_draw_round_panel(...)` | 지역 StyleBoxFlat을 조립해 rect에 draw한다. | node 없는 둥근 panel을 만든다. |
| `_draw_step_badge(...)` | halo→원→숫자를 alpha와 함께 그린다. | 현재 단계 강조를 만든다. |
| `_draw_floor(origin,width)` | rect·상단선·반복 사선 pattern을 그린다. | 공통 지면을 만든다. |
| `_draw_animated_character(...)` | texture/region→aspect fit→선택적 transform→region draw 순서다. | gameplay sprite 한 frame을 그린다. |
| `_draw_tetromino(...)` | 네 cell/atlas 영역을 선택적 중심 회전으로 그린다. | 재사용 블록 예시를 만든다. |
| `_draw_arrow(...)` | 선과 end 기준 삼각형 머리를 계산한다. | 직선 방향을 표시한다. |
| `_draw_arc_arrow(...)` | Bezier sample 25개와 마지막 방향 arrowhead를 만든다. | 곡선 방향을 표시한다. |
| `_key_chip(...)` | 문자열 길이 폭·emphasis 색·halo·text를 계산한다. | 현재 키와 눌림 강조를 표시한다. |
| `_draw_shortcut_row(...)` | key chip과 54px 아래 설명을 그린다. | 시스템 키 한 행을 만든다. |
| `_text(...)` | newline이면 줄별 y 증가, 아니면 한 번 draw한다. | node 없는 한글 텍스트를 그린다. |
| `_binding(action)` | settings null guard 뒤 결합 키 문자열을 조회한다. | action 하나의 표시 키를 반환한다. |
| `_keys(a,b)` | 두 binding 결과를 `/`로 연결한다. | 좌/우 같은 쌍 키 문자열을 반환한다. |

## 10. 시작 화면 controller

### lifecycle·navigation·입력

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_ready()` | 입력/font/factory/settings/audio→화면 build→MAIN 순서다. | 전체 UI object graph를 준비한다. |
| `_draw()` | 배경/grid/장식 블록을 그린다. | 모든 메뉴 화면의 공통 배경을 만든다. |
| `show_main_menu()` | `_show_screen(MAIN)`을 호출한다. | MAIN과 첫 focus를 복원한다. |
| `show_tutorial()` | page 0→refresh→TUTORIAL 순서다. | 설명을 처음부터 연다. |
| `show_options()` | OPTIONS 상태로 전환한다. | 두 설정 카드를 표시한다. |
| `show_key_custom()` | 키 문구 refresh 후 KEY_CUSTOM으로 전환한다. | 최신 binding 표를 연다. |
| `show_volume()` | VOLUME으로 전환한다. | 볼륨 화면을 연다. |
| `next_tutorial_page()` / `previous_tutorial_page()` | index를 경계 안에서 ±1하고 refresh한다. | page와 버튼 disabled를 동기화한다. |
| `start_game()` | 기존 instance/경로/타입 검사→instantiate→GAME→signal 순서다. | 성공 bool과 실행 게임을 남긴다. |
| `request_exit()` | signal 뒤 테스트가 아니면 SceneTree quit한다. | launcher 관찰과 실제 종료를 처리한다. |
| `begin_key_capture(action,slot)` | 대상 저장→안내문→overlay 표시 순서다. | 다음 key event를 특정 슬롯에 연결한다. |
| `cancel_key_capture()` | 대상 sentinel 초기화와 overlay 숨김을 수행한다. | 캡처를 종료한다. |
| `_input(event)` | press key만 game-exit modal→Z confirm 우선순위로 처리한다. | GUI보다 앞서 global 메뉴 키를 소비한다. |
| `_unhandled_key_input(event)` | GUI 미처리 key를 capture→back 순서로 처리한다. | custom navigation 중복을 막는다. |
| `_handle_key_capture(event)` | key 추출→Settings 검증/commit→결과 표시→성공 시 닫기 순서다. | overlay가 열렸으면 true다. |
| `_handle_game_exit_prompt_input(event)` | 열린 modal의 방향/Z/X/Esc 또는 GAME의 새 Esc를 처리한다. | menu prompt 흐름을 하나의 입력 gate로 관리한다. |
| `_handle_menu_confirm_input(event)` | GAME/capture guard→Enter 소비→Z에서 focused Button emit 순서다. | 메뉴의 Z 확인을 구현한다. |
| `_is_escape_key(event)` | physical/logical key 중 하나를 비교한다. | Esc 여부 bool이다. |
| `_handle_back_navigation(event)` | 현재 화면에 따라 MAIN 또는 OPTIONS로 돌아간다. | 처리했을 때 true다. |

### 화면·overlay builder

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_build_interface()` | game host→5개 screen→3개 overlay를 만든다. | visible 전환만으로 재사용할 object graph를 만든다. |
| `_build_main_screen()` | panel/title/portrait/4버튼/footer를 만든다. | MAIN 메뉴와 focus 배열을 준비한다. |
| `_build_tutorial_screen()` | canvas/prev/next/counter/back을 만든다. | TUTORIAL 화면을 준비한다. |
| `_build_options_screen()` | KEY/VOLUME 카드와 back을 만든다. | OPTIONS 화면을 준비한다. |
| `_create_option_card(...)` | panel/title/description/button/callback을 조립한다. | 카드의 Button을 반환한다. |
| `_build_key_screen()` | title/header/rows/footer를 조립한다. | KEY_CUSTOM 화면을 만든다. |
| `_build_key_headers(screen)` | 세 열 제목을 배치한다. | 키 표 header를 만든다. |
| `_build_key_rows(screen)` | 정의 순서대로 `_build_key_row`를 호출한다. | action 수만큼 행을 만든다. |
| `_build_key_row(...)` | stripe/label/primary/secondary/cache를 구성한다. | refresh 가능한 action 행을 만든다. |
| `_add_key_row_stripe(...)` | 짝수 행에 입력을 무시하는 ColorRect를 추가한다. | 표 가독성을 높인다. |
| `_build_secondary_key_control(...)` | 1슬롯은 `—`, 2슬롯은 key/clear 버튼을 만든다. | metadata에 맞는 보조 열을 만든다. |
| `_build_key_footer(screen)` | status/reset/back을 만든다. | 키 표 하단 동작을 연결한다. |
| `_build_volume_screen()` | panel과 BGM/SFX row, 설명, back을 만든다. | VOLUME 화면을 준비한다. |
| `_create_volume_row(...)` | 이름/slider/퍼센트 label과 callback을 만든다. | 갱신할 값 Label을 반환한다. |
| `_build_capture_overlay()` | shade/panel/안내/취소를 만든다. | 숨은 key capture modal을 준비한다. |
| `_build_message_overlay()` | shade/panel/body/확인을 만든다. | 공통 오류 modal을 준비한다. |
| `_build_game_exit_overlay()` | shade/panel/Yes/No와 callback을 만든다. | 게임 복귀 확인 modal을 준비한다. |

### 상태 갱신·modal·factory

| 함수 | 호출과 내부 순서 | 결과 |
| --- | --- | --- |
| `_show_screen(type)` | 모든 일반 화면 숨김→GAME host/대상 표시→기본 focus 순서다. | screen state와 visible/focus를 일치시킨다. |
| `_refresh_tutorial()` | canvas page/counter/prev-next disabled를 갱신한다. | page UI를 동기화한다. |
| `_refresh_key_buttons()` | action cache를 순회해 slot text를 바꾸고 canvas redraw한다. | 설정표와 설명 키를 동기화한다. |
| `_clear_secondary(action)` | Settings 삭제 결과를 표시 helper로 넘긴다. | 보조 키를 지운다. |
| `_show_binding_result(result)` | message와 성공/실패 색을 적용한다. | 키 변경 결과를 표시한다. |
| `_reset_keys()` | Settings reset 후 성공 문구를 표시한다. | 기본 키를 복구한다. |
| `_on_music_changed(value)` / `_on_sfx_changed(value)` | Settings setter와 값 Label 갱신을 수행한다. | slider·AudioServer·파일을 동기화한다. |
| `_show_message(message)` / `_hide_message()` | 본문·visible·z order를 바꾸거나 숨긴다. | 공통 안내 modal을 재사용한다. |
| `_show_game_exit_prompt()` | controller snapshot/pause/physics lock→overlay→No focus 순서다. | 게임 입력을 잠근 확인 상태를 만든다. |
| `_hide_game_exit_prompt()` | overlay를 숨기고 physics와 이전 PLAYING 상태를 복원한다. | X/No 취소가 게임으로 돌아간다. |
| `_confirm_return_to_main_menu()` | prompt 숨김→game free 예약→viewport 복원→MAIN 순서다. | 실행 게임을 제거하고 메뉴로 돌아간다. |
| `_loaded_game_controller()` | instance 유효성 뒤 지정 child를 typed cast한다. | controller 또는 null을 반환한다. |
| `_apply_menu_viewport_size()` | content scale과 비-headless window를 960×800으로 바꾼다. | 게임 화면 크기를 메뉴 크기로 복원한다. |
| `_play_select_sfx()` | 첫 focus guard→play→짧은 stop timer 순서다. | menu focus cue를 낸다. |
| `_create_screen(name,type)` | full-rect hidden Control 생성→child/Dictionary 등록 순서다. | 화면 root를 반환한다. |
| `_add_screen_title(...)` | 제목·부제·구분선을 추가한다. | 공통 header를 만든다. |
| `_create_panel/_create_label/_create_button/_create_slider` | UI factory에 인자를 위임한다. | 생성된 widget을 그대로 반환한다. |
| `_draw_decorative_blocks(...)` | S 모양 네 셀과 색별 atlas region을 반복 draw한다. | 공통 배경 장식을 만든다. |

## 11. 테스트 코드

### `tests/main_game_test.gd`

| 함수 | 역할 |
| --- | --- |
| `_init()` | async `_run()`을 deferred 예약한다. |
| `_run()` | 입력 보존, 기본 키, 계산식, physics 경로, 리소스, 스폰 여백, 실제 펀치 scene을 검사하고 종료 코드를 반환한다. |
| `_expect(condition,description)` | 검사 수와 실패 수를 누적하고 결과를 출력한다. |
| `_test_spawn_side_margin()` | 7종 안전 후보 수·실제 셀 여백·안전 후보 우선·벽 옆 fallback·완전 차단 GAME_OVER를 검사한다. |
| `_test_tap_punch()` | 실제 scene에서 press 판정 예약, hit 이동, miss 무이동을 검증한다. |
| `_prepare_punch(...)` | 각 펀치 사례의 보드·피스·캐릭터 private 상태를 동일하게 초기화한다. |

### `start_screen/tests/main_ui_test.gd`

| 함수 | 역할 |
| --- | --- |
| `_init()` | async `_run()`을 deferred 예약한다. |
| `_run()` | legacy cfg migration, Enter 차단, Z 시작, Esc modal, X 취소, Yes 복귀와 리소스 정리를 검증한다. |
| `_expect(condition,description)` | 검사 수/실패 수와 콘솔 결과를 관리한다. |

## 12. 함수 설계에서 확인할 C++ 학습 포인트

- `_physics_process()`는 세부 계산을 직접 길게 수행하기보다 작은 private 함수의 호출 순서를 소유한다.
- 검사 함수는 가능하면 bool/값을 반환하고, 실제 상태 변경은 상위 함수 한곳에서 commit한다.
- `Node` child의 수명은 parent가 소유한다. 멤버에 저장한 node 참조를 C++의 owning raw pointer로 오해하지 않는다.
- `Dictionary`/`Variant` 경계에서는 `_typed_keys()`나 `_parse_key_array()`처럼 typed 배열로 변환한다.
- `queue_free()`와 `call_deferred()`는 callback 실행 중 object graph를 즉시 파괴하지 않기 위한 안전 장치다.
- draw helper는 상태를 변경하지 않는 것이 원칙이며, controller와 renderer의 책임을 분리한다.
