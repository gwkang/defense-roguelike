# 작은 변경 실행 계약 · DR-WF-SMALL-001 r1

2026-10-02 사용자 “작업을 중단하고 워크플로우부터 개선해”에 따라 이 프로젝트에만 적용한다. 기존 필수 결과를 유지하고 작은 모듈의 중복 역할·보고서·봉인을 통합한다. 전역 번들·공식 lock·다른 프로젝트는 변경하지 않는다.

## 경로 선택

`planning/workflow-policy.json`과 프로젝트 프로필의 `workflow.smallChangePolicyPath`가 실제 진입점이다. 명세가 확정된 단일 모듈, 국소 버그, 실행 도구의 제한된 개선은 기본적으로 이 경로를 사용한다. 새 제품 결정, 미해결 소유권/저장 구조, 정식 아트·화면 설계, 외부 권한이 필요하면 그 결정 또는 영향을 받는 부분만 기존 전문 경로로 반환한다. 파일 수나 테스트 수만으로 역할을 늘리지 않는다.

기본 역할은 조정자, 작성자, 별도 실행 주체의 독립 리뷰어다. 작성자는 기존 충분한 설계를 짧게 연결하거나 필요한 설계 결정·코드·테스트·위키 delta를 같은 단위에서 작성한다. 리뷰어는 먼저 필요한 설계 경계를 검토하고, 안정된 후보에서 코드·가독성·실패 경계·검증·지식·완료를 함께 검토한다. 조정자는 사용자 권한, 동시 편집, 입력 버전, 원본 반영과 최종 결과를 책임진다. 별도 K01/A01 작업자, 단계별 STOP 봉인과 보고서 세트는 기본 경로에 추가하지 않는다. 리뷰어의 독립성을 역할 이름 변경이나 작성자 자체 검사로 대체하지 않는다.

T1–T4의 반복 실패·사용자 품질 반려·모순된 PASS·예산 대비 무진전은 기존 원인 계보와 수정 한도 안에서 같은 독립 리뷰어에게 범위를 좁혀 조사시킨다. 모순된 PASS에 의존한 재시도/승격은 해소 전까지 보류한다. 리뷰어가 해당 변경을 직접 작성했거나 전문성이 필요한 별도 사건이면 그 부분에만 별도 리뷰어를 둔다. 일반 완료/중요 통합 회고는 독립 리뷰의 `completion` 항목으로 통합하며 없애지 않는다.

## 한 번의 준비와 단일 증거 목록

작업 시작 때 필요한 지침 의존성을 한 번에 열거한다. 출처·revision/hash·읽기 승인/소비 기록이 있는 충분한 지침은 재사용하고 각 하위작업에 동일 근거를 전달한다. 변경 여부가 미확인이면 미확인이라고 기록한다. 보호 파일 본문을 별도 위치에 복사해 제한을 우회하지 않는다. 새 제한은 정상 권한 검토 경로에서 처리한다. 읽기 승인은 ACL 변경이 아니다.

실행 자료는 `planning/workflow-runs/<run-id>/evidence.json` 하나에 모은다. 루트/후보 파일과 hash, 권한·설계 근거, 실제 작성자/리뷰어 host acknowledgement, 검사 이름/fixture/JSON 입력, 영향별 검사, 원본·생산 save의 hash-only 보존 기준, 모든 명령·raw 출력·종료/timeout·실제 수·후보 신원을 담는다. 이전 명령 실패를 삭제하거나 새 단계에서 수리 예산을 초기화하지 않는다.

[실행 도구](tools/workflow_evidence.py)의 `init`이 상대 경로·링크 탈출·JSON·fixture anchor·실제 검사 이름·입력 신원·실행자 분리를 먼저 확인한다. `init` PASS는 준비만 뜻한다. 후보에 읽는 테스트 source도 포함한다. 파일이나 test name이 없거나 검사 계획이0이면 검증 완료가 아니다. 보호 지침을 이 도구가 임의로 읽거나 권한을 확장하지 않는다.

`check`는 shell 없이 실제 명령을 실행한다. 명령 전에 불완전 attempt를 기록하고 raw stdout/stderr를 보관한다. 검사 adapter는 현재 LÖVE/unittest 완료 표시와 실제 이름·수, smoke 관측, wiki checker 출력 또는 PNG capture를 해석한다. 종료0만으로 PASS를 만들지 않는다. 테스트0, 누락 이름, 중복 PASS, 미완료·실패·timeout, 실행 중 후보/원본/save 변경은 실패다. 마지막 실패를 이전 PASS로 덮지 않는다. 새 후보는 새 신원을 가진 연결된 기록에서 영향을 받는 검사를 다시 수행하며 과거 결과는 역사로 유지한다.

host acknowledgement는 조정자가 실제 host 응답을 근거로 기록한다. 도구는 그 신원·내용 변경 및 작성자/리뷰어 분리를 검사하지만 인증 서비스나 조작 방지 저장소는 아니다. 후보 hash는 검증 입력의 정합성이며 테스트 의미나 사람의 판단을 대신하지 않는다.

## 검증 선택

먼저 새 단위의 의미 있는 핵심 검사와 저장·실패/취소/retry 경계를 검증한다. 필요한 경우 같은 안정 후보에서 기존 핵심 회귀 또는 전체 suite 한 번과 bounded runtime smoke를 실행한다. 이미 충분히 통과한 전체 suite·폰트 probe·완료 모듈 검사를 새 보고서 때문에 반복하지 않는다. 변경 또는 미해결 결함이 있는 검증만 다시 수행한다. 정적 검사와 실제 엔진 검사, synthetic fixture와 자연 플레이를 구분한다.

UI 영향은 `layout`, `minimumWidth`, `alerts`, `trade`, `save`, `battle`, `formalArt` 각각에 적용 여부·근거·검사 ID를 적는다. 배치/탭/밀도 변경은 실제 변경 상태와 480×270 최소 폭을 포함한다. 글꼴 변경은 실제 glyph/줄높이/확대 영향도 확인한다. 알림 변경은 단일/실제 가능한 동시 최장 알림, 거래 변경은 실제 전후·확인/취소·실패 경계를 포함한다. 거래가 표시도 바꾸면 `layout` 또는 `alerts`와 capture를 함께 선택한다. 필요한 확대/입력 상태만 추가하고 관성적으로 21장을 요구하지 않는다. formalArt는 이 경로에서 승격할 수 없다.

capture 계획은 상태·target·새 PNG 경로를 매핑한다. 기존 파일은 재사용하지 않고 실행 뒤 실제 PNG 크기와 hash를 확인한다. 리뷰어가 적용되는 모든 capture를 직접 확인하고 `inspectedArtifacts`에 기록한다. 캡처할 때 RNG·Run·저장 bytes/write count가 바뀌지 않는 기존 게임 guard도 유지한다. 기존 화면에 영향이 없으면 근거 있는 비적용으로 기록한다.

위키와 source manifest delta는 작성자가 관련 파일만 함께 준비하고 독립 리뷰어가 내용·링크·현재 출처를 같은 증거 목록에서 확인한다. 필요한 canonical/scoped diff 검사만 실행한다. 원본 join 전 후보·현재 원본·생산 save·다른 실행의 변경을 대조하며 충돌하면 해당 쓰기만 중단한다. 원본 반영 후 필요한 smoke와 변경/보존 readback은 조정자가 같은 목록에 추가한다. 게임 저장 파일을 테스트 입력으로 파싱하거나 덮어쓰지 않는다.

## 완료와 시간

`review`는 실제 리뷰어 ID, run/candidate/evidence 신원, 차단0, 설계·가독성·실패·coverage·보존·UI·지식·완료 항목을 요구한다. 리뷰 후 검사가 추가되면 증거 신원이 달라지므로 바뀐 목록의 확인을 같은 리뷰어가 갱신한다. 새로운 전체 감사/봉인 체계는 만들지 않는다.

`report`는 동일 목록에서 actual count·raw 링크·실패 포함 모든 시도와 완료 기록을 생성하며 미실행/오래된 검증/리뷰 없이 성공 문서를 만들지 않는다. `stage`는 design/implementation/review/integration/knowledge의 시작·종료 벽시계 시간을 기록한다. subprocess 시간은 별도 실제 측정이다. 과거 설계 시간이나 모델 내부 비용을 추정치로 채우지 않는다. 45–75분은 미검증 목표이며 도구 회귀 통과만으로 실작업 시간 절감이나 목표 달성을 주장하지 않는다.

정상 편집으로 후보가 바뀐 뒤에도 이미 열린 `stage end`는 시작을 보존해 종료하고 `endIdentityCurrent`/오류를 기록한다. 시간 관측은 검증 PASS가 아니며 이전 후보의 검사·리뷰·완료를 최신으로 만들지 않는다.

기능 재개는 현재 사용자 중단 지시를 해제하는 별도 지시가 필요하다. 이번 개선은 M16 후보를 재개·원본 반영하거나 다음 백로그를 시작하지 않는다.

## 명령

저장소 루트에서 실행한다. 모든 경로는 해당 프로젝트/실행 기록에 맞춘다.

```powershell
python -B planning/tools/workflow_evidence.py init --root . --plan planning/workflow-runs/<run-id>/plan.json --record planning/workflow-runs/<run-id>/evidence.json
python -B planning/tools/workflow_evidence.py stage --record planning/workflow-runs/<run-id>/evidence.json --name implementation --state begin
python -X utf8 -B planning/tools/workflow_evidence.py native --record planning/workflow-runs/<run-id>/evidence.json --id regression
python -B planning/tools/workflow_evidence.py review --record planning/workflow-runs/<run-id>/evidence.json --result planning/workflow-runs/<run-id>/review.json
python -B planning/tools/workflow_evidence.py report --record planning/workflow-runs/<run-id>/evidence.json --output planning/workflow-runs/<run-id>/result.md
```

`plan.json`에는 도구의 `preflight`가 요구하는 schemaVersion/runId/authority/outcome/designDecision/candidateFiles/actors/checks/impacts/preservation/guards를 넣는다. 각 test check에는 adapter·positive minimumCount·actual expectedNames·후보에 포함된 testSources, image check에는 artifacts와 state/target coverage를 넣는다. 필요 JSON·fixture만 jsonInputs/fixtures에 지정한다. 검사 수·예전 후보 경로·버전은 하드코딩해 복제하지 않는다.

## 운영 관측 보조 · 2026-10-05

[운영 지침](workflow-operations.md)은 기존 checkpoint·정확 ID 집합·필드 조회·실제 시작 시각·합류 소유권을 연결한다. 읽기 전용 workflow_support.py는 현재 단일 evidence의 latest attempt/pending/drift/review 적용성을 관측하며 기존 검사·독립 리뷰·완료 gate를 대신하지 않는다. 정책·제품 재개 권한·필수 acceptance 구조는 동일하다.

## 공통 native 실행 · DR-WF-EXEC-001-r1


LÖVE의 regression/focused/smoke/captures 검사는 `checks.<id>.native`에 mode, 저장소 상대 candidate, 명시적인 절대 engine 경로를 선언하고 `native`로 실행한다. entry 생략 시 candidate 자체를 사용하며 별도 entry는 그 후보 안의 디렉터리여야 한다. 실제 실행 cwd는 candidate이고 engine·entry는 절대 경로다. 호출 위치의 원본 tests와 후보 src가 섞이지 않도록 상대 명령을 직접 조합하지 않는다. main.lua와 존재하는 conf.lua, 실행에서 읽는 소스·테스트·fixture는 candidateFiles/testSources에 포함한다. helper entry가 사용하는 데이터도 동결한다.

기본 timeout은 regression 180초, focused 60초, smoke 30초, captures 60초다. 이는 완료되지 않는 실행을 끊는 상한이며 기다려야 하는 시간이 아니다. 관측 근거가 있으면 plan의 timeoutSeconds로 0초 초과·3600초 이하의 유한값을 명시한다. timeout·비정상 종료를 PASS로 바꾸지 않으며 부분 raw도 보존한다. CLI와 Python 자식 출력은 UTF-8을 고정한다. 결과에는 실제 cwd·command·timeout·환경·engine hash가 남는다. 엔진 변경도 이전 native 결과 재사용을 막는다.

```json
"regression": {
  "adapter": "love",
  "minimumCount": 1,
  "expectedNames": ["실제 소스에서 확인한 핵심 테스트 이름"],
  "testSources": ["planning/workflow-runs/<run-id>/candidate/tests/core_spec.lua"],
  "native": {
    "mode": "regression",
    "candidate": "planning/workflow-runs/<run-id>/candidate",
    "engine": "C:/Program Files/LOVE/lovec.exe"
  }
}
```

이 조각은 전체 plan이 아니다. minimumCount/expectedNames/testSources와 candidateFiles는 실제 검사 범위에 맞춘다. regression은 기본 게임 entry에 --test를 전달하고 core/session/integration 세 suite를 모두 요구한다. focused는 명시한 전용 entry를 실행하며 expectedSuites에 실제 부분 suite 목록을 적는다. smoke는 --smoke, captures는 --capture를 전달한다. 현재 기본 게임 main.lua는 --capture를 제공하지 않으므로 captures는 해당 인자를 처리하는 동결된 전용 entry가 필요하다. 캡처 경로를 entry가 쓰는 후보 상대 경로와 plan의 저장소 상대 artifacts/coverage에 정확히 맞춘다.

세 게임 테스트는 `WORKFLOW SUITE {"schemaVersion":1,"suite":"core|session|integration","count":N,"failures":F}` 형식으로 같은 완료 결과를 낸다. 종료 전에 실패한 suite도 결과를 출력한다. adapter는 각 suite 직전의 실제 PASS/FAIL 수, 전체 이름 중복, 기대 suite 집합, failure=0과 기존 TEST SUITE 종료표시를 대조한다. 잘못된 JSON·누락·중복·구형 출력 혼합·count 불일치는 완료가 아니다. 구형 역사 로그는 기존 adapter로 계속 읽되 새 JSON 결과와 한 실행에서 섞지 않는다.

raw stdout/stderr는 `raw/<run-id>/<candidate-identity>/<attempt>-<check-id>-<uuid>/`에 실행마다 새로 만들며 파일도 배타적으로 생성한다. 다른 기록의 동일 후보·동일 시도 번호와 겹치지 않는다. 실패·재시도와 기존 raw 경로는 보존하고 보고서가 실제 경로를 연결한다. 동일 evidence.json은 한 작성자가 순차 갱신하며 병렬 실행은 서로 다른 record를 사용한다. 전체 suite는 안정 후보에서 필요한 한 번으로 마무리하고 준비·수리 중에는 영향을 받는 핵심 검사만 선택한다.
