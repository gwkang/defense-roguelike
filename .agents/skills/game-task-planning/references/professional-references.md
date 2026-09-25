# 전문 근거 선택 · v1

단순 작업은 기존 프로젝트 근거를 재사용하고 `추가 자료 불필요: 이유`만 기록한다. 엔진/API 보장·시간·수명·저장·계측·접근성 판단이 결과를 바꾸면 해당 자료만 확인한다. 참고 자료는 제품 범위나 검증 항목을 늘리는 권한이 아니다.

## 선택 기록 양식
| ID/card version | 발행자/제목/URL/관련 절 | 확인일/상태 | engine/tool/version/target | 필요한 결정 ID·권고/API/채택 요구 구분 | 채택/미채택·이유/한계 | artifact/verification ID |
| --- | --- | --- | --- | --- | --- | --- |

상태는 verified/unverified/stale. verified는 실제 확인한 버전/절에만 쓴다. 아래 후보는 과거 선별 자료이며 이번 실행의 현재 API 확인 증거가 아니다. 현재 버전의 공식 문서·설치 소스와 대조한 뒤 선택 기록을 채운다. 접근 실패 시 필수 미정 판단만 차단하고, 이론 참고 실패로 독립 작업까지 멈추지 않는다. 다른 엔진/저장 백엔드에 보장을 전이하거나 권고 수치를 채택 근거 없이 강제하지 않는다.

## 조건부 후보 카드

### REF-01 — 게임 경험과 규칙 연결 · card v1

- 출처: Robin Hunicke, Marc LeBlanc, Robert Zubek, [MDA: A Formal Approach to Game Design and Game Research](https://www.cs.northwestern.edu/~hunicke/MDA.pdf), 2004.
- 읽을 때/역할: 원하는 경험이 추상적이거나 기능 변경의 플레이 영향을 설명할 때. game-feature-spec, game-improvement-assessment, game-test-design.
- 우리 적용: '재미있게'를 원하는 경험, 그 경험을 만드는 플레이 상황, 이를 지원할 행동 규칙으로 구체화한다. 성공 사례와 반례를 명세에 연결한다.
- 검증: 실제 플레이 관측이 의도한 경험을 지지하는지 확인한다. MDA 양식을 채웠다는 이유로 재미가 검증됐다고 주장하지 않는다. 별도 프로토타입 단계를 강제하지 않는다.
- 등록 상태: unverified for current target; 실제 사용 시 위 선택 기록으로 확인일/버전/적용 한계와 결정·검증을 고정.

### REF-02 — 시간 스텝과 시뮬레이션 · card v1

- 출처: Glenn Fiedler, [Fix Your Timestep!](https://gafferongames.com/post/fix_your_timestep/), 2004.
- 읽을 때/역할: 프레임률에 따른 이동 차이, 물리 불안정, 카메라 떨림, pause/resume 시간 처리. game-technical-design, game-movement-implementation, game-camera-implementation, game-session-implementation, game-performance-profiling.
- 우리 적용: 프로젝트의 시뮬레이션/렌더링 시계와 엔진의 기존 업데이트 방식을 먼저 확인한다. 시간 스텝·보간·처리 한도의 선택 이유를 기술 계약에 기록한다.
- 검증: 서로 다른 프레임률, 일시적 긴 프레임, 중단 후 재개 시나리오를 관측한다. 기존 엔진 루프 위에 별도 루프를 무조건 추가하지 않으며 고정 스텝만으로 모든 플랫폼의 결정론을 보장하지 않는다.
- 등록 상태: unverified for current target; 실제 사용 시 위 선택 기록으로 확인일/버전/적용 한계와 결정·검증을 고정.

### REF-03 — 코드 검토의 판단 기준 · card v1

- 출처: Google Engineering Practices, [What to look for in a code review](https://google.github.io/eng-practices/review/reviewer/looking-for.html).
- 읽을 때/역할: substantive 코드 변경, 설계 대안이나 리뷰 기준이 불명확할 때. game-code-review, game-technical-design, programming-supervisor.
- 우리 적용: 실제 결함·유지보수 위험과 취향을 구분한다. 테스트 코드의 기대값도 읽고 근거 있는 finding으로 보고한다.
- 검증: finding에 발생 조건·영향·위치·수정 소유자가 있는지 확인한다. 팀 전용 스타일을 모든 엔진/언어에 강제하지 않는다.
- 등록 상태: unverified for current target; 실제 사용 시 위 선택 기록으로 확인일/버전/적용 한계와 결정·검증을 고정.

### REF-04 — 게임 텍스트 가독성 · card v1

- 출처: Microsoft, [Xbox Accessibility Guideline 101: Text display](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101).
- 읽을 때/역할: 작은 글자, 텍스트 확대, 화면 거리/크기, 현지화에 따른 읽기 문제. game-ui-screen-spec, game-ui-handoff, game-ui-runtime-validation, game-ui-acceptance-review.
- 우리 적용: 대상 기기와 언어에 맞는 가독성/확대 기준을 명세하고 실제 화면에서 확인한다.
- 검증: 작은 대상 화면, 긴 문구, 적용되는 확대 상태의 클리핑과 조작성을 관측한다. Xbox 전제의 수치를 모바일에 그대로 복사하거나 지침을 인증 통과로 표현하지 않는다.
- 등록 상태: unverified for current target; 실제 사용 시 위 선택 기록으로 확인일/버전/적용 한계와 결정·검증을 고정.

### REF-05 — 게임 입력·감각·인지 접근성 · card v1

- 출처: Game Accessibility Guidelines 발행팀, [Full list](https://gameaccessibilityguidelines.com/full-list/).
- 읽을 때/역할: 입력 방식·색상 의존 정보·설정·사용자 이해·실패 피드백을 변경할 때. game-feature-spec, game-input-implementation 및 UI 역할.
- 우리 적용: 관련 항목만 선택해 프로젝트 의도·대상과 맞는 수용 기준으로 연결한다. 필요한 제품 선택은 제안과 확정을 구분한다.
- 검증: 선택한 입력/정보 전달 방식의 실제 동작을 관측한다. 체크리스트만으로 모든 장애·사용자군의 접근성 검증을 완료했다고 하지 않는다.
- 등록 상태: unverified for current target; 실제 사용 시 위 선택 기록으로 확인일/버전/적용 한계와 결정·검증을 고정.

### REF-06 — Godot 장면 경계 · card v1

- 출처: Godot 공식 문서, [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html).
- 읽을 때/역할: Godot 프로젝트에서 장면 경계나 노드 관계 변경. game-technical-design, game-session-implementation, game-content-loading.
- 우리 적용: 실제 Godot 버전에 맞는 페이지로 다시 확인하고 부모/자식 소유·의존성·신호 연결을 설계한다.
- 검증: 장면 재사용·반복 진입/종료와 연결 해제를 확인한다. Godot의 노드 관례를 다른 엔진의 필수 구조로 강제하지 않는다.
- 등록 상태: unverified for current target; 실제 사용 시 위 선택 기록으로 확인일/버전/적용 한계와 결정·검증을 고정.

### REF-07 — Unity 성능 측정 · card v1

- 출처: Unity 6.0 공식 매뉴얼, [Profiler](https://docs.unity3d.com/6000.0/Documentation/Manual/Profiler.html).
- 읽을 때/역할: 해당 Unity 버전 프로젝트의 병목 조사. game-performance-profiling, game-improvement-assessment.
- 우리 적용: 실제 사용 버전·빌드·측정 대상과 계측 조건을 기록하고 관련 모듈로 원인을 조사한다.
- 검증: 동일 시나리오와 대상 환경의 전후 결과를 비교한다. 에디터 측정만으로 대상 기기 개선을 단정하지 않는다. 다른 버전/엔진에서는 해당 공식 자료를 선택한다.
- 등록 상태: unverified for current target; 실제 사용 시 위 선택 기록으로 확인일/버전/적용 한계와 결정·검증을 고정.

### REF-08 — Phaser 장면 수명주기 · card v1

- 출처: Phaser 공식 문서, [Scenes](https://docs.phaser.io/phaser/concepts/scenes).
- 읽을 때/역할: Phaser 프로젝트의 장면 전환, pause/sleep/restart, 이벤트 수명 변경. game-session-implementation, game-input-implementation, game-content-loading, game-code-review.
- 우리 적용: 설치된 Phaser 버전의 실제 API와 소스를 대조하고 상태별 이벤트·입력·자원 책임을 정한다.
- 검증: 반복 재시작, 일시정지/복귀, 종료 후 늦은 콜백과 중복 입력을 확인한다. 장면 일시정지와 게임 전체 정지를 같다고 가정하지 않는다.
- 등록 상태: unverified for current target; 실제 사용 시 위 선택 기록으로 확인일/버전/적용 한계와 결정·검증을 고정.

### REF-09 — 저장의 원자성 가정 · card v1

- 출처: SQLite 공식 기술 문서, [Atomic Commit In SQLite](https://www.sqlite.org/atomiccommit.html).
- 읽을 때/역할: SQLite 기반 저장이나 커밋 실패/중단 복구의 개념 검토. game-save-implementation, game-technical-design, game-bug-diagnosis.
- 우리 적용: 쓰기 완료·내구성·복구의 구분을 저장 계약에 명시하고 실제 저장 백엔드의 공식 보장을 별도로 확인한다.
- 검증: 부분 실패·중단·재시작과 마이그레이션 실패를 시험한다. 이 자료의 보장을 JSON 파일/localStorage/서버 API에 전이하지 않는다. 워크플로우 원장도 SQLite를 사용하지 않으면 별도 보장 검증이 필요하다.
- 등록 상태: unverified for current target; 실제 사용 시 위 선택 기록으로 확인일/버전/적용 한계와 결정·검증을 고정.

### REF-10 — 브라우저 검증 안정성 · card v1

- 출처: Playwright 공식 문서, [Best Practices](https://playwright.dev/docs/best-practices).
- 읽을 때/역할: Playwright를 실제로 사용하는 브라우저 게임의 검증 도구. game-test-design, game-test-infrastructure, game-functional-verification, game-ui-runtime-validation.
- 우리 적용: 테스트 간 상태 의존을 제거하고 실제 상태 조건을 관측한다. 테스트 환경에 맞는 trace/실패 증거를 보존한다.
- 검증: 알려진 결함 주입으로 하네스가 실패를 잡는지 확인한다. canvas 내부 객체를 DOM locator가 볼 수 있다고 가정하지 않는다. 렌더링과 게임 상태 관측 수단을 별도로 설계한다. 네이티브 게임에 Playwright 설치를 강제하지 않는다.
- 등록 상태: unverified for current target; 실제 사용 시 위 선택 기록으로 확인일/버전/적용 한계와 결정·검증을 고정.
