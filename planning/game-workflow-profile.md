# defense-roguelike 게임 프로젝트 프로필

Revision: 1 · 2026-09-25. 현재 저장소의 `README.md`와 파일 구성을 확인했다. 아직 근거가 없는 제품·기술 설정은 미정으로 유지한다.

| 설정 | 값 | 출처 |
| --- | --- | --- |
| 게임 | `defense-roguelike` · 상세 장르/규칙 미정 | [README](../README.md), 저장소 이름 |
| 엔진 / 차원 | 미정 · 엔진 설정 파일 없음 | 저장소 파일 조사 |
| 플랫폼 | 미정 | 저장소 파일 조사 |
| 화면 / 입력 | 미정 | 저장소 파일 조사 |
| 게임 언어 | 미정 | 저장소 파일 조사 |
| `communication.preferredLanguage` | `ko` · 문서도 상속, 별도 override 없음 | 워크플로 기본 언어와 사용자 선호 |
| `workflowRunRegistryPath` | `planning/workflow-runs/active.json` | 이번 프로젝트 적용 |

## 명령

작업 디렉터리: 저장소 루트. 명령 정의를 조사했지만 현재 `README.md` 외에 빌드·실행·테스트 설정은 없다. 이번 프로필 작성에서 게임 실행이나 빌드를 검증하지 않았다.

| 목적 | 명령 |
| --- | --- |
| 실행 / 빌드 / 테스트 | 미정 · 엔진 또는 빌드 설정이 추가된 뒤 실제 정의를 기록 |

## 참조와 미정 설정

- 작업 규칙: [AGENTS.md](../AGENTS.md)
- 워크플로 적용 기록: [.agents/skills/WORKFLOW_ADOPTION.md](../.agents/skills/WORKFLOW_ADOPTION.md)
- 제품 기준, UI 설정, 컴포넌트 카탈로그, 모델 라우팅 프로필, 위키 연동은 확인되지 않았다. 해당 작업이 시작되면 실제 자료 또는 사용자 결정을 근거로 추가한다.

## 작은 변경 실행 경로 · DR-WF-SMALL-001 r1

| 설정 | 값 | 출처 |
| --- | --- | --- |
| `workflow.smallChangePolicyPath` | `planning/workflow-policy.json` | 사용자 2026-10-02 워크플로우 개선 지시 |
| `workflow.smallChangeContractPath` | `planning/workflow-small-change.md` | 프로젝트 한정 역할 통합·필수 결과 유지 |
| `workflow.evidenceToolPath` | `planning/tools/workflow_evidence.py` | 경로/JSON/fixture/검사 이름 preflight·실제 실행·보고서 생성 |

현재 M16은 후보 부분 구현 상태로 중단했으며 제품/저장/원본 반영을 완료했다고 표시하지 않는다. 이전 완료 모듈과 현재 게임 콘텐츠 기준은 유지한다. 작은 변경의 실작업 소요시간과 45–75분 목표는 미검증이다.
