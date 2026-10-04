# LÖVE 전투·저장 기술 설계

공개 범위 안내(2026-10-04): 아래 확정/위임/제안 규칙과 수치는 원문대로 유지한다. 설계 시점의 단계 상태와 역사적 검사는 당시 범위이며, 현재 지원 구현·검증 범위는 [README](../README.md)와 [M31 공개 검증 요약](workflow-runs/m31-unlock-20261004/publication-summary.md)을 따른다. 별도 표시한 로컬 전용 설계/검사/아트 자료는 이번 공개에 포함되지 않는다.

`DR-TECH-001` · revision2 · 2026-09-29 · design@1 · goal revision9 · `/root` / game-technical-design@1.

## 1. 무엇을 구현 가능하게 만드는가

[첫 구간 명세 DR-SLICE-001 r2](first-slice-spec.md)의 동일 출현·입력은 1배/2배에서도 같은 전투 결과를 내고, 거래/완료 저장 중 중단돼도 골드와 해금이 서로 다른 시점으로 복원되지 않도록 한다. 입력은 baseline v0.9, TOWER-C01 r1, MOD r2, UNLOCK r1, UX r2이다. 최초 양식 계약은 revision8의 T24/T26, 최신 개선·검증은 revision9 (`planning/workflow-runs/design-document-20260925/revision-9.md` · 로컬 전용·이번 공개 제외).

관측: 저장소에 `main.lua`, `conf.lua`, 실행/테스트 정의가 없다(2026-09-29 scoped file search). 아래 이름은 **선택한 후속 구현 경계**이며 이미 존재하는 함수나 파일이라고 주장하지 않는다. 엔진은 사용자 지정 LÖVE+Lua, 기술 목표는 **LÖVE 11.5 / Windows x64**로 선택했다. 공식 홈페이지가 현재11.5를 배포 대상으로 안내하는 것을 확인했으며 설치·호환 실행은 미실행이다. [공식 배포](https://love2d.org/)

설계 상태: 첫 구간의 기술 계약 작성, 정적 검토 상태는 실행 기록. 코드 작성 권한·대상 런타임 검증·전원 차단 내구성을 뜻하지 않는다. 4–15웨이브와 고난도/정식 화면은 소비 범위 밖이다.

## 2. 선택과 대안

| 결정 | 선택 / 이유 | 채택하지 않은 대안·비용 |
| --- | --- | --- |
| TD1 시계 | 60Hz 고정 tick, 렌더 분리 | 가변 dt 직접 피해/이동은 구현은 짧지만 경계 사건이 프레임률에 의존 |
| TD2 규칙 구조 | 작은 Lua 데이터·함수 모듈, 단일 전투 writer | ECS/범용 효과 그래프는 현재 규모에서 별도 언어·수명 관리 부담. 48종을 불명확한 공용 문자열 eval로 처리하지 않음 |
| TD3 세이브 경계 | meta+run을 한 checkpoint payload에 기록 | 별도 파일에 해금/골드 따로 쓰면 완료 도중 중단 시 불일치 가능 |
| TD4 복원 | combat 시작 checkpoint 복원, 중간 프레임 저장 안 함 | 모든 탄환/예약/연출을 중간 저장하면 현재 요구보다 복구 범위 커짐 |
| TD5 랜덤 | 상점용 RNG와 표현용 RNG 분리, 명시 상태 보존 | 전역 random을 공유하면 애니메이션 호출 수가 상품 결과 변경 |

주요 위험은 실제 저장 API의 실패/부분쓰기, 전투 사건의 정의와 해금 카운터 연결, 화면 좌표 변환이다. 구현 전에 어댑터의 readback/오류 반환을 실제 LÖVE에서 확인한다. 위키 일부가403으로 열리지 않아 API의 원자성/전원 내구성을 추정하지 않았다.

## 3. 책임·데이터·인터페이스

### 3.1. 단일 작성자 경계

| 후속 모듈 경계 | 유일한 책임·작성 상태 | 읽는 것 / 금지 |
| --- | --- | --- |
| content | 버전 있는 정의/좌표/편성 로드·유효성 검사 | 실행 중 불변. 기존 카탈로그의 효과/ID를 재정의하지 않음 |
| session | phase, pauseReasons, 전환과 command 접수, 저장 대기 | 보상/피해 수식 직접 구현 금지 |
| rules | 거래 후보·능력치·정산·해금 평가를 결과값으로 반환 | RNG/storage/render 호출 금지 |
| battle | tick, 적/타워 charge/탄환, 전투 이벤트·임시 관측 | battle step만 전투 상태 변경. 영구 해금 직접 쓰기 금지 |
| shop | 상품 생성·visit 카운터·구매 제외 풀, 거래 후보 | injected RNG만 사용; 실패 명령은 RNG commit 안 함 |
| save | checkpoint encode/검증/readback/복구 | 게임 수식/보상 추가 금지 |
| view/input | 상태 projection을 표시하고 명령 생성 | 골드/타워/해금 직접 변경 금지. 선택/스크롤은 로컬 표시 상태 |

이는 파일 수를 강제하는 것이 아니라 상태 소유 계약이다. 같은 구현 파일에 작은 함수로 시작해도 책임과 테스트 경계는 유지한다. 멀티스레드·네트워크·비동기 worker는 이번 설계에 없다.

선택 인터페이스: `validateContent(defs) -> errors`; `projectStats(run,towerId) -> stats/conditions`; `tryCommand(state,command,rngCopy) -> candidate/events/error`; `stepBattle(state,dtFixed) -> state/events`; `reduceCompletion(state,event) -> checkpointCandidate`; `commitCheckpoint(candidate) -> committed|failed|uncertain`; `loadCheckpoint() -> valid|recovered|unsupported|missing|corrupt`. 구현자가 이름을 바꿔도 소유/입출력 의미를 바꾸지 않는다.

### 3.2. 최소 데이터 계약

| 데이터 | 필수 필드·불변식 |
| --- | --- |
| MapDef | id, revision, width/height, entrances[{id,routeId}], routes[{id,points,totalLength}], exit. 입구ID 고유, 모든 route 존재·지도 내·직교·양의 구간, 마지막 점은 exit |
| WaveDef | id/index, groups[{groupId,entranceId,enemyId,count,firstTick,intervalTicks}]. 양의 count/interval, firstTick>=0, 참조 유효. seconds→ticks 변환은 authoring validation에서 정수 여부 검사 |
| TowerInstance | instanceId, typeId, paidGold, patchIds[], placement 또는 null, charge, activated. ID 판 안 불변·재사용 없음; 패치3 이하; 점유1 |
| ModuleInstance | moduleId, negative, paidGold, growth, effectSpecificState. 한 ID 판1회 획득, 구매 제외 집합과 장착 집합 구분 |
| RunState | runId, contentVersion, phase, mapId, nextWaveIndex, gold,hp, towerInstances,modules, acquiredModuleIds, frozenUnlockPool, nextInstanceId, shopState, unlockRunProgress, completedWaveIds |
| ShopState | visitId, offers[타워/패치/모듈], rerollCount, refundUseCount, firstRerollDone, 거래영수증/교체매칭용 기록, rngState |
| BattleState | waveId,tick, nextGroupIndices, enemies,projectiles, nextSpawnOrdinal,nextProjectileId, waveObservations, firstShot/shotCount/streakRecords, 누수/유지조건. checkpoint에는 시작 상태로만 보관 |
| EnemyInstance | enemyId/typeId, routeId,s,totalLength,hp,maxHp,spawnOrdinal,slowUntilTick, slowRatio, 최근 피격종류/시각. 기록은 효과 판정 후 갱신 |
| Projectile | projectileId, sourceTowerId/typeId, targetId, position,speed, launchBaseDamage, launchAttackId, sourceKind, 추가 단발 예약·M24 epoch. 일반/추가·첫 표적 구분 |
| MetaState | unlockedTowerIds,unlockedModuleIds,collectionPurchaseIds. 이미 해금된 ID를 조건 변경으로 다시 잠그지 않음 |

원문 카탈로그/해금에 필요한 effectSpecificState와 unlockRunProgress는 생략 가능한 장식 필드가 아니다. 다음을 포함한다: M33–M40 성장과 M40 관측 패치ID, M48 직전 정산값, M29 환급 횟수, M30 방문 첫 리롤, I27 타워별 연속, I35/I38/I39 연속, I36 적격 판매/대체 구매·다음웨이브 매칭, I40 실전 패치ID, I48 직접 모듈수입 완료 수, 타워의 과거 온전한 웨이브 배치 이력. 영구 이력과 현재 판 진척은 분리한다.

Ixx의 조건식 자체는 [해금 명세](module-unlocks.md)를 사용한다. 시작/완료 배치 스냅샷과 중간 조건위반 latch, 타워별 일반 첫표적 발사/적중/킬, 처치 직전HP/최대HP/남은경로, 완료 정산 전골드/슬롯/장착액/직접모듈수입을 제공한다. 단순히 완료 시점의 상태만 검사해 ‘웨이브 내내’ 조건을 만족시켜서는 안 된다.

표현 좌표는 적/타워의 연속 격자 중심 좌표를 사용한다. `worldToCanvas`/역변환은 동일 원점·tileSize를 사용하고 window→480×270은 letterbox와 실제 정수 확대율을 역적용한다. 영역 밖 클릭을 가장자리 칸으로 clamp하지 않는다. sprite offset/그림 크기/은박 효과는 게임 좌표·피격 규칙에 영향 없음. 최종 tileSize/패널 geometry는 후속 screen-spec, playable UI는 자신의 임시 geometry를 명시하고 동일 역변환을 검증한다.

## 4. 시뮬레이션과 세션 전환

### 4.1. 시간·정렬·명령

- `dtFixed=1/60`. 매 렌더 프레임 실시간 경과×speed를 accumulator에 더하고, 충분할 때 고정 step을 실행한다. 프레임당 최대8step을 수행하고 나머지 부채는 유지한다. 숨은 tick 삭제/랜덤 건너뛰기 없음. 과부하는 느린 실시간 진행으로 나타나며 성능 문제로 기록한다.
- pause 진입 시 미처리 실시간 부채는 폐기하되 이미 실행한 tick은 되돌리지 않는다. 포커스 복귀 시 벽시계 경과를 보충하지 않는다. 검증은 **같은 tick에 같은 명령**을 넣어 비교하며 같은 실제 초 클릭이 1배/2배에서 같다고 주장하지 않는다.
- tick0 예정 출현 생성 후 첫 step의 종료 시각은1/60. 이후 step 종료 tick에 예정된 출현은 이동 단계에 들어가되 그 tick 새 적의 이동량은0으로 두어 출현 전 시간만큼 먼저 움직이지 않게 한다. tick0 적은 첫 step에 정상 이동한다. 출현 t=k/60인 적의 무방어 출구 도달은 그 시각+경로 이동시간의 올림 tick이다.
- 순서는 DR-SLICE-001 4.4. 테이블 `pairs` 순회순서를 게임 판정에 쓰지 않는다. groupId/towerInstanceId/projectileId/spawnOrdinal로 명시 정렬. 중심 거리 경계는 `distanceSquared <= radiusSquared + 1e-9`; 표적 남은 거리 차가1e-9 이내면 spawnOrdinal로 동률 처리.
- 일반 발사마다 launchAttackId 증가. M24는 표적 전환 때 epoch 증가, 이전 epoch 탄환의 늦은 적중은 새 streak에 합산하지 않는다. 빗나감은 발생 시점의 현재 연속 수를0으로 만든다. 추가 타격은 일반 적중/발사 수를 바꾸지 않는다. MOD4.3의 사건 의미를 후속 로그에서 직접 확인한다.
- UI 명령은 commandId/expectedStateRevision을 가진다. 사용된 commandId 재전달은 같은 결과를 반환하고 새로 실행하지 않는다. 오래된 preview 확인은 현재 상태로 다시 검증/preview 요구. 새로 구입한 다른 개체로 대상을 바꾸지 않는다.

#### 사격 진척의 수치 계약

`rate`는 현재 최종 공격속도(회/초), `dt=1/60`, `EPS_CHARGE=1e-9`(충전1회분 단위). 데이터/능력치 투영은 rate가 유한 양수인지 검사한다. 부동소수의 `0.9999999999999999` 때문에 발사가1tick 밀리지 않도록 아래 임계 비교를 사용하되, 정상 양수 잔여 진척을 매 발사마다0으로 버리지 않는다.

```text
활성·배치·진행 중인 타워만:
  q = charge + rate / 60
  target = 기존 우선순위로 현재 유효 표적 선택
  target이 없으면: charge = min(1, q); 종료
  q >= 1 - EPS_CHARGE 동안:
    일반 발사(target); q = max(0, q - 1)
    target = 현재 유효 표적 재선택
    target이 없으면: q = min(1, q); 반복 종료
  charge = q
```

표적이 없는 동안만1로 제한한다. 적중은 별도 단계이므로 같은 tick에 발사한 탄환 때문에 즉시 사망한 것으로 가정하지 않는다. 같은 타워의 여러 발은 발사 순으로 attack/projectile ID를 부여하며 다음 towerInstanceId로 진행한다. 고속 수치를 tick당1발로 숨겨 제한하지 않는다. 무표적 동안 비축한 공격 여러 발과 현재 tick에 실제 발생한 여러 발은 다르다. 추가 공격 M21/23/24의 카운터/예약은 각각의 일반 발사를 기존 규칙대로 처리한다.

연속 표적·고정 rate·초기0의 수학적 기준은 tick N까지 `floor(N×rate/60)`회, n번째 발사는 `ceil(60n/rate)`tick이다(정확한 정수 경계에서 위 오차 허용). 개별 간격은 서로 다른 정수 tick일 수 있지만 잔여를 버려 장기 발사율을 낮춰서는 안 된다. 저장은 tick 종료의 charge만 보관, speed 변경·이동·회수·준비·복귀가 임의로0/1로 초기화하지 않는다.

분석 회귀: fire-cadence.mjs (`planning/analysis/fire-cadence.mjs` · 로컬 전용·이번 공개 제외)를 `node planning/analysis/fire-cadence.mjs`로 실행한다. 누적 알고리즘과 별도 이상적 발사시각 oracle을 비교하며4/4.6/5.8/1÷3회, 합성75회/초, 장시간 무표적→획득, pause/미배치·속도 변경,1배/2배 tick 묶음을 포함한다. 75는 미래의 숨은 상한을 막는 합성 입력이지 출시 포탑 수치가 아니다. 이것은 JS 문서 수식 검사이며 실제 Lua 상태·표적·투사체·저장 통합과 SL03 실행을 대체하지 않는다.

### 4.2. 상태 전환·checkpoint

| 현재 / 명령·사건 | 다음 / 확정 경계 | 비고 |
| --- | --- | --- |
| TITLE / 새 판 | SHOP S00 | Meta를 읽어 frozenUnlockPool 작성, 새runId/RNG, 성공 저장 후 진입 |
| SHOP / 거래·배치·리롤 | 같은 SHOP | rules/복제 RNG로 candidate 생성→checkpoint 확정→화면 반영 |
| SHOP / 상점 접기 | PREPARE (동일 visit 접근권 유지) | 상품/RNG/방문 사용량 불변 |
| PREPARE / 유효 변경 | PREPARE | 성공 candidate 저장 후 반영, 실패 rollback |
| SHOP 또는 PREPARE / 전투 시작 | COMBAT | wave 카운터 초기화·영수증/유지조건 반영→waveStart checkpoint 성공 후 tick0 |
| COMBAT / pause·focusLost | COMBAT + pauseReasons | 관찰/설정만, 배치명령 거부. 사용자 재개는 포커스가 돌아온 경우에만 |
| COMBAT / 일반 완료 | PREPARE 또는 SHOP | 같은 snapshot에서 정산·성장·해금→단일 완료 checkpoint. W03은 S01 생성/RNG/방문 초기화까지 포함 |
| COMBAT / 패배·최종 승리 | RESULT | 패배/승리와 해당 meta만 저장, 일반 정산 없음 |
| 임의 durable 행동 / 저장 오류 | SAVE_ERROR | candidate와 이전committed state 보관, 변경 명령 차단, 재시도/명시적 종료만 |

모듈 구매·판매나 수용량 회수 선택은 확인 전 transactionDraft에만 존재한다. 그동안 실제 타워/돈/모듈은 바꾸지 않는다. 상점은 시뮬레이션 정지 상태이며 거래 중 후보가 전투로 바뀌지 않는다. 전투 배치는 메모리에 반영하되 D15에 따라 개별 checkpoint를 쓰지 않고 시작 snapshot으로 되돌릴 수 있다.

## 5. 저장과 복원

### 5.1. 저장 봉투와 RNG

`save-a.json`/`save-b.json` 두 세대. envelope는 `schemaVersion=1`, `generation`(단조 증가 정수), `contentVersion`, `engineTarget`, `payloadJson`(UTF-8 문자열), `payloadChecksum`을 포함한다. checksum은 payloadJson 원문 바이트의 SHA-256으로 선택한다. payload 내부는 MetaState + checkpointKind + RunState + resumeDescriptor + 최근 완료/거래identity. JSON은 데이터 parser만 사용하고 Lua 실행문으로 load하지 않는다. codec 선택/종속성 고정은 구현자 담당, API 명칭 추정 대신 readback 시험 필수.

RNG는 주입 가능한 `drawInteger(lo,hi)/getState/setState` 경계. 구현 시 LÖVE RandomGenerator 어댑터의 상태 왕복을 검사한다. 룰 데이터가 현재 고정인 W01–W03은 출현에 RNG를 소비하지 않는다. 상점은 유형 순서 타워→패치→모듈, 각 유형 등급→정렬된 ID에서 항목→모듈의 negative 순으로 뽑는다. 비어 있는 후보는 추첨하지 않으며 고갈칸 품절. 실제 상태 문자열/엔진 버전을 함께 저장한다. UI hover/취소·예고·효과는 이 RNG를 소비하지 않는다. 장식 RNG는 checkpoint에서 제외해도 전투 결과가 같아야 한다.

### 5.2. 확정 절차와 실패

1. 마지막 committed generation은 건드리지 않고 더 오래된/빈 슬롯에 generation+1 후보를 쓴다. 거래/완료 계산은 복제 상태에서1회만 수행한다.
2. 쓴 파일을 다시 읽어 checksum·schema·contentVersion·참조/수량/ID 불변식을 검증한다. 유효하면 그 generation 전체를 committed로 삼고 메모리/성공 알림을 갱신한다. pointer 파일 변경에 의존하지 않는다.
3. 쓰기 도중 실패/중단된 파일은 검증에서 탈락. 기존 정상 세대는 남는다. 재시도는 **같은 candidate**를 사용하며 새 상품/새 보상을 다시 추첨/계산하지 않는다.
4. 쓰기 결과가 불명확하면 두 슬롯을 재검사한다. 후보 generation이 온전하면 이미 commit된 것으로 처리하고, 아니면 이전 세대로 유지. 재읽기 자체도 실패하면 SAVE_ERROR로 유지해 추가 변경을 막는다.
5. 저장 성공 전 완료/해금 성공 표시와 다음 전투를 허용하지 않는다. 실패 상태 종료는 ‘저장되지 않은 변경을 잃을 수 있음’을 명시. 재시작은 디스크에서 가장 높은 유효 세대를 사용한다.

동일 `runId:waveIndex:complete`가 이미 committed이면 완료 재전달은 no-op. 한 후보에서 골드·성장·run진척·영구해금·다음상점 RNG를 함께 저장하므로 그중 일부만 commit하지 않는다. 거래도 visitId/transactionId로 중복 방지. 이전 meta가 현재 미완료 wave를 재시도할 때 다시 잠기는 일이 없도록 **waveStart snapshot도 그 시작 시점의 최신 MetaState를 포함**한다.

### 5.3. 복원 사례·호환

- `checkpointKind=combatStart`: 원래 시작 배치/charge/모듈/골드/HP/진척/RNG로 복원, wave 카운터는 snapshot의 초기값. PAUSED 관찰 상태에서 시작하며 명시적 재개 전 적이 움직이지 않는다. 전투 중 신규 배치/누수/적중 임시기록은 보존하지 않는다.
- 거래 후 정상 재실행: 거래가 포함된 generation이면 같은 상품 빈칸·환급·성장·RNG 복원. 저장 전 강제 종료라면 온전한 이전 세대 또는 온전하게 기록된 새 세대 중 하나이며 반쪽 거래 없음.
- 완료 저장 직후 UI 전환 전 종료: 다음 준비/상점 checkpoint 복원, 완료 정산 재실행 안 함. W03 해금은 이후 판 패배에도 유지.
- 두 파일 없음: 새 프로필. 두 파일 손상: 원본 보존, 오류 표시, 자동 초기화/새 판 덮어쓰기 금지. 낮은 유효 세대로 복구하면 rollback 사실과 세대 차이를 알린다.
- 더 높은 schema/contentVersion의 유효 파일 발견: 오래된 세대가 읽힌다는 이유로 자동 downgrade/덮어쓰기하지 않고 unsupported. 실행 중 contentVersion과 다르면 해당 콘텐츠 버전을 제공하거나 별도 migration이 있어야 재개. 이 설계는 미구현 제품의 schema1이며 미래 migration을 구현했다고 주장하지 않는다.
- U1/U2/U3 구형 저장이 실제 발견되면 UNLOCK7절의 ID 매핑을 별도 migration으로 작성·검증. 존재하지 않는 전투 진척을 생성하지 않는다. 지금 legacy adapter를 임의 제작하지 않는다.

두 슬롯+readback은 **앱 중단/부분쓰기 복구 전략**이지 OS 캐시/디스크 고장/전원 차단 시 마지막 완료의 절대 보존 보장이 아니다. 두 정상 세대가 함께 손상되거나 최신 세대가 유실되면 진행 손실이 가능하다. 내구성을 요구하는 추가 플랫폼 API는 별도 실제 검증 없이는 약속하지 않는다.

## 6. 확인 방법과 남은 경계

| 입력/행동 | 기대 결과 | 연결 기준 |
| --- | --- | --- |
| same content/seed + tick명령으로 1배/2배 | spawn/shot/hit/leak/complete 로그 의미 동일, 렌더 시간 제외 | SL02–SL06 |
| 두 경로 remaining=3, 길이21/20 | 타겟 spawnOrdinal 우선; M22 둘 다 참. remaining=5.1이면 길이21만 참 | SL04 |
| 처음 냉각 적중, 그 뒤 M17 공격 | 첫 냉각에 자기 둔화 소급 없음, 뒤 타격에 적용 | SL05 |
| 완전한 완료 candidate 쓰기 후 성공 반환 전 중단 | 유효 highest generation 채택; 정산/해금 중복0 | SL08 |
| W03 완료 중 부분쓰기, 이전 combatStart 정상 | W03 시작으로 복구; 이전 완료 해금 보존, 이번 미확정 해금 재평가 | SL08 |
| M29 가진 상태 정가4·잔액3 | 거래 거부, 환급을 선불로 사용할 수 없음 | SL07 |
| M05 판매로 설치8→수용6, 회수2 선택 중 취소 | 타워8/모듈/돈 전부 이전 상태 | SL07 |
| 창 크기/letterbox 변경 후 같은 칸 클릭 | 같은 world cell, 밖 클릭은 거부 | SL09 |

위 표는 설계 walkthrough이며 실제 테스트 결과가 아니다. 구현 순서는 콘텐츠 검증·규칙/전투 → 거래/완료 reducer → 저장 readback/실패 → 입력/기능 UI 통합. 상세 작업계획과 assertion 구현/실행 배정은 후속 game-task-planning/test-design 소유이다.

범용 시스템/전투중 프레임 세이브/네트워크로 확장하지 않는다. 유지 가능한 제품 구조로 구현하려면 이 계약을 만족하는 실제 LÖVE 첫 구간 결과와 분리된 기능 검증이 필요하다. 다른 맵/새 공격 형태/새 저장 요구가 이 경계를 넘으면 해당 기술 결정을 revision한다.

참고: [Mindustry SpawnGroup](https://github.com/Anuken/Mindustry/blob/master/core/src/mindustry/game/SpawnGroup.java)의 출현 데이터 분리, [SaveIO](https://github.com/Anuken/Mindustry/blob/master/core/src/mindustry/io/SaveIO.java)의 저장 버전/백업 복구를 읽었다. 공개 master 조회의 구조 참고일 뿐 우리 코드·엔진 API·두 슬롯 설계의 검증 결과가 아니다.
