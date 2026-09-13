# Giftmap

"누구에게 무엇을 선물해야 할지 모르겠다"는 순간에 조건을 몇 번 고르면
어울리는 선물 상품을 골라주는 모바일 앱.

현재 단계는 **API 연동 전 로컬 MVP**다. 네트워크 요청, 외부 AI, 서버, 실제 상품·제휴 연동은
포함하지 않으며 모든 추천은 기기 안에서 결정적으로 계산된다.

## 실행

```bash
flutter pub get
flutter run          # Android API 24+ · 번들 Mock 데이터로 동작

# Supabase에서 상품을 불러오려면(선택)
flutter run   --dart-define=SUPABASE_URL=https://<프로젝트>.supabase.co   --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>
```

설정 절차는 [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md)에 있다.
값을 주지 않거나 연결에 실패하면 자동으로 번들 Mock 데이터로 되돌아간다.

### 실제 상품 수집(선택)

`crawler/`는 공급원의 공개 상품 페이지에서 상품명·가격·이미지 URL·상품 URL을 읽어
Supabase에 올리는 Node.js 프로그램이다. 앱과 분리되어 있고 단독으로 실행된다.

```bash
cd crawler
npm install
npm run install:browser                       # Playwright Chromium
node src/index.js --source 10x10 --dry-run    # 수집만 확인
npm run collect                               # 수집 + Supabase upsert(.env 필요)
```

자세한 내용과 공급원 추가 방법은 [crawler/README.md](crawler/README.md)에 있다.

## 검증

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## 구조

```
lib/
├── app/            # MaterialApp, AppScope(의존성), AppShell(바텀 탭), AppRouter
├── core/           # theme, 공통 위젯, 제휴 정책, 분석 이벤트, 실패 타입, 포맷 유틸
├── data/           # 번들 JSON: 카테고리 / 위험 규칙 / 검색어 템플릿 / 상품 카탈로그
└── features/       # feature-first: home, categories, search, products,
                    #                library(찜), gift_finder, history,
                    #                anniversary, settings, splash
```

`gift_finder`는 `domain` → `data` → `application` → `presentation` 순서로 나뉜다.
점수 계산은 `LocalRecommendationEngine`에만 있고 화면은 계산하지 않는다.

## 추천 엔진

사용자에게 보이는 결과는 **상품**이다. 카테고리 방향을 먼저 정하고, 그 방향을 보너스로 반영해
상품을 점수화한다(`ProductRecommendationEngine`). 동점은 상품 id 오름차순이라
같은 입력은 항상 같은 상품·같은 순서를 만든다.

카테고리 방향(`LocalRecommendationEngine`)은 기본 40점에서 시작해 상황(0~20), 관계(0~15), 예산(0~15), 실용↔감성 거리(0~10)를 더하고
위험 규칙 패널티(0~50)를 뺀 뒤 0~100으로 제한한다.

- `avoidTags`와 겹치는 카테고리, 위험도 `avoid` 카테고리는 제외
- 상위 그룹당 1개만 골라 결과 다양성 확보
- 동점은 `categoryId` 오름차순 → 같은 입력은 항상 같은 순서
- 3개가 안 되면 `safeDefault` 카테고리로 보충
- 결과는 항상 서로 다른 카테고리 정확히 3개

## 화면 구조

하단 탭은 **홈 / 카테고리 / 선물추천 / 찜 / 기록** 5개다.
검색은 탭이 아니라 홈 최상단 검색창에서 들어간다.

- **홈**: 선물추천 배너, 상황별 빠른 시작, 큐레이션 캐러셀(스와이프 + 이전/다음 버튼)
- **카테고리**: 상위 그룹 → 세부 카테고리 → 정렬 → 반응형 상품 그리드
- **선물추천**: 상황·받는 사람·예산·느낌·피하고 싶은 것 5단계 → 상품 추천 결과
- **찜**: 저장한 상품 모아보기(앱을 다시 켜도 유지)
- **기록**: 최근 본 상품 / 추천 기록 (검색 키워드는 저장하지 않음)

## 데이터와 경계

- 카테고리 가격은 **데모 시세**이며 실시간 판매가가 아니다. UI 전반에 이 고지가 붙는다.
- 시세 근거가 없는 카테고리는 가격 필드가 `null`이고 화면에는 "가격 확인 필요"로 표시된다.
  `null`을 0원으로 표시하지 않는다.
- 번들 상품 46종은 전부 데모 데이터이며 실제 브랜드·상품이 아니다.
  화면에 DEMO 배지와 고지를 표시한다(`isDemo == true`).
- Supabase에는 `crawler/`가 수집한 실제 상품(`isDemo == false`)이 함께 들어 있다.
  실제 상품에는 DEMO 배지가 붙지 않고, 상세에서 원본 판매 페이지로 이동할 수 있다.
- 데모 상품 이미지는 외부 URL을 쓰지 않는다. asset이 없으면 카테고리별 로컬 비주얼을 그린다.
  수집한 실제 상품만 공급원이 공개한 이미지 URL을 쓰고, 불러오지 못하면 같은 비주얼로 되돌아간다.
- 찜과 최근 본 상품은 기기 로컬에 저장되어 앱을 다시 켜도 유지된다.
- 추천 기록과 기념일은 인메모리로 보관한다. 앱을 다시 켜면 비워진다.
- 상품 수·카테고리 수를 코드에 고정하지 않는다. 모든 화면이 카탈로그 길이를 따른다.
- 브랜드·가격·이미지·판매 URL이 없어도 화면이 깨지지 않는다
  (가격이 없으면 "가격 확인 필요", URL이 없으면 구매 CTA 비활성).
- 상품 상세의 단일 CTA "상품 보러 가기"는 수집한 실제 상품에서만 활성화되어
  원본 판매 페이지를 외부 브라우저로 연다. 데모 상품에서는 비활성이고 이유를 버튼 위에 설명한다.
- 자연어 검색은 외부 AI 없이 로컬 키워드 파서만 사용하며, 신뢰도가 낮은 조건은
  사용자가 직접 고르도록 되묻는다.

## 다음 단계

`RecommendationRepository`와 `ProductDataSource` 계약이 유지되어 있어,
데이터 출처가 늘어나도 화면 코드는 바뀌지 않는다.
수집 공급원을 늘리려면 `crawler/src/adapters/`에 어댑터를 추가한다.
주입 지점은 `lib/app/giftmap_app.dart`의 `_bootstrap()` 한 곳이다.

## 디자인 되돌리기

이전(코랄 중심) 디자인은 백업 브랜치에 그대로 보존되어 있다.

```bash
git switch backup/giftmap-ui-before-refresh-20260912-0143   # 이전 디자인
git switch feat/giftmap-ui-refresh                          # 새 디자인
```
