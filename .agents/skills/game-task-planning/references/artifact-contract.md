# 산출물 규격 · v1

## 공통 envelope

모든 산출물은 아래 값을 본문 또는 기존 실행 기록의 정확한 locator/revision으로 제공한다. 감독을 거치지 않은 단일 호출도 task ID와 attempt 1을 부여한다. 없는 값을 만들어 내지 말고 미정 이유와 반환 소유자를 적는다.

| 필수 필드 | 작성·소비 규칙 |
| --- | --- |
| artifact ID, type/version, location/revision | 아래 유형과 원본을 식별한다. 문서가 아닌 코드·이미지는 sidecar 또는 인계 기록 사용 |
| task/attempt, producer executor, role ID/version | 실제 작성자와 적용한 카드 식별. 공유 실행이면 run/dispatch도 연결 |
| inputs/revisions, intent/criterion IDs | 어떤 요구와 후보에서 나온 결과인지 연결 |
| body template/rule locator/version, consumer | 아래 유형의 내용과 실제 다음 역할. 기존 템플릿을 중복 작성하지 않음 |
| decision states, source links, blockers/return owner | 사실·제안·확정·위임·미정을 구분. 해당 사항 없음은 사유 필요 |
| verification contract, separate verifier executor, result/evidence | 고정 범위·허용 수정·한도 및 현재 검증. 미실행은 unverified; 작성자와 같은 executor는 거부 |

프로필은 설정표와 정확한 참조만 본문에 둔다. 위 envelope의 작업·작성자·검증 정보는 기존 인계/검증 기록에 연결하며 본문에 반복하지 않는다. 프로필 전용 JSON·전체 출처 해시·별도 승인 문서를 필수로 만들지 않는다.

## 유형별 본문

각 행은 최소 작성 양식이다. 필수 내용은 채우거나 적용 제외 이유를 적는다. 스킬 본문의 전문 규칙과 전용 템플릿은 그대로 추가 적용한다.

| 역할 / type@version | 필수 내용 / 원본 양식 | 소비·반환 기준 |
| --- | --- | --- |
| game-workflow / routing@1 | routing-template의 원문·범위·의도·선택·다음 경로 | 요청 범위가 바뀌면 라우터 반환 |
| game-knowledge-maintenance / knowledge-delta@1 | 대상 페이지/주장, 출처와 revision·적용 범위·확인 상태, 필수/선택 구분, 변경 또는 생략 이유, 의미·문서 검증 결과, 미해결 충돌 | 원본 보존, 현재 근거 일치, 필수 갱신 검증 완료; 관련 없는 정리는 보류 |
| game-project-profile / profile@1 | profile-template의 적용 가능한 공통 설정·실제 명령·기존 기준 참조 | 정확성·충분성·조회 용이성 확인; 미정 값은 의존 작업만 차단 |
| game-feature-spec / specification@1 | feature-spec-template의 의도·상태·수용 기준·보존 조건 | proposed/unresolved에 의존하는 구현 차단 |
| game-workflow-supervision, 세 indie-game 진입 / run@1 | run-template의 작업·사건·검증·수용·최종 상태 | 미충족 필수 기준은 완료 불가 |
| game-workflow-audit / workflow-audit@1 | 감사 trigger/비용·run/task/candidate revision·실제 소비 스킬/인접 handoff·범위/한도; 4종 finding과 5종 원인 계층·근거/계약 비교/owner; 제한 개선 eligibility·최소 변경/제외/원래 사례와 무관 사례 검사/비용·rollback | 읽기 전용 shadow 결과이며 자동 task/gate/edit/완료 판정이 아님. 별도 권한의 author와 auditor·author 모두와 다른 verifier 없이는 개선으로 소비하지 않음 |
| game-task-planning / plan@1 | run-template Tasks/Acceptance: 소유자·입출력·의존·읽기/쓰기·자원·join | 입력/실행자/양식 미정은 해당 dispatch 차단 |
| game-technical-design / design@1 | technical-design-template: 현 코드·선택 이유·계약·실패·검증·인계 | 중대한 결정 미정은 담당자에게 반환 |
| game-improvement-assessment / assessment@1 | 기준선 후보/환경·관측·가설·대안/비용·보존 조건·비교 기준; 의도 ID/출처/confirmed-proposed-delegated-unresolved/선택 이유 | 위임 출처와 선택 결과 없이 제안을 구현 범위로 소비하지 않음; 비교 조건이 다르면 inconclusive |
| game-bug-reproduction / reproduction@1 | 기대값/출처/확정 상태·실제값·환경/후보·초기 상태/fixture·입력 순서·성공/전체 시도 수·원본 증거·한계 | 기대값 미정은 명세 반환, 관측은 보존; 재현 실패는 결함 부재 아님 |
| game-bug-diagnosis / diagnosis@1 | 관측 사실·경쟁 가설·가설 구별 관측·신뢰도·영향 계약·수정 소유자/범위·다음 확인 | 증상만으로 원인 확정 금지; 불충분 근거는 다음 관측 반환 |
| game-test-design / scenarios@1 | scenario/criterion ID·후보/target·사전조건/fixture·행동·예상 관측·증거·설계자/테스트 작성자/실행자·회귀 경계 | 기대값 출처 또는 실행 능력 미정은 해당 사례 차단; 실제 결과를 미리 채우지 않음 |
| 구현 8역할 및 game-test-infrastructure / change@1 | 변경 파일/후보·계약 revision·소유 상태·변경 이유·로컬 회귀 증거·실패/인계 | 범위 밖 변경 거부; 도구는 알려진 실패 감지 근거 필요 |
| game-performance-profiling / measurement@1 | 안정 후보/격리 방법·환경/작업부하·계측 조건/반복·분포/비용·원본 trace·가설/교란·한계 | 입력 변경 시 증거 무효; 다른 조건의 비교는 개선 판정 불가 |
| game-build-packaging / package@1 | 입력 후보·도구/설정·target·재현 명령·출력 manifest/hash·패키지 검사 | 패키징을 기능 통과나 공개로 소비하지 않음 |
| game-functional-verification / verification@1 | criterion/scenario별 후보·실행/관측·환경·원본 증거·pass/fail/inconclusive·유효성·반환 | 미실행/변경 중 입력은 통과 불가 |
| game-code-review / review@1 | 후보·작성자/리뷰어·고정 범위·발견 위치/발생 조건/영향/수정 소유자·판정/한계 | 근거 없는 취향은 결함 아님; 자기 리뷰는 독립 판정 불가 |
| game-ui-ux-design / ui.game-ui-ux-design@1 | UX decision output-contract의 과업·흐름·정보/상호작용 위계·배치 의도·상태/대상 시나리오·인계와 결정 출처 | 실제 사용자 조사/런타임/시각 승인을 주장하지 않고 component·screen-spec·mockup에 영향 결정을 인계 |
| 기존 UI 역할 / ui.<skill-name>@1 | 선택한 모드의 원본 UI 출력 규격 locator와 파일 hash; 정식 모드의 필수 표/coverage/승인 기록 | ui-adapter 계약과 선택한 모드의 원본 소비 검사 함께 적용 |

game-ui-implementation은 같은 역할/type을 유지하고 배정 기록에 `playable-functional`, `source-preparation`, `full-integration` 중 하나를 명시한다. `playable-functional`에는 [기능 인계](../../game-ui-implementation/references/output-contract.md#playable-functional-interface), `source-preparation`에는 [원본 준비 결과](../../game-ui-implementation/references/output-contract.md#code-native-runtime-source-preparation-before-asset-readiness), `full-integration`에는 정식 구현 packet·matrix를 적용한다. 정식 표/coverage/승인 기록을 다른 두 모드의 가짜 값으로 채우지 않는다. 공통 envelope·독립 검증은 세 모드 모두에 적용한다.

구현 8역할은 rule/input/movement/camera/session/content-loading/save/platform이다. 소비자는 공통 envelope의 입력·상태·현재 증거와 해당 유형의 실제 의미를 검사한다. 형식 또는 내용 누락은 그 산출물 소유자에게 반환하며 검증 범위를 늘리지 않는다.
