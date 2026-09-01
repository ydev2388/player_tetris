# 재현 가능한 릴리스 증거

정식 릴리스는 다음 연결을 하나의 빌드 실행으로 증명한다.

```text
VERSION → commit → annotated tag → release.ps1 → artifact → SHA-256
```

## 각 단계의 의미

- `VERSION`은 사람이 부르는 릴리스 번호의 단일 원본이다. `project.godot`의 화면 버전과 반드시 같아야 한다.
- `commit`은 빌드 입력 전체를 고정한다. 릴리스 스크립트는 수정 파일이나 추적되지 않은 파일이 있으면 중단한다.
- annotated tag `v<version>`은 버전 이름을 정확한 commit에 결속하고 태그 작성자·시각·메시지를 남긴다.
- `release.ps1`은 태그가 가리키는 깨끗한 소스에서 테스트, export, 패키징, 실제 브라우저 실행을 수행한다.
- artifact는 이번 실행 전에 출력 디렉터리를 지운 뒤 새로 만든 itch.io 업로드용 ZIP이다.
- `SHA256SUMS`는 ZIP, 매니페스트, 로그, 실행 스크린샷이 릴리스 이후 바뀌지 않았는지 검증한다.

검증 증거는 서로 대체하지 않는다. `release-manifest.json`은 각 항목을 별도로 기록한다.

- assertion 결과 표식과 개수
- 각 프로세스의 exit code
- process log와 Godot engine log의 예상하지 못한 오류 수
- Web export 필수 파일과 ZIP 내부 구조
- HTTP 응답과 실제 headless browser 실행, 30초 실제 시간 대기, `Block Fighter` canvas 상태, 콘솔 오류 0건 및 스크린샷
- artifact 크기, 생성 시각, SHA-256

## 정식 빌드

정식 빌드는 `v1.0.2` 태그를 checkout한 깨끗한 작업 트리에서 실행한다.

```powershell
pwsh -NoProfile -File .\release.ps1
```

공백·한글이 포함된 경로도 프로세스 인자 단위로 안전하게 전달하기 위해 PowerShell 7 이상을 사용한다.

결과는 다음 위치에 생성된다.

```text
build/releases/1.0.2-<short-commit>/
├── artifact/block-fighter-web-1.0.2.zip
├── logs/
├── runtime/web-runtime.png
├── release-manifest.json
└── SHA256SUMS
```

`-AllowUntagged`는 태그를 만들기 전에 스크립트 자체를 검증하는 임시 실행에만 사용한다. 이 모드의 결과는 정식 릴리스가 아니다. `-SkipBrowserSmoke` 결과도 itch.io 배포 승인 증거로 사용하지 않는다.

브라우저 검증은 가상 시간이 아니라 실제 시간으로 WebAssembly 초기화를 기다린다. 캡처 화면의 평균 밝기가 `100` 미만이거나 밝은 표본 픽셀 비율이 `0.35` 미만이면 어두운 Godot 로딩 화면에 머문 것으로 보고 실패한다. 이 기준은 밝은 `Block Fighter` 시작 메뉴가 표시됐는지를 구분한다.
