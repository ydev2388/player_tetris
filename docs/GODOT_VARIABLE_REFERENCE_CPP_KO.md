# Kung Fu Tetris 5차 Godot 변수 보고서 — C++ 학습자용

이 문서는 5차 GDScript의 상수, enum, signal, 멤버 변수와 주요 지역 변수의 의미를
파일별로 설명한다. 함수 동작은 `GODOT_FUNCTION_REFERENCE_CPP_KO.md`에서 별도로 다룬다.

## 1. GDScript 변수와 C++ 대응

| GDScript | C++ 관점 | 수명·주의점 |
| --- | --- | --- |
| `const NAME` | `static const` 또는 `static constexpr` | script resource가 로드되는 동안 공유된다. |
| `var member: Type` | 인스턴스 멤버 변수 | Node/RefCounted 인스턴스마다 별도 값이다. |
| `@onready var node = $Path` | scene dependency를 준비 시점에 resolve한 pointer/cache | `_ready()` 이후 유효하다고 가정한다. |
| `@export var` | editor/scene 직렬화가 가능한 public configuration field | `.tscn` 값이 기본값을 덮을 수 있다. |
| 함수 안 `var` | stack local과 유사 | 함수 종료 후 변수 이름은 사라지지만 참조 객체 수명은 refcount/parent가 결정한다. |
| `Array[Type]` | `std::vector<Type>`에 가까움 | 동적 길이이며 참조형 container다. 복사가 항상 deep copy는 아니다. |
| `PackedInt32Array` | 연속 `std::vector<int32_t>`에 가까움 | 보드 행처럼 숫자 밀집 데이터에 사용한다. |
| `Dictionary` | `std::unordered_map<Variant, Variant>` | key/value 타입을 함수 경계에서 검증해야 한다. |
| `StringName` | interned string identifier | action 이름처럼 자주 비교하는 식별자에 적합하다. |
| `Variant` | `std::variant` + type erasure | `is`, `as`, 명시 변환으로 타입을 좁힌다. |

`_name`은 C++의 `private`와 같은 강제 접근 제한이 아니라 프로젝트 관례다. 테스트가 private
상태를 직접 설정하는 것은 가능하지만 production code에서는 공개 API와 signal을 우선한다.

## 2. 데이터·배치 파일

### `scripts/main_layout.gd`

| 이름 | 의미 |
| --- | --- |
| `BASE_CELL_SIZE` | 원본 설계 좌표의 32px 셀 길이. |
| `DISPLAY_SCALE` | 설계 좌표를 실제 화면·물리 좌표로 키우는 1.5 배율. |
| `CELL_SIZE` | 실제 한 셀 48px. View와 Physics가 공유한다. |
| `BOARD_SIZE` | 보이는 10×20 셀의 pixel 크기. |
| `GAME_VIEWPORT_SIZE` | 게임 화면 논리 해상도 1000×1080. |
| `BOARD_ORIGIN` | 게임 View에서 보드 좌상단 위치. |
| `HUD_RECT` | 우측 HUD panel 영역. |

이 파일은 인스턴스 멤버가 없다. C++의 상수 namespace처럼 사용한다.

### `scripts/tetromino_data.gd`

| 이름 | 의미 |
| --- | --- |
| `Type` | I/J/L/O/S/T/Z를 0~6으로 제한하는 enum class 대응 값. |
| `TYPE_COUNT` | 7-bag 반복문이 enum 항목 수를 알기 위한 상수. |

함수의 `cells`, `rotated`, `center_x/center_y`, `relative_x/relative_y`는 회전 한 번 동안만
사용하는 지역 계산값이다. 원본 배열을 직접 바꾸지 않고 새 배열을 반환한다.

### `scripts/piece_bag.gd`

| 이름 | 소유권·의미 |
| --- | --- |
| `_random` | bag 셔플만 담당하는 `RandomNumberGenerator` 인스턴스. spawn 위치 RNG와 분리된다. |
| `_pieces` | 아직 뽑지 않은 type 배열. `pop_back()`하므로 뒤쪽이 stack top 역할을 한다. |

### `scripts/input_actions.gd`

| 이름 | 의미 |
| --- | --- |
| `DEFINITIONS` | action 이름, 한글 label, 기본 keycode, slot 수를 가진 단일 메타데이터 원본. |

`definition`은 한 action의 Dictionary snapshot, `values`는 타입이 보장되지 않은 Variant,
`result`는 `Array[int]`로 정리한 typed 지역 버퍼다. C++에서도 parsing 경계에서는 raw DTO와
validated domain value를 분리하는 편이 안전하다.

### `scripts/character_animation_data.gd`

| 이름 | 의미 |
| --- | --- |
| `IDLE/HANG/ATTACK/JUMP/ROTATION_KICK` | animation state machine의 문자열 key. |
| `*_TEXTURE` | 각 상태 sprite atlas의 미리 로드된 resource handle. |
| `REGIONS` | 상태 key → source `Rect2` frame 배열. |
| `FRAME_DURATIONS` | 상태 key → frame당 초. |

`frame_index`는 `elapsed / duration`에서 계산한 지역 정수다. idle/hang에서는 modulo로 반복하고
일회성 상태에서는 마지막 index로 제한한다.

## 3. 보드 모델과 물리

### `scripts/board_model.gd`

| 이름 | 의미 |
| --- | --- |
| `WIDTH` | 유효 x 범위가 0~9인 보드 폭. |
| `VISIBLE_HEIGHT` | 사용자에게 보이는 20행. |
| `HIDDEN_ROWS` | spawn/top-out용 상단 숨은 2행. |
| `HEIGHT` | 실제 저장 행 22. |
| `EMPTY` | 점유되지 않은 셀을 나타내는 -1 sentinel. `std::optional` 대신 정수 sentinel을 쓴 구조다. |
| `cells` | 바깥 index가 y, 안쪽 index가 x인 `Array[PackedInt32Array]`. BoardModel이 유일한 소유자다. |

주요 지역 변수는 `survivors`(삭제되지 않은 행), `cleared`(삭제 개수), `board_cell`(origin을
더한 현재 좌표), `distance`(고스트 탐색 누적값)다. 반복문 index와 결과 accumulator를 분리한다.

### `scripts/board_physics.gd`

| 이름 | 소유권·의미 |
| --- | --- |
| `CELL_SIZE` | MainLayout에서 가져온 48px 물리 셀. |
| `BOARD_PIXEL_SIZE` | 10×20 보이는 보드의 물리 pixel 크기. |
| `controller` | 논리 BoardModel과 active piece의 authoritative owner를 가리키는 onready 참조. |
| `locked_body` | 고정 셀 CollisionShape2D 자식을 소유하는 StaticBody2D. |
| `active_body` | 활성 피스 네 shape를 소유하고 이동하는 AnimatableBody2D. |
| `character` | 보드 재구성 후 위치 검사를 요청할 캐릭터 참조. |
| `_last_board_signature` | 마지막 고정 collider 재구성 시점의 hash. -1은 강제 재구성 sentinel. |

`shape_resource`는 충돌 모양 데이터, `shape_node`는 scene tree child다. C++의 데이터 객체와
component/node 객체를 분리한 것과 같다.

## 4. 게임 컨트롤러

### signal과 enum

| 이름 | 의미 |
| --- | --- |
| `game_changed` | View와 BoardPhysics에 일반 상태 변경을 알린다. |
| `game_restarted` | 캐릭터와 collider cache까지 강제 reset해야 함을 알린다. |
| `active_piece_descended(prev,current)` | 캐릭터 압착 검사를 위해 낙하 전후 origin을 전달한다. |
| `lines_cleared` | 줄 삭제 SFX를 요청한다. |
| `GameState.PLAYING/PAUSED/GAME_OVER` | 게임 시간 진행과 입력 가능 상태를 제한한다. |

### 상수

| 이름 | 의미 |
| --- | --- |
| `SPAWN_Y` | 새 피스 원점의 숨은 행 y. |
| `SPAWN_SIDE_MARGIN_CELLS` | 우선 스폰에서 테트로미노의 실제 좌우 점유 셀과 벽 사이에 비워 두는 한 칸 여백. |
| `LOCK_DELAY_SECONDS` | 접지 후 고정까지 0.5초. |
| `MAX_LOCK_RESETS` | 이동/회전으로 lock delay를 늘릴 수 있는 최대 15회. |
| `MEDITATION_TIME_SCALE` | 명상 중 테트리스 시간 2배. |
| `SPAWN_RANDOM_SEED_OFFSET` | bag RNG와 spawn-x RNG의 같은 seed 수열을 분리하는 offset. |
| `INPUT_ACTIONS` | static 입력 정의 script handle. |
| `JLSTZ_KICKS`, `I_KICKS` | SRS 전이 문자열 → 보정 좌표 배열 lookup table. |

### 상태 멤버

| 이름 | 소유권·의미 |
| --- | --- |
| `board` | 고정 셀의 authoritative 모델. Controller가 소유한다. |
| `bag` | 아직 나올 피스 순서를 소유하는 7-bag. reset 시 교체된다. |
| `state` | 현재 `GameState`. |
| `meditation_active` | true일 때 중력과 lock에만 2배 effective delta를 적용한다. |
| `active_type` | 현재 낙하 피스의 Type 정수. |
| `active_rotation` | 0/1/2/3 회전 index. |
| `active_origin` | 네 로컬 셀의 기준 보드 좌표. |
| `next_type` | 다음 spawn 예정 type. |
| `score`, `level`, `total_lines` | 누적 점수, 현재 속도/배율 단계, 누적 삭제 행. |
| `_fall_accumulator` | 아직 한 셀 낙하로 소비되지 않은 게임 시간. |
| `_lock_accumulator` | 현재 접지에서 누적한 고정 대기시간. |
| `_lock_resets` | 현재 피스에서 사용한 lock delay 초기화 횟수. |
| `_spawn_random` | spawn 원점 선택 전용 RNG. |

`effective_delta`는 명상 배율을 곱한 지역 시간, `was_grounded`는 변형 전 접지 snapshot,
`candidates`는 우선 한 칸 여백, 필요할 때 여백 0 fallback 원점을 담는 지역 배열이다.
`safe_margin`, `first_origin_x`, `end_origin_x`는 실제 점유 셀의 좌우 경계를 origin 순회 범위로 변환한다.
snapshot을 먼저 잡아 mutation 전후를 비교한다.

## 5. 캐릭터 컨트롤러

### signal·scene dependency·audio channel

| 이름 | 의미 |
| --- | --- |
| `stats_changed` | lives/stamina/charge/cooldown 변경을 View에 알린다. |
| `feedback_changed` | feedback 문자열 생성·만료를 알린다. |
| `controller` | 피스 이동/회전과 게임 종료를 명령할 GameController 참조. |
| `sprite` | texture/region/flip/rotation/modulation/visible의 대상. |
| `left_ray`, `right_ray` | 매달릴 collider 탐지용 RayCast2D. |
| `_sfx_player` | 일반 단발음 channel. 새 재생이 이전 단발음을 교체할 수 있다. |
| `_sfx_cue_player` | 차지 단계·줄 삭제처럼 일반음과 겹칠 보조 channel. |
| `_meditation_loop_player` | 명상 지속음 전용 channel. |
| `_charge_loop_player` | 펀치 차지 지속음 전용 channel. |

### 공간·이동·점프 상수

| 그룹 | 포함 변수 | 의미 |
| --- | --- | --- |
| 셀 환산 | `CELL_SIZE`, `GIT_GRID_SCALE`, `CHARACTER_HEIGHT` | 원본 물리값을 48px 보드에 맞춘다. |
| 몸체 | `CHARACTER_COLLIDER_WIDTH/HEIGHT/OFFSET_Y` | sprite와 독립적인 사각 collider 규격. |
| 재스폰 | `RESPAWN_TOP_MARGIN_CELLS`, `RESPAWN_CENTER_Y`, `RESPAWN_BODY_SIZE` | frame과 무관한 상단 점유 영역. |
| 수평 이동 | `MOVE_SPEED`, `GROUND_ACCELERATION/DECELERATION`, `AIR_ACCELERATION/DECELERATION` | 지상/공중 목표 속도 접근 규칙. |
| 수직 이동 | `JUMP_VELOCITY`, `GRAVITY`, `FALL_GRAVITY_MULTIPLIER`, `MAX_FALL_SPEED` | 위가 음수인 Godot 좌표계의 점프/낙하 값. |
| 입력 유예 | `COYOTE_TIME`, `JUMP_BUFFER_TIME`, `JUMP_RELEASE_MULTIPLIER` | 조작 허용 시간과 가변 점프 배율. |
| 벽 액션 | `WALL_JUMP_HORIZONTAL_SPEED`, `WALL_JUMP_VERTICAL_MULTIPLIER`, `HANG_CLIMB_SPEED`, `HANG_REGRAB_COOLDOWN`, `HANG_JUMP_GRACE_TIME`, `WALL_JUMP_STEER_TIME/ACCELERATION` | 매달리기와 벽점프의 속도·유예·보정 규칙. |

### 행동·피해 상수

| 그룹 | 포함 변수 | 의미 |
| --- | --- | --- |
| stamina | `MAX_STAMINA`, `HANG_STAMINA_DRAIN` | 최대 100, 가득 찼을 때 약 3초 매달림. |
| 블록 플립 | `ROTATION_COOLDOWN`, `ROTATION_FAILED_COOLDOWN`, `ROTATION_SPIN_DURATION`, `POST_SPIN_APEX_SPEED` | 성공/실패 재사용 시간, 0.42초 연출과 종료 frame 경계. |
| 자력 재스폰·피해 | `SELF_RESPAWN_HOLD_SECONDS`, `INVULNERABILITY_SECONDS`, `MAX_LIVES` | hold 1초, 피해 무적 1.2초, 생명 3. |
| 펀치 | `ATTACK_COOLDOWN`, `ATTACK_ANIMATION_DURATION`, `PUNCH_HIT_CONFIRM_SECONDS` | sequence 간격, sprite 우선 시간, release 판정 창. |
| 차지 표 | `PUNCH_STAGE_TIMES`, `PUNCH_TOTAL_COSTS`, `PUNCH_MAX_HOLD_TIME` | 0/0.4/0.9초와 누적 비용 0/8/18. 같은 index가 같은 단계다. |
| hitbox·압착 | `PUNCH_HITBOX_WIDTH`, `CRUSH_ALPHA_THRESHOLD`, `CRUSH_CORE_SIZE`, `FIXED_SUPPORT_TOLERANCE` | 주먹 범위와 sprite alpha 기반 몸통/발판 검사 규격. |
| animation | `ANIMATION_DATA` | 상태별 texture/region table script. |
| SFX resource | `SFX_HURT`부터 `SFX_WALL_CLIMB` | preload된 효과음 handle. 재생 상태가 아니라 immutable resource 참조다. |

### 공개 gameplay 상태

| 이름 | 의미 |
| --- | --- |
| `lives` | 남은 생명. 0이면 controller가 GAME_OVER로 전환한다. |
| `stamina` | 0~100 행동 자원. 현재는 매달리기와 적중한 차지 펀치에 사용한다. |
| `facing` | 왼쪽 -1, 오른쪽 +1. 피스 이동/회전과 sprite 방향의 공통 원본이다. |
| `is_hanging` | 일반 이동 대신 hang branch를 선택하는 flag. |
| `is_meditating` | 정지와 controller 시간 2배를 나타내는 flag. |
| `charge_time` | 현재 X hold 경과 초. release/reset에서 0이다. |
| `rotation_cooldown_remaining` | 0보다 크면 새 블록 플립을 거부하는 countdown. |
| `feedback_text` | View가 1.4초 동안 표시할 최근 행동 결과. |

### private state machine 변수

| 그룹 | 변수 | 의미 |
| --- | --- | --- |
| 일반 timer | `_invulnerability_remaining`, `_feedback_remaining` | 피해 무시와 메시지 만료 countdown. |
| flip | `_spin_remaining`, `_spin_elapsed`, `_spin_direction`, `_pending_rotation_launch_velocity`, `_post_spin_animation_seeded` | 회전 진행·시작 방향·다음 frame 상승·종료 frame 보존. |
| hang | `_hang_body`, `_hang_last_global_position`, `_hang_regrab_remaining`, `_hang_jump_grace_remaining`, `_hang_jump_facing` | 붙은 body와 이동 delta, 재잡기/점프 유예, 벽 방향. |
| jump | `_coyote_remaining`, `_jump_buffer_remaining`, `_wall_jump_control_remaining`, `_wall_jump_wall_facing`, `_variable_jump_active` | 점프 입력 유예와 벽점프 조향, release cut 가능 상태. |
| punch | `_charging`, `_attack_cooldown_remaining`, `_attack_animation_remaining`, `_pending_punch_stage`, `_pending_punch_hit_remaining`, `_charge_audio_started` | hold sequence, sprite 우선, release 판정 예약과 audio latch. |
| 메뉴 입력 | `_ignore_initial_jump_until_released` | 메뉴 Z가 게임 첫 점프로 전파되는 것을 막는 latch. |
| animation | `_animation_state`, `_animation_time` | 현재 frame table key와 그 상태 경과 초. |
| 접지·재스폰 | `_respawn_airborne_pending`, `_was_grounded_for_stamina`, `_self_respawn_hold_time`, `_self_respawn_requires_release` | 순간이동 접지 cache, 착지 edge, Q hold와 반복 발동 방지. |
| cache/RNG | `_crush_mask_cache`, `_animation_image_cache`, `_respawn_random` | CPU alpha 연산 재사용과 상단 위치 선택 전용 난수열. |

지역 변수 중 `grounded`, `jump_pressed`, `was_playing` 같은 이름은 함수 시작 시점의 snapshot이고,
`target_*`, `candidate`, `moved_rect`, `swept_rect`는 commit 전 검사용 임시 값이다. C++에서도
상태를 바로 바꾸기보다 후보를 지역 변수에서 완전히 검증한 뒤 멤버에 commit하면 부분 변경을 막을 수 있다.

## 6. 게임 View

### 상수

| 그룹 | 변수 | 의미 |
| --- | --- | --- |
| layout 별칭 | `DISPLAY_SCALE`, `CELL_SIZE`, `GAME_VIEWPORT_SIZE`, `BOARD_ORIGIN`, `BOARD_SIZE`, `PANEL_RECT` | MainLayout의 단일 원본을 View에서 읽기 쉽게 별칭으로 둔다. |
| bar rect | `STAMINA_BAR_RECT`, `PUNCH_BAR_RECT`, `ROTATION_BAR_RECT`, `SELF_RESPAWN_BAR_RECT` | HUD 연속 수치의 destination 영역. |
| overlay rect | `SELF_RESPAWN_PANEL_RECT` | hold 진행 panel 전체 영역. |
| palette | `BACKGROUND_COLOR`, `BOARD_COLOR`, `GRID_COLOR`, `PANEL_COLOR`, `TEXT_COLOR`, `MUTED_TEXT_COLOR`, `CYAN`, `ORANGE` | 상태가 아니라 immutable theme 값. |
| resource | `BLOCK_TEXTURE`, `BLOCK_SPRITE_REGIONS`, `CHARACTER_TEXTURE`, `CHARACTER_SOURCE_RECT` | 블록 atlas lookup과 HUD 초상 source. |

### scene 참조와 UI cache

| 이름 | 의미 |
| --- | --- |
| `controller`, `character` | View가 읽을 authoritative gameplay object. View는 이 상태를 소유하지 않는다. |
| `_title_label`, `_next_label` | 고정 제목과 next 제목. |
| `_stats_label`, `_life_label`, `_stamina_label`, `_punch_label`, `_rotation_label` | `_refresh()`가 갱신하는 상태 Label. |
| `_feedback_label`, `_status_label` | 행동 결과와 pause/game-over 문구. |
| `_self_respawn_panel`, `_self_respawn_fill` | Q hold 중만 보이는 높은 z-index 진행 UI. |
| `_system_font` | retained Label과 `draw_string()`이 공유하는 font resource. |

View 함수의 `ratio`, `pulse`, `ghost_origin`, `source_region`, `destination`은 한 draw pass에서만
유효한 파생값이다. gameplay 멤버로 저장하지 않아 stale cache를 피한다.

## 7. 시작 화면 설정

### `start_screen/scripts/start_screen_settings.gd`

| 그룹 | 이름 | 의미 |
| --- | --- | --- |
| signal | `bindings_changed` | 키 버튼과 튜토리얼 key chip의 redraw 요청. |
| signal | `audio_changed` | BGM/SFX 값 변경 통지. |
| signal | `settings_error(message)` | 파일·중복 문제를 UI modal에 전달. |
| 저장 | `DEFAULT_SETTINGS_PATH` | 배포판 사용자별 cfg 기본 경로. |
| bus | `MUSIC_BUS`, `SFX_BUS` | AudioServer 이름 식별자. |
| 입력 의존성 | `INPUT_ACTIONS`, `ACTION_DEFINITIONS` | 입력 static API와 전체 action metadata 별칭. |
| migration | `SELF_RESPAWN_ACTION`, `SELF_RESPAWN_MIGRATION_KEYS` | 구버전 cfg에 새 Q 동작을 안전하게 보충하기 위한 이름과 후보. |
| public state | `settings_path` | 현재 인스턴스가 읽고 쓸 경로. 테스트에서 workspace 경로로 교체한다. |
| public state | `music_percent`, `sfx_percent` | 0~100 선형 퍼센트. AudioServer는 이를 mute/dB로 변환해 사용한다. |
| private state | `_bindings` | action `StringName` → keycode `Array[int]`의 authoritative 메모리 설정. |

주요 지역 변수는 `config`(이번 load/save parser), `load_error/save_error`(예외 대신 쓰는 Error),
`definition`(한 action metadata), `keys`(commit 전 지역 복사), `conflict`(중복 정보), `used`
(Dictionary를 set처럼 사용한 keycode 집합)이다.

## 8. 시작 화면 UI factory

### `start_screen/scripts/start_screen_ui.gd`

| 이름 | 의미 |
| --- | --- |
| `_font` | 생성하는 Label/Button이 공유할 resource handle. |
| `_panel_background` | Button normal 배경 기본값. |
| `_border_color` | Button/Panel 공통 테두리 기본값. |
| `_text_color` | Button 기본 글자색. |

`panel`, `label`, `button`, `slider`는 함수가 생성해 parent에 연결한 뒤 반환하는 지역 참조다.
parent가 Node 수명을 소유한다. `style`은 theme override가 참조하므로 함수가 끝나도 resource가
필요한 동안 유지된다.

## 9. 튜토리얼 Canvas

### 상수

| 그룹 | 이름 | 의미 |
| --- | --- | --- |
| resource | `ANIMATION_DATA`, `BLOCK_TEXTURE`, `BLOCK_SPRITE_REGIONS` | 캐릭터 frame table과 block atlas lookup. |
| palette | `PANEL`, `PANEL_DARK`, `BORDER`, `TEXT`, `MUTED`, `CYAN`, `ORANGE`, `PURPLE`, `RED` | page 전체가 공유하는 immutable theme 값. |
| timing | `ANIMATION_FPS`, `ANIMATION_FRAME_INTERVAL` | 논리 12FPS와 1/12초 fixed step. |
| timing | `LOOP_FADE_SECONDS`, `PAGE_DURATIONS`, `ROTATION_KICK_DURATION` | loop 전환 fade, page별 총 초, 실제 flip 연출 초. |

### 멤버

| 이름 | 의미 |
| --- | --- |
| `page` | 0~4의 현재 설명 page. |
| `settings` | 실제 사용자 binding 문자열을 읽는 non-owning 참조. |
| `_font` | 모든 즉시-mode `draw_string()`이 공유하는 font. |
| `_animation_time` | 현재 page loop 안의 경과 초. page 변경에서 0으로 돌아간다. |
| `_animation_accumulator` | 가변 render delta를 12FPS 고정 step으로 변환하고 남은 시간. |

### 주요 지역 변수

| 이름 패턴 | 의미 |
| --- | --- |
| `*_ratio` | 현재 시간을 보간 가능한 0~1 값으로 바꾼 결과. 원본 시간과 구분한다. |
| `*_alpha` | 현재 draw 호출에만 사용할 투명도. gameplay 상태가 아니다. |
| `*_position`, `*_x`, `*_y` | Bezier/lerp 결과인 이번 frame destination 좌표. |
| `*_stage`, `*_active`, `*_triggered` | timeline 분기 결과의 지역 snapshot. |
| `source_region`, `target_size`, `target_position` | atlas source와 aspect-fit destination을 분리한 값. |
| `direction`, `perpendicular`, `points` | arrow line에서 삼각형 머리 또는 polyline을 계산하는 기하 값. |
| `style` | 한 번의 round panel draw에만 쓰는 StyleBoxFlat. |

Canvas는 `_animation_time` 이외의 연출 값을 멤버로 저장하지 않는다. 같은 time과 page에서 같은
draw 결과를 만드는 함수형 renderer에 가까워 테스트와 디버깅이 쉽다.

## 10. 시작 화면 Controller

### signal·resource·theme·enum

| 그룹 | 이름 | 의미 |
| --- | --- | --- |
| signal | `game_loaded(game_root)` | instantiate/add_child가 끝난 game root 전달. |
| signal | `exit_requested` | 실제 quit 전 외부 launcher 통지. |
| scene/layout | `GAME_SCENE_DEFAULT`, `MENU_VIEWPORT_SIZE`, `TUTORIAL_PAGE_COUNT` | 기본 game factory 경로, 메뉴 해상도, 설명 page 수. |
| portrait/block | `PORTRAIT`, `PORTRAIT_SOURCE`, `BLOCK_TEXTURE`, `CYAN_BLOCK_SOURCE`, `ORANGE_BLOCK_SOURCE` | MAIN 초상과 배경 장식 atlas source. |
| script/audio | `TUTORIAL_CANVAS_SCRIPT`, `UI_SCRIPT`, `SFX_SELECT` | runtime child/factory class와 menu cue resource. |
| palette | `BACKGROUND`, `PANEL`, `PANEL_DARK`, `BORDER`, `TEXT`, `MUTED`, `CYAN`, `ORANGE`, `PURPLE`, `DANGER` | 시작 화면 공통 theme 상수. |
| enum | `Screen` | MAIN/TUTORIAL/OPTIONS/KEY_CUSTOM/VOLUME/GAME 상태 집합. |

### export·공개 상태

| 이름 | 의미 |
| --- | --- |
| `game_scene_path` | editor/scene에서 교체할 수 있는 PackedScene 경로. |
| `settings_file_path` | 설정 저장 경로 injection point. 테스트 cfg와 배포 cfg를 분리한다. |
| `suppress_quit_for_tests` | true면 EXIT가 process를 종료하지 않게 하는 test seam. |
| `settings` | child로 소유하는 StartScreenSettings의 typed 참조. |
| `current_screen` | screen state machine의 현재 enum. |
| `tutorial_page` | 현재 0-based 설명 index. |

### UI object graph cache

| 그룹 | 변수 | 의미 |
| --- | --- | --- |
| 공통 | `_font`, `_ui` | 공유 font와 RefCounted UI factory. |
| 화면 | `_screens`, `_main_buttons`, `_options_first_button` | enum→Control lookup, MAIN focus 순서, OPTIONS 첫 focus. |
| 키 설정 | `_key_buttons`, `_key_status` | action→주/보조 버튼 배열과 결과 Label. |
| 튜토리얼 | `_tutorial_canvas`, `_tutorial_counter`, `_tutorial_prev_button`, `_tutorial_next_button` | page renderer와 navigation cache. |
| 볼륨 | `_music_value_label`, `_sfx_value_label` | slider 옆 동적 퍼센트 Label. |
| 게임 | `_game_host`, `_game_instance` | 게임 scene parent와 현재 nullable root. |
| 종료 modal | `_game_exit_overlay`, `_game_exit_yes_button`, `_game_exit_no_button`, `_game_exit_was_playing` | modal UI와 열기 전 gameplay snapshot. |
| 선택음 | `_select_sfx_player`, `_select_sfx_timer`, `_skip_initial_select_sfx` | focus cue channel, 짧은 stop timer, 첫 자동 focus latch. |
| 키 캡처 | `_capture_overlay`, `_capture_label`, `_capture_action`, `_capture_slot` | modal UI와 적용 대상. 빈 action/-1 slot은 비활성 sentinel. |
| 안내 modal | `_message_overlay`, `_message_label` | 공통 오류 overlay와 동적 본문. |

### 주요 지역 변수

| 이름 | 의미 |
| --- | --- |
| `key_event`, `key_code` | 범용 InputEvent를 key subtype/int로 좁힌 지역 값. |
| `game_resource` | runtime type 검사 전의 범용 Resource handle. |
| `screen`, `panel`, `button`, `label`, `slider` | builder가 parent에 연결하는 node 지역 참조. 수명은 parent가 소유한다. |
| `button_data` | MAIN 버튼 text/color/callback을 한 배열로 선언한 지역 table. |
| `definition`, `action_name`, `action_buttons` | 키 설정 행 하나의 metadata와 cache를 조립하는 지역 값. |
| `result` | Settings API의 `{ok,message}` 반환 Dictionary. |
| `game_controller`, `was_playing` | modal 상태 전환 전후를 안전하게 복원할 지역 typed 참조/snapshot. |

## 11. 테스트 변수

### `tests/main_game_test.gd`

| 이름 | 의미 |
| --- | --- |
| `INPUT_ACTIONS`, `GAME_CONTROLLER`, `GAME_SCENE` | 테스트 대상 script/scene resource handle. |
| `_checks`, `_failures` | 전체 assertion 수와 실패 수. `_failures`가 process exit code가 된다. |
| `custom_event`, `custom_events` | 기본값 보장이 사용자 F8 event를 보존하는지 볼 fixture와 결과 snapshot. |
| `expected_counts`, `candidates`, `chosen_origin` | 7종별 한 칸 여백 후보 수와 실제 안전 후보 우선 선택을 검증하는 fixture/snapshot. |
| `i_spawn_row`, `fallback_origin`, `fallback_x` | I 피스 중앙 차단 뒤 벽 옆 fallback과 전체 차단을 검증하는 위치 값. |
| `scene`, `controller`, `character` | 실제 펀치 통합 테스트의 object graph 참조. scene을 테스트가 끝에 free한다. |
| `start_origin` | release 전후 active origin 비교용 immutable snapshot. |

### `start_screen/tests/main_ui_test.gd`

| 이름 | 의미 |
| --- | --- |
| `START_SCREEN_SCENE` | 테스트마다 새 UI root를 만드는 PackedScene. |
| `TEST_SETTINGS_PATH` | workspace build 폴더의 임시 cfg. |
| `_checks`, `_failures` | assertion/exit code accumulator. |
| `legacy_config` | Esc·Q·K·Backspace 충돌을 재현하는 입력 fixture. |
| `screen` | 실제 시작 화면 인스턴스. test가 owner다. |
| `enter_event`, `menu_confirm_event`, `escape_event`, `cancel_event`, `move_event`, `confirm_event` | 실제 키보드 없이 입력 gate를 검증하는 합성 InputEventKey. |
| `controller`, `character`, `overlay`, `yes_button` | game/menu 상태와 focus를 관찰하는 typed 참조. |

## 12. 변수 설계 점검 기준

- authoritative state는 한 객체만 소유한다. 보드는 GameController, 키 설정은 StartScreenSettings가 원본이다.
- View와 Tutorial은 가능한 한 파생값을 지역 변수로 계산하고 gameplay 상태를 복제하지 않는다.
- `*_remaining`은 감소하는 countdown, `*_elapsed`/`*_time`은 증가하는 경과시간으로 이름을 구분한다.
- `*_active`, `is_*`, `has_*`, `*_pending`은 서로 다른 bool 의미를 이름에서 드러낸다.
- `KEY_NONE`, `-1`, 빈 `StringName`, `null` 같은 sentinel은 문서와 validation 함수에서 계약을 명확히 한다.
- Node 수명은 parent가 관리하고, RefCounted/resource 수명은 참조 수가 관리한다. 멤버 참조를 무조건 소유 포인터로 해석하지 않는다.
- `Dictionary`와 `Variant`는 저장·UI 경계에서만 사용하고 gameplay 계산은 typed 값으로 좁힌다.
