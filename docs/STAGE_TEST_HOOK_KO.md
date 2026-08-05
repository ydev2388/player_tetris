# 스테이지 테스트 훅

디버그 빌드에서 게임 실행 중 `Enter`를 누르면 현재 스테이지를 즉시 3별
클리어하고 결과를 확인할 수 있습니다. 스테이지 해금·별 보상·설정 저장을
확인하기 위한 테스트 전용 훅입니다.

출시 빌드에는 포함하지 않아야 합니다. 스테이지 클리어 판정이 구현되면
`start_screen/scripts/start_screen.gd`의 `_handle_debug_completion_input()`과
`_complete_stage_for_debug()`를 제거하고 이 문서도 함께 삭제하세요.
