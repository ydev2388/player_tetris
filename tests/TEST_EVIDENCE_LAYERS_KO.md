# 테스트 증거 3계층

테스트 파일의 수나 내부 함수 수가 아니라, 서로 다른 질문에 답하는 증거를 분리한다.
상위 계층이 하위 계층을 대체하지 않으며, 공식 검증은 1→2→3 순서로 실행한다.

## 1층 — 순수 계약

질문: SceneTree 상태나 프레임 타이밍 없이도 도메인 명령의 계약이 맞는가?

공식 suite: `res://tests/contracts/pure_contract_test.gd`

형식:

```text
이전 detached snapshot + command
  → 성공: 새 snapshot + committed events
  → 실패: 이전 snapshot과 동일 + events 비어 있음
```

현재 증거:

- Board 유효 lock의 셀/얼음 metadata 동시 커밋
- Board 중복 좌표·점유 대상 lock 실패의 snapshot 동일성
- 소방관 성공/교체/제거의 상태와 사건 payload 일치
- 소방관 잘못된 방향·막힌 경로·빈 효과 제거 실패의 snapshot 동일성
- 방패 성공의 셀·방향·수명과 사건 일치, 잘못된 방향 실패의 snapshot 동일성
- 시계공 두 freeze 값의 동시 커밋, 잘못된 aggregate 실패의 snapshot 동일성
- 효과 일괄 제거의 세 사건과 최종 빈 snapshot
- 물길·시계공 만료의 단일 사건, 빈 효과의 중복 만료 방지
- 생명·gameplay cooldown의 범위와 delta 진행
- 진행도 별 차액·무피해·다음 층 해금, 중복 완료·잘못된 층·재화 부족 실패
- Board/Event/Result/Progression snapshot 별칭 격리

이 suite는 `PackedScene.instantiate()`나 gameplay Node를 사용하지 않는다. Godot 실행기는
GDScript를 실행하는 host일 뿐, 테스트 대상은 RefCounted 값·모델·서비스다.

## 2층 — Scene 연결

질문: 실제 Scene에서 adapter, 명령, 상태 소유자, Physics/View projection이 끝까지 연결되는가?

공식 suite:

- `res://tests/main_game_test.gd`
- `res://start_screen/tests/main_ui_test.gd`
- `res://tests/*_runtime_integration_test.gd` 9종
- `res://start_screen/tests/character_unlock_persistence_test.gd`

여기서는 다음을 확인한다.

- 실제 `main.tscn`/`start_screen.tscn` node 연결
- `CharacterInputAdapter → InputFrame → AbilityResolver → GameSession` 명령 흐름
- Controller signal/event가 View/VFX에 도달하는지
- 실제 Physics frame, 충돌, 시전 지연과 시간축
- 메뉴의 Settings facade가 진행도·오디오·저장 adapter에 연결되는지
- ScreenView 포커스 정책과 캐릭터 해금의 재실행 persistence

순수 규칙의 모든 실패 조합을 이 계층에서 반복하지 않는다. Scene suite는 wiring과 런타임
시간축에 집중한다.

## 3층 — 배포

질문: 실제로 배포할 Web 산출물이 만들어지고 브라우저에서 실행되는가?

공식 증거:

- Godot 4.7.1 Web release export
- `index.html`, `index.js`, `index.wasm`, `index.pck` 필수 파일
- source-only 디렉터리가 없는 ZIP
- HTTP 200
- 실제 headless browser의 `Block Fighter` title과 canvas
- 브라우저 console error 0, 비어 있지 않은 스크린샷

`release.ps1`의 `release-manifest.json`은 `verification.layers`에 세 계층의 목적과 step 목록을
별도로 기록한다. `build_web.sh`도 `[LAYER 1/3]`부터 `[LAYER 3/3]`까지 같은 순서로 실행한다.

## 새 테스트 배치 기준

- Scene 없이 표현할 수 있는 규칙, 불변식, 실패 원자성은 먼저 1층에 둔다.
- 실제 node path, input event, signal wiring, draw/physics projection이 필요한 증거만 2층에 둔다.
- export preset, package, HTTP, browser/WASM 실행은 3층에 둔다.
- 같은 사실을 모든 계층에서 반복하지 않는다. 대신 각 계층의 경계 연결점만 한 번 더 확인한다.
