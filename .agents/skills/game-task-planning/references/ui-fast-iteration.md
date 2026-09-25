# 빠른 화면 초안과 영향 범위별 수정

실제 화면을 본 뒤 수정하는 비용을 줄일 때 적용한다. 스타일·템플릿 선택이 모두 끝나기 전에 알려진 실제 내용으로 화면을 조립하고, 수정 가능한 원본을 정식 산출물까지 이어간다. 기존 UI 결정 권한과 필수 검증은 [UI 연결 계약](ui-adapter.md)을 따른다.

## 초기 화면 초안

- game-ui-screen-spec은 승인된 스타일이 없어도 출처가 있는 내용·대상 크기·주요 상태를 먼저 정리할 수 있다. 시각 선택과 binding은 OPEN으로 남긴다. 새 과업/정보 구조가 있는 초안에는 game-ui-ux-design의 간결한 잠정 과업·흐름 framing을 함께 사용한다. game-ui-mockup은 이 기록을 받아 `EXPLORATORY — NOT APPROVED` 화면 초안을 만든다. 이 경로에는 전체 스타일 선택·컴포넌트 템플릿 승인·정식 UX/screen-spec 승인이 선행 조건이 아니다.
- 실제 문구와 데이터 형식, 알려진 target 크기와 주요 상태를 사용한다. 상태 선택기는 검토 도구임을 표시하며 제품의 전환·입력 동작을 증명하지 않는다. 필요한 내용·target·상태 자체가 없으면 그 범위만 OPEN/BLOCKED로 반환하고 확인 가능한 범위만 조립한다. 누락을 가짜 문구·상태·게임 규칙으로 메우지 않는다.
- 재사용 가능한 기존 표현을 우선 쓰고, 미정 스타일·배치·가족은 임시 표현임을 표시한다. 이는 제안이며 catalog reuse, 보호 속성 변경 승인 또는 완성된 시각 방향으로 주장하지 않는다. 전체 선택을 기다리거나 모든 조합을 만들지 말고, 현재 수정 판단에 필요한 화면·상태만 보여준다. 가족별 선택 증거가 필요한 경우 해당 기존 계약을 따른다.
- 초안 기록은 기존 작업 기록에 원본/실행·재현 방법, 입력 출처와 revision, 화면·target·상태 범위, 미정 선택/임시 표현, 변경점/다음 소유자를 남기면 된다. 정식 Mockup candidate packet이나 READY/MATCH를 채우기 위한 가짜 증거를 만들지 않는다. 초안 판단은 초안 범위로 독립 확인하며 정식 fidelity/runtime 검증으로 보고하지 않는다.

## 수정 가능한 원본과 인계

컴포넌트 표현, 스타일 값, 실제 내용과 state fixtures를 분리해 한 값이나 가족을 바꾸면 해당 초안에 반영되게 한다. 기존 프로젝트 도구/구조를 사용하며 새 프레임워크·설치·공용 디자인 시스템을 의무화하지 않는다. 초안과 정식 시안 모두 검토용 compositor/layout source 작성·수정을 허용한다. 정식 시안의 간격 수정도 이 원본에서 처리하고 새 composite를 고정한다. 제품 scene/input 코드 구현 권한은 아니다.

호환되면 preview와 runtime이 같은 승인된 컴포넌트 원본·스타일 값·fixtures를 소비하도록 인계한다. 검토용 selector와 제품 입력/데이터 연결은 분리한다. renderer/엔진 차이로 직접 재사용할 수 없으면 source locator/revision과 대응 runtime 값·adapter, 단위/폰트/배치/상태 차이 및 검증할 차이만 기존 handoff의 관련 슬롯에 기록한다. 이때 preview는 시각 의도, 제품 runtime은 실제 동작 증거라는 역할과 비교 가능한 속성·허용 차이를 먼저 정한다. 다른 renderer의 픽셀 일치나 preview의 정지 화면으로 제품 모션 합격을 요구하지 않는다. 엔진이 아직 없으면 mapping을 OPEN으로 둔다. 초안 source 재사용은 catalog 승인·asset readiness·runtime 검증을 대체하지 않는다.

초안을 정식 후보로 전환할 때는 미정 선택을 권한에 따라 해소하고 screen-spec·component·mockup 원래 필수 계약을 충족한다. 수정 가능한 원본을 버리고 다시 제작할 필요는 없다. 원본 revision에서 정식 composite를 재현해 immutable 경로/hash로 고정하며, 승인된 snapshot은 덮어쓰지 않는다. handoff는 이 source와 runtime 재사용/mapping을 연결하고 implementation은 승인된 범위에서 이를 소비한다.

## 실제 영향으로 수정 경로 선택

수정 전 바뀌는 속성, 그 속성의 소유자와 실제 소비 화면·상태·target을 찾는다. 아래는 기본 경로이며 크기나 이름만으로 영향 범위를 축소하지 않는다.

| 요청/영향 | 소유자와 최소 확인 |
| --- | --- |
| 색·여백·폰트 등 스타일 값 | 값의 소유자가 수정. 공유/보호 속성이면 component-system, 화면 소유 값이면 screen-spec/handoff, 선택 자체가 바뀌면 art-direction으로 반환. 실제 소비 화면·상태의 대비/텍스트 핏/배치/입력 영역 등 영향받은 기준만 확인 |
| 컴포넌트 외형·공유 상태 표현 | component-system이 해당 가족/버전·템플릿을 수정. 소비자 목록과 상태를 따라 catalog fingerprint, 관련 composite/binding/asset readiness를 갱신하고 해당 보호 속성과 상태를 검증 |
| 화면 배치 | screen-spec/handoff가 해당 화면의 배치·responsive 규칙을 수정하고 mockup 원본에 반영. 영향 target, 내용 경계와 hit 영역을 확인 |
| 의미·동작·구조 | screen-spec과 해당 제품/입력/규칙/세션 소유자로 반환. 바뀐 명세·상태·회귀 기준을 확정한 뒤 영향 구현과 runtime 검증을 수행 |

초안은 같은 source에서 수정·비교한다. 정식 산출물도 바뀐 가족·화면·상태의 증거만 다시 만들며, 작은 수정에 전체 시안 재제작·모든 선택 재승인·전체 구현을 요구하지 않는다. 정식 시안의 제품 반영은 기존 승인·asset/implementation 준비 조건이 충족된 뒤 implementation 소유자가 수행한다. 별도 playable functional interface 모드의 임시 제품 UI는 승인된 기능·입력 계약과 실제 runtime 기능 검증을 따르며 이 탐색 시안을 제품으로 승격하는 경로가 아니다. 시각 조정도 사용자가 직접 남긴 승인 조건은 그대로 지킨다.

현재 revision/hash와 변경→소비자→영향 기준/증거를 기존 기록에 연결한다. 공통 값이 여러 화면에 쓰이면 그 소비 범위를 확인하고, 재사용할 근거는 변경에 영향받지 않았음을 설명한다. hash가 바뀐 artifact의 옛 MATCH/READY를 새 것으로 복사하지 않는다. 영향 없는 결정을 유지하면서 변경된 downstream lock/matrix를 현재 identity로 재연결하고 해당 증거를 재검증한다. 기존 packet의 영향 슬롯/행만 갱신하고, 변경 없는 packet 전체를 재작성하거나 새로운 승인 단계를 만들지 않는다. runtime 변경이 있으면 현재 build의 영향 화면·상태에서 runtime-validation/독립 수용을 거친다. 초안 캡처나 문서 검사는 게임 동작·수정 속도 개선 실측이 아니다.

## 부분 변경의 runtime 증거

전체 승인 coverage map과 필수 행은 유지한다. 현재 후보를 고정하고, 기존 packet의 evidence IDs에 연결되는 작은 적용 기록을 둔다. 각 coverage 관측 키/속성 범위마다 현재 후보 fingerprint, `CURRENT` 또는 `HISTORICAL_REUSE`, raw evidence ID와 원래 capture build/hash/environment/fixture, 비교 근거와 독립 검증자 판정을 기록한다. matrix에는 raw ID만 넣고 이 기록을 packet의 증거 충분성/lock 슬롯에서 연결한다. 별도 schema나 승인 단계를 만들지 않는다.

- `CURRENT`: 고정된 현재 후보에서 실제 재관측한 증거. raw manifest와 현재 fingerprint가 일치해야 한다.
- `HISTORICAL_REUSE`: 이전에 수용된 baseline의 실제 runtime 증거로, 원래 fingerprint와 파일을 그대로 보존한다. 구현 작성자와 별도 검증자가 baseline→현재 source/의존성 차이, renderer·font·asset·입력·동작을 포함한 관련 공통 의존, 환경/설정, fixture/내용/target 및 승인 계약을 비교해 해당 관측과 모든 주장 속성이 영향받지 않음을 근거 locator/hash로 확인해야 한다. 단순 파일명/불변 주장/이전 PASS는 근거가 아니다. 검증되지 않은 baseline, 누락 raw evidence, 추적 불가능한 의존 또는 불명확한 영향은 재사용하지 않는다.

현재 build를 적는 runtime/acceptance matrix 행은 현재 후보에 대한 적용 판정이며 모든 raw capture가 현재 build에서 생성됐다는 뜻이 아니다. `VERIFIED`는 필수 adapter/속성/state/target의 실제 runtime 증거가 CURRENT 또는 검증된 HISTORICAL_REUSE로 빠짐없이 뒷받침될 때만 허용한다. acceptance reviewer는 동일 기록을 독립 확인하고 critical/high-risk 범위를 현재 후보에서 재현한다. runtime 결정과 acceptance 결정은 현재 후보 fingerprint에 새로 연결하며 과거 승인/판정을 복사하지 않는다.

공유 font/renderer/style/입력/동작 변경은 실제 소비 범위의 재사용 근거를 무효화한다. 영향 범위가 불명확하면 재관측을 확대하며, baseline 또는 비교 근거가 없으면 필요한 전체 범위를 현재 runtime에서 관측한다. 변경 화면을 담은 과거 전체 화면 캡처는 그 화면의 현재 composition 증거로 재사용할 수 없다. 한 상태의 국소 변경에서 다른 상태의 의존 불변이 입증되면 그 다른 상태만 재사용할 수 있다. 바뀐 속성/상태/전체 화면 비교와 영향 target은 현재 관측으로 확인한다.

후보 fingerprint가 다시 바뀌면 현재 적용 판정을 무효화하고 다시 비교한다. 역사적 raw 증거 자체를 삭제하거나 새 fingerprint로 고쳐 쓰지 않는다. packet은 현재 재관측 범위, 검증된 역사적 재사용 범위, 남은 BLOCKED를 구분해 보고한다. 혼합 증거를 전체 현재 build 재실행으로 표현하거나 coverage를 줄여 통과시키지 않는다.
