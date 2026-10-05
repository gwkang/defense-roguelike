# defense-roguelike 게임 프로젝트 프로필

공개 범위 안내(2026-10-04): 현재 제품 구현과 검증의 공개 근거는 [M31 공개 검증 요약](workflow-runs/m31-unlock-20261004/publication-summary.md)이다. 아래 workflow registry/policy/contract/tool 설정은 현재 로컬 운영 경로이며 이번 커밋에 포함되지 않는다. 공개 checkout의 기존 AGENTS/스킬·워크플로우 파일은 이전 커밋의 기준선일 뿐 현재 로컬 overlay와 같은 신원이라고 주장하지 않는다. 필수 knowledge 5개 설정과 modelRoutingProfilePath는 아래 공개 파일에 유지한다. 과거 설계·실행 기록은 명시한 로컬 전용 경로에서 보존한다.

Revision: 21 · 2026-10-04. 필수 위키·모델 라우팅 설정을 유지하고 I43/M43 추가 및 M28 보존의 제품·저장 경계를 반영했다. 테스트 러너의 실패 종료 전달을 수정했다. 전투 시작 저장 재시도 성공 후 같은 웨이브의 Battle을 생성하는 복구를 보완했다. I46/M46 비상 출력 한 종을 추가했다. I41/M41 중가 연동 한 종을 추가했다. I42/M42 자산 연동 한 종을 추가했다. I15/M15 혼합 개조 한 종을 추가했다. I14/M14 고급 정비 한 종을 추가했다. I12/M12 균등 투자와 I16/M16 공용 설계를 추가했다. 변경·검증 기록은 균등 투자 실행 (`planning/workflow-runs/m12-unlock-20261002/run.md` · 로컬 전용·이번 공개 제외), 고급 정비 실행 (`planning/workflow-runs/m14-unlock-20261002/run.md` · 로컬 전용·이번 공개 제외), 혼합 개조 실행 (`planning/workflow-runs/m15-unlock-20261001/run.md` · 로컬 전용·이번 공개 제외), 자산 연동 실행 (`planning/workflow-runs/m42-unlock-20261001/run.md` · 로컬 전용·이번 공개 제외), 중가 연동 실행 (`planning/workflow-runs/m41-unlock-20261001/run.md` · 로컬 전용·이번 공개 제외), 비상 출력 실행 (`planning/workflow-runs/m46-unlock-20261001/run.md` · 로컬 전용·이번 공개 제외), 전투 시작 복구 실행 (`planning/workflow-runs/combat-start-retry-20261001/run.md` · 로컬 전용·이번 공개 제외), 러너 종료 코드 실행 (`planning/workflow-runs/runner-exit-20261001/run.md` · 로컬 전용·이번 공개 제외), I43/M43 실행 (`planning/workflow-runs/m43-unlock-20260930/run.md` · 로컬 전용·이번 공개 제외), I28/M28 실행 (`planning/workflow-runs/m28-unlock-20260930/run.md` · 로컬 전용·이번 공개 제외), 필수 절차 정정 (`planning/workflow-runs/workflow-mandatory-20260930/run.md` · 로컬 전용·이번 공개 제외)에 있다.

| 설정 | 값 | 출처 |
| --- | --- | --- |
| 게임 | `defense-roguelike` · `DR-MOD-I31-r1` 포탑 6종·시작 모듈 24종 + 영구 해금 M12/M14/M15/M16/M28/M31/M41/M42/M43/M46·W01–W15 개발 루프 | [README](../README.md), [DR-RUN-002 r1](full-run-continuation.md), `src/content.lua` |
| 엔진 / 차원 | LÖVE 11.5 · 2D | `conf.lua`, `main.lua` |
| 플랫폼 | 현재 개발 검증 대상 Windows x64; 출시 대상 미정 | `conf.lua`, 실행 기록 |
| 화면 / 입력 | 480×270 논리 화면, nearest 정수 확대/letterbox · PC 마우스와 키보드 보조키 · 6기 단위 인벤토리 페이지 · SHOP 보유 관리/판매 확인·취소 · SHOP/PREPARE 무료 회수 · 판매 및 M06 구매의 수용량 초과 exact-N 선택 · PREPARE 모듈 상태/동적 상세 · 우클릭/Esc 한 계층 뒤로 | `src/view.lua`, `src/input.lua`, DR-UX-001 r2, DR-UX-FULL-001 r1, DR-UX-TRADE-001 r1, Stage B 기능 UI (`planning/workflow-runs/first-slice-implementation-20260929/revision5/stage-b-ux.md` · 로컬 전용·이번 공개 제외) |
| 게임 언어 | 한국어 UI; `C:/Windows/Fonts/malgun.ttf` 우선, 안전한 기본 폰트 fallback | `src/view.lua` |
| `communication.preferredLanguage` | `ko` · 문서도 상속, 별도 override 없음 | 워크플로 기본 언어와 사용자 선호 |
| `workflowRunRegistryPath` | `planning/workflow-runs/active.json` | 이번 프로젝트 적용 |
| `communication.artifactLanguage` | `ko` · preferredLanguage와 동일, 독립 override 미사용 | 사용자 한국어 보고 계약 |
| `modelRoutingProfilePath` | `planning/model-routing-profile.json` | 현재 호스트 지원과 필수 라우팅 결정 (`planning/workflow-runs/workflow-mandatory-20260930/run.md` · 로컬 전용·이번 공개 제외) |
| `knowledge.enabled` | `true` | 사용자 “필수야” → “모두 수정해” |
| `knowledge.projectName` | `defense-roguelike` | 기존 프로젝트 이름·사용자 위키 이름 규칙 |
| `knowledge.root` | `defense-roguelike-wiki/` | [위키](../defense-roguelike-wiki/index.md) |
| `knowledge.indexPath` | `defense-roguelike-wiki/index.md` | [인덱스](../defense-roguelike-wiki/index.md) |
| `knowledge.policyPath` | `defense-roguelike-wiki/policy.md` | [유지 정책](../defense-roguelike-wiki/policy.md) |

## 명령

작업 디렉터리: `run-game.cmd`는 시작 위치와 무관하다. 직접 테스트 명령은 저장소 루트에서 실행한다. LÖVE 기본 경로는 현재 Windows 개발 호스트에서 확인한 위치다.

| 목적 | 명령 |
| --- | --- |
| 실행 | `run-game.cmd` 더블클릭 또는 저장소 루트에서 `.\run-game.cmd` |
| 워크플로우 후보 검증(현재 로컬 overlay 전용·이번 공개 제외) | `python -X utf8 -B planning/tools/workflow_evidence.py native --record <해당 evidence.json> --id <계획의 검사 ID>` · 공통 실행 계약 (`planning/workflow-small-change.md` · 현재 로컬 계약/오버레이·이번 공개 제외) |
| 직접 통합 테스트 | `& 'C:\Program Files\LOVE\lovec.exe' . --test` |
| bounded runtime smoke | `.\run-game.cmd --smoke` (저장소 밖에서는 스크립트의 절대 경로 사용) |
| 위키 문서·출처 검사 | `python -B defense-roguelike-wiki/check_docs.py` 및 `git diff --check` |

현재 로컬 overlay의 워크플로우 증거는 공통 실행기가 계획의 후보 cwd·절대 entry·검사별 timeout을 고정한다. 직접 명령은 수동 진단이며 공통 증거 기록을 대신하지 않는다. 세 suite는 WORKFLOW SUITE schemaVersion=1 JSON 완료 결과를 통일해 출력하고 실제 PASS 수·failure 수·통합 종료와 함께 해석한다.

통합 테스트는 core/session/integration 세 suite가 모두 성공하면 종료 코드0을 반환한다. 예외 또는 suite의 실패 종료 요청이 있으면 최종 종료 코드1이며, 뒤의 성공 요청이 앞의 실패를 지우지 않는다. 중단·시간 초과는 검증용 부모 실행기가 완료 표시와 종료를 함께 판단한다. 해당 대조 검증은 제품에 새 timeout/cancel 옵션을 추가하지 않았다. 러너 설계 (`planning/workflow-runs/runner-exit-20261001/technical-design.md` · 로컬 전용·이번 공개 제외).

## 참조와 미정 설정

- 작업 규칙: AGENTS.md (`AGENTS.md` · 현재 로컬 계약/오버레이·이번 공개 제외)
- 워크플로 적용 기록: .agents/skills/WORKFLOW_ADOPTION.md (`.agents/skills/WORKFLOW_ADOPTION.md` · 현재 로컬 계약/오버레이·이번 공개 제외)
- 제품 기준은 `DR-SLICE-001 r2`, `DR-TECH-001 r2`, `DR-UX-001 r2`와 그 연속 계약 `DR-RUN-002 r1`, `DR-UX-FULL-001 r1`, DR-TRADE-TECH-001 r1 (`planning/workflow-runs/first-slice-implementation-20260929/revision5/technical-design.md` · 로컬 전용·이번 공개 제외), DR-UX-TRADE-001 r1 (`planning/workflow-runs/first-slice-implementation-20260929/revision5/ux.md` · 로컬 전용·이번 공개 제외), Stage B 기능 UI (`planning/workflow-runs/first-slice-implementation-20260929/revision5/stage-b-ux.md` · 로컬 전용·이번 공개 제외)에 한정한다.
- 현재 개발 범위는 W01–W15, S00–S04, 보스 승패와 RESULT 새 판 확인, SHOP 타워/모듈 판매 확인·취소, SHOP/PREPARE 무료 타워 회수, 수용량 감소 판매와 `M06` 구매의 exact-N 회수 선택까지다. `M06` 회수는 타워 인스턴스와 부착 패치를 보존한다. 저장 실패에서는 이전 정상 run을 유지하고 기존 재시도/안전 종료 흐름을 사용한다. START_COMBAT 실패의 재시도 readback 성공 뒤에만 같은 웨이브의 전투 객체를 한 번 생성하며, 반복 실패와 중복 재시도는 전투를 시작/초기화하지 않는다. 복구 설계 (`planning/workflow-runs/combat-start-retry-20261001/technical-design.md` · 로컬 전용·이번 공개 제외).
- 새 판의 기본 모듈 풀은24종이며 확정된 M12/M14/M15/M16/M28/M31/M41/M42/M43/M46만 각각 추가해 최대34종이 된다. 기존 판의 풀·상품·RNG는 해금 뒤에도 유지하고 다음 성공한 새 판에서만 반영한다. 기존 `DR-RUN-002-r1` 판은6종 동결 모듈 풀을 그대로 보존하며 로드만으로 저장을 다시 쓰지 않는다. `M29/M30` 가격·환급 영수증과 `M32/M33/M34/M37` 정산 예상·성장 현재/다음/초기화 조건은 실제 UI에서 확인한다.
- T05 저격은 W05 생존 완료→W06 도달, T06 전격은 W15 보스 처치 승리의 저장 확정에서 영구 해금한다. 현재 판의 상품·풀·RNG는 유지하고 다음 새 판부터 포탑 후보에 반영한다. `DR-MOD-S24-r1`/`DR-RUN-002-r1` 저장은 당시 동결 풀과 현재 진척을 유지하고 기록된 완료의 해금 권리만 복원하며 load는 write0이다. 참조: R7 기술 계약 (`planning/workflow-runs/first-slice-implementation-20260929/revision7/technical-design.md` · 로컬 전용·이번 공개 제외), R7 기능 UX (`planning/workflow-runs/first-slice-implementation-20260929/revision7/ux.md` · 로컬 전용·이번 공개 제외), `src/game.lua`, `src/save.lua`.
- I28은 W03–W14 일반 생존 완료의 정산 전 골드가20 이상일 때 M28 예치금을 영구 해금한다. 같은 완료 checkpoint의 readback 성공 뒤 확정되고 현재 판의 풀·상품·RNG는 유지한다. 다음 새 판부터 후보24+M28이며 무료 지급이나 등장 보장은 없다. M28은12G 중가이며 장착 시 일반 생존 정산에서 `min(4, floor(정산 전 골드/5))`를 지급한다. W01/W02도 이자는 적용되며 W15·패배·중복 완료는 제외한다. 판매는 효과를 제거하되 영구 권리와 이번 판 획득 이력을 유지한다. M28 설계 (`planning/workflow-runs/m28-unlock-20260930/technical-design.md` · 로컬 전용·이번 공개 제외), 기능 UX·검증 계획 (`planning/workflow-runs/m28-unlock-20260930/ux-and-test-plan.md` · 로컬 전용·이번 공개 제외).
- I43은 W03–W14 일반 생존 완료의 전투 내내 장착 모듈1개 이상·실제 빈 슬롯2개 이상이면 M43 여유 회로를 영구 해금한다. 현재 전투 중 모듈·수용량 불변 경계를 근거로 시작 저장 상태를 사용한다. M43은12G 중가이며 장착한 배치 타워 피해에 실제 빈 슬롯당+12%, 최대+36%를 기존 모듈 피해 합에 더한다. 자신도1칸을 사용하고 구매·판매 미리보기는 실제 전후 빈칸·M43 보너스를 표시한다. 동시 해금은 같은 완료 checkpoint에 저장하고 알림은 readback 뒤 표시한다. M43 설계 (`planning/workflow-runs/m43-unlock-20260930/technical-design.md` · 로컬 전용·이번 공개 제외), 기능 UX·검증 계획 (`planning/workflow-runs/m43-unlock-20260930/ux-and-test-plan.md` · 로컬 전용·이번 공개 제외).
- I46은 W03–W14 일반 생존 완료에서 시작HP1–5·이번 누수0 또는 W09–W14 완료HP20으로 M46을 해금한다. M46은12G 중가이며 현재HP1–5에서 배치 타워 피해+40%를 기존 모듈 피해 합에 더한다. 회복·패배 방지 없음, Battle 소유 현재HP와 UI 투영을 같은 tick에 맞추며 저장된 시작HP는 유지한다. 단일·동시 해금의 조건·효과는 저장 readback 뒤 공개한다. M46 설계 (`planning/workflow-runs/m46-unlock-20261001/technical-design.md` · 로컬 전용·이번 공개 제외), 기능 UX·검증 계획 (`planning/workflow-runs/m46-unlock-20261001/ux-and-test-plan.md` · 로컬 전용·이번 공개 제외).
- I41은 신규 W06–W14 일반 생존 완료에서 서로 다른 중가 모듈2개 이상을 전투 내내 유지하면 M41을 영구 해금한다. 고가16G M41은 자신을 제외한 장착 중가 모듈당 배치 타워 피해+8%p, 상한32%를 기존 모듈 피해 합에 더한다. 기본4슬롯에서는 자신과 다른 중가3개로 최대24%이며 상한32%는 확장 슬롯을 구현했다는 뜻이 아니다. 중가 거래의 전후 효과와 판매 후 영구 권리·이번 판 획득 이력을 표시한다. 최대4종 동시 해금은 같은 완료 checkpoint/readback 뒤 공개하고 기존 상세 조회로 조건·효과를 확인한다. M41 설계 (`planning/workflow-runs/m41-unlock-20261001/technical-design.md` · 로컬 전용·이번 공개 제외), UX·검증 계획 (`planning/workflow-runs/m41-unlock-20261001/ux-and-test-plan.md` · 로컬 전용·이번 공개 제외).
- I42는 새 W09–W14 일반 생존 완료에서 모든 장착 모듈의 기록 실지불액 합40G 이상을 전투 내내 유지하면 M42 자산 연동을 해금한다. 고가16G M42는 자신을 제외한 장착 기록 실지불4G당 배치 피해+2%p(내림/상한30%p)를 기존 모듈 피해 합에 더한다. 현재 골드·환급·판매가·리롤·타워·패치 값으로 대신하지 않는다. 정상 가격 구매/기본4칸의 다른3종 최대48G는24%p이고, M42 권리·풀·획득 기록이 유효한 현재 I42 버전의 비정가 저장값은 기본4칸에서도60G/상한30%p가 가능하다. 유효 보존20G+20G/장착2종/빈칸2의 새 W09 완료는 다섯 권리를 같은 checkpoint/readback 뒤 해금할 수 있다. 과거 완료로 소급하거나 현재 판 후보·상품·RNG를 바꾸지 않는다. M42 설계 (`planning/workflow-runs/m42-unlock-20261001/technical-design.md` · 로컬 전용·이번 공개 제외), UX·검증 계획 (`planning/workflow-runs/m42-unlock-20261001/ux-and-test-plan.md` · 로컬 전용·이번 공개 제외).
- I15는 신규 W06–W14 일반 생존 완료에서 서로 다른 ID의 패치3종을 가진 같은 타워1기를 전투 시작부터 완료까지 배치하면 M15 혼합 개조를 영구 해금한다. 후기 배치·중복 패치3개·패배·미완료·중복 완료는 제외한다. 중가12G M15는 장착 시 서로 다른 패치3종인 배치 타워의 모듈 공격속도 합에+20%p를 더한다. 타워별로 판정하고 기존 패치 효과를 보존한다. 거래 미리보기는 선택 타워의 전후 효과와 수용량 감소의 정확 회수 결과를 반영한다. 해금은 같은 완료 checkpoint의 readback 뒤 공개하며 현재 판 후보·상품·RNG는 유지한다. 다음 성공한 새 판부터만 후보에 추가되고 무료 지급·등장 보장·장착 승계가 아니다. M15 설계 (`planning/workflow-runs/m15-unlock-20261001/technical-design.md` · 로컬 전용·이번 공개 제외), UX·검증 계획 (`planning/workflow-runs/m15-unlock-20261001/ux-and-test-plan.md` · 로컬 전용·이번 공개 제외).
- I14는 신규 W09–W14 일반 생존 완료에서 부착 패치 정가 합21G 이상인 같은 타워1기를 전투 시작부터 완료까지 배치하면 M14 고급 정비를 영구 해금한다. 정가는 Content의 패치 가격이며 기록 실지불액·현재 골드·타워/모듈 가격으로 대신하지 않는다. 중가7G 패치3개는 성공하고 고가10G 패치2개는 제외된다. 중가12G·슬롯1 M14는 장착 시 배치 타워별 고가 패치 하나당 기존 모듈 피해 합에+8%p를 더하고 패치 자체 능력치와 기존 모듈 효과는 보존한다. 후기 배치·패배·미완료·중복 완료는 해금에서 제외한다. 거래의 선택 타워 전후 효과·M41/M42/M43 연동·정확 회수와 취소/저장 실패/retry를 반영한다. 해금은 같은 완료 checkpoint의 readback 뒤 공개하고 현재 판 후보·상품·RNG를 유지한다. 다음 성공한 새 판부터 후보에 추가되며 무료 지급·등장 보장·장착 승계가 아니다. M14 설계 (`planning/workflow-runs/m14-unlock-20261002/technical-design.md` · 로컬 전용·이번 공개 제외), UX·검증 계획 (`planning/workflow-runs/m14-unlock-20261002/ux-and-test-plan.md` · 로컬 전용·이번 공개 제외).
- I12는 신규 W06–W14 일반 생존 완료에서 배치 타워3기 이상 모두가 같은 양의 패치 개수를 전투 내내 유지하면 M12 균등 투자를 영구 해금한다. 패치 ID가 같거나 중복이어도 개수를 세며 미배치 타워는 제외한다. 시작3기 뒤 같은 개수의4기째 추가 배치는 허용하고, 무패치4기째와 시작2기 뒤3기째 배치는 제외한다. 중가12G·슬롯1 M12는 장착 시 현재 배치 타워2기 이상 모두의 패치 개수가 같은 양수일 때 배치 타워의 모듈 사거리 합에+25%p를 더한다. 해금의3기와 효과의2기를 구분하며 패치 사거리와 기존 모듈 효과를 보존하고 연쇄거리·폭발반경은 바꾸지 않는다. 전투의 실제 Battle 소유 상태와 같은 tick에 투영하고 후기 불균등 배치는 새 표적 획득부터 반영한다. 패치 구매·모듈 구매/판매·타워 판매·정확 회수의 선택 전후 효과와 취소/저장 실패/retry를 반영한다. 해금은 같은 완료 checkpoint readback 뒤 공개하며 현재 판 후보·상품·RNG는 유지한다. 다음 성공한 새 판만 후보에 추가되며 무료 지급·등장 보장·장착 승계가 아니다. M12 설계 (`planning/workflow-runs/m12-unlock-20261002/technical-design.md` · 로컬 전용·이번 공개 제외), UX·검사 계획 (`planning/workflow-runs/m12-unlock-20261002/ux-and-test-plan.md` · 로컬 전용·이번 공개 제외).
- `DR-MOD-I16-r1`을 포함한 열세 기존 콘텐츠 버전은 load write0으로 당시 풀·상품·RNG·진척·기록 지불·포탑 권리·M12/M14/M15/M28/M41/M42/M43/M46 권리를 유지한다. 과거 완료 기록으로 I12/I14/I15/I16/I28/I31/I41/I42/I43/I46을 소급 추정하지 않는다. 다음 정상 저장에서 새 버전이 기록된다. 해금 조회의 포탑/예치금/여유/비상/중가/자산/혼합/고급/균등/공용/예비 열한 탭은 확정 권리와 이번 판 후보·상품 상태를 구분한다.
- 잠긴 나머지 모듈14종, 전체 도감, 고난도 모드, 48종 전체 콘텐츠 및 정식 UI/아트는 지원 범위가 아니다.
- 패키징, 배포, 출시 대상, 정식 UI 컴포넌트 카탈로그는 아직 설정하지 않았다. 위키·모델 라우팅은 위 설정을 사용한다.

## 작은 변경 실행 경로 · DR-WF-SMALL-001 r1

| 설정 | 값 | 출처 |
| --- | --- | --- |
| `workflow.smallChangePolicyPath` | `planning/workflow-policy.json` | 사용자 2026-10-02 워크플로우 개선 지시 |
| `workflow.smallChangeContractPath` | `planning/workflow-small-change.md` | 프로젝트 한정 역할 통합·필수 결과 유지 |
| `workflow.evidenceToolPath` | `planning/tools/workflow_evidence.py` | 경로/JSON/fixture/검사 이름 preflight·실제 실행·보고서 생성 |

최신 사용자 재개 지시에 따라 M16 단위만 진행한다. 원본 반영과 실제 검증 상태는 M16 실행 증거 (`planning/workflow-runs/m16-unlock-20261002/evidence.json` · 로컬 전용·이번 공개 제외)를 따른다. 후속 백로그 재개 권한은 없다. 작은 변경의 실작업 소요시간과 45–75분 목표는 미검증이다.

- I16은 신규 W09–W14 일반 생존 완료에서 배치 타워 전체의 서로 다른 패치 ID 5종 이상을 시작부터 완료까지 유지하면 M16 공용 설계를 영구 해금한다. 중복 ID는1종, 예비 타워는 제외한다. 고가16G·슬롯1 M16은 현재 배치 전체 패치 ID당 기존 모듈 피해 합에+3%p, 최대27%p를 더한다. 시작4종 뒤 늦은5번째 배치는 해금에서 제외하고, 이미5종 뒤 무패치/중복/새ID 예비 배치는 유지된다. 같은 완료 checkpoint의 readback 뒤 권리·알림을 공개하며 현재 판 풀·상품·RNG는 유지한다. 다음 성공 새 판만 시작24+확정10권리, 최대34종을 재추첨한다. 판매/패배 후 권리·이번 판 획득 기록은 보존하고 무료 지급·등장 보장·장착 승계는 없다. M16 재개 권한·범위 (`planning/workflow-runs/m16-unlock-20261002/resume-authority.md` · 로컬 전용·이번 공개 제외), 현재 실행 증거 (`planning/workflow-runs/m16-unlock-20261002/evidence.json` · 로컬 전용·이번 공개 제외).

## 2026-10-04 최신 재개 범위

사용자 ‘개선된 워크플로우로 이어서 진행해’로 M16 완료 후 I31/M31 단위를 재개한다. 위의 M16-only/후속 백로그 미승인 문장은 당시 범위로 보존하며 이번 최신 범위는 [M31 공개 검증 요약](workflow-runs/m31-unlock-20261004/publication-summary.md)과 현재 정책의 currentResumeScope를 따른다. 다른 후속 단위는 미승인이다.

- I31은 신규 W09–W14 일반 생존 완료에서 미배치 타워의 서로 다른 종류2종 이상을 전투 내내 보유하면 M31 예비 보급을 영구 해금한다. 동종은1종이며 예비를 배치하여1종만 남으면 제외한다. 중가12G·슬롯1 M31은 일반 생존 정산의 완료 미배치 종류당+1G, 최대3G를 기존 수입에 합산한다. W01–W14 효과와 W09–W14 해금 창을 구분하며 W15·패배·미완료·중복 완료는 지급/해금하지 않는다. 시작/summary/정산 후보의 타워 ID·종류·패치를 대조하고 시작 배치의 위치 유지와 summary/후보 배치 일치를 검증한다. COMBAT writer는 기존 예비 배치만 가능하므로 미배치 종류 집합의 단조 감소가 전투 내내 조건의 근거다. 회수·판매·구매 writer가 추가되면 이 증명을 다시 검토한다. 완료 checkpoint readback 뒤 권리·알림을 공개하며 현재 판 풀·상품·RNG는 동결한다. 다음 성공 새 판만 시작24+확정10권리, 최대34종 후보를 재추첨한다. load write0의13개 역사 버전은 당시 풀·상품·RNG·권리·지불 기록을 보존하고 I31을 소급 추정하지 않는다.

## 현재 로컬 운영 보조 경로 · 2026-10-05

`workflow.operationsPath`: [planning/workflow-operations.md](workflow-operations.md). `workflow.supportToolPath`: [planning/tools/workflow_support.py](tools/workflow_support.py). 읽기 전용 status/compare-set/inspect를 기존 단일 실행 증거와 checkpoint에 연결한다. 현재 profile의 제품/version, 정책과 기능 재개 범위는 이 운영 보조로 변경하지 않는다.
