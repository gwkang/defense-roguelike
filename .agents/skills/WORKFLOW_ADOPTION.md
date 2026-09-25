# defense-roguelike indie-game-workflow 적용

## 현재 적용본

- 공식 원본: `https://github.com/gwkang/indie-game-workflow`
- upstream revision: `09d7ce58c16ff62778e545f6d820b281ced79e96`
- bundle version: `0.9.5-ux-audit`
- 적용일: 2026-09-25
- 범위: 공식 번들의 39개 스킬, 원본 잠금 파일, LICENSE, 잠금 바이트 보존용 `.gitattributes`, 프로젝트 진입 규칙, 프로젝트 프로필, 실행 레지스트리

설치된 배포 파일은 [indie-game-workflow.lock.json](indie-game-workflow.lock.json)의 SHA-256을 기준으로 공식 원본과 동일해야 한다. 프로젝트 전용 설정은 이 문서, 루트 `AGENTS.md`, `planning/game-workflow-profile.md`, `planning/workflow-runs/`에 두며 배포 스킬 내부에 섞지 않는다.

## 사용 규칙

- 모든 새 게임 요청과 재개 요청은 `game-workflow`를 유일한 진입점으로 사용한다.
- 저장소·제품 변경, 여러 단계 작업, 열린 실행 재개, 다중 역할 또는 독립 검증이 필요한 작업은 라우팅 뒤 하나의 `game-workflow-supervision`이 이어받는다.
- 신규 개발, 개선, 버그 수정은 각각 `indie-game-development`, `indie-game-improvement`, `indie-game-bugfix` 정책으로 분류하고 필요한 전문 스킬만 사용한다.
- 상태가 있는 실행은 `planning/workflow-runs/active.json`에서 찾는다. 실행 기록과 증거는 `planning/workflow-runs/<run-id>/`에 두고 중복 기록을 만들지 않는다.
- 엔진, 플랫폼, 입력, 화면, 로케일, 명령과 제품 기준은 [프로젝트 프로필](../../planning/game-workflow-profile.md)의 현재 근거를 사용한다.
- 작성자와 별도 검증 주체의 독립 검증 계약을 유지한다. 별도 검증을 실행할 수 없는 환경에서는 자체 검사를 독립 검증으로 표시하지 않는다.

## 현재 경계

- 저장소가 초기 상태이므로 엔진·플랫폼·제품 규칙·빌드 명령은 미정이다.
- 위키 연동과 프로젝트별 모델 라우팅 프로필은 활성화하지 않았다.
- 이 적용은 게임 코드 생성, 제품/UX 결정, 에셋 선택, 커밋, 푸시, 배포 또는 출시를 승인하지 않는다.
- 현재 세션에서 파일 설치와 해시 검증을 수행할 수 있지만, 호스트의 새 스킬 자동 발견은 다음 작업 진입 시 별도로 확인한다.

## 갱신 절차

공식 원격 revision과 bundle lock을 먼저 확인한다. 기존 프로젝트 변경을 보존하고 installer의 preview를 실행한 뒤 적용한다. 내용이 다른 기존 스킬은 자동 덮어쓰지 않으며, 변경 전후 해시와 프로젝트별 overlay를 구분해 기록한다.
