# Kung Fu Tetris SFX v2

48 kHz / 16-bit / mono WAV입니다. 이전 sfxr 단일 파형 대신 여러 레이어를 합성했습니다.

## 기본 연결

- 피격: `01_player_hurt.wav`
- 블록 펀치: `02_block_punch.wav`
- 블록 플립: `03a_block_flip.wav`
- 점프: `04_jump.wav`
- 줄 제거: `07_block_elimination.wav`
- 메뉴 선택: `08_select.wav`

## 명상

1. 명상 진입 시 `05a_meditation_start.wav`를 한 번 재생합니다.
2. 유지 중 `05b_meditation_loop.wav`를 반복합니다.
3. 종료 시 루프를 멈추고 `05c_meditation_end.wav`를 재생합니다.

## Godot 권장 설정

- 짧은 원샷은 `AudioStreamPlayer`로 재생합니다.
- 명상/차지 루프는 별도의 `AudioStreamPlayer`를 사용합니다.
- WAV Import의 Loop Mode는 유지 루프 파일에만 Forward로 지정합니다.
- 피격과 펀치가 겹칠 때 찢어지는 소리가 나면 SFX 버스에 Compressor를 약하게 적용합니다.
- 실제 게임에서 전체 SFX 피크는 대략 -6 dBFS 부근부터 조정하는 것이 안전합니다.

## 라이선스

이 팩은 해당 프로젝트를 위해 절차적으로 새로 합성한 파일입니다. 게임 프로젝트에서 수정 및 상업적으로 사용할 수 있습니다.
