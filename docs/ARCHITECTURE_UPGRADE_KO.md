# Block Fighter 아키텍처 업그레이드 기록

기준 소스: `ver.1.0.2`, 태그 `v1.0.2`, 기준 커밋
`d96678dae0575659dfa558bd99a22a935bb73a6c`.

이 문서는 기능을 유지하면서 다음 목표로 이동한 변경을 단계별로 기록한다.

- 규칙 상태의 소유자와 변경 명령을 명확히 한다.
- 명령은 전체 검증 후 한 번에 커밋한다.
- 실패한 명령은 원본 상태와 사건 수를 바꾸지 않는다.
- View와 Physics는 원본을 복제하지 않고 읽기 전용 투영으로 유지한다.
- 설정·저장·오디오 같은 외부 효과의 성공 여부를 호출 경계로 돌려준다.
- 순수 계약, 실제 Scene, 실제 export를 서로 다른 증거로 검증한다.

## 1단계 — 불변식 봉인과 실패 원자성

상태: 완료.

### 1. BoardModel 저장소 캡슐화

변경 위치: `scripts/board_model.gd`.

- 외부 쓰기가 가능했던 `cells`, `ice_cells`를 `_cells`, `_ice_cells`로 바꿨다.
- 읽기는 `get_cell()`, `is_ice_cell()`을 사용한다.
- 전체 상태 비교에는 원본과 분리된 deep copy인 `create_snapshot()`을 사용한다.
- Physics 변경 감지는 배열 참조 대신 `content_signature()`를 사용한다.
- fixture와 향후 stage setup용 단일 셀 명령 `set_cell()`을 추가했다.
- `set_cell()`은 좌표와 블록 타입을 검증하며 EMPTY 셀의 얼음 metadata를 자동 제거한다.

개선 효과:

- View, Physics, Character, 테스트가 배열 구조와 행 저장 방식에 직접 결합하지 않는다.
- 일반 셀과 얼음 metadata가 서로 다른 경로로 변경되는 것을 막는다.
- snapshot 소비자가 반환 배열을 수정해도 원본 보드는 바뀌지 않는다.
- 잘못된 블록 타입이나 범위 밖 좌표가 저장소로 유입되는 것을 차단한다.

보안·무결성 관점:

- 네트워크 보안 기능은 아니지만, 손상된 fixture·save migration·향후 mod 입력이 비정상
  타입이나 좌표를 전달해도 보드 원본을 오염시키지 않는 방어 경계가 생겼다.
- EMPTY 셀에 얼음 플래그가 남는 숨은 상태를 제거해 표시와 충돌 판정의 불일치를 줄였다.

### 2. lock_cells의 원자적 커밋

변경 위치: `scripts/board_model.gd`, `scripts/game_controller.gd`.

- `lock_cells()` 반환형을 `void`에서 `bool`로 바꿨다.
- 블록 타입, 빈 셀 목록, 모든 대상 좌표, 중복 좌표, 기존 점유 여부를 먼저 검사한다.
- 하나라도 실패하면 아무 셀도 쓰지 않고 `false`를 반환한다.
- 모두 성공한 경우에만 일반 셀과 얼음 metadata를 함께 기록한다.
- GameController는 lock 성공 뒤에만 씨앗·고드름 제거와 줄 삭제를 진행한다.

개선 효과:

- 네 칸 피스 중 일부만 기록되는 부분 커밋을 제거했다.
- 기존 블록을 덮어쓰는 상태 손상을 제거했다.
- lock 실패가 보스 씨앗이나 고드름만 먼저 지우는 부수효과를 만들지 않는다.
- Controller가 BoardModel의 성공 결과를 확인해야 다음 규칙 단계로 진행하는 명시적 계약이 생겼다.

### 3. 실패한 물길 명령의 무변경 보장

변경 위치: `scripts/game_controller.gd`의 `create_water_path()`.

이전 구현은 기존 물길을 먼저 삭제하고 방향을 바꾼 뒤 명령을 검증했다. 따라서 `false`를
반환해도 이전 물길이 사라지고 `game_changed`가 발행될 수 있었다.

새 구현은 다음 순서를 사용한다.

1. state, 방향, 최대 길이를 검증한다.
2. 로컬 `candidate_cells`에서 전체 후보를 계산한다.
3. 후보가 없으면 기존 상태와 사건 수를 유지한 채 `false`를 반환한다.
4. 후보가 유효할 때만 `water_path_cells`, 방향을 교체하고 `game_changed`를 한 번 발행한다.

개선 효과:

- 반환값 `false`가 실제로 “아무것도 커밋되지 않음”을 뜻한다.
- 잘못된 입력, 일시정지 중 입력, 막힌 시작점이 기존 스킬 효과를 취소하지 않는다.
- 사건 구독자는 성공적으로 확정된 변경에만 반응한다.

### 4. 전 스테이지 무피해 계약 정합성

변경 위치: `start_screen/scripts/start_screen_settings.gd`.

- `STAGE_NO_DAMAGE_COUNT`를 `STAGE_COUNT`와 동일한 10으로 통합했다.
- 무피해 상태 배열을 10개로 확장했다.
- 설정 schema를 3에서 4로 올렸다.
- 구버전의 1~5층 기록은 유지하고, 존재하지 않던 6~10층은 안전한 기본값 `false`로
  migration한다.

개선 효과:

- 문서와 캐릭터 화면의 “전 스테이지 무피해” 문구가 실제 해금 규칙과 일치한다.
- 1~5층만 무피해로 완료해 닌자를 조기 해금하던 계약 오류를 제거했다.
- 구버전 세이브가 새 스테이지를 자동 달성한 것으로 승격되는 권한 상승성 migration을 막았다.

### 5. 설정 명령 결과와 UI 재동기화

변경 위치: `start_screen/scripts/start_screen_settings.gd`,
`start_screen/scripts/start_screen.gd`.

- 키 기본값 복원과 세 볼륨 변경 명령이 `Dictionary` 결과를 반환한다.
- 성공 결과에는 확정된 값이, 실패 결과에는 `ok=false`와 구체적인 이유가 담긴다.
- `_failure(message)`가 전달받은 메시지를 버리던 오류를 수정했다.
- 볼륨 slider와 label은 사용자가 요청한 값이 아니라 Settings가 저장 후 확정한 값을 다시 읽는다.
- 저장 실패로 rollback된 경우 `set_value_no_signal()`로 slider도 원래 값으로 복원한다.
- 키 기본값 복원 UI도 실패를 성공 문구로 표시하지 않는다.

개선 효과:

- 디스크 상태, 메모리 상태, 화면 표시가 같은 committed 값을 가리킨다.
- 저장 실패가 호출자에게 숨겨지지 않는다.
- UI가 저장되지 않은 설정을 성공한 값처럼 표시하는 기만적 상태를 제거했다.
- `set_value_no_signal()`을 사용해 rollback 표시가 다시 저장 명령을 호출하는 재귀를 막았다.

### 6. 테스트와 배포 계약

추가·변경된 증거:

- Board snapshot 격리
- 범위 밖·점유·중복·잘못된 타입 lock의 무변경
- 유효 lock의 일반 셀·얼음 metadata 동시 커밋
- 방향 0·길이 0·일시정지·막힌 물길 명령의 상태/사건 무변경
- 설정 저장 실패의 구체적 결과 반환
- 저장 실패 뒤 볼륨 slider/label의 committed 값 복원
- 1~9층 무피해와 10층 피해 클리어에서 닌자 잠금 유지
- 1~10층 무피해 후 닌자 해금과 재실행 persistence
- schema 3의 5층 무피해 세이브를 schema 4의 10층 배열로 안전하게 migration

검증 결과:

- 메인 게임: 241 assertions, failures 0
- 메인 UI: 122 assertions, failures 0
- 캐릭터 해금 persistence 전용 테스트: failures 0
- runtime integration 8종: 모두 결과 marker 성공
- Godot 4.7.1 Web release export: 성공, 필수 `index.html`, `index.js`, `index.wasm`,
  `index.pck` 생성 확인
- `git diff --check`: 통과

공식 assertion gate도 `release.ps1`, `build_web.sh`, `GAME_OVERVIEW_KO.md`에 241/122로
동기화했다.

## 2단계 — 소방관 특수 스킬 수직 슬라이스

상태: 완료.

### 1. 공용 명령 결과와 사건 값 객체

추가 위치: `scripts/command_result.gd`, `scripts/game_event.gd`,
`scripts/firefighter_cast_command.gd`.

- `MainCommandResult`가 성공 여부, 안정적인 결과 code, 진단 message, 커밋된 사건 목록을
  한 값으로 반환한다.
- `MainGameEvent`는 소방관 물길 커밋/제거 종류와 ability id, 셀 snapshot, 방향, 지속시간,
  교체 여부, 제거 이유를 전달한다.
- `MainFirefighterCastCommand`는 입력 순간의 시작 셀과 방향만 보관한다. 물길 길이 3칸과
  수명 4초는 외부 입력이 아니라 `GameController`의 규칙 상수다.
- 결과와 사건이 노출하는 배열은 복제본이므로 소비자가 내용을 변경해도 원본 계약은
  변하지 않는다.

개선 효과:

- `bool` 하나로는 구분할 수 없던 실패 원인을 `game_not_playing`, `invalid_start_cell`,
  `invalid_direction`, `path_blocked`, `no_active_effect`로 식별한다.
- 다음 캐릭터 스킬도 같은 Result/Event 외곽 계약을 재사용할 수 있다.
- View와 테스트가 Controller의 내부 배열 형식에 의존하지 않는다.

### 2. 시전 자세를 보존하는 명령 흐름

변경 위치: `scripts/character_controller.gd`의 `_attempt_special_skill()`,
`_resolve_pending_special()`.

- V 입력이 받아들여진 순간 `_front_board_cell()`과 `facing`으로
  `MainFirefighterCastCommand`를 만들고 `_pending_firefighter_command`에 보관한다.
- 0.6초 시전 지연 뒤 같은 명령을 `GameController.execute_firefighter_cast()`에 전달한다.
- 시전 도중 이동하거나 방향을 바꿔도 저장된 cast context는 변하지 않는다.
- 쿨다운, 특수 동작, 시전 효과음은 입력 시점에 시작하는 기존 게임 감각을 유지한다.
- 지연 중 보드가 바뀌어 최종 물길 생성이 실패해도 기존 규칙처럼 쿨다운은 환불하지 않는다.

제거된 중복 상태:

- `_pending_water_start_cell`
- `_pending_water_direction`
- `_water_remaining`

호환용 `CharacterController.water_remaining()`은 값을 보관하지 않고
`GameController.water_path_remaining()`에 위임한다.

### 3. 물길 집합체와 원자적 사건 발행

변경 위치: `scripts/game_controller.gd`의 `execute_firefighter_cast()`,
`clear_water_path()`, `_advance_water_path()`.

- 물길 셀, 방향, 남은 시간을 `_water_path_cells`, `_water_path_direction`,
  `_water_path_remaining`으로 함께 봉인했다.
- 외부 읽기는 `has_water_path()`, `water_path_snapshot()`, `water_path_direction()`,
  `water_path_remaining()`만 사용한다.
- 명령은 PLAYING 상태, 보드 범위, 정확한 `-1/+1` 방향을 먼저 검사하고 로컬 배열에서
  전체 경로를 계산한다.
- 성공한 경우에만 셀·방향·4초 수명을 한 번에 커밋한다.
- 기존 물길 교체는 빈 중간 상태나 별도 제거 사건 없이 `replaced_existing=true`인 커밋
  사건 하나로 표현한다.
- 커밋 순서는 `상태 변경 → game_event_committed → game_changed → 결과 반환`이다.
  동기 signal 소비자는 callback 안에서도 이미 확정된 상태를 읽는다.
- 실패한 명령은 기존 셀·방향·수명과 두 signal의 발행 횟수를 모두 유지한다.

시간과 종료 규칙:

- 물길 수명은 Controller의 physics 시간에서 실제 delta로 감소한다.
- PAUSED에서는 멈추고, 명상 시간 배율에는 영향받지 않으며, 낙하 동결 중에는 계속 간다.
- 만료는 `expired`, 생명 손실은 `character_reset`, 캐릭터 교체는 `character_changed`,
  재시작·게임오버는 `game_reset` 이유의 제거 사건을 사용한다.
- 이미 빈 물길을 다시 제거하면 `no_active_effect` 실패 결과만 반환하고 사건을 발행하지 않는다.
- 일괄 초기화는 물길 제거 사건을 한 번만 발행하고 일반 화면 갱신도 batch 끝에서 처리한다.

### 4. View는 사건에 반응하고 원본 상태를 투영

변경 위치: `scripts/game_view.gd`의 `_on_game_event_committed()`,
`_draw_character_skill_effects()`.

- View는 `game_event_committed`를 구독한다.
- 물길 커밋 사건은 0.18초 등장 pulse를 시작하고 제거 사건은 pulse를 정리한다.
- View가 보관하는 값은 표현 전용 pulse 시간뿐이다.
- 실제 물길 존재 여부와 셀은 매 draw에서 `water_path_snapshot()`으로 읽는다.
- 사건 payload를 새 gameplay 원본으로 저장하지 않으므로 View가 늦게 연결되거나 사건을
  놓쳐도 현재 Controller snapshot만으로 화면을 복원할 수 있다.

### 5. 기술·무결성·코드 품질 관점

- 임의 정수 방향을 `signi()`로 묵시 변환하지 않고 `-1/+1` 외 입력을 거부한다.
- 범위 밖 시작 셀과 null command를 상태 계산 전에 차단한다.
- 명령으로 물길 길이나 지속시간을 조작할 수 없으므로 향후 mod·replay·네트워크 입력 경계에서
  규칙 상수를 우회할 수 없다.
- 실패 결과와 무변경 상태가 일치해 재시도, replay, 사건 기록의 결정성이 높아졌다.
- 셀 배열 alias를 제거해 View나 테스트의 우발적 변경이 규칙 상태로 역류하지 않는다.
- 만료·사망·초기화가 겹쳐도 `has_water_path()`를 commit guard로 사용해 중복 제거 사건을 막는다.
- 물길 상태와 수명이 같은 소유자 안에 있어 “화면에는 물이 있지만 타이머는 끝난 상태” 같은
  분할 진실을 제거했다.

### 6. 테스트와 배포 계약

추가·변경된 증거:

- 성공 Result, 사건 payload, 실제 커밋 상태의 일치와 callback 시점의 상태 가시성
- Result/Event/상태 snapshot 배열 격리
- 방향 0·2, 범위 밖 시작점, PAUSED, 막힌 경로 실패의 상태·수명·사건 무변경
- 기존 물길의 단일 사건 원자적 교체와 4초 수명 재시작
- pause/명상/낙하 동결의 서로 다른 시간축
- 만료, 재시작, 생명 손실, 게임오버의 단일 제거 사건
- 실제 V 입력, 0.6초 cast 자세 보존, Controller 수명 소유, View pulse 반응
- 공개 명령과 조회 API를 사용하는 fixture로 직접 물길 대입 제거

검증 결과:

- 메인 게임: 251 assertions, failures 0
- 메인 UI: 122 assertions, failures 0
- 캐릭터 해금 persistence 전용 테스트: failures 0
- runtime integration 8종: 모두 결과 marker 성공
- 소방관 runtime marker: `events=1`, `view_pulse=true`, cast pose 보존
- Godot 4.7.1 Web release export: 성공, 필수 `index.html`, `index.js`, `index.wasm`,
  `index.pck` 생성 확인
- 최종 테스트·export 로그의 script/parse/engine error: 0
- `git diff --check`: 통과

공식 assertion gate도 `release.ps1`, `build_web.sh`, `GAME_OVERVIEW_KO.md`에 251/122로
동기화했다.

## 2.5단계 — 전체 캐릭터 특수 스킬 수직 슬라이스

상태: 완료.

### 1. 공용 cast context와 책임별 실행 경계

추가·변경 위치: `scripts/ability_cast_command.gd`, `scripts/command_result.gd`,
`scripts/game_event.gd`, `scripts/character_controller.gd`의 `_attempt_special_skill()`,
`_resolve_pending_special()`, `_execute_local_ability()`.

- `MainAbilityCastCommand`가 ability id, 입력 순간 위치, 시작 셀, 방향, 후보 셀을 읽기 전용
  값으로 보관한다. 후보 배열은 생성·조회 양쪽에서 복제한다.
- 일반인·성녀·닌자는 이동속도, 피해 방어, 투사체처럼 캐릭터 몸체 불변식을 실제로 지키는
  `CharacterController`가 커밋한다.
- 복서·방패병·소방관·청소부·시계공은 보드 셀, 활성 피스, 낙하 시간처럼 보드 불변식을
  바꾸므로 `GameController`의 명령 경계가 커밋한다.
- 모든 경계는 `MainCommandResult`를 반환하고 성공한 커밋은 `MainGameEvent`를 결과와 signal에
  함께 담는다. 실패는 안정적인 `code`와 빈 사건 목록을 반환한다.
- 쿨다운·시전 동작·효과음은 입력 접수 시점에 시작하고, 실제 규칙 검증은 각 스킬의 지연 뒤
  수행한다. 지연 중 실패해도 기존 게임 규칙대로 쿨다운은 환불하지 않는다.

이 구조는 모든 상태를 한 거대 Controller로 이동시키는 방식이 아니다. “어떤 상태를 함께
지켜야 하는가”를 기준으로 aggregate를 나누고, 외곽의 Command/Result/Event 모양만 통일했다.

### 2. 입력 순간 문맥 보존

변경 위치: `scripts/character_controller.gd`의 `_attempt_special_skill()`,
`_start_ninja_projectile()`.

- 복서는 전방 하단·상단 후보와 방향을 입력 순간 고정한다.
- 방패병은 시전 위치에서 계산한 세로 3셀 후보와 방향을 고정한다.
- 청소부는 입력 순간 발밑 중심 셀을 고정한다.
- 닌자는 플레이어 의도인 발사 위치, 보드 행, 방향만 고정한다. 캐릭터 충돌 금지 셀은 입력 당시
  복제하지 않고 실제 충돌 커밋 직전에 현재 collider snapshot으로 다시 계산한다.
- 소방관의 기존 `MainFirefighterCastCommand` 문맥 보존도 그대로 유지한다.
- 실제 보드 점유·이동 가능 여부는 지연이 끝난 시점의 최신 authoritative 보드에서 검증한다.

따라서 시전 중 캐릭터가 이동하거나 돌아서도 공격 위치가 순간이동하지 않으며, 반대로
보드가 바뀐 경우에는 오래된 성공 판정을 강제로 적용하지 않는다.

### 3. 보드 효과의 원본 봉인

변경 위치: `scripts/game_session.gd`의 지속 효과 명령과 `scripts/game_controller.gd`의
`execute_boxer_cast()`, `execute_shield_guard_cast()`, `execute_cleaner_cast()`,
`execute_clockmaker_cast()`, `clear_transient_blockers()`, `clear_fall_freeze()` facade.

- `MainGameSession`이 방패 셀, 방향, 2초 수명을 private backing state로 함께 소유한다.
- 시계공의 낙하·미래 기믹 정지 수명도 Session에 봉인하고 `MainGameRules`의 3초로만 커밋한다.
- View와 외부 코드는 `transient_blocker_snapshot()`, `barrier_remaining()`,
  `barrier_direction()`, `fall_freeze_remaining()`을 사용한다.
- 방패의 빈 후보, 복서의 무대상·막힌 이동, 청소부의 무대상, PAUSED 상태 명령은 기존 효과와
  사건/화면 변경 횟수를 보존한다.
- 방패와 시계공 만료는 각각 `expired` 제거 사건을 한 번 발행한다.
- 재시작·게임오버·생명 손실·캐릭터 교체는 `clear_skill_effects()`의 batch 경계에서 방패,
  물길, 시간정지를 함께 비운 뒤 사건을 발행한다.

### 4. 캐릭터 효과와 typed 닌자 projection

추가·변경 위치: `scripts/ninja_projectile_snapshot.gd`,
`scripts/character_controller.gd`의 `_execute_local_ability()`,
`ninja_projectile_snapshot()`, `_finish_ninja_projectile()`, `_update_timers()`.

- 일반인 질주는 2초 상태 커밋/만료 사건을 발행한다.
- 성녀는 3초 이동 강화와 1회 방어를 한 집합으로 커밋하고, 방어 소비와 만료를 별도 typed
  사건으로 구분한다.
- 닌자는 발사 커밋과 충돌 결과를 분리한다. 충돌 사건은 위치, 방향, 접촉 종류, 실제 밀기
  성공 여부를 전달한다.
- 내부 투사체 상태를 View에 Dictionary로 넘기지 않고 읽기 전용
  `MainNinjaProjectileSnapshot`으로 투영한다.
- 호환용 `ninja_special_result()`는 기존 호출자를 위해 남겼지만 실제 View는 typed snapshot만
  사용한다.

### 5. View와 사건 사용 규칙

변경 위치: `scripts/game_view.gd`의 `_ready()`, `_on_game_event_committed()`,
`_on_character_ability_event_committed()`, `_draw_character_skill_effects()`,
`_draw_ninja_shuriken_effect()`.

- View는 보드 사건과 캐릭터 사건을 모두 구독해 redraw/VFX 시작 계기로만 사용한다.
- 방패 셀은 draw마다 스냅샷을 한 번 읽고, 시간 정지도 getter로 읽는다.
- 닌자 VFX는 한 번 얻은 typed snapshot에서 위치·비행·충돌 애니메이션을 그린다.
- 사건 payload를 장기 gameplay 상태로 복제하지 않으므로 늦게 연결된 View도 현재 snapshot으로
  복구할 수 있다.

### 6. 기술·무결성·코드 품질 개선

- 외부 호출자가 방패·시간정지 duration을 넘길 수 없고 규칙 상수만 사용한다.
- 잘못된 ability id, `-1/+1`이 아닌 방향, 범위 밖 시작 셀, 무대상 명령을 커밋 전에 차단한다.
- 명령·사건·조회 배열의 alias를 끊어 외부 변경이 보드 충돌 규칙으로 역류하지 않는다.
- `fall_freeze_remaining`, `transient_blocker_cells` 직접 대입을 없애 테스트도 실제 공개 명령을
  통과한다. 테스트 전용 우회가 제품 불변식을 숨기지 않는다.
- 성공한 보드 변경은 `상태 커밋 → typed 사건 → game_changed → 결과 반환` 순서를 사용한다.
- 실패 시 부분 이벤트나 화면 갱신을 남기지 않아 replay, 저장 복구, 향후 네트워크 입력 검증의
  결정성이 높아졌다.
- 일반 `ABILITY_COMMITTED`, 제거 `ABILITY_CLEARED`, 일회성 소비 `ABILITY_CONSUMED`, 닌자 충돌
  `NINJA_PROJECTILE_IMPACTED`를 구분해 소비자가 문자열 message를 해석하지 않는다.

### 7. 테스트와 배포 계약

추가·변경된 증거:

- 공용 명령의 입력 배열, 결과 사건 배열, 방패 snapshot의 별칭 격리
- 실패한 방패와 PAUSED 시계공 명령의 상태·수명·사건·화면 신호 무변경
- 복서 이동량, 청소부 제거 수, 시계공 규칙 수명의 사건 payload 일치
- 일반인·성녀의 캐릭터 커밋 사건과 닌자 발사/충돌 사건
- 복서·방패·청소부·소방관·닌자의 지연 중 이동/방향 변경 cast context 보존
- 실제 V 입력으로 일반인·방패병·시계공을 잇는 추가 runtime 수직 슬라이스
- 재시작·게임오버 batch에서 방패·물길·시간정지 제거 사건이 각각 한 번만 발생

검증 결과:

- 메인 게임: 269 assertions, failures 0
- 메인 UI: 122 assertions, failures 0
- 캐릭터 해금 persistence 전용 테스트: failures 0
- runtime integration 9종: 모두 결과 marker 성공
- Godot 4.7.1 Web release export: 성공, 필수 `index.html`, `index.js`, `index.wasm`,
  `index.pck` 생성 확인
- 최종 테스트·export 로그의 script/parse/engine error: 0
- `git diff --check`: 통과

공식 assertion/runtime gate도 `release.ps1`, `build_web.sh`, `GAME_OVERVIEW_KO.md`에
269/122와 runtime 9종으로 동기화했다.

## 3단계 — RefCounted GameSession 추출

Status: complete.

### Ownership after extraction

Added `scripts/game_session.gd` as `MainGameSession extends RefCounted`. One session now owns:

- `MainBoardModel` and `MainPieceBag`
- `MainActivePieceState` (type, rotation, origin, remaining mino indices, lock/fall state) and next piece
- score, level, total lines, stage number, stage clock, challenge flag, and boss-stage state
- player lives and rule-facing rotation/special cooldowns
- spawn and gimmick random generators plus deterministic test overrides
- persistent board skill results: firefighter water, shield barrier, and clockmaker freezes

`MainGameController` keeps its public names as forwarding properties so scenes, View, Physics, and existing tests do not gain a second source of truth during migration. It retains Godot lifecycle, delta advancement, input/pause/restart handling, scene lookup, and signal emission.

`MainCharacterController` still owns CharacterBody2D physics, stamina, animation, cast wind-up, invulnerability, and presentation timers. Its `lives`, rotation cooldown, and special cooldown properties project to the shared session. This deliberately does not attempt to purify character physics in this stage.

### Board and skill command boundary

Clockmaker, shield-guard, and firefighter validation plus atomic persistent-effect commits moved into `MainGameSession`. The controller delegates the command, then emits the returned committed events and `game_changed` only on success. Clearing and batch reset use the same session boundary, retaining state-commit -> event -> view-change order.

Board cells themselves remain encapsulated by `MainBoardModel`; GameSession owns that model rather than copying its arrays. PieceQueue keeps its private 7-bag and RNG but is now session-owned. This composes the existing focused models instead of replacing them with a single giant script.

### Compatibility and snapshots

The controller compatibility properties are a temporary migration seam, not duplicate storage. Reads and writes immediately target session fields. `board_snapshot()`, `active_piece_snapshot()`, `progress_snapshot()`, and `skill_effect_snapshot()` provide detached projections; returned arrays cannot mutate authoritative session arrays.

### Evidence

`tests/main_game_test.gd` verifies RefCounted ownership, two-way compatibility projection, detached snapshots, seeded queue/spawn determinism, CharacterController life/cooldown projection, atomic reset, and all earlier command/event invariants.

Current gates:

- main game: 269 assertions, 0 failures
- main UI: 122 assertions, 0 failures
- runtime integrations: 9 suites
- Godot 4.7.1 Web release export and required artifact checks

`release.ps1`, `build_web.sh`, and `docs/GAME_OVERVIEW_KO.md` use the same 269/122 assertion contract.

### Intentional remaining boundary

GameController still contains frame orchestration, boss presentation sequencing, and some board-operation coordination. CharacterController still contains all kinematic movement and local body effects. Moving those now would combine a state-ownership migration with a physics rewrite and make regressions harder to isolate. A later step may move more pure rule functions behind GameSession commands while leaving Node adapters intact.

## 4단계 — CharacterController 실행 책임 분리

상태: 완료.

### 변경 전과 설계 일치 여부

변경 전 `CharacterController`는 Godot 전역 입력 조회, 캐릭터별 스킬 `match`, 이동 속도 적분,
`move_and_slide()`, 매달림 원본 상태, 애니메이션 시간과 Sprite 변경, 네 개의 오디오 플레이어를
한 파일에서 함께 소유했다. 4단계 구현은 계획한 네 경계를 실제 physics/ability/presentation 경로에
연결했다. 단, 충돌 형상 계산과 이동 상태 전환까지 전부 Motor로 옮기지는 않았다.
`CharacterBody2D`의 ray/shape cast와 scene node 순서에 민감한 조정은 Controller 셸에 남기고,
Motor는 위치·속도 커밋, 접지 조회, 실제 이동 호출과 매달림 원본 상태를 소유한다. 이는 계획의
“처음부터 캐릭터 물리 전체를 순수화하지 않는다”는 점진 이전 원칙과 동일하다.

### 1. CharacterInputAdapter와 InputFrame

추가 위치: `scripts/character_input_frame.gd`, `scripts/character_input_adapter.gd`.
연결 위치: `scripts/character_controller.gd`의 `_physics_process()`와 모든 입력 처리 함수.

- `MainCharacterInputAdapter.capture()`만 Godot `Input` singleton을 읽는다.
- 좌우 축과 jump/punch/special/rotation/grab/climb/meditate/self-respawn 상태를 물리 프레임마다
  `MainCharacterInputFrame` 하나로 고정한다.
- Controller의 행동 우선순위는 같은 프레임 snapshot만 읽으므로 함수 호출 순서 사이에 입력을
  다시 조회해 서로 다른 답을 얻지 않는다.
- 테스트나 향후 replay/AI는 Godot 입력 장치를 흉내 내지 않고 InputFrame 경계에 값을 공급할 수 있다.

### 2. CharacterMotor

추가 위치: `scripts/character_motor.gd`.
연결 위치: `scripts/character_controller.gd`의 일반 이동, 명상 이동, 중력, 경계 clamp,
접지 판정, 매달림 forwarding property와 reset 경로.

- `move_and_slide()`를 호출하는 생산 코드 경계는 Motor 하나다.
- 수평 목표 속도 접근, 상승/하강 중력 배율, 최대 낙하 속도와 보드 위치 clamp를 Motor가 적용한다.
- `is_hanging`, 붙은 body, 면 좌표, 상하 범위, 모서리 오르기 진행도는 Motor의 단일 원본이다.
  Controller의 기존 필드명은 장면/회귀 테스트 호환을 위한 forwarding property일 뿐 복제 상태가 아니다.
- ray cast, 보드 셀과 실제 collider의 교차 계산, coyote/jump/action 상태 전환은 아직 Controller에
  남는다. 다음 물리 순수화 단계에서 입력과 보드 query를 값으로 바꾼 뒤 옮길 수 있다.

### 3. AbilityPolicy와 AbilityResolver

추가 위치: `scripts/character_ability_policy.gd`, `scripts/prepared_character_ability.gd`,
`scripts/character_ability_resolver.gd`.
연결 위치: `scripts/character_controller.gd`의 `_attempt_special_skill()`,
`_resolve_pending_special()`, `commit_normal_ability()`, `commit_chef_ability()`,
`commit_ninja_ability()`.

- 8개 캐릭터의 시전 지연, 접지 필요 여부, command builder, 실행 aggregate를 한 policy registry에서
  선언한다. CharacterController의 `match character_id`와 `match command.ability_id`를 제거했다.
- 입력 순간 Resolver가 `MainPreparedCharacterAbility`를 만들고, 지연 뒤에도 같은 command를 실행한다.
  이동·회전 중 cast context 고정이라는 2단계 계약을 유지한다.
- 보드를 바꾸는 복서·방패병·소방관·청소부·시계공은 GameController/GameSession 명령으로,
  몸체 불변식인 일반인·요리사·닌자는 CharacterController의 작은 commit handler로 보낸다.
- 캐릭터마다 Motor/Presenter/Controller 클래스를 만드는 대신 정책 행과 필요한 builder/handler만
  추가하므로 클래스 폭증을 피한다.

### 4. CharacterPresenter와 AudioAdapter

추가 위치: `scripts/character_presenter.gd`, `scripts/character_audio_adapter.gd`.
연결 위치: `scripts/character_controller.gd`의 `_ready()`, `_apply_animation_frame()`,
방향·회전·색·깜빡임 갱신, SFX/명상 loop/정리 함수.

- Presenter가 animation state/time과 실제 Sprite atlas, geometry, flip, rotation, modulate,
  visibility 투영을 소유한다.
- AudioAdapter가 primary/cue/meditation/special 네 채널의 생성, bus, stream 교체, 재생, 반복과
  종료 정리를 소유한다. 테스트는 더 이상 Controller의 플레이어 필드를 직접 변경하지 않는다.
- 성녀 보호막처럼 캐릭터 전용 보조 Sprite의 규칙적 표시 시점 계산은 아직 Controller에 남는다.
  주 캐릭터 Sprite와 SFX 수명 경계가 먼저 분리된 점진적 Presenter 추출이다.

### 장점과 비용

장점:

- 새 캐릭터는 거대한 분기 두 곳을 수정하지 않고 정책 registry와 필요한 작은 handler를 추가한다.
- 모든 행동이 한 InputFrame을 사용해 입력 재현성과 테스트 결정성이 높아진다.
- 매달림 원본과 animation 원본이 각각 Motor/Presenter 하나에 있어 분할 진실이 줄었다.
- SFX node 세부사항을 게임 규칙에서 제거해 채널 교체와 음소거 adapter 전환이 쉬워졌다.
- GameSession/CommandResult/GameEvent를 유지하므로 2·3단계의 원자적 보드 커밋 계약을 훼손하지 않는다.

비용과 남은 한계:

- 기존 장면과 테스트를 깨지 않기 위한 Motor/Presenter forwarding property가 잠시 존재한다.
- Controller는 여전히 Godot collision query와 coyote/jump/punch/피해 상태 전환을 조정하므로 파일이
  작아졌다는 것만으로 완전한 순수 도메인 모델은 아니다.
- 정책 실행은 문자열 메서드 이름이 아니라 등록 시 만들어 둔 `Callable`을 사용한다. 다만 GDScript의
  `Callable`은 매개변수와 반환 타입을 언어 수준에서 완전히 강제하지 않으므로 Resolver의 typed target
  adapter와 계약 테스트가 잘못된 target/result를 계속 방어한다.
- InputFrame은 RefCounted 값 snapshot이지만 GDScript 언어 수준의 강제 불변 객체는 아니다.
  생산 경로가 capture 뒤 수정하지 않는 계약을 지키며, 필요하면 다음 단계에서 private backing field로
  더 엄격히 봉인할 수 있다.
- 보조 VFX까지 무리하게 Presenter로 옮기지 않아 현재는 Controller와 Presenter 양쪽에서 표현 결정을
  일부 나눈다. 대신 대규모 시각 회귀 위험을 줄였다.

### 검증 계약

`tests/main_game_test.gd`에 InputFrame 정규화, 8개 policy 등록, 시전 지연/접지 정책,
소방관 context 고정, Motor 속도 적분·매달림 reset, Presenter Sprite 투영,
Controller의 직접 Input/캐릭터 match 제거를 검증하는 8 assertions를 추가했다.

4단계 완료 당시 gate snapshot:

- 메인 게임: 277 assertions, failures 0
- 메인 UI: 122 assertions, failures 0
- runtime integration: 9 suites
- Godot 4.7.1 Web release export와 필수 산출물 검사

`release.ps1`, `build_web.sh`, `docs/GAME_OVERVIEW_KO.md`의 메인 assertion 계약도 277로
동기화했다.

## 5단계 — StartScreen 변경 이유 분리

상태: 완료.

### 변경 전과 설계 일치 여부

변경 전에는 `start_screen.gd`가 현재 화면 enum, 모든 화면의 visible 전환, 화면별 최초 초점,
메뉴 UI 생성과 게임 인스턴스 수명을 함께 소유했다. `start_screen_settings.gd`도 진행도 상태와
해금/보상 규칙, `ConfigFile` 직렬화, 볼륨 값, `AudioServer` bus 생성·적용을 한 클래스에서
처리했다. 따라서 캐릭터 해금 규칙을 바꾸는 일과 설정 파일 schema를 바꾸는 일, 볼륨 계산을
바꾸는 일이 같은 파일을 동시에 수정했다.

5단계 구현은 계획한 `ScreenRouter`, 화면별 View, `ProgressionService`,
`SettingsRepository`, `AudioSettingsAdapter` 경계를 실제 생산 경로에 연결했다. 화면마다 별도
scene/class 파일을 강제로 만들지는 않았다. 코드로 생성되는 기존 Control root마다 가벼운
`BlockFighterScreenView` 인스턴스를 하나씩 두어 표시와 진입 동작을 캡슐화했다. 이는 파일 수가
아니라 변경 이유를 분리한다는 원래 목표와 일치한다.

다만 `start_screen.gd`의 9개 화면 UI 조립 함수 자체는 이번 단계에 남겼다. 픽셀 좌표 기반 메뉴를
동시에 scene resource로 옮기면 구조 이전과 시각 회귀가 한 변경에 섞이기 때문이다. 따라서
“라우팅/화면 수명 경계”는 추출됐지만 “모든 화면 레이아웃 코드의 파일 분할”까지 완료한 것은
아니다.

### 1. ScreenRouter와 화면 View

추가 위치: `start_screen/scripts/screen_router.gd`,
`start_screen/scripts/screen_view.gd`.
연결 위치: `start_screen/scripts/start_screen.gd`의 `_ready()`, `_create_screen()`,
`_show_screen()`, `_focus_screen()`.

- `BlockFighterScreenRouter`가 `current_screen`의 단일 원본이다.
- `_create_screen()`이 만든 MAIN/FLOOR_SELECT/STAGE_SELECT/CHARACTER/SHOP/TUTORIAL/
  OPTIONS/KEY_CUSTOM/VOLUME root는 각각 별도 `BlockFighterScreenView`로 등록된다.
- `ScreenView`는 자신의 root visible과 진입 callback을 소유한다. Router는 기존 View를 모두
  닫고 대상 View 하나를 연며, GAME일 때만 game host를 표시한다.
- 등록되지 않은 화면 요청은 `false`를 반환하고 기존 화면을 유지한다.
- `StartScreen.current_screen`은 호환용 읽기 projection이며 별도 상태를 저장하지 않는다.
- 음악 전환, 메뉴 흐름, 게임 scene 생성·제거는 composition root인 `StartScreen`에 남는다.

이로써 화면을 여는 함수마다 visible 상태를 직접 조합하지 않고 하나의 전환 경계를 사용한다.
늦게 추가되는 화면도 root와 진입 동작을 등록하면 같은 표시 불변식을 적용받는다.

### 2. ProgressionService

추가 위치: `start_screen/scripts/progression_service.gd`.
연결 위치: `start_screen/scripts/start_screen_settings.gd`의 진행도 조회·변경 API.

- `BlockFighterProgressionService`는 10개 층 최고 별, 무피해 기록, 별 재화, 6개 패시브 레벨,
  도전 최고 기록, 디버그 전체 해금의 원본 상태를 소유한다.
- 다음 층/도전 모드/캐릭터 해금, 패시브 비용, 최고 별 차액 보상, 무피해 누적 같은 순수 규칙이
  이 서비스로 이동했다.
- `complete_stage()`, `upgrade_passive()`, `reset_passive_upgrades()`,
  `record_challenge_lines()`는 메모리 상태와 결과만 계산하며 파일 시스템을 알지 못한다.
- `snapshot()`은 배열을 복제해 반환하고 `restore()`는 저장 실패 rollback에 사용한다.
- 기존 `StartScreenSettings`의 공개 이름은 화면과 이전 테스트를 위한 facade로 유지하지만 조회와
  명령은 서비스에 위임한다. 중복된 진행도 원본은 없다.

이 경계 덕분에 해금/보상 규칙은 `ConfigFile` 없이 단위 검증할 수 있고, 향후 저장 형식을 JSON이나
클라우드 저장으로 바꿔도 진행도 계산을 수정할 필요가 없다.

### 3. SettingsRepository와 트랜잭션 경계

추가 위치: `start_screen/scripts/settings_repository.gd`.
연결 위치: `start_screen/scripts/start_screen_settings.gd`의 `load_settings()`,
`save_settings()`.

- `BlockFighterSettingsRepository`만 실제 설정 경로와 `ConfigFile.load/save`를 소유한다.
- input, language, audio snapshot, progress snapshot을 schema 4의 섹션/키로 직렬화한다.
- facade는 입력·오디오·진행도 명령 전에 snapshot을 만들고, 서비스 변경 뒤 repository 저장을
  시도한다. 저장 실패 시 snapshot을 복원하고 실패 결과를 호출자에게 반환한다.
- schema migration과 손상 값 정규화는 현재 facade의 load orchestration에 남겼다. migration은
  옛 schema와 현재 도메인 양쪽을 알아야 하므로, 단순 I/O repository에 규칙을 숨기지 않았다.

따라서 “진행도 규칙”과 “어디에 어떤 키로 저장하는가”가 분리되면서도 기존의 메모리/디스크/UI
원자성은 유지된다.

### 4. AudioSettingsAdapter

추가 위치: `start_screen/scripts/audio_settings_adapter.gd`.
연결 위치: `start_screen/scripts/start_screen_settings.gd`의 세 볼륨 명령,
`ensure_audio_buses()`, `apply_audio()`.

- `BlockFighterAudioSettingsAdapter`가 master/music/sfx percent 원본을 소유한다.
- BGM/SFX bus의 생성, 음소거, 선형 percent→dB 변환, master 곱, 기존 SFX 50% 보정과 -10dB
  보정을 이 adapter 한 곳에서 적용한다.
- `StartScreenSettings`에는 `AudioServer` 호출이 남지 않는다. 기존 공개 percent property는
  adapter에 위임하는 호환 seam이다.
- 저장은 adapter의 detached snapshot만 받는다. 저장소는 오디오 엔진을 모르고, adapter는
  `ConfigFile`을 모른다.

이제 설정 파일 schema 변경과 믹서 정책 변경이 서로 다른 파일에서 일어난다. 테스트에서도 값의
저장과 실제 bus 적용을 별도 증거로 확인할 수 있다.

### 역할 흐름

```text
메뉴 입력 → StartScreen (흐름 조정)
              ├─ ScreenRouter → ScreenView(root 표시·진입 초점)
              └─ StartScreenSettings facade
                    ├─ ProgressionService (규칙·진행도 원본)
                    ├─ AudioSettingsAdapter (볼륨 원본·AudioServer 적용)
                    └─ SettingsRepository (ConfigFile I/O)
```

### 장점

- 캐릭터 해금/별 보상/패시브 비용 변경은 저장 파일과 AudioServer 코드를 건드리지 않는다.
- 저장 위치·schema·직렬화 변경은 진행도 계산과 믹서 계산을 건드리지 않는다.
- 볼륨 bus나 감쇠 정책 변경은 진행도와 ConfigFile migration에 영향을 주지 않는다.
- 현재 화면 원본이 하나라 메뉴 root 두 개가 동시에 보이거나 GAME host와 메뉴가 겹칠 가능성이
  줄었다.
- Progression snapshot과 UI View root가 명시돼 독립 테스트와 향후 save/replay 복구가 쉬워졌다.
- 기존 public API와 scene 구조를 유지해 Stage 1~4 기능 및 저장 파일과의 호환성을 보존했다.

### 비용과 남은 한계

- 호환 facade가 forwarding property와 트랜잭션 orchestration을 유지하므로
  `StartScreenSettings`가 즉시 작은 파일이 되지는 않았다.
- 진행도/오디오 load 값 정규화와 schema migration은 아직 facade에 있다. migration 종류가 늘면
  별도 `SettingsMigration` 정책으로 추출할 가치가 있다.
- 각 ScreenView는 독립 인스턴스지만 UI node 조립 함수와 많은 control 참조는 StartScreen에
  남아 있다. 화면별 레이아웃이 자주 독립 변경되기 시작하면 builder를 View별 파일로 옮길 수 있다.
- GDScript property 호환을 위해 facade에서 `star_currency` 직접 대입이 가능하다. 생산 UI는 명령을
  사용하지만, 다음 단계에서 fixture 전용 주입 API를 마련하면 setter를 더 엄격히 봉인할 수 있다.
- RefCounted 서비스 간 의존성은 단순하지만 interface/protocol을 언어 수준에서 강제하지 않는다.
  테스트 double이 필요해지면 repository/adapter port를 얇은 base class로 정의할 수 있다.

### 검증 계약

`start_screen/tests/main_ui_test.gd`에 다음 10개 구조/런타임 assertions를 추가했다.

- Router가 현재 화면을 소유하고 미등록 화면 전환을 무변경으로 거부한다.
- 게임 외 9개 화면 root가 각각 ScreenView로 등록되고 대상 View만 표시된다.
- ProgressionService, SettingsRepository, AudioSettingsAdapter가 실제 Settings facade에 연결된다.
- facade 공개 값이 분리된 원본 상태를 투영한다.
- repository만 테스트 설정 경로를 소유한다.
- Progression snapshot 배열 변경이 원본 진행도를 오염시키지 않는다.
- adapter가 BGM/SFX AudioServer 경계를 실제로 생성·적용한다.

5단계 완료 당시 gate snapshot:

- 메인 게임: 277 assertions, failures 0
- 메인 UI: 132 assertions, failures 0
- 캐릭터 해금 persistence 전용 테스트: failures 0
- runtime integration: 9 suites
- Godot 4.7.1 Web release export와 필수 산출물 검사

이 수치는 6단계의 순수 계약·추가 회귀 검사가 들어오기 전 기록이다. 현재 공식 수치는 아래
6단계와 최종 재검증 절의 55/281/134다.

## 6단계 — 테스트 증거 3계층 분리

상태: 완료.

### 변경 전과 설계 일치 여부

변경 전에도 `main_game_test`, `main_ui_test`, runtime integration 9종, Web export와 브라우저
smoke가 있어 실제 연결과 배포 증거는 강했다. 그러나 순수 Board/GameSession 계약 검증이
2,000줄이 넘는 `main_game_test.gd` 안에 섞여 있었다. 규칙 실패 하나를 확인해도 Scene node,
Controller signal과 fixture 설정을 함께 이해해야 했고, release manifest도 모든 테스트를 평평한
step 목록으로만 기록했다.

6단계는 계획대로 제품 규칙을 다시 복제하지 않고 증거의 질문을 세 층으로 분리했다.
`tests/contracts/pure_contract_test.gd`를 1층 공식 gate로 추가하고, 기존 main/UI/runtime를
2층 Scene 연결 증거로 분류했으며, 기존 Web export·ZIP·실제 브라우저 smoke를 3층으로 유지했다.
`release.ps1`과 `build_web.sh`도 1→2→3 순서를 명시적으로 실행한다.

### 1층 — 순수 계약 테스트

추가 위치: `tests/contracts/pure_contract_test.gd`.

테스트 대상은 `MainBoardModel`, `MainGameSession`, `MainCommandResult`, `MainGameEvent`,
`BlockFighterProgressionService`다. `PackedScene`이나 gameplay Node를 만들지 않고 RefCounted
객체만 사용한다.

각 테스트는 다음 구조를 따른다.

```text
before_snapshot + command
  성공 → after_snapshot + committed events가 같은 사실을 표현
  실패 → after_snapshot == before_snapshot, result.events.is_empty()
```

55 assertions가 다음을 검증한다.

- Board lock 성공의 셀/얼음 동시 커밋과 중복·점유 실패의 전체 snapshot 동일성
- 소방관 물길 성공·교체·제거 사건과 session 상태 일치
- 잘못된 방향·막힌 경로·빈 효과 제거 실패의 snapshot 동일성과 빈 사건
- 방패 셀·방향·수명과 사건 일치, 잘못된 방향 실패 원자성
- 시계공 두 freeze 값의 동시 커밋, aggregate 불일치 실패 원자성
- 시계공·방패·물길 batch reset의 사건 수·이유·최종 빈 snapshot
- 진행도 최고 별 차액, 무피해, 다음 층 해금, 중복 보상 방지
- 잘못된 층과 재화 부족 강화 실패의 진행도 snapshot 동일성
- Board snapshot, Result events, Event cells, Progression snapshot의 alias 격리
- Session이 자체 game state와 `GameRules`로 명령을 검증하고 호출자가 수명을 주입하지 못하는 경계
- 물길·시계공 만료의 원자적 정리와 중복 제거 사건 방지
- 생명·gameplay cooldown의 음수 차단과 실제 delta 감소

이 계층은 signal 순서나 node path를 증명하지 않는다. 도메인 명령 자체가 외부 효과 없이도
결정적이라는 사실만 빠르게 증명한다.

### 2층 — Scene 연결 테스트

기존 위치: `tests/main_game_test.gd`, `start_screen/tests/main_ui_test.gd`,
`tests/*_runtime_integration_test.gd` 9종과 캐릭터 해금 persistence 1종.

이 계층의 역할은 다음 연결을 증명하는 것이다.

- 실제 Scene node와 script/export 연결
- `CharacterInputAdapter → InputFrame → AbilityResolver → GameSession`
- 명령 결과와 Controller signal이 View/VFX에 도달하는지
- CharacterMotor와 실제 Physics frame·collision·시전 지연
- StartScreen View/Router와 Settings의 Progression/Repository/Audio adapter 연결

순수 실패 조합은 새 1층에서 우선 검증하고, 2층은 wiring과 시간축을 중심으로 유지한다.
기존 동작 계약에 Session 봉인, 정확한 청소부 사건, 닌자 충돌 시점 안전성,
ScreenView 포커스, 설정 Codec 경계를 추가해 main 281개, UI 134개로 보강했다.

### 3층 — 배포 테스트

기존 위치: `release.ps1`, `build_web.sh`.

- Godot 4.7.1 Web release export와 네 필수 파일을 검사한다.
- source-only tests/docs/tools가 ZIP에 들어가지 않았는지 검사한다.
- HTTP 200과 실제 headless browser의 title/canvas를 검사한다.
- 실제 30초 로딩 뒤 console error 0과 비어 있지 않은 밝은 스크린샷을 확인한다.

3층은 1·2층의 규칙 정확성을 대신하지 않는다. 반대로 순수 계약 성공도 export preset, WASM,
브라우저 초기화를 증명하지 못하므로 세 층을 모두 유지한다.

### 공식 파이프라인과 증거 metadata

- `release.ps1`은 import 다음에 `pure_contract_test` 55개를 가장 먼저 실행한다.
- `release-manifest.json`의 `verification.layers`가 `pure_contract`, `scene_connection`,
  `deployment`의 목적과 step 목록을 기록한다.
- `build_web.sh`는 `[LAYER 1/3]`, `[LAYER 2/3]`, `[LAYER 3/3]` 표식을 출력하고 같은
  gate 순서를 사용한다.
- 분류 규칙과 새 테스트 배치 기준은 `tests/TEST_EVIDENCE_LAYERS_KO.md`에 기록했다.

### 장점

- 규칙 회귀가 Scene wiring 실패보다 먼저, 더 짧고 직접적인 메시지로 발견된다.
- 실패 시 snapshot 동일성이 공식 계약이 되어 부분 커밋과 숨은 사건 발생을 조기에 차단한다.
- Scene 테스트는 node 연결·input·signal·physics에 집중해 실패 원인 범위가 좁아진다.
- 배포 성공과 규칙 성공이 manifest에서 서로 다른 증거로 남아 “export됐으니 규칙도 맞다”는
  잘못된 결론을 막는다.
- 순수 suite는 Scene fixture가 없어 캐릭터·보드 규칙 추가 시 빠르게 확장할 수 있다.
- 각 계층의 중복 목적이 줄어 전체 테스트 시간이 증가하는 속도를 제어할 수 있다.

### 비용과 남은 한계

- `main_game_test.gd`에는 과거에 작성한 순수 성격 assertions가 여전히 일부 남아 있어 당장은
  1·2층 사이에 중복이 있다. 한 번에 삭제하면 회귀 증거를 잃으므로 신규 계약부터 1층 우선으로
  배치하고 기존 것은 점진적으로 이동한다.
- 순수 suite도 GDScript 실행을 위해 Godot `SceneTree` runner를 host로 사용한다. 다만 Scene이나
  gameplay Node를 인스턴스화하지 않으므로 테스트 대상은 RefCounted 도메인에 한정된다.
- ProgressionService는 아직 typed `MainGameEvent`를 반환하지 않고 Dictionary 결과를 사용한다.
  이 부분은 상태 snapshot 계약으로 검증하며, 향후 메뉴 도메인 사건이 필요해질 때 별도 event
  타입을 도입할 수 있다.
- 1층 성공만으로 signal 연결, draw 결과, 실제 충돌, export 성공을 보장하지 못하므로 2·3층을
  생략할 수 없다.
- 공식 `release.ps1`은 깨끗한 태그 작업 트리를 요구하므로 개발 중 미커밋 상태에서는 각 gate를
  workspace-local 로그로 따로 실행해야 한다.

### 현재 검증 계약

- 순수 계약: 55 assertions, failures 0
- 메인 Scene/게임: 281 assertions, failures 0
- 메인 UI/메뉴 연결: 134 assertions, failures 0
- runtime Scene/persistence integration: 10 suites
- Web release export, 필수 파일, ZIP 및 브라우저 smoke 유지

공식 assertion gate는 `release.ps1`, `build_web.sh`, `docs/GAME_OVERVIEW_KO.md`에
55/281/134로 동기화했다.

## 재검수 보강 — 상태 봉인과 커밋 시점 안전성

초기 2~6단계 구현을 다시 검수한 뒤 다음 경계를 보강했다.

- `MainGameRules`가 소방관 최대 길이·지속시간, 방패·시계공 지속시간을 소유한다. 공개 명령은
  이 값을 인자로 받지 않으므로 잘못된 0초 효과를 성공 상태로 만들 수 없다.
- `MainGameSession`의 지속 효과 배열·방향·시간과 생명·쿨다운은 읽기 전용 query 뒤에 두고,
  변경은 cast/clear/advance/player resource 명령으로만 수행한다.
- `GameController.session` 원본 노출을 제거했다. Scene/View/Character는 Controller의 snapshot과
  좁은 명령 API만 사용한다.
- 닌자와 복서는 입력 당시 방향·대상 의도는 보존하지만, 활성 피스를 움직이기 직전에는 현재
  캐릭터 collider snapshot을 다시 검사한다. 지연 중 캐릭터가 이동해도 피스를 몸 안으로 밀지 않는다.
- 청소부는 후보 세 칸을 사건에 기록하지 않고 `MainBoardMutationReceipt`가 반환한 실제 제거 셀만
  기록한다. 상태와 사건을 리플레이·VFX·업적에서 동일한 사실로 해석할 수 있다.
- `MainCharacterRuntimePort`가 GameController의 캐릭터 의존을 max lives, collider snapshot,
  binding, hazard damage, local reset으로 제한한다. batch reset은 캐릭터 로컬 정리에서 다시
  GameController를 호출하지 않아 중복 제거 경로를 만들지 않는다.
- 스킬 정책은 문자열 `has_method/call` reflection 대신 등록된 typed target Callable을 사용한다.
- `ScreenView`가 화면 진입 시 포커스 후보·우선순위·비활성 fallback을 소유하고 StartScreen은
  화면과 버튼의 배선만 담당한다.
- `SettingsCodec`이 ConfigFile section/key schema, `SettingsRepository`가 파일 경로와 I/O,
  `StartScreenSettings`가 값 검증과 migration을 맡는다.
- `GameView`는 닌자 투사체도 draw마다 typed snapshot을 한 번만 읽어 그리기 함수에 전달한다.
  충돌 VFX 수명 상수는 `CharacterController`가 아니라 `MainGameRules`에서 읽는다.
- 브라우저 smoke를 생략한 release manifest는 `PASS`가 아니라
  `PASS_WITHOUT_BROWSER_SMOKE`로 기록하며 persistence suite도 공식 Scene 계층에 포함한다.

## 최종 재검증 결과 — 2026-09-04

현재 미커밋 개발 트리를 Godot 4.7.1로 다시 검증한 결과는 다음과 같다.

- 순수 계약: 55 assertions, failures 0
- 메인 Scene/게임: 281 assertions, failures 0
- 메인 UI/메뉴: 134 assertions, failures 0
- 실제 입력·물리 runtime integration 9종: 모두 exit 0
- 캐릭터 해금 persistence: `failures=0`; 릴리스가 읽는 결과 표식도 배열이 아닌 안정적인 숫자로 통일
- Web release export: `index.html`, `index.js`, `index.wasm`, `index.pck` 모두 생성·비어 있지 않음
- Web ZIP: 필수 항목 4개, 누락 0, source-only 금지 경로 0
- 실제 브라우저: HTTP 200, `Block Fighter`, canvas 1개, 30초 뒤 loading progress 숨김,
  browser error 0, 시작 화면 렌더링 확인
- `release.ps1` PowerShell parser, `build_web.sh`의 `bash -n`, `git diff --check`: 모두 통과
- 최종 로그에서 `SCRIPT ERROR`, `Parse Error`, `Compile Error`, ObjectDB/resource leak 표식: 0

Godot 로그에는 제한된 Windows 실행 환경 때문에 모든 프로세스에서 root certificate store를 읽지
못했다는 플랫폼 메시지가 있고, Web export 종료 때 AppData의 editor settings를 저장하지 못했다는
메시지가 있다. 두 종류 모두 workspace-local `--log-file`을 사용한 실행은 exit 0이었고 테스트,
리소스 패킹, WASM 브라우저 초기화에는 영향을 주지 않았다. 소스 오류와 구분해 기록하며 릴리스
게이트의 오류 검사를 약화시키지는 않았다.

공식 `release.ps1` 전체 실행은 의도적으로 수행하지 않았다. 이 스크립트는 깨끗하고 태그된 source를
요구하는 최종 배포 경계인데, 현재 작업은 1~6단계 미커밋 변경을 보존해야 하기 때문이다. 대신 같은
세 계층 gate를 workspace-local 로그와 별도 Web 산출물로 실행했다. 커밋·태그는 만들지 않았다.
