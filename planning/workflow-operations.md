# 워크플로우 운영 · DR-WF-OPS-001 r1

이 문서는 [작은 변경 계약](workflow-small-change.md)의 현재 단일 원장·역할·권한을 그대로 사용한다. status는 읽기 전용 관측이며 게임 PASS·완료·외부 권한을 판정하지 않는다. 도구 통과와 실제 작업 시간 절감은 별도 관측이다.

## 현재 checkpoint 하나

기존 run의 맨 위 또는 현재 checkpoint 한 곳에 `selectedUnit`, `state`, `rootAppliedVersion`, 현재 candidate/evidence locator, `nextOwner`, 원인별 남은 `budget`을 유지한다. 배정·반환·FAIL·수리·완료 때 같은 checkpoint를 갱신한다. 과거 기록은 그대로 두며 새 봉인·보고서·승인 gate를 추가하지 않는다. 원장과 checkpoint가 어긋나면 status를 읽어 오래된 요약을 정정한다. 실패 원장 r2와 현재 후보 r3의 locator를 구분하고 둘의 결과를 합치지 않는다.

```powershell
python -B planning/tools/workflow_support.py status --root . --record planning/workflow-runs/<run-id>/evidence-current.json
python -B planning/tools/workflow_support.py status --root . --record planning/workflow-runs/<run-id>/evidence-failed.json
```

이 예시의 <run-id>·파일명·ACK field는 실제 프로젝트 기록에 맞춰 명시적으로 설정한다. 예시 경로의 실행 자료는 이 공개 checkout에 포함하지 않는다. 읽는 시점의 hash drift·pending·latest failure·review 적용성에 따라 관측은 달라진다. status의 latestChecks는 check별 마지막 실제 append 시도이며 `actualCount`는 그 시도의 저장 count 합이다. count는 성공 수나 완료 승인으로 소비하지 않는다. source와 raw locator를 따라 필요한 항목만 확인한다. 관측 unverified의 profile/input drift는 현재 게임 결함 확정이 아니다. 외부 engine, production guards/save, 실행자 인증은 이 보조 도구 범위 밖이며 기존 evidence 검사와 독립 리뷰가 소유한다.

## 정확한 집합과 전이

검사목록은 수만 적지 말고 exact ID를 유지한다. producer의 원본 source 집합과 consumer가 변환 뒤 소비한 집합을 각각 해당 소유자가 JSON 문자열 ID 배열로 제공한다. current frontier와 historical frontier를 분리한다. 예를 들어 원본 필요 목록에 한 ID가 있는데 변환 fixture가 그 ID를 빼면 동일한 나머지 ID가 많아도 FAIL이다. ID가 일치해도 저장 migration semantics·실제 runtime coverage는 별도 독립 검토가 필요하다. 이 도구는 Lua 문자열에서 의미를 추론하거나 제품 기대값을 고치지 않는다.

```powershell
python -B planning/tools/workflow_support.py compare-set --expected planning/workflow-runs/<run-id>/expected-ids.json --actual planning/workflow-runs/<run-id>/actual-ids.json
```

missing/extra/duplicates/inputErrors와 각 입력 bytes SHA256를 소비한다. order 차이는 허용하며 empty·타입오류는 입력 오류2, 집합 불일치/중복은1, 정확한 일치는0이다. 배열 생성의 근거 locator와 전이 producer/consumer, 의미 검토 담당자를 기존 반환에 기록한다. 예제 synthetic ID를 실제 역사 fixture의 검증 완료로 승격하지 않는다.

## 필요한 JSON만 조회

actor ACK는 해당 배정의 정확한 locator로 읽고 executor, role, candidate, model/effort, actual start 등 필요한 field만 선택한다. 다른 ACK 검색 결과나 잘린 preview를 전문 소비로 취급하지 않는다.

```powershell
python -B planning/tools/workflow_support.py inspect --json planning/workflow-runs/<run-id>/author-ack.json --field executorId --max-chars 2000
```

`--field`는 object의 dot key 경로다. 배열 index 문법은 지원하지 않는다. missing/non-object parent는 명시 오류다. `--max-chars`는 선택 projection 문자열의32–20000자 한도이며 envelope·source locator는 별도다. truncated=true이면 projection=null과 preview를 출력하고 원 크기를 남긴다. 전문이 필요하면 범위를 나눠 선택하거나 원본 파일을 직접 읽는다. 모든 경로는 명시 root(status) 또는 현재 cwd(compare/inspect) 안의 상대 경로이며 보호 경로·traversal·링크 탈출은 거부한다.

## 실제 시간과 안전한 합류

실제 설계 시작과 authoring 시작을 그 시점에 run 또는 actor ACK에 UTC로 기록하고 정확 locator를 기존 checkpoint에 연결한다. 누락된 pre-init 시간은 미측정으로 보고하며 소급 계산하지 않는다. init 이후 기존 workflow_evidence.py stage begin/end로 design/implementation/review/integration/knowledge를 연결한다. status는 pre-init을 자동 계산하지 않으며 ACK/run의 실제 시각과 stage 사이의 연결은 담당자가 확인한다.

root와 candidate는 별도 신원이다. rootAppliedVersion은 원본의 현재 신원, candidate/evidence는 검증한 후보 신원이다. 동시에 쓰는 채팅/작성자가 있으면 root 보존/read set의 소유자와 사용 종료를 확인하고 join을 기다린다. 각 writer는 배정된 경로만 수정하며 source snapshot은 안정 상태·before/after hash와 용도를 기록한다. 위키 구조를 위한 source 복제는 게임 runtime/acceptance를 증명하지 않는다. 보호 지침 본문을 복제하지 않으며 safe join 때 최신 bytes와 승인 delta만 대조한다. overlap drift가 있으면 해당 합류만 보류하고 새 원본에 필요한 검증을 수행한다.

PNG 관측은 root 안의 명시 artifact bytes에 기존 png_size를 사용해 디코딩한다. PNG 손상·Pillow 부재/디코딩 오류는 unverified 원인으로 보존한다. record schema·count·exit/attempt 정수는 bool/float를 허용하지 않고 소비한 hash/type를 검증한다. review 적용성은 receipt 외에 실제 JSON의 candidate/run/evidence/actor/PASS/차단0·필수 findings·실제 image coverage를 대조하며 host 인증·게임 완료를 추론하지 않는다.

보조 관측과 fixture는 기존 evidence producer의 실제 schema를 재사용한다. image target은 양의 WIDTHxHEIGHT 문자열이며 임의 배열 schema로 바꾸지 않는다. Windows actual junction/다른 OS symlink 등 호스트가 지원하는 실제 fixture로 경계를 검사하되 skip/mock PASS를 만들지 않는다.
