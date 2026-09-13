# Testing — Giftmap

현재 저장소의 테스트 구성과 검증 절차를 기술한다.
`flutter_test`만 사용하며 테스트용 패키지를 추가하지 않는다.

## 1. 테스트 전략

| 계층 | 무엇을 검증하나 | 위치 |
|---|---|---|
| Unit (도메인/데이터) | 점수 규칙, 결정론, JSON 스키마, 파서, 정책 | `test/features/**`, `test/core/**` |
| Unit (상태) | 컨트롤러 단계 전환, 폴백, 중복 제출, dispose 안전성 | `test/features/gift_finder/gift_finder_controller_test.dart` |
| Widget (부품) | nullable 가격 표시, 적합도·위험도 표기 | `test/features/gift_finder/recommendation_visuals_test.dart` |
| Widget (흐름) | 실제 앱을 띄운 화면 간 이동과 상태 | `test/widget_test.dart`, `test/app_flows_test.dart` |

원칙:

- 추천 규칙은 **실제 번들 JSON**으로 검증한다. 별도 fixture 데이터를 만들지 않는다
  (`test/fixtures/ruleset_fixture.dart`가 `lib/data/*.json`을 직접 읽는다).
- 화면 테스트는 공용 하네스(`test/helpers/app_harness.dart`)를 통해 앱을 부팅한다.
- 테스트는 네트워크를 쓰지 않는다. 앱 자체에 네트워크 코드가 없다.

## 2. 현재 테스트 구성 (총 108개)

| 파일 | 개수 | 범위 |
|---|---:|---|
| `features/gift_finder/local_recommendation_engine_test.dart` | 12 | 카테고리 점수·제외·결정론·보충 |
| `features/gift_finder/product_recommendation_engine_test.dart` | 12 | 상품 점수·예산·회피·결정론·fallback |
| `features/products/product_catalog_test.dart` | 12 | 카탈로그 검증·검색·필터·정렬·큐레이션 |
| `features/library/library_stores_test.dart` | 13 | 찜·최근 본 상품·중복·상한·persistence |
| `features/gift_finder/gift_finder_controller_test.dart` | 10 | 입력 검증·제출·폴백·슬롯 교체·재사용 |
| `features/gift_finder/bundled_category_data_source_test.dart` | 6 | JSON 스키마·손상 데이터·안전 기본값 |
| `features/gift_finder/local_intent_parser_test.dart` | 5 | 키워드 파싱·신뢰도·결정론 |
| `features/products/product_card_test.dart` | 5 | 가격·할인 표기·상품 비주얼·데모 배지 |
| `features/history/history_store_test.dart` | 6 | 저장·삭제·필터·요약 |
| `features/anniversary/anniversary_store_test.dart` | 6 | 등록·정렬·D-day·삭제 |
| `core/affiliate_link_policy_test.dart` | 6 | https·allowlist·고지·미지원 결과 |
| `core/config/supabase_config_test.dart` | 6 | 설정 유무 판정·service_role 키 차단 |
| `features/products/remote_first_product_data_source_test.dart` | 4 | 원격 우선·실패/빈 결과/타임아웃 fallback |
| `widget_test.dart` | 5 | 홈 큐레이션·위저드 5단계·상품 상세·텍스트 확대·터치 영역 |
| `commerce_flows_test.dart` | 7 | 검색·빈 결과·찜·최근 본 상품·보관함·추천 기록 |
| `app_flows_test.dart` | 4 | 기록 삭제 확인·기념일·전체 삭제·문의 |

## 3. 상품 추천 검증 항목

- **결정론**: 같은 `GiftIntent`는 항상 같은 상품과 같은 순서
- **점수 범위**: 모든 상황에서 `0..100`
- **avoidTags 제외**: 회피 태그를 가진 상품이 결과에 없다
- **risk penalty / avoid 제외**: 상사 + 개인 관리 제품 조합은 추천되지 않는다
- **예산**: 예산을 넘는 상품은 예산 점수를 거의 받지 못하고, `budgetFit`은 항상 `0..25`
- **상황·관계 일치**: 맞는 상품이 맞지 않는 상품보다 높은 점수를 받는다
- **fallback**: 조건이 좁아도 최소 3개를 채운다. 카탈로그가 비면 빈 목록을 돌려준다
- **표시 데이터**: 모든 추천에 배지와 이유 문구가 있다

## 4. 상품 카탈로그·검색 검증 항목

- 상품 30개 이상, 카테고리 10개 이상
- 모든 상품이 `isDemo`이고 가격·이름·브랜드·설명이 비어 있지 않다
- 할인 상품은 정가 > 판매가, 할인율 > 0
- 키워드 검색, 대소문자·공백 무시, 결과 없음
- 카테고리 필터, 가격 구간 필터, 정렬(낮은 가격/높은 가격)
- 같은 검색어는 항상 같은 순서
- 없는 id는 조용히 무시

## 5. 찜 / 최근 본 상품 검증 항목

- 찜: 추가·해제·`contains`·중복 방지·최신 우선·전체 삭제
- 최근 본 상품: 상세 진입 시 추가·중복 제거·최신순·최대 개수 제한·개별/전체 삭제
- 둘 다 저장소를 다시 읽어도 유지(persistence)

## 6. 카테고리 추천 엔진 검증 항목

- **점수 범위**: 모든 상황 × 관계 × 카테고리 조합에서 점수가 `0..100`
- **avoidTags 제외**: 회피 태그를 지정하면 해당 태그를 가진 카테고리가 결과에 없다
- **risk penalty**: 관계가 멀어지면(향 규칙 적용) 같은 카테고리의 점수가 낮아지고
  `caution` 문구와 `riskLevel`이 함께 남는다
- **avoid 제외**: 상사 + 개인 관리 제품처럼 `avoid` 규칙이 걸린 카테고리는 결과에 오르지 않는다
- **deterministic ordering**: 같은 `GiftIntent`를 두 번 계산하면 순서까지 동일하다
- **입력 민감도**: 조건이 달라지면 추천 순서가 실제로 달라진다
- **정확히 3개**: 결과는 항상 서로 다른 카테고리 3개
- **fallback 보충**: 후보가 줄어드는 조건에서도 `safeDefault`로 3개를 채운다
- **nullable price**: `priceAvailable=false`인 카테고리는 가격 3종이 모두 `null`
- **budget fit**: 예산이 맞을수록 점수가 높고 항상 `0..15`
- **검색어**: 항목마다 2~3개이며 빈 문자열이 없다

## 7. 컨트롤러 검증 항목

- 필수 조건(상황·관계·예산)이 모두 있어야 `canSubmit`
- 직접 입력 예산은 1,000원~10,000,000원 밖이면 오류 문구를 반환
- 단계 이동은 `0..3`을 벗어나지 않음
- 정상 제출 시 결과 3개 + 기록 콜백 1회 호출
- 저장소가 예외를 던지면 로컬 엔진 결과(`usedFallback=true`)로 완결
- 저장소가 응답하지 않으면 로컬 안전장치가 동작해 역시 로컬 결과로 완결
  (네트워크 타임아웃이 아니라 로컬 가드다)
- 분석 중 중복 제출은 무시
- `dispose` 이후에는 `notifyListeners`가 호출되지 않음
- "다른 후보"는 한 슬롯만 바꾸고 나머지는 유지하며 중복이 생기지 않음

## 8. 위젯/흐름 검증 항목

**하단 내비게이션** — 5개 탭(홈·카테고리·선물추천·찜·기록)이 있고 검색 탭은 없다.
각 탭으로 이동하면 해당 화면이 뜬다.

**카테고리** — 상위 그룹을 고르면 상품 수가 바뀌고, "전체"로 되돌릴 수 있다.
화면에 표시되는 개수는 카탈로그가 돌려준 목록 길이와 일치한다.

**캐러셀** — 첫 페이지에서 이전 버튼이 비활성이고, 다음 버튼/스와이프로 이동하면
이전 버튼이 활성화된다(스와이프와 버튼 상태가 동기화된다).

**긴 텍스트·null** — 상품명 2줄/브랜드 1줄 말줄임, 가격 없음("가격 확인 필요"),
브랜드 없음(카테고리 이름 대체), 이미지 없음(로컬 비주얼), productUrl 없음(CTA 비활성).

**상품 수 변화** — 0개·1개·다수에서 모두 예외 없이 렌더링된다.

**핵심 흐름** — Home → 선물추천(5단계) → Analyzing → Result → Product Detail

- 홈에 상품 카드(`ProductTileCard`)가 노출된다(텍스트 목록이 아니다)
- 위저드는 `01 / 05` 진행 표시와 단계별 제목을 보여준다
- 결과 화면에 "이런 선물을 추천해요"와 상품 그리드(`ProductGridCard`)가 있다
- 상품 상세에 추천 이유와 참고사항이 있고, "상품 보러가기"는 데모 상태로
  **비활성(`onPressed == null`)**이며 이유 문구가 함께 보인다

**Search** — 검색 진입 → 추천 검색어 → 키워드 검색 → 결과 그리드 → 상세.
결과가 없으면 빈 상태와 추천 검색어를 보여준다

**찜 / 최근 본 상품** — 카드에서 찜하면 찜 탭에 모이고, 해제하면 즉시 비워진다.
같은 상품을 다시 찜해도 중복되지 않는다. 상세를 열면 기록 탭의 "최근 본 상품"에 쌓인다

**기록 탭** — 최근 본 상품·추천 기록 두 세그먼트만 있고 검색 기록은 없다.
추천 기록에는 당시 5단계 조건 요약과 추천 방향이 함께 남는다

**홈** — 검색창이 하나이고 최근 본 상품 섹션이 없다

**History** — 추천 완료 후 보관함의 추천 기록에 항목이 생기고, 상세에서
"이 조건으로 다시 추천"이 결과를 다시 만들며, 삭제는 확인 다이얼로그에서 취소/확정이 모두 동작한다

**Anniversary** — 기념일을 추가하면 목록에 나타나고, 확인 다이얼로그를 거쳐 삭제된다

**Settings** — "데이터 전체 삭제"가 확인 후 기록을 비운다

**접근성** — 텍스트 배율 1.3배에서 예외 없이 렌더링되고, 주요 CTA 높이가 48dp 이상이다

## 9. 위젯 테스트 작성 시 주의점

이 저장소에서 실제로 겪은 함정이므로 새 테스트를 쓸 때 참고한다.

1. **부팅은 `bootApp()`을 쓴다.** `rootBundle`은 테스트 사이에 Future를 캐시해
   두 번째 테스트부터 부팅이 끝나지 않는다. 하네스는 번들 대신
   `FixtureCategoryDataSource`를 주입한다.
2. **Splash가 사라질 때까지 `pump`한 뒤** `pumpAndSettle`을 호출한다.
   스플래시의 원형 인디케이터는 무한 애니메이션이라 그대로 `pumpAndSettle`하면 타임아웃된다.
3. **`Scrollable`은 여러 개다.** `IndexedStack`이 3탭을 모두 만들고 화면 안에
   스크롤되지 않는 내부 `GridView`도 있으므로 `scrollUntilVisible`이 실패한다.
   `scrollHome()` / `scrollLastList()`를 쓴다. `scrollLastList()`는 실제로 스크롤 여지가 있는
   마지막 `Scrollable`을 골라서 끈다.
4. 바텀시트·긴 폼의 버튼은 화면 밖에 있을 수 있으므로 탭 전에 스크롤한다.

## 10. Integration test

`integration_test` 패키지가 `pubspec.yaml`에 없고 현재 단계에서는 dependency를 추가하지 않으므로
`integration_test/` 디렉터리는 존재하지 않는다.
그 자리를 `test/widget_test.dart`와 `test/app_flows_test.dart`의 흐름 테스트가 대신한다.
패키지 추가가 승인되면 동일한 시나리오를 실기기 통합 테스트로 승격한다.

## 11. 검증 명령

작업 단위마다:

```bash
dart format lib test
flutter analyze
flutter test <관련 파일>
```

최종:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

기준: 포맷 변경 없음, analyze 이슈 0, 테스트 전부 통과.
실패를 남긴 채 다음 기능으로 넘어가지 않는다.
테스트를 삭제하거나 주석 처리해 통과시키지 않는다.

## 11-1. Supabase 연동 검증

- 단위 테스트는 네트워크를 쓰지 않는다. `SupabaseProductDataSource`는 실제 연결이
  필요하므로 자동 테스트 대상이 아니며, 대신 fallback 경로를 전부 검증한다.
- 테스트 환경에는 `--dart-define` 값이 없으므로 `SupabaseConfig.fromEnvironment()`는
  항상 미설정 상태다. 즉 `flutter test`는 늘 번들 Mock 데이터로 돈다.
- 실제 원격 연결은 `docs/SUPABASE_SETUP.md`의 7절(연결 확인)로 수동 검증한다.

## 11-2. 수집기 검증

수집기는 Flutter 테스트와 분리되어 있다.

```bash
cd crawler
npm test                                       # 추출·정규화·robots 규칙 (네트워크 없음)
node src/index.js --source 10x10 --limit 5 --dry-run   # 실제 공급원에서 수집만 확인
```

- `npm test`는 네트워크를 쓰지 않는다. JSON-LD 추출, 가격이 없을 때 `null` 유지,
  `is_demo = false` 표시, 같은 입력이 같은 id를 만드는지, robots 허용 판단을 확인한다.
- `--dry-run`은 Supabase에 쓰지 않고 `crawler/out/<source>.json`에만 남긴다.
- 앱 쪽 수집 상품 동작은 `test/features/products/collected_product_test.dart`에서
  네트워크 없이 검증한다(CTA 활성 조건, 이미지 fallback).

## 11-3. 실제 상품 모드 검증

- `test/features/products/real_product_mode_test.dart`: 원격 실패 시 데모로 덮지 않고
  재시도 화면을 띄우는지, 다시 시도가 실제로 재요청하는지.
- `test/features/products/paged_product_grid_test.dart`: 상품이 많을 때 나눠 보여 주고
  스크롤이 끝에 닿으면 이어 붙는지.
- `test/features/gift_finder/ai_recommendation_test.dart`: 서버가 돌려준 id 중
  카탈로그에 실제로 있는 상품만 남기는지, 3개 미만이면 로컬 엔진에 맡기는지.
- 이 테스트들은 네트워크를 쓰지 않는다. `--dart-define` 값이 없으므로
  `flutter test`는 항상 데모 모드(번들 데이터)로 돈다.

## 11-4. 홈 구성 검증

- `test/features/products/catalog_mix_test.dart`: 한 출처·분류가 홈을 뒤덮지 않는지,
  같은 카탈로그면 항상 같은 순서가 나오는지.

## 12. 수동 확인 (에뮬레이터)

자동 검증 후 Android API 24 에뮬레이터에서 다음을 확인한다.

0. 320×568 / 360×800 / 390×844 / 412×915 / 태블릿 폭에서 홈·결과 화면 오버플로 확인
1. 홈 → 선물추천 5단계 → 추천 상품 그리드 → 상품 상세
2. 검색 → 필터·정렬 → 상품 상세 → 뒤로가기
3. 상품 찜 → 보관함 "찜한 상품" 확인 → 앱 재시작 후에도 유지되는지
4. 상품 상세 진입 → 보관함 "최근 본 상품" 확인
5. 보관함 추천 기록에서 재추천·삭제
6. 기념일 추가·삭제, 설정에서 데이터 전체 삭제
7. 비행기 모드에서 1~2번 흐름이 동일하게 완주되는지 (모든 계산이 로컬)
8. 시스템 글꼴 크기를 키운 상태에서 상품 카드가 깨지지 않는지
9. Supabase 연결 상태(실제 상품 모드)에서
   - 목록에 DEMO 배지가 붙은 상품이 하나도 없는지
   - 상품 상세의 "상품 보러 가기"가 원본 판매 페이지를 여는지
   - 목록을 계속 내리면 상품이 이어 붙는지
   - 비행기 모드로 앱을 다시 켰을 때 재시도 화면이 뜨는지(데모로 대체되지 않는지)
