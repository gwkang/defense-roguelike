# 위키 유지 정책

공개 범위 안내(2026-10-04): 이번 [공개 검증 요약](../planning/workflow-runs/m31-unlock-20261004/publication-summary.md)과 [출처 신원](sources.json)은 포함된 공개 파일의 현재 bytes에 한정한다. 이전 로컬 전체129 출처 기록·독립 검토·raw/capture와 미공개 overlay는 로컬 보존본/불변 실행 증거에 남으며 이번 공개의 직접 링크나 현재 공개 source 신원으로 대체하지 않는다. 아래 역사적 관측은 당시 범위다.

2026-09-30 · revision 1 · 사용자 “필수야”와 “모두 수정해”에 근거한다. 프로젝트 계약 (`AGENTS.md` · 현재 로컬 계약/오버레이·이번 공개 제외), [프로필](../planning/game-workflow-profile.md), 수정 실행 (`planning/workflow-runs/workflow-mandatory-20260930/run.md` · 로컬 전용·이번 공개 제외)을 따른다.

## 출처와 상태

사용자의 최신 결정 → 해당 planning 명세/기술·UX 계약 → 현재 코드·설정으로 실제 구현을 구분한다. 검증은 해당 후보와 범위에 연결된 독립 결과만 사용한다. intended, confirmed-decision, implemented-source, historical-verified, proposed, unresolved 상태를 구분한다. wiki가 원본을 덮어쓰거나 충돌을 임의 해결하지 않는다.

페이지별 출처·적용 버전/범위·마지막 확인·상태를 남긴다. 정확한 현재 bytes SHA-256은 [sources.json](sources.json)에 유지한다. 이 초기 구성의 읽기 확인은 과거 게임 후보의 runtime 검증 갱신이 아니다. 원본이 바뀌면 해당 주장만 다시 확인하고 신원을 갱신한다.

## 필수 쓰기 경로

모든 게임 작업의 game-workflow는 index/policy 경로를 전달하고 supervisor는 관련 페이지/출처를 조회한다. specialist는 재사용할 발견과 출처·revision·확인 상태를 반드시 반환한다. 발견이 없으면 no-change 근거를 반환한다.

변경으로 관련 위키 설명이 틀리거나 새로운 관련 지식이 생기면 supervisor가 game-knowledge-maintenance에 범위를 배정한다. 해당 유지 작업은 최종 후보 동결·완료 전에 작성자와 별도 verifier의 의미·문서 검증을 통과해야 한다. 미설정·차단·보류는 필수 작업 완료로 대체할 수 없다.

이 요청은 초기 구성 및 관련 지식 유지의 로컬 권한을 제공한다. 상담·진단·읽기 전용 요청은 읽기 전용으로 유지하고 필요한 지식 갱신의 미충족 범위를 보고한다. 원본 소스 변경, 역사적 기록 재작성, 무관한 신규 조사·정리, 외부 공개나 예약 자동화 권한은 생기지 않는다.

작성자는 배정된 페이지만 수정한다. 공유 index와 source manifest는 한 명의 작성자가 조립한다. 다른 실행과 읽기/쓰기 범위가 겹치면 순차 처리 또는 격리한다. 입력 변경은 영향받은 검증을 무효화하고 재검증한다.

## 문서 검증

저장소 루트에서 `python -B defense-roguelike-wiki/check_docs.py`로 위키 링크·필수 페이지/설정·출처 bytes 신원을 검사한다. `git diff --check`도 실행한다. 구조 PASS만으로 의미 정합성이나 실게임 PASS를 주장하지 않는다. 별도 verifier가 각 주장·원본을 비교하고 승인된 정정이 maintenance로 전달되는 경로를 확인한다.

## 부가 기능 처리

로그는 기존 workflow run을 재사용한다. 검색은 현재 파일 검색으로 충분하여 별도 서비스를 만들지 않는다. 분류는 index의 개발/시각/워크플로우 세 주제를 사용한다. 예약 유지의 필요성은 확인했으나 사용자의 스케줄 요청이 없어 자동화를 생성하지 않는다. 이는 위키 자체나 관련 유지 생략의 근거가 아니다.
