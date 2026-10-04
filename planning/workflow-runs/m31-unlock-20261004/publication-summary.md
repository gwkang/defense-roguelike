# I31/M31 공개 구현·검증 요약

2026-10-04 · `m31-unlock-20261004` · public-summary revision1. 이 요약은 승인된 첫 런타임 공개 의존성과 I31/M31의 로컬 검증 결과를 설명한다. 커밋/푸시 완료 여부는 별도 Git 결과로 확인하며 이 문서 작성만으로 완료를 주장하지 않는다.

현재 구현은 `DR-MOD-I31-r1`, 시작 모듈24종과 확정 영구 권리10종을 합한 최대34종, 포탑6종의 W01–W15 개발 루프다. I31은 새 W09–W14 일반 생존 완료에서 미배치 타워의 서로 다른 종류2종 이상을 전투 내내 보유할 때 M31 예비 보급을 해금한다. M31은 중가12G·슬롯1이며 W01–W14 일반 생존 정산의 완료 미배치 종류당+1G, 최대3G를 기존 수입에 합산한다. W15·패배·미완료·중복 완료는 제외한다. 완료 checkpoint readback 뒤 권리와 알림을 공개하며 현재 판 풀·상품·RNG는 유지하고 다음 성공 새 판의 후보에만 반영한다. 제품 계약의 상세는 [README](../../../README.md), [개발 기준](../../../defense-roguelike-wiki/development.md), [모듈 해금 명세](../../module-unlocks.md)에 있다.

작성자 `/root/m31_author`와 별도 독립 리뷰어 `/root/m31_review`가 다른 실행 주체로 검증했다. 승인된 후보에서 독립 전체 회귀243(core88/session46/integration109), 실패0, exit0, stderr0이 확인됐다. 작성자 focused8(core3/integration5), 실제 LÖVE framebuffer8(480×270 및 필요한 확대), root의 원본 join 후 smoke1도 PASS/exit0이다. framebuffer는 텍스트 overlay를 포함하며 현재 조회11탭·현재/구매/판매·영수증·단일/10권리 알림을 확인했다. 최대10권리 동시 해금은 허용된 보존 지불20+20 fixture의 새 W09 실제 완료와 저장 readback 증거다. 기본 정가 자연 플레이로10종을 도달했다는 뜻이 아니다.

raw 출력·시도별 ledger·독립 리뷰 원문·화면 PNG·이전 실패와 linked cycle은 로컬 불변 실행 증거로 보존하고 공개하지 않는다. 과거 source 전체129 기록도 공개 전 문서 보존본과 로컬 실행 증거에 유지한다. 공개 [source manifest](../../../defense-roguelike-wiki/sources.json)는 이번 선택된 파일만 바인딩하며 미공개 dirty AGENTS/스킬/tool/overlay의 현재 신원이나 과거 검사 결과를 공개 baseline bytes로 대체하지 않는다. 자연 플레이·S00부터 특정 seed 경로·물리 입력·기기·정식 아트·밸런스·배포·출시는 이 로컬 검사로 검증하지 않았다.

공개 범위는 런타임/테스트/launcher17개와 현재 기획/프로필/모델 설정, 시각 방향 문서3개, 필수 위키7개, 이 요약 및 `.gitattributes`의 선택 경로 bytes 보존 규칙이다. 전체48모듈 구현, 미공개 역사 폴더, 아트 이미지, 워크플로우 스킬/정책/도구 변경은 포함하지 않는다. 필수 위키5페이지와 knowledge 5설정/modelRoutingProfilePath를 유지하며 문서 검사기의 의미 게이트는 변경하지 않았다. 현재 로컬 mandatory workflow overlay는 공개 checkout의 이전 baseline과 구분한다.

아래17개 SHA-256은 독립 검증한 후보를 원본에 정확히 join한 뒤 root의 postjoin evidence에서 확인한 bytes다. 이번 공개 문서 정리 중 코드·테스트·launcher bytes는 변경하지 않았다. 직접 검사는 저장소 루트에서 `& 'C:\Program Files\LOVE\lovec.exe' . --test`, smoke는 `.\run-game.cmd --smoke`, 위키는 `python -B defense-roguelike-wiki/check_docs.py`로 실행한다. 테스트의 메모리 저장과 별도 smoke identity를 사용한다.

| 런타임 파일 | SHA-256 |
| --- | --- |
| [conf.lua](../../../conf.lua) | `843e97206bee87bc16cbb5fc41d9ef617b9e9369708076e0c01587451fe78dc9` |
| [main.lua](../../../main.lua) | `eba6b5591cfdebdc81a7710d7f1d1f8acb03a548bc440da76346fc3dc479bdea` |
| [run-game.cmd](../../../run-game.cmd) | `cf21e64ba83df9580b21fd68cc834f5e38ec888a08a60b4888cc2c73b56c9884` |
| [src/battle.lua](../../../src/battle.lua) | `83ac150e0e932e593bb24c57c247d6de31d5a71563e86eecf55b2a1a9c3d01e2` |
| [src/content.lua](../../../src/content.lua) | `eab326588d9c6c99bd873902b61d8036ab766e71d60bcb6fabe3f9edbaf4073d` |
| [src/game.lua](../../../src/game.lua) | `fc5ccf4676eadc871fac51bd88be51da587294cfda13d4f771df570246b208f8` |
| [src/input.lua](../../../src/input.lua) | `29638a56d9666c6098530243805397899d03dd5d8e4ad1ddf76df9bb7c1e062e` |
| [src/json.lua](../../../src/json.lua) | `4156e9a99136b6d1c14c48905c8eb3ba61ec797fb654f85f151c5a5d1306a289` |
| [src/rng.lua](../../../src/rng.lua) | `dd0df4d7c9c36acf8a63bb3f54a583a3af655c8a45470d6e3f85c77bd9c2fb56` |
| [src/rules.lua](../../../src/rules.lua) | `d4edd5c1330f4a111e705e700f3872800d10928b81a82ee2fec01fc4727de81b` |
| [src/save.lua](../../../src/save.lua) | `f9142ac476db8bb749e554785170e38b257dfc9ca4737ffed4a8058e9a3de3b5` |
| [src/session.lua](../../../src/session.lua) | `658422dabbd06739cdf564bb4b449a7880e36c023bd900b6ab6c7bf264ac5ee1` |
| [src/shop.lua](../../../src/shop.lua) | `644213921a82d2e9f82c1e16a0f65d064a7d167352bf13b626f22471a616acc4` |
| [src/view.lua](../../../src/view.lua) | `28b1b89a5568fc3aa6f9a2ba9d5303767f4bbb2ca84439530157ff7783cc51be` |
| [tests/core_spec.lua](../../../tests/core_spec.lua) | `0779fd5ab73ea5399effd66e202d67b63da6111b4d35507e17d8d89f4b469fa8` |
| [tests/integration_spec.lua](../../../tests/integration_spec.lua) | `550be80e020f2e097d04961a9c975889613f1c72dccbfabbee1f47e810f7cb97` |
| [tests/session_spec.lua](../../../tests/session_spec.lua) | `51f21738fbba9fc6088acb4fab2dcbc7827cfa93679d458a72bb850ec11f9ee8` |
