# 필수 워크플로우 결정

공개 범위 안내(2026-10-04): 아래 필수 절차와 보강의 결정·구현·검토 상태는 현재 로컬 운영 계약에 관한 기록이다. 이번 제품 공개는 dirty AGENTS/스킬·overlay·실행 도구·감사 원장을 포함하지 않는다. 공개 checkout에 이미 있던 워크플로우 baseline을 현재 로컬 overlay 신원이나 검사 PASS로 소비하지 않는다. 공개 제품 검증은 [M31 공개 검증 요약](../planning/workflow-runs/m31-unlock-20261004/publication-summary.md)을 따른다.

2026-10-01 · revision 2 · confirmed-decision. 출처: 현재 사용자 “필수야” → “모두 수정해”, 수정 실행 (`planning/workflow-runs/workflow-mandatory-20260930/run.md` · 로컬 전용·이번 공개 제외), 프로젝트 계약 (`AGENTS.md` · 현재 로컬 계약/오버레이·이번 공개 제외). 지침 접근·재사용 절차는 후속 사용자 “승인해. 근데 이런일이 발생하지 않도록 해줘”와 M43 실행 (`planning/workflow-runs/m43-unlock-20260930/run.md` · 로컬 전용·이번 공개 제외)에 따른다.

위키 생성·사용·관련 지식 반영·동기화는 필수다. 과거 위키 미설정 기록은 역사로 유지하고 현재 완료 조건에 사용할 수 없다. [프로필](../planning/game-workflow-profile.md)의 knowledge 5개 설정과 index/policy를 실제로 조회한다.

감독, 코드 리뷰, 회고 감사, 모델 라우팅 및 부가 항목 처리판정도 임의 생략하지 않는다. 적용되는 결과는 수행하고, 관계없는 추가 생산은 적용 제외 이유·소유자를 남긴다. URL·예산 등의 사용자 입력 부재를 요구 충족으로 위장하지 않고 기존 권한·자료로 충분한지 확인한다. 외부 서비스·자동화·공개 권한은 별도다.

이 프로젝트의 계약 수정은 설치된 로컬 overlay다. 공식 upstream lock은 원본 신원으로 보존하고 변경 파일 신원은 overlay 기록 (`planning/workflow-runs/workflow-mandatory-20260930/overlay-manifest.json` · 로컬 전용·이번 공개 제외)에 둔다. 공개 원본 변경·commit·push를 뜻하지 않는다.

지식 정정은 [유지 정책](policy.md)에 따라 supervisor → game-knowledge-maintenance → 별도 verifier → 최종 후보로 연결한다. 소스가 바뀌면 페이지의 의미와 sources.json 신원을 함께 확인한다. no-change는 실제 비교 근거가 있어야 하고 누락·차단을 대신하지 않는다.

## 지침 읽기·승인 질문 반복 예방

새 단위 배정 전에 supervisor가 필요한 지침과 보존된 실제 읽기 결과의 출처·버전·적용 모드를 한 번에 대조한다. 충분한 지침은 재사용하고, 현재 source 변경이나 다른 역할 때문에 실제로 부족한 부분만 확인한다. 하위 작업은 supplied run/task 문맥과 읽기 승인 근거를 상속하며 동일 승인 질문을 각각 반복하지 않는다. 부족분은 root가 모아 처리한다. 정확한 절차와 읽기 결과의 근거는 지침 재사용 기록 (`planning/workflow-runs/m43-unlock-20260930/instruction-reuse.md` · 로컬 전용·이번 공개 제외)에 있다.

읽기 승인과 제품 변경·외부 작업 권한은 별개다. 승인된 추가 권한 실행은 이후 일반 실행의 읽기 권한을 영구 변경하지 않는다. 보호 지침을 다른 경로로 복제해 제한을 우회하거나 Windows ACL/전역 보안을 바꾸지 않는다. 일반 읽기에서 PermissionDenied가 출력됐으면 명령 전체 exit0만으로 성공이라고 보고하지 않는다.

현재 원인 진단은 제한 실행 토큰과 `.agents` 특수 ACL의 존재까지 확인했으며 직접 실패를 만든 ACL/샌드박스 경로는 미확인이다. 이 절차는 불필요한 재읽기·중복 승인 질문을 줄이는 예방책이며 호스트 접근 제한을 해제했다는 의미가 아니다.


## 코드 리뷰 주의사항 · 2026-10-01

implemented-source: 로컬 리뷰 스킬 (`.agents/skills/game-code-review/SKILL.md` · 현재 로컬 계약/오버레이·이번 공개 제외)은 후보·범위 확인부터 호출자·테스트 기대값, 실패 경로와 반증 확인까지 검토 순서를 명시한다. 변경에 관련된 수명·저장·신뢰 경계·비용만 선택하고 필수 수정과 선택 조언을 구분한다. 프로젝트 심각도 기준이 우선하며 fallback P0–P3는 영향과 증거 확신을 따로 기록한다. 공식 자료 채택 기록 (`planning/workflow-runs/code-review-skill-20261001/research.md` · 로컬 전용·이번 공개 제외), 실행·검증 상태 (`planning/workflow-runs/code-review-skill-20261001/run.md` · 로컬 전용·이번 공개 제외), 후보 신원 (`planning/workflow-runs/code-review-skill-20261001/manifest.json` · 로컬 전용·이번 공개 제외)을 따른다. 실제 리뷰 성능·게임 품질·시간 절감은 아직 미검증이다.

확인 상태: 별도 V1 문서 의미 검토 C1–C5 PASS 및 A1 회고 no-change. 제한된 순차 사례 검토에서 양쪽 지침 모두 기대 결과를 냈으며 효과 우월성은 입증하지 않았다. 실제 모델 runtime 신원 확인은 unknown으로 남아 전체 workflow PASS를 주장하지 않는다. 검증 반환 (`planning/workflow-runs/code-review-skill-20261001/verification.md` · 로컬 전용·이번 공개 제외)과 회고 (`planning/workflow-runs/code-review-skill-20261001/audit.md` · 로컬 전용·이번 공개 제외).


## Lua/Python 코드 품질 지침 · 2026-10-01

implemented-source: 언어별 진입 (`.agents/skills/game-task-planning/references/language-coding.md` · 현재 로컬 계약/오버레이·이번 공개 제외), Lua (`.agents/skills/game-task-planning/references/code-quality-lua.md` · 현재 로컬 계약/오버레이·이번 공개 제외), Python (`.agents/skills/game-task-planning/references/code-quality-python.md` · 현재 로컬 계약/오버레이·이번 공개 제외)을 리뷰·공통 구현 계약과 UI 구현 모드에서 조회한다. Lua의 false/nil·테이블 순서/공유·pcall 반환 오류, Python의 가변 기본값·중첩 공유·타입 힌트/검증·예외/취소를 변경된 행동에 한정해 적용한다. 기존 형식·도구·버전이 우선이고 언어 패턴·스타일 취향만으로 결함을 만들지 않는다.

호스트 관측: Python3.12.4, 별도 LÖVE probe에서 Lua5.1/LuaJIT2.1.1700008891 확인. probe 소스 (`planning/workflow-runs/code-review-skill-20261001/r2/runtime-probe/main.lua` · 로컬 전용·이번 공개 제외)는 실제 게임·저장·시각 검증이 아니다. 공식 Python docs의 일부 web 접근 실패는 CPython v3.12.4 문서 원본을 직접 조회해 해결했다. 조사·범위 (`planning/workflow-runs/code-review-skill-20261001/r2/research.md` · 로컬 전용·이번 공개 제외), source 신원 (`planning/workflow-runs/code-review-skill-20261001/r2/sources/manifest.json` · 로컬 전용·이번 공개 제외), 후보 신원 (`planning/workflow-runs/code-review-skill-20261001/r2/manifest.json` · 로컬 전용·이번 공개 제외)을 따른다. 별도 V2 검토 L1–L5 PASS 및 A2 회고를 완료했다. 검증·독자 사례 (`planning/workflow-runs/code-review-skill-20261001/r2/verification.md` · 로컬 전용·이번 공개 제외), 회고·기록 정정 (`planning/workflow-runs/code-review-skill-20261001/r2/audit.md` · 로컬 전용·이번 공개 제외)을 따른다. 이는 지침 내용과 격리된 언어 행동 확인이며 blind 모델 A/B·실제 게임 품질·시간 절감은 미측정이다. 실행 모델 runtime 신원은 unknown으로 전체 모델 확인 게이트는 미검증이다.

## 작은 변경 역할 통합 · 2026-10-02 현재 결정

사용자 ‘작업을 중단하고 워크플로우부터 개선해’가 작은 변경의 역할/문서 절차를 갱신했다. 위의 supervisor→지식 유지→별도 verifier 및 별도 완료 감사 전달은 해당 작은 변경에서 작성자+한 독립 리뷰어의 동일 증거 검토로 통합한다. 결과 의무·설계/가독성/실패 경계·원본/save 보존·모델/권한 규칙은 유지한다. 프로젝트 정책 (`planning/workflow-policy.json` · 현재 로컬 계약/오버레이·이번 공개 제외), 작은 변경 계약 (`planning/workflow-small-change.md` · 현재 로컬 계약/오버레이·이번 공개 제외), 실행 도구 (`planning/tools/workflow_evidence.py` · 현재 로컬 계약/오버레이·이번 공개 제외)를 실제 진입점에서 사용한다. UI는 변경 상태·최소 폭·알림·거래 영향을 빠뜨리지 않고 필요한 capture만 선택한다. 검증0/오래된PASS를 완료로 처리하지 않으며 링크·보고서·완료 기록과 단계 시각을 단일 evidence 목록에서 만든다. 개선 실행 (`planning/workflow-runs/workflow-improvement-20261002/run.md` · 로컬 전용·이번 공개 제외)의 실제 도구 회귀·독립 검토를 따른다. 게임 개발은 중단됐고 M16 후보는 미검증 상태로 보존한다. 시간 절감 및 45–75분 목표 달성은 미검증이다.

## 캡처·smoke 증거 경계 수리 · 2026-10-02

implemented-source: 사용자 후속 ‘수정해’에 따라 도구의 PNG 헤더만 있는 손상 파일 수용과 smoke 중복/실패 혼합 완료표시 수용을 수리한다. PNG 검사는 동일 bytes의 모든 chunk 길이/CRC·완전한 IEND와 실제 픽셀 디코딩을 모두 확인한다. Pillow의 verify/load만으로 IEND CRC·마지막 1–4 bytes 누락을 차단할 수 없어 끝 청크의 완결성은 별도로 검사한다. Pillow가 없는 실행 환경에서는 PNG 검증을 차단하며 자동 설치하지 않는다. smoke는 성공 완료표시가 정확히 한 번이고 실패 표시가 없어야 한다. 정상·잘린·손상 PNG와 정상·중복·실패 혼합 smoke는 도구 회귀 (`planning/tools/test_workflow_evidence.py` · 현재 로컬 계약/오버레이·이번 공개 제외)에서 격리된 fixture/실제 subprocess로 검증한다. 현재 후보의 검사·독립 리뷰 결과는 개선 실행의 repair-r6 결과를 따른다. 이 수리는 게임 렌더링·기기 검증이나 실제 작업의 시간 절감 증거가 아니다.

## 공통 실행·완료 출력·raw 분리 · 2026-10-02

implemented-source: 사용자 ‘모두 개선해줘’에 따라 공통 실행 계약 (`planning/workflow-small-change.md` · 현재 로컬 계약/오버레이·이번 공개 제외)과 증거 도구 (`planning/tools/workflow_evidence.py` · 현재 로컬 계약/오버레이·이번 공개 제외)에 native 실행을 추가했다. 후보 cwd와 절대 entry/engine, UTF-8, regression/focused/smoke/captures별 timeout을 고정하며 실제 설정·엔진 hash를 기록한다. 짧은 잘못된 timeout과 원본/후보 경로 혼합을 준비에서 차단하고 timeout의 부분 raw는 실패 기록으로 보존한다. 엔진/entry 및 사용 입력은 실행 계획과 동결 신원에 연결한다.

core/session/integration의 완료 출력은 WORKFLOW SUITE JSON schemaVersion=1로 통일했다. suite별 실제 수·실패 수·누락/중복·구형 결과 혼합과 TEST SUITE 종료를 함께 확인하며 역사 로그의 기존 읽기는 유지한다. raw는 run/candidate/attempt UUID별 새 폴더·배타 생성 파일에 저장하여 다른 record의 같은 후보·번호와 충돌하지 않는다. 같은 record는 한 작성자가 순차 갱신한다. 검사 소스 (`planning/tools/test_workflow_evidence.py` · 현재 로컬 계약/오버레이·이번 공개 제외)와 실행 증거 (`planning/workflow-runs/workflow-improvement-20261002/execution-tools-r3/evidence.json` · 로컬 전용·이번 공개 제외)에서 반례·실제 subprocess·현재 LÖVE suite를 확인한다. 검사별 timeout은 대기시간/성능 목표가 아니며 준비 수리에 전체 suite를 반복 요구하지 않는다.

앞의 ‘M16 미검증·게임 중단’ 문장은 이전 개선 revision 당시 상태다. M16은 별도 세션의 사용자 재개 권한으로 해당 완료 기록 (`planning/workflow-runs/m16-unlock-20261002/result.md` · 로컬 전용·이번 공개 제외)에 반영됐다. 이번 도구 개선은 그 제품 후보를 보존하며 후속 기능·백로그를 진행하지 않는다. 게임 화면·입력·저장 동작을 바꾸지 않아 UI capture는 근거 있는 비적용이다. 실제 작업 소요시간 절감은 아직 측정하지 않았다.
