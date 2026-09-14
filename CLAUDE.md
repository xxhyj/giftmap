# CLAUDE.md — Giftmap 개발 기준

Claude Code가 이 저장소에서 작업할 때 항상 지켜야 할 기준이다.
제품 상세는 `docs/PRD.md`, 구조는 `docs/ARCHITECTURE.md`, UI는 `docs/DESIGN_SYSTEM.md`,
검증은 `docs/TESTING.md`를 따른다.

## 1. 프로젝트 목적

GiftMap(선물지도)은 기념일·생일처럼 선물을 골라야 하는 순간에, 상대방과의 관계·상황·예산·선호를
입력하면 어울리는 **선물 상품과 탐색 방향**을 추천하는 모바일 앱이다.
조건 입력 → 추천 → 상품 탐색 → 비교 → 찜 → 상세 확인으로 이어지는 커머스형 탐색 경험을 목표로 한다.
실제 결제·판매는 하지 않으며, 현재 상품 데이터는 전부 로컬 데모 데이터다.

## 2. 현재 개발 단계의 범위

이 단계의 목표는 **공개 상품 페이지에서 수집한 실제 상품으로 핵심 사용자 흐름을 돌리는 것**이다.
추천은 서버(Edge Function)의 OpenAI가 실제 상품 중에서 고르고, 실패하면 로컬 결정론 엔진이 맡는다.

포함:
- Flutter Stable / Dart null safety / Material 3 / Android API 24+
- 로컬 번들 JSON 데이터(카테고리 방향 + 상품 카탈로그)와 결정론적 추천 엔진
- 상품 검색 · 상품 상세 · 찜 · 최근 본 상품(로컬 저장)
- 로컬(인메모리) 추천 기록과 기념일
- 로컬 키워드 기반 자연어 파서

상품 수집기 `crawler/` (앱 밖, 선택):
- Node.js + Playwright로 공급원의 **공개 상품 페이지**에서 상품명·가격·이미지 URL·상품 URL을
  읽어 Supabase `products`에 upsert한다. Flutter 앱과 분리된 프로그램이며 단독 실행된다.
- JSON-LD의 `schema.org/Product`/`Offer`를 우선 쓰고, 없으면 공개 메타데이터를,
  그래도 비면 어댑터의 `enrich`가 화면의 공개 표시값을 읽는다. 값을 지어내지 않는다.
- `robots.txt`가 허용한 경로만 방문한다. 로그인·CAPTCHA·접근 제한은 **우회하지 않는다**.
  `robots.txt`를 받을 수 없으면 규칙을 모르는 것이므로 수집하지 않는다.
  (네이버쇼핑은 `Disallow: /`, 쿠팡은 robots.txt 자체가 403이라 둘 다 수집 대상이 아니다)
- 분류 페이지만 쓰면 한 분야에 쏠리므로 선물 카테고리별 검색어(`GIFT_KEYWORDS`)로 넓게 훑는다.
- 중복 통합으로 빠진 판매처의 URL·가격은 `product_offers`에 보존한다.
- 수집 상품은 `is_demo = false`로 데모 상품과 구분하고, 상세에서 원본 판매 페이지를 연다.
- Supabase 키(`service_role`)는 `crawler/.env` 환경변수로만 받는다. 앱에는 넣지 않는다.
- 공급원 추가는 `crawler/src/adapters/`에 어댑터를 더하는 방식이다. 자세한 내용은 `crawler/README.md`.

Vercel API `server/` (앱 밖, 선택):
- Flutter 앱 → Vercel HTTPS API → Supabase 상품 DB / OpenAI 구조다.
  앱에는 `API_BASE_URL` 만 들어가고 Supabase·OpenAI 키는 서버 환경변수에만 둔다.
- `--dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://...` 일 때만 켜진다.
  `USE_MOCK` 의 기본값은 true 이며, 값을 주지 않으면 예전 경로가 그대로 동작한다.
- 엔드포인트는 `/api/health`, `/api/products`, `/api/products/:id`, `/api/recommend` 네 개다.
  자세한 내용은 `server/README.md`.
- 이 배포는 **API 전용**이다. 화면은 내보내지 않는다. GitHub `main` 에 푸시하면
  Vercel 이 `server/` 를 자동 배포한다.
- 앱은 `package:http` 로 서버를 부른다. 웹에서도 컴파일되는 것이 이유였고,
  안드로이드에서도 같은 코드가 그대로 돈다.
- 웹으로 띄우면 인앱 브라우저(webview_flutter)가 없어 `kIsWeb` 일 때 CTA 가 새 탭을 연다.
  안드로이드의 인앱 브라우저 흐름은 그대로다.
- 앱에서 Supabase 를 직접 읽던 예전 경로는 제거했다. 남은 경로는 API 와 번들 Mock 둘뿐이고,
  `ApiBootstrap` 이 고른다.

Supabase:
- 상품 DB 는 Supabase 에 있지만 **앱은 직접 붙지 않는다.** 읽는 것은 `server/` 의
  Vercel API 뿐이고, 앱에는 Supabase 주소도 키도 들어가지 않는다.
- 스키마·마이그레이션은 `supabase/migrations/`, 수집기는 `crawler/` 가 쓴다.
- 설정 방법은 `docs/SUPABASE_SETUP.md` 참고.

제외(이후 별도 명령으로 진행):
- 앱 안에서의 LLM 호출 (서버 함수를 통해서만 쓴다)
- 로그인·사용자 동기화, 앱에서 Supabase에 쓰기
- Firebase, 직접 만든 서버(앱이 호출하는 API 서버), REST/GraphQL API
  (`crawler/`는 앱이 호출하지 않는 오프라인 수집 도구라 여기 해당하지 않는다)
- 실시간 가격·재고·실제 제휴 링크
  (수집한 실제 상품의 가격·이미지 URL·판매 URL은 수집 시점의 공개 정보다)
- 로그인/회원가입/결제/장바구니/배송
- Push Notification, 카메라, 관리자 CMS

## 3. 절대 금지

- 앱에서 외부 AI API를 직접 호출하기 (OpenAI 호출은 `server/api/recommend.js` 안에서만 한다)
- "나중을 위한" 빈 API client·서버 스텁 작성
- API Key·Secret·인증정보를 앱 코드나 asset에 포함
  (앱에 들어가는 값은 `API_BASE_URL` 뿐이고 `--dart-define`으로만 전달한다)
- Supabase·OpenAI 키를 앱에 넣기 (서버 환경변수에만 둔다)
- 앱에서 Supabase 에 직접 연결하기 (`server/` 의 API 를 거친다)
- 새 dependency 임의 추가 (특히 AI/API/서버/DB 관련), code generation 도입
- `flutter clean`, `git reset --hard`, 프로젝트 삭제·재생성
- 기존 기능 삭제나 주석 처리로 오류 숨기기
- 알 수 없는 가격을 0원으로 표시하기
- 화면(presentation) 파일에서 추천 점수 계산하기

## 4. 아키텍처 원칙

- **feature-first**: `lib/features/<feature>/{domain,data,application,presentation}`
- 공통 토큰·위젯·정책은 `lib/core`, 앱 조립은 `lib/app`
- 의존 방향은 presentation → application → domain, data는 domain 계약을 구현한다
- 상태 관리는 `ChangeNotifier` + `InheritedWidget`(`AppScope`)만 사용한다. 상태관리 패키지 금지
- 로컬 저장은 `IdListStorage` 계약을 통해서만 접근한다(현재 구현: shared_preferences / 인메모리)
- 상품 데이터는 `ProductDataSource` 계약으로만 읽는다
  (번들 Mock / Vercel API 두 구현체)
- 라우팅은 `Navigator` + `MaterialPageRoute` (`lib/app/app_router.dart`). 라우팅 패키지 금지
- 하단 탭은 홈 / 카테고리 / 선물추천 / 찜 / 기록 5개다. 검색 탭은 두지 않는다
  (검색은 홈 최상단 검색창에서 들어간다)
- 저장소는 인터페이스로 추상화한다. 현재 구현체는 Mock/InMemory뿐이다
- 과도한 추상화 금지. 계층은 실제로 필요한 만큼만 만든다

## 4-1. 실제 상품 모드

`--dart-define`으로 `USE_MOCK=false` 와 `API_BASE_URL` 이 들어오면 **실제 상품 모드**다.

- 상품은 서버가 내려주는 `is_demo = false` 행만이다. 번들 데모 46종은 화면에 나오지 않는다.
- 이 모드에서는 Mock fallback을 쓰지 않는다. 읽기에 실패하거나 상품이 0건이면
  데모로 덮지 않고 **오류·재시도 화면**(`LoadFailureScreen`)을 보여 준다.
- 값이 없으면 번들 데모 데이터로 동작한다(테스트가 이 경로를 쓴다).
- 상품이 수백 건이므로 목록은 `PagedProductGrid`로 나눠 보여 준다(스크롤 시 자동 확장 + 더 보기).
  검색·카테고리·추천 결과 모두 같은 위젯을 쓴다.
- 홈은 한 출처·한 분류가 뒤덮지 않도록 `ProductCatalog.interleave`로 섞어 구성한다.
  출처를 바깥 고리에 둔다. 분류를 바깥에 두면 상품이 많은 출처가 앞자리를 다 가져간다.
- 홈의 여섯 줄은 `ProductCatalog.homeSections()`가 한 번에 만든다. 줄마다 따로 뽑으면
  같은 상품이 여러 줄에 겹쳐 나온다. 앞줄에 쓴 상품은 다음 줄에서 뺀다.
- 홈에는 `ExposureQuota.home`을 건다(도서 15%, 한 판매처 35%). 판매처가 셋뿐이고 그중
  하나가 책만 팔면 두 한도를 동시에 지킬 수 없어, 지킬 수 있는 만큼으로 자동으로 풀린다.
  카테고리·검색 화면에는 한도를 걸지 않는다. 책을 전부 탐색할 수 있어야 한다.
- 같은 상품을 가리키는 카드는 `ProductCatalog.sellable`에서 하나로 합친다. 판단 기준은
  정규화한 판매 URL과 브랜드·상품명이며, 합쳐진 판매처는 `offersOf`로 남는다.
- 서버 페이지네이션은 `sort_order`(공급원 안에서의 순번) → `id` 오름차순으로 고정한다.
  `order()`에 `ascending: true`를 적지 않으면 내림차순이 되어 뒤에서부터 받는다.
  `sort_order`가 모두 같으면 첫 페이지가 한 공급원으로만 채워진다.

## 4-3. 재고와 검색 집계

- 재고는 `availability`(`in_stock`/`out_of_stock`/`unknown`)와 `last_verified_at`으로 관리한다.
  품절이어도 **행을 지우지 않는다**.
- 품절이 확인된 상품은 홈·검색·카테고리·추천에서 뺀다(`ProductCatalog.sellable`).
  찜·최근 본 상품에서는 그대로 보여 주되 품절 표시를 붙이고 CTA를 잠근다.
- 재고를 모르는 상품(`unknown`)은 품절로 단정하지 않고 그대로 보여 준다.
- 마지막 확인이 14일을 넘은 상품은 추천 점수를 8점 낮춘다.
- 검색어는 `search_events`에 **익명으로만** 남긴다. 사용자 id·기기 id를 보내지 않고,
  20자 넘거나 문장처럼 긴 입력은 아예 기록하지 않는다. 집계는 3회 이상 검색어만 센다.
- 집계가 모자라면 "인기 검색어"라고 부르지 않고 "추천 검색어"로 표시한다.

## 4-2. 추천 (서버 AI → 로컬 엔진)

```
사용자 조건
 └ Vercel API `POST /api/recommend`
     ├ Supabase에서 조건에 맞는 실제 상품 후보를 고르고
     ├ OpenAI에게 그 후보 중에서만 3~5개를 고르게 한 뒤
     └ 실제로 존재하는 상품 id만 돌려준다
앱은 받은 id를 카탈로그에서 다시 확인하고, 없으면 버린다.
3개 미만이거나 호출이 실패하면 `ProductRecommendationEngine`(로컬)이 맡는다.
```

- 모델은 상품·가격·URL을 만들 수 없다. 고를 수만 있다.
- 후보는 이미지·가격·판매 URL이 모두 있는 상품으로 제한한다(화면에 온전히 보여 줄 수 있는 것만).
- `OPENAI_API_KEY`는 Vercel 환경변수로만 존재한다. 앱에는 절대 넣지 않는다.

## 5. 추천 엔진 원칙

점수 로직은 `lib/features/gift_finder/data/`의 두 엔진에만 존재한다.
`LocalRecommendationEngine`이 카테고리(선물 방향)를, `ProductRecommendationEngine`이 상품을 고른다.

### 5-1. 카테고리 방향

```
base                 40
situation match    0..20
relationship match 0..15
budget fit         0..15
preference distance 0..10
risk penalty      0..-50
avoidTags 충돌        제외
riskLevel == avoid    제외
최종 점수          0..100
```

- 동점은 `categoryId` 오름차순 → **같은 입력은 항상 같은 순서**
- 결과는 서로 다른 카테고리 **정확히 3개**, 상위 그룹당 1개로 다양성 확보
- 3개 미만이면 `safeDefault` 카테고리로 보충

### 5-2. 상품 추천 (사용자에게 보이는 결과)

```
base                 30
occasion match     0..25
recipient match    0..20
budget fit         0..25   (예산 초과 시 크게 감점)
preference match   0..10
age match          0..5
direction bonus    0..12   (카테고리 방향 1/2/3위 = 12/8/5)
stale penalty        -8   (마지막 확인이 14일 넘은 상품)
risk penalty      0..-50
avoidTags 충돌        제외
riskLevel == avoid    제외
최종 점수          0..100
```

- 품절이 확인된 상품(`availability == out_of_stock`)은 후보에서 제외한다
- 동점은 **상품 id 오름차순** → 같은 입력은 항상 같은 상품·같은 순서
- 결과는 상품 단위이며 같은 상품을 중복 추천하지 않는다
- 조건이 좁아 3개 미만이면 예산에 맞는 안전한 상품으로 보충한다

## 6. 데이터 원칙

- 카테고리·위험 규칙·검색어 템플릿·상품 카탈로그는 `lib/data/*.json` 번들 asset이다
- 번들 상품은 전부 `isDemo: true`인 **데모 데이터**이며, 실제 브랜드·상품·시세가 아니다
- 서버는 `crawler/`가 수집한 `isDemo: false` 실제 상품을 내려준다.
  실제 상품에는 DEMO 배지를 붙이지 않고, 상세의 단일 CTA로 원본 판매 페이지를 연다
- 번들 데모 상품 이미지는 외부 URL을 쓰지 않는다. asset이 없으면 카테고리별 로컬 비주얼을 그린다.
  수집한 실제 상품만 공급원이 공개한 이미지 URL을 쓰고, 실패하면 같은 비주얼로 되돌아간다
- 가격은 **Demo/Mock 시세**이며 UI에 항상 고지를 표시한다
- 시세 근거가 없으면 가격 필드는 `null`이고 화면에는 "가격 확인 필요"로 표시한다
- 번들 데이터가 손상되면 예외를 던지지 않고 안전한 기본 카테고리 세트로 진입한다

## 7. UI 원칙

- Premium하되 부담 없는, 따뜻하고 친근한 인상. 과도한 카드·그라디언트·그림자·AI 느낌 금지
- 한 손 사용 기준: 주요 CTA는 하단, 높이 56dp, 최소 터치 영역 48dp
- 본문 최소 15sp, 캡션 13sp, 명확한 타이포그래피 계층과 충분한 여백
- 색상만으로 상태를 전달하지 않는다(적합도·위험도는 수치·라벨·아이콘 병행)
- Text Scale 1.3배에서도 overflow가 없어야 한다
- 포인트 컬러(accent)는 찜·할인처럼 눈에 띄어야 하는 곳에만 쓰고,
  주요 행동은 primary(딥 그린)를 쓴다. 빨강은 error에만 쓴다
- 상품 개수·카테고리 개수를 숫자로 가정하지 않는다. 항상 목록 길이를 따른다
- 상품 카드의 텍스트는 브랜드 1줄·상품명 2줄로 말줄임하고, 상세에서는 전체를 보여준다
- 상품 화면은 이미지가 가장 먼저 인식되어야 한다. 텍스트가 이미지를 압도하지 않는다
- 가격은 강한 위계로 표시하고, 할인 정보는 할인율 → 판매가 → 정가 순으로 읽히게 한다

## 8. 작업 절차

모든 작업 단위에서 다음 순서를 지킨다.

1. 현재 프로젝트 상태 확인 (파일을 먼저 읽는다)
2. 계획 수립
3. 구현 (작은 단위로)
4. `dart format lib test`
5. `flutter analyze`
6. 관련 `flutter test`
7. 에뮬레이터/시뮬레이터에서 작은 단위 실행 확인

최종 검증:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

오류를 남긴 채 다음 기능으로 넘어가지 않는다. 원인을 분석하고 수정한 뒤 다시 검증한다.

## 9. 개발 환경

- 메인 IDE는 Cursor이며 프로젝트 개발은 Claude Code가 수행한다
- Android Studio는 개발 IDE로 사용하지 않는다 (SDK/에뮬레이터 관리 용도만)
- Android Gradle 파일, SDK/JDK/PATH를 임의로 수정하지 않는다

## 10. 문서 유지

기능을 추가·변경하면 관련 문서(`docs/`)와 `README.md`를 같은 작업에서 갱신한다.
문서는 **현재 저장소의 실제 상태**만 기술한다. 미구현 기능을 구현된 것처럼 쓰지 않는다.
