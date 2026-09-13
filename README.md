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

### 실제 상품 수집

`crawler/`는 공급원의 공개 상품 페이지에서 상품명·브랜드·가격·이미지 URL·원본 URL·
카테고리·품절 여부를 읽어 Supabase에 올리는 Node.js 프로그램이다.
앱과 분리되어 있고 단독으로 실행된다.

```bash
cd crawler
npm install
npm run install:browser                                  # Playwright Chromium
node src/index.js --limit 5 --dry-run                    # 수집만 확인
npm run collect                                          # 수집 + upsert(.env 필요)
node src/index.js --source all --limit 700 --rounds 8    # 넓게 수집
```

현재 공급원은 텐바이텐·무신사·알라딘이다. robots.txt가 허용한 경로만 방문하고
로그인·CAPTCHA·접근 제한은 우회하지 않는다. 공급원 추가 방법과 검토했으나
제외한 사이트 목록은 [crawler/README.md](crawler/README.md)에 있다.

### 추천 (서버 AI → 로컬 엔진)

Supabase Edge Function `recommend`가 조건에 맞는 실제 상품 후보를 추린 뒤
OpenAI에게 **그 후보 중에서만** 3~5개를 고르게 한다. 모델은 상품·가격·URL을
만들 수 없고 고를 수만 있으며, 앱은 받은 상품 id를 카탈로그에서 다시 확인한다.
호출이 실패하거나 고른 상품이 3개 미만이면 로컬 추천 엔진이 그대로 맡는다.
`OPENAI_API_KEY`는 함수 시크릿으로만 존재하고 앱에는 들어가지 않는다.

```bash
cp supabase/.env.example supabase/.env.local   # 값 채우기(커밋되지 않음)
npx supabase functions deploy recommend --project-ref <프로젝트 ref>
```

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
- **실제 상품 모드**(Supabase 값이 주어졌을 때): `is_demo = false`인 수집 상품만 보여 준다.
  번들 데모 46종은 화면에 나오지 않고, 읽기에 실패하면 데모로 덮지 않고 재시도 화면을 띄운다.
- **데모 모드**(Supabase 값이 없을 때): 번들 상품 46종으로 동작한다.
  이들은 실제 브랜드·상품이 아니며 화면에 DEMO 배지와 고지가 붙는다.
- 상품이 많아 목록은 스크롤에 따라 이어 붙인다(끝에 "더 보기"도 함께 둔다).
- 데모 상품 이미지는 외부 URL을 쓰지 않는다. asset이 없으면 카테고리별 로컬 비주얼을 그린다.
  수집한 실제 상품만 공급원이 공개한 이미지 URL을 쓰고, 불러오지 못하면 같은 비주얼로 되돌아간다.
- 찜과 최근 본 상품은 기기 로컬에 저장되어 앱을 다시 켜도 유지된다.
- 추천 기록과 기념일은 인메모리로 보관한다. 앱을 다시 켜면 비워진다.
- 상품 수·카테고리 수를 코드에 고정하지 않는다. 모든 화면이 카탈로그 길이를 따른다.
- 브랜드·가격·이미지·판매 URL이 없어도 화면이 깨지지 않는다
  (가격이 없으면 "가격 확인 필요", URL이 없으면 구매 CTA 비활성).
- 상품 상세의 단일 CTA "상품 보러 가기"는 Giftmap 안의 인앱 브라우저로 판매처 페이지를 연다.
  로그인 없이 상품을 볼 수 있고, 구매까지 갈 사람은 그 페이지에서 판매처 앱을 고를 수 있다.
  상단 뒤로·닫기로 상품 상세에 즉시 돌아온다.
- 품절은 공급원이 알려 줄 때만 표시한다. 모르면 표시하지 않고 품절로 단정하지 않는다.
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
