# Architecture — Giftmap

현재 저장소의 실제 구조를 기술한다. 네트워크·서버·외부 AI 코드는 존재하지 않는다.

## 1. 기술 스택

- Flutter 3.47.2 (stable) / Dart 3.13.2 / Material 3 / Android API 24+
- dependencies: `flutter`, `cupertino_icons`, `shared_preferences`(찜·최근 본 상품 로컬 저장)
- dev_dependencies: `flutter_test`, `flutter_lints`
- 상태관리·라우팅·네트워크 패키지 **없음**, code generation **없음**

## 2. 디렉터리 구조

```
lib/
├── main.dart                     runApp(GiftmapApp())
├── app/
│   ├── giftmap_app.dart          부트스트랩, 의존성 조립, MaterialApp
│   ├── app_scope.dart            AppDependencies + InheritedWidget
│   ├── app_shell.dart            ShellTabController + 3탭 IndexedStack
│   └── app_router.dart           MaterialPageRoute 생성 지점
├── core/
│   ├── theme/                    colors, spacing, text styles, theme
│   ├── widgets/                  selectable_chip, section_header,
│   │                             bottom_action_bar, empty_state_view, rounded_surface
│   ├── affiliate/                affiliate_link_policy.dart
│   ├── analytics/                analytics_event.dart (인메모리 수집)
│   ├── errors/                   app_failure.dart (sealed)
│   └── utils/                    currency_format, date_format
├── data/                         gift_categories.json / risk_rules.json /
│                                 search_queries.json / products.json
└── features/
    ├── splash/presentation
    ├── home/{presentation,widgets}
    ├── search/presentation
    ├── products/{domain,data,presentation}
    ├── library/{domain,data,application,presentation}
    ├── gift_finder/{domain,data,application,presentation}
    ├── history/{domain,data,application,presentation}
    ├── anniversary/{domain,data,application,presentation}
    └── settings/presentation
```

## 3. feature-first 원칙

각 feature는 아래 4계층 중 필요한 것만 갖는다.

| 계층 | 역할 | 예 |
|---|---|---|
| domain | 모델·enum·저장소 계약. Flutter 위젯에 의존하지 않는다 | `gift_intent.dart`, `recommendation_repository.dart` |
| data | 계약 구현, 번들 데이터 해석, 점수 계산 | `local_recommendation_engine.dart` |
| application | 화면이 구독하는 상태(`ChangeNotifier`) | `gift_finder_controller.dart` |
| presentation | 화면과 위젯. 상태를 읽고 이벤트만 전달 | `result_screen.dart` |

의존 방향: presentation → application → domain, data → domain.
**presentation에서 점수 계산이나 비즈니스 규칙을 수행하지 않는다.**
feature 간 직접 의존 대신 콜백(`SessionCompleted`)이나 `AppScope`를 통해 연결한다.

## 4. 화면·라우팅 구조

- 라우팅은 `Navigator` + `MaterialPageRoute`. 생성은 `AppRouter`에 모은다.
- 탭 3개(`HomeScreen`, `GiftFinderFlowScreen`, `LibraryScreen`)는 `IndexedStack`으로 유지되어
  탭을 바꿔도 진행 중 세션이 보존된다.
- 탭 전환은 `ShellTabController`(`ValueNotifier<int>`)로 하며, push된 화면에서도 요청할 수 있다.
- **`AppScope`는 `MaterialApp`보다 위에 있어야 한다.** push된 화면은 루트 Navigator에 올라가므로,
  `AppScope`가 `MaterialApp.home` 아래에 있으면 의존성을 찾지 못한다.

흐름:

```
Splash ─(부트스트랩 완료)→ AppShell
Home ─검색→ Search → ProductDetail
Home ─CTA/빠른 진입→ 선물 찾기 탭(01→02→03→04→05) → Analyzing → Result → ProductDetail
Home ─큐레이션 카드→ ProductDetail → 비슷한 상품 → ProductDetail
보관함(찜 / 최근 본 상품) → ProductDetail
보관함(추천 기록) → HistoryDetail → 재추천(Analyzing) / 삭제
Home → Anniversary → 선물 추천받기(선물 찾기 탭)
Home → Settings
```

위저드 5단계는 별도 라우트가 아니라 `GiftFinderFlowScreen` 안에서
`controller.step`으로 전환되는 단계 위젯이다(뒤로가기 시 이전 단계로 복귀).
상품 상세는 어느 경로에서 열어도 같은 화면이며, 뒤로가기는 열었던 화면으로 돌아온다.

## 5. Domain model

| 모델 | 설명 |
|---|---|
| `GiftIntent` | 확정된 사용자 입력. `budgetRange`, `budgetLabel` 등 표시용 파생값 포함 |
| `GiftCategory` | 번들 JSON에서 읽은 카테고리. `fromJson`이 스키마를 검증한다 |
| `RiskRule` | 태그·관계·상황 조합에 대한 위험 규칙과 패널티 |
| `GiftRuleset` | 카테고리 + 규칙 + 검색어 템플릿 묶음, 버전과 가격 고지 포함 |
| `GiftRecommendation` | 결과 1건. nullable 가격 3종과 `priceAvailable` 보유 |
| `RecommendationResult` | 결과 3개 + 예비 후보 + `usedFallback` + 생성 시각 |
| `HistoryEntry` | 생성일 + `GiftIntent` + `RecommendationResult` |
| `Anniversary` | 이름·관계·종류·날짜, `daysUntil`/`dDayLabel` |
| `Product` | 상품 1건. 브랜드·가격·할인·태그·상황·관계·연령·데모 표시 |
| `ProductCatalog` | 상품 목록과 검색·필터·정렬·큐레이션 (전부 결정론적) |
| `ProductPick` | 추천된 상품 + 점수 + 위험도 + 배지 + 이유 |

Null 규칙: 가격 근거가 없으면 `priceAvailable=false`이고 가격 필드는 모두 `null`이다.
UI는 `null`을 0원으로 변환하지 않는다.

## 6. Repository abstraction

```dart
abstract interface class RecommendationRepository {
  Future<RecommendationResult> recommend(GiftIntent intent);
}
```

- 현재 구현체는 `MockRecommendationRepository`(로컬 엔진 위임) 하나뿐이다.
- `RemoteRecommendationDataSource`는 **계약만 선언**되어 있고 구현·연결하지 않는다.
- `HistoryRepository`, `AnniversaryRepository`, `CategoryDataSource`, `ProductDataSource`,
  `IdListStorage`도 같은 방식의 계약이며, 현재 구현체는 각각 `InMemoryHistoryRepository`,
  `InMemoryAnniversaryRepository`, `BundledCategoryDataSource`, `BundledProductDataSource`,
  `PrefsIdListStorage`(테스트는 `InMemoryIdListStorage`)다.

## 7. Local recommendation engine

`LocalRecommendationEngine`이 유일한 점수 계산 지점이다.

```
score = 40
      + (상황 일치 ? 20 : 0)
      + (관계 일치 ? 15 : 0)
      + budgetFit(0..15)
      + round(10 * (1 - |intent.preference - category.preference|))
      - riskPenalty(0..50)
      → clamp(0, 100)
```

- `budgetFit`: 중앙값이 예산 구간 안이면 15, 구간이 겹치면 4~9, 30% 이내 근접이면 2, 아니면 0
- 회피 태그와 겹치는 카테고리, 위험도 `avoid` 카테고리는 후보에서 제외
- 정렬은 점수 내림차순 → `categoryId` 오름차순 (**결정론적**)
- 상위 그룹(`group`)당 1개만 선택해 다양성 확보
- 3개 미만이면 `safeDefault` → 남은 후보 순으로 보충
- 선택되지 않은 후보는 `alternates`로 남아 "다른 후보" 교체에 쓰인다
- 검색어는 카테고리 기본 검색어 + 템플릿 치환에서 중복을 제거해 최대 3개

`LocalIntentParser`는 외부 AI 없이 키워드 맵과 정규식으로 조건을 뽑고 `confidence`를 매긴다.
0.7 미만은 확정값으로 쓰지 않고 사용자에게 되묻는다.

## 7-2. Product recommendation engine

`ProductRecommendationEngine`이 사용자에게 보이는 결과를 만든다.

```
score = 30
      + (상황 일치 ? 25 : 0)
      + (관계 일치 ? 20 : 0)
      + budgetFit(0..25)          예산 초과 시 크게 감점
      + round(10 * (1 - |intent.preference - 태그로 추정한 상품 성향|))
      + (연령 일치 ? 5 : 0)
      + directionBonus(0..12)     카테고리 방향 1/2/3위 = 12/8/5
      - riskPenalty(0..50)
      → clamp(0, 100)
```

- 회피 태그와 겹치는 상품, 위험도 `avoid` 상품은 후보에서 제외
- 정렬은 점수 내림차순 → **상품 id 오름차순**(결정론적)
- 결과가 3개 미만이면 예산에 맞는 안전한 상품으로 보충
- 카테고리 → 상품 카테고리 연결은 `directionMap` 하나로 관리한다
- 위험 규칙은 카테고리와 상품이 같은 태그 어휘를 쓰므로 `RiskRule.matchesTags`를 공유한다

## 8. Mock data

- `lib/data/gift_categories.json` — 현재 8개 카테고리
  (홈 프래그런스, 티웨어·차 세트, 데스크 액세서리, 프리미엄 타월, 핸드 케어, 모바일 액세서리,
  경험 이용권, 화분·플랜테리어)
- `lib/data/risk_rules.json` — 위험 규칙 6개
- `lib/data/search_queries.json` — 검색어 템플릿
- 세 파일은 `pubspec.yaml`의 `flutter: assets:`에 등록되어 있다.
- 가격은 Demo 시세이며 `priceDisclaimer`가 함께 배포된다.
  `experience_voucher`는 시세 근거가 없어 `priceAvailable: false`다.
- 파싱 실패·데이터 손상 시 예외 대신 `safeDefaultRuleset`(안전 카테고리 3개)으로 진입한다.

## 8-2. 찜 / 최근 본 상품

- `IdListStorage`(키 → 상품 id 목록) 하나의 계약을 찜과 최근 본 상품이 공유한다.
- `FavoritesStore`는 토글·중복 방지·최신 우선 정렬을, `RecentlyViewedStore`는
  중복 제거·최신순·최대 50개 유지를 담당한다.
- 저장 실패(플러그인이 없는 환경 등)는 삼키고 메모리 상태로 계속 동작한다.

## 9. Local history / anniversary

- 두 feature 모두 `ChangeNotifier` 스토어(`HistoryStore`, `AnniversaryStore`)가
  저장소를 감싸고 화면은 `ListenableBuilder`로 구독한다.
- 저장은 **인메모리**다. 저장 패키지를 추가하지 않기로 한 현재 규칙에 따른 선택이며,
  영속화는 같은 계약(`HistoryRepository` 등)을 구현하는 방식으로 이후 단계에서 교체한다.
- 추천 완료 시 `GiftFinderController`의 `onSessionCompleted` 콜백이 기록을 저장한다.

## 10. 상태 관리 원칙

- 진행 중인 추천 세션은 `GiftFinderController` 하나가 소유한다
  (단계, 선택값, 결과, 제출 중복 방지, dispose 이후 notify 방지).
- 전역 의존성은 `AppDependencies`에 모아 `AppScope`(InheritedWidget)로 전달한다.
- 화면은 상태를 읽고 이벤트만 전달한다. 상태관리 패키지를 도입하지 않는다.
- `build` 중 상태를 바꾸지 않는다(분석 화면은 첫 프레임 이후 `submit()`을 호출한다).

## 11. 의존성 원칙

- 새 패키지를 임의로 추가하지 않는다. 특히 AI/API/서버/DB 관련 패키지는 금지.
- 패키지가 없어 기능을 완성할 수 없으면 **TODO 주석 대신 명시적 결과 타입**으로 표현한다.
  예: 외부 브라우저 실행 수단이 없으므로 `AffiliateLinkPolicy.open()`은 `LinkOpenNotSupported`를
  반환하고, 상세 시트의 상품 이동 버튼은 비활성 상태로 이유를 설명한다.
- 제휴 정책은 https·host allowlist·고지 표시를 모두 만족해야 통과한다.
  고지가 없으면 이동도 클릭 기록도 허용하지 않는다.
- 분석 이벤트는 동의 전 아무것도 기록하지 않으며 원문 검색어를 담지 않는다.

## 12. 현재 단계와 향후 API 연동 단계의 경계

| 항목 | 현재 | 이후 API 단계 |
|---|---|---|
| 추천 | `MockRecommendationRepository` → 로컬 엔진 | 같은 계약의 원격 구현 추가, 실패 시 로컬 폴백 |
| 의도 파싱 | `LocalIntentParser` | 서버 파서 + 스키마 검증, `ParsedIntent` 모양 유지 |
| 상품 | 번들 `products.json`(데모 46종) | 실제 상품 카탈로그 |
| 상품 이미지 | 카테고리별 로컬 비주얼 | 실제 상품 이미지 |
| 가격 | Demo 시세 + 고지 | 출처·관측일을 가진 evidence |
| 제휴 | 비활성 CTA(이동 없음) | 실제 딥링크 + 클릭 측정 |
| 저장 | 인메모리 | 로컬 영속화 및 마이그레이션 |
| 분석 | 인메모리, 동의 기본 false | 서버 전송 |

교체 지점은 `lib/app/giftmap_app.dart`의 `_bootstrap()` **한 곳**이다.
화면과 컨트롤러는 구현체를 알지 못하므로 수정할 필요가 없다.
현재 단계에서는 API client·서버 스텁·빈 인터페이스 구현체를 미리 만들지 않는다.
