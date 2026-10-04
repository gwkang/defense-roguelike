# 전체 런 연결 명세·기술 설계

공개 범위 안내(2026-10-04): 아래 확정/위임/제안 규칙과 수치는 원문대로 유지한다. 설계 시점의 단계 상태와 역사적 검사는 당시 범위이며, 현재 지원 구현·검증 범위는 [README](../README.md)와 [M31 공개 검증 요약](workflow-runs/m31-unlock-20261004/publication-summary.md)을 따른다. 별도 표시한 로컬 전용 설계/검사/아트 자료는 이번 공개에 포함되지 않는다.

`DR-RUN-002` · revision1 · 2026-09-29 · `specification@1 + design@1` · `first-slice-implementation-20260929 / continuation-design / attempt1` · `/root/core_impl` (`game-feature-spec@1`, `game-technical-design@1`).

입력은 [기획 v0.9](design-baseline.md)의 D02/D08–D16과 U-DELEGATE, [DR-SLICE-001 r2](first-slice-spec.md), [DR-TECH-001 r2](runtime-design.md), 현재 `src/content.lua`, `battle.lua`, `game.lua`, `save.lua`, `session.lua`다. 목표는 현재 S01/W04 경계에서 W15 보스 결과와 새 판까지 이어 가는 것이다. 상태는 **독립 정적 검토 전 ready-for-review**이며 구현 권한이나 밸런스 통과를 뜻하지 않는다. 다음 소비자는 core/content·battle, persistence, shop/game integration, UI UX와 CT01–08 검증이다.

## 1. 의도·범위

| ID | 결정·상태 | 출처와 선택 이유 |
| --- | --- | --- |
| C401 | delegated: M01에서 W04–W15를 진행하고 W3/6/9/12 뒤 S01–S04, W15 뒤 RESULT | D09/U-DELEGATE. W01–W03 데이터와 정산은 그대로 보존 |
| C402 | confirmed/delegated: 상점은 다음 3웨이브, 준비는 다음 웨이브, 보스 규칙은 처음부터 실제 원본으로 공개 | D13. 안내용 복제 편성 금지 |
| C403 | confirmed: 일반 누수 -1, boss 탈출 즉시 패배, boss 처치 즉시 승리, 같은 tick 패배 우선 | C12/C13/D14와 DR-SLICE 4.4 |
| C404 | delegated: `DR-SLICE-001-r2` 저장만 읽기 전용 migration하여 W04에서 계속 | 사용자 재개 요청. 재화·배치·상품·meta·세대를 초기화하지 않음 |
| C405 | delegated: 고정 fixture cycle 대신 현재 지원 풀의 D08 가중 추첨과 저장 RNG 사용 | U-DELEGATE. 실패·미리보기는 RNG를 소비하지 않아 재개 결과 보존 |
| C406 | delegated: victory/defeat RESULT를 저장하고 새 판은 meta만 보존한 새 identity로 시작 | D14–D16. 취소·저장 실패는 기존 RESULT 불변 |

포함: E05, W04–W15, 구간 상점, 예고, RESULT/new-run, known-old migration. 제외: 나머지 42모듈 효과, T05/T06 실제 해금 진행, 신규 맵/타워/패치/아트, 고난도 패널티, 배포. 현재 4타워·9패치·6모듈은 계속 **development fixture subset**이며 전체 카탈로그 완료로 표시하지 않는다.

## 2. 콘텐츠 원본

`contentVersion="DR-RUN-002-r1"`. M01/E01–E04/T01–T04/패치9/모듈6과 W01–W03의 모든 값·group 순서는 변경하지 않는다. 아래 `A/E02/8@0+54`는 `entrance/enemy/count@firstTick+intervalTicks`; 왼쪽부터 G01…이고 동시 tick은 group 순이다.

| wave | groups | 수 / HP | 무공격 마지막 출구(약) |
| --- | --- | --- | --- |
| W04 | `A/E02/8@0+54; B/E04/16@120+21; A/E01/8@360+60` | 32 / 368 | 34.0s |
| W05 | `A/E03/3@0+210; B/E02/8@120+54; B/E04/16@300+18` | 27 / 536 | 39.31s |
| W06 | `A/E01/12@0+48; B/E03/3@60+180; A/E04/20@300+15` | 35 / 748 | 37.77s |
| W07 | `A/E02/12@0+42; B/E04/24@120+15; A/E01/12@300+42` | 48 / 552 | 33.7s |
| W08 | `A/E03/4@0+132; B/E02/12@120+39; B/E01/12@300+42` | 28 / 912 | 38.91s |
| W09 | `A/E04/30@0+12; B/E03/4@60+108; A/E02/14@240+27; B/E01/10@420+42` | 58 / 1,038 | 37.17s |
| W10 | `A/E01/16@0+36; B/E02/16@60+27; A/E04/24@180+15` | 56 / 696 | 30.0s |
| W11 | `A/E03/5@0+90; B/E01/16@120+36; A/E04/20@300+12` | 41 / 1,084 | 38.31s |
| W12 | `A/E03/6@0+72; B/E02/16@60+24; A/E04/28@180+12; B/E01/12@420+36` | 62 / 1,340 | 38.31s |
| W13 | `A/E02/20@0+21; B/E04/40@60+9; A/E01/16@300+30` | 76 / 824 | 33.5s |
| W14 | `A/E03/8@0+48; B/E01/20@60+30; A/E02/20@180+18; B/E04/32@300+9` | 80 / 1,840 | 37.91s |
| W15 | `A/E05/1@0+60; B/E01/16@60+33; A/E04/24@180+12; B/E02/12@300+24; A/E03/4@240+48` | 57 / 2,328 | 38.71s |

E05 시험값: `boss=true`, HP 1,200, 기본 속도 0.60칸/s, route R_A. HP가 **600 미만**이면 다음 이동 tick부터 기본 속도×1.20; 정확히 600은 미발동이다. 냉각은 일반 적과 동일하며 소환·면역·타워 무효화는 없다. 수치·편성은 U-DELEGATE로 선택한 플레이테스트 시작값이고 실제 난이도/재미는 미검증이다.

## 3. 전투·세션 계약

- 일반 W04–W14는 기존 완료/정산을 사용한다. `waveIndex % 3 == 0`인 W3/6/9/12만 구간 +6을 주고 새 S01/S02/S03/S04를 같은 완료 checkpoint에서 생성한다. 그 외는 PREPARE. W15 victory/defeat에는 일반 완료·무누수·구간 정산을 만들지 않는다.
- battle은 `bossKilledThisTick`, `bossEscapedThisTick`, `hpZeroThisTick`을 stage3/4 사건으로 기록하고 finish owner 한 곳에서 `defeat if hpZero or bossEscaped; else victory if bossKilled; else normal completion` 순으로 1회 확정한다. W15은 출현 종료·일반 적0이어도 살아 있는 boss가 있으면 완료하지 않는다. boss 처치 순간 뒤 damage 사건은 중단한다.
- `run.result={kind="victory"|"defeat", waveId, tick, reason}`를 `runResult` checkpoint와 RESULT에 저장한다. RESULT에서는 거래/전투가 없고 `NEW_RUN`만 가능하다. 새 판 확인은 새 `runId`·shop seed를 한 draft에 고정하고 취소 시 폐기, 저장 실패/재시도 시 같은 draft를 쓴다. 생산 identity provider는 `os.time + love.timer.getTime + love.math.random + process nonce`를 SHA-256한 opaque ID/독립 seed를 만들며 테스트는 주입한다; 기존 `run:<sessionSerial>`은 재시작 충돌 때문에 금지한다.
- 새 판은 HP20/12골드/무료 T01 2기/미배치/패치·모듈·성장0/S00으로 시작하고 meta만 보존한다. 현재 판의 gold/tower/module/completedWave는 이월하지 않는다.

## 4. 상점·예고 계약

- `src/shop.lua`가 유일한 offer/RNG writer다. `tier`를 콘텐츠에 명시하고 현재 풀은 tower low T01/T04·mid T02/T03, patch 각 tier 3종, module low M01/M02/M25/M26·mid M17·high M05다. 새 런의 `frozenUnlockPool`은 이 fixture subset snapshot이며 meta 해금으로 꾸미지 않는다.
- `shopState`는 `visitId, offers, soldOut, rerollCount, refundUseCount, firstRerollDone, rngState, accessOpen`을 가진다. RNG는 기존 `Rng.new`의 `park-miller-v1`; 새 판 entropy seed 이후 state만 저장한다. 종류 순 tower→patch→module, 각 종류에서 사용 가능한 tier의 60/30/10만 재정규화해 tier 1회, 정렬 ID 1회 추첨한다. 후보가 없으면 `soldOut[kind]=true`이고 그 종류는 draw 0회다.
- 모듈 후보는 `acquiredModuleIds`를 제외한다(D02). 설치 목록만 검사하면 안 된다. 구매는 RNG를 소비하지 않고 칸을 비운다. 새 방문/리롤은 RNG clone으로 전체 후보를 만든 뒤 **저장 성공 candidate에서만** offers와 next RNG를 확정한다. preview/취소/잔액·검증 실패/저장 실패는 committed RNG·offers 불변이다.
- S00–S04는 접어 PREPARE로 갈 수 있고 다음 combat 시작 전만 같은 visit/RNG/상품/리롤로 재개한다. combatStart checkpoint에서 `accessOpen=false`; 이후 PREPARE에서 이전 방문을 열 수 없다. 예고는 `defs.waves`와 E05 fields를 직접 projection하며 별도 수량 표를 유지하지 않는다.

## 5. 저장 호환 설계

- `Save.new`에 `migrations={ ["DR-SLICE-001-r2"] = migrateRun002 }`를 주입한다. `_readSlot`은 envelope 구조→checksum algorithm/checksum→schema1→engine target을 먼저 검증한다. 현재 version은 현 validator, exact known-old만 legacy validator→migration→현 validator 순; unknown/higher schema/content는 기존처럼 `unsupported`이고 더 낮은 valid 세대로 몰래 downgrade하지 않는다. envelope와 `runState.contentVersion`은 둘 다 정확히 `DR-SLICE-001-r2`여야 하며 불일치는 `corrupt`다.
- legacy validator는 확장된 현재 defs가 아니라 고정된 r2 snapshot만 사용한다: M01, W01–W03, E01–E04, T01–T04, 패치9종, M01/M02/M05/M17/M25/M26, visit S00/S01. `nextWaveIndex`는 정수1–4만 허용하고 5–16이나 W04–W15/E05 등 새 ID 참조는 old envelope 안에서 `corrupt`다. `completedWaveIds`는 next index 직전까지 W01부터 빈틈없는 prefix이고 그 이후 wave는 없어야 한다.
- legacy phase guard는 실제 구버전 전이를 보존한다. SHOP은 next1/S00 또는 next4/S01+W03완료만, PREPARE는 next1–4와 해당 완료 prefix만, COMBAT은 next1–3+`combatStart`+현재 Wxx 일치만, RESULT는 next1–3·HP0의 기존 일반전 패배만 유효하다. 디스크 checkpoint에 없던 TITLE/SAVE_ERROR, next4 COMBAT, S01인데 W03 미완료, 현재 wave가 이미 완료된 COMBAT은 semantic `corrupt`다.
- migration은 메모리에서만 수행하고 load 중 write는 0회다. 반환 상태 `migrated`는 source version/generation을 보존하며 Session이 복원한다. 다음 사용자 durable 행동이 성공할 때만 반대 slot에 새 version/generation으로 쓴다. checksum 손상은 migration 전에 `corrupt`다.
- old payload의 HP/gold/towers/placements/patches/modules/acquired/completed/meta/offers/reroll/generation을 그대로 보존하고 offer 재추첨·보상·해금·RNG draw를 하지 않는다. `run.contentVersion`만 갱신하고 `developmentComplete=false`; missing fixture frozen pool은 현재 구현 subset snapshot으로 표시하되 meta unlock은 추가하지 않는다. missing `rngState`는 old payload checksum+runId+visitId의 안정 hash로 seed를 만들며 draw하지 않는다.
- reopen 추론: old S00+next1 SHOP/PREPARE는 open, old S01+next4+completed W03 SHOP/PREPARE는 open. S00+next2/3 PREPARE, 모든 COMBAT/RESULT, 불일치 visit/completed 조합은 closed 또는 semantic corrupt다. old RESULT는 구버전에 victory가 없었으므로 reward/unlock 없이 `result.kind="defeat"`로만 명시한다. combatStart는 원 W01–W03이 동일하므로 시작 snapshot 복원을 유지한다.

## 6. 수용·인계

CT01–CT08의 실행 원본은 후반 연결 검증 계획 (`planning/workflow-runs/first-slice-implementation-20260929/continuation/test-plan.md` · 로컬 전용·이번 공개 제외)이다. CT01은 위 표·W01–03 불변, CT02는 W3/6/9/12 전환/정산, CT03은 boss·동률, CT04는 실제 known-old envelope read-only migration, CT05는 visit 폐쇄, CT06은 RESULT 새 판 원자성, CT07은 seeded weighted shop/acquired 제외, CT08은 실제 LÖVE 정보·조작을 검증한다. 정적 walkthrough는 실행 PASS가 아니다.

핵심 구현 순서: content/battle/rules → save migration/session RESULT → shop/game → UI projection → 현재 후보 동결 후 code review와 독립 CT01–08. 이 revision의 미해결 제품 결정은 없고, 플레이 밸런스 조정은 관측 후 새 revision 소유다. 별도 verifier는 본 파일의 수치 합계·tick 정수·기존 계약 충돌을 읽기 전용으로 판정해야 한다.
