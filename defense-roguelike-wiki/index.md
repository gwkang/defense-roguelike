# defense-roguelike 위키

공개 범위 안내(2026-10-04): 이번 [공개 검증 요약](../planning/workflow-runs/m31-unlock-20261004/publication-summary.md)과 [출처 신원](sources.json)은 포함된 공개 파일의 현재 bytes에 한정한다. 이전 로컬 전체129 출처 기록·독립 검토·raw/capture와 미공개 overlay는 로컬 보존본/불변 실행 증거에 남으며 이번 공개의 직접 링크나 현재 공개 source 신원으로 대체하지 않는다. 아래 역사적 관측은 당시 범위다.

2026-10-04 · revision 13 · 필수 프로젝트 지식. 초기 구성은 수정 실행 (`planning/workflow-runs/workflow-mandatory-20260930/run.md` · 로컬 전용·이번 공개 제외), I28/M28은 예치금 실행 (`planning/workflow-runs/m28-unlock-20260930/run.md` · 로컬 전용·이번 공개 제외), I43/M43은 여유 회로 실행 (`planning/workflow-runs/m43-unlock-20260930/run.md` · 로컬 전용·이번 공개 제외)을 따르며 테스트 러너의 실패 종료 수정은 러너 실행 (`planning/workflow-runs/runner-exit-20261001/run.md` · 로컬 전용·이번 공개 제외)에 있다. 전투 시작 저장 실패 후 재시도 복구는 복구 실행 (`planning/workflow-runs/combat-start-retry-20261001/run.md` · 로컬 전용·이번 공개 제외)에서 확인한다. I46/M46 비상 출력은 비상 출력 실행 (`planning/workflow-runs/m46-unlock-20261001/run.md` · 로컬 전용·이번 공개 제외)을 따른다. I41/M41 중가 연동은 중가 연동 실행 (`planning/workflow-runs/m41-unlock-20261001/run.md` · 로컬 전용·이번 공개 제외)에 있다. I42/M42 자산 연동은 자산 연동 실행 (`planning/workflow-runs/m42-unlock-20261001/run.md` · 로컬 전용·이번 공개 제외)에 있다. I15/M15 혼합 개조는 혼합 개조 실행 (`planning/workflow-runs/m15-unlock-20261001/run.md` · 로컬 전용·이번 공개 제외)에 있다. I14/M14 고급 정비는 고급 정비 실행 (`planning/workflow-runs/m14-unlock-20261002/run.md` · 로컬 전용·이번 공개 제외)에 있다. I12/M12 균등 투자는 균등 투자 실행 (`planning/workflow-runs/m12-unlock-20261002/run.md` · 로컬 전용·이번 공개 제외)에 있다.

| 주제 | 내용·현재 상태 |
| --- | --- |
| [개발 기준](development.md) | LÖVE 개발 환경, 예치금·여유 회로·비상 출력·중가 연동·자산 연동·혼합 개조·고급 정비·균등 투자와 저장 경계, R7/M28/M43 역사적 검증, 현재 러너 종료 코드·전투 시작 재시도와 실제 검증 범위 |
| [시각 기준](visual-direction.md) | 선택된 음식 디펜스 방향과 패치 방향, 미승인 모듈 제안 구분 |
| [워크플로우 필수 절차](workflow.md) | 위키·감독·리뷰·회고·모델 필수 결정, 확인한 지침 재사용과 중복 승인 질문 예방, 코드 리뷰 주의사항과 Lua/Python 구현 기준 로컬 보강 |
| [출처·쓰기·검증 정책](policy.md) | 출처 권위, 갱신 소유자, 완료 조건과 검사 명령 |

현재 사실을 소비하기 전에 페이지의 정확한 출처와 [출처 신원](sources.json)을 확인한다. 이 위키는 제품 명세·사용자 승인·실제 실행 증거를 대체하지 않는다. 실행 원장은 레지스트리 (`planning/workflow-runs/active.json` · 로컬 전용·이번 공개 제외)에 있다.

작은 변경의 현재 워크플로우는 프로젝트 로컬 경로 (`planning/workflow-small-change.md` · 현재 로컬 계약/오버레이·이번 공개 제외)와 개선 실행 (`planning/workflow-runs/workflow-improvement-20261002/run.md` · 로컬 전용·이번 공개 제외)에 따른다. 사용자 재개 지시에 따른 M16 단위와 후속 백로그의 미승인 상태를 구분한다. M16 현재 실제 결과는 단일 실행 증거 (`planning/workflow-runs/m16-unlock-20261002/evidence.json` · 로컬 전용·이번 공개 제외)를 따른다.

현재 I31/M31 예비 보급의 구현·저장·조건은 [개발 기준](development.md), 현재 실제 검사·독립 리뷰는 [M31 공개 검증 요약](../planning/workflow-runs/m31-unlock-20261004/publication-summary.md)를 따른다. M16-only는 당시 기록이며 최신 사용자 재개는 M31 단위만 허용한다.
