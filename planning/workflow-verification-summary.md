# 워크플로우 도구 공개 검증 범위

이 변경은 현재 공개 HEAD의 제품·위키 출처를 유지하며 읽기 전용 운영 도구와 그 정확한 evidence 파서/테스트 의존성, 관련 계약만 게시한다. 현재 로컬 진행 중인 게임 후보·권리·버전·기능 검증 기록은 이 변경으로 공개하지 않는다.

```powershell
python -X utf8 -B -m unittest discover -s planning/tools -p test_workflow_support.py -v
python -X utf8 -B -m unittest discover -s planning/tools -p test_workflow_evidence.py -v
python -X utf8 -B defense-roguelike-wiki/check_docs.py
```

앞선 안정된 로컬 후보의 작성자/독립 검증에서는 support19와 evidence44, 위키 구조 검사가 통과했다. 이 게시 후보의 실제 재검사는 같은 명령으로 수행하며 결과가 없는 실행을 PASS로 간주하지 않는다. 테스트는 합성 원장·ID·PNG·실제 호스트 directory link와 격리된 보존 입력을 사용한다. 도구 관측과 게임 기능/기기/출시·실제 작업 시간 절감의 증거는 구분한다. 상태/ACK 예시는 사용자가 실제 로컬 기록의 정확한 locator/field를 지정하는 방법이며 해당 실행 자료의 공개 재현을 약속하지 않는다.

이번 게시 후보의 실제 재검사에서 support19와 evidence44가 모두 PASS했다. 두 도구 테스트 소스와 구현은 독립 검증된 입력과 같은 bytes이며, 공개 HEAD의 제품 bytes는 이 워크플로우 변경으로 바꾸지 않았다. 위키 출처는 공개 HEAD 목록에 관련 워크플로우 파일만 추가하고 현재 bytes를 연결한다.
