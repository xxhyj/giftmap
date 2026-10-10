# Giftmap 상품 수집기

Supabase `products` 표에 실제 상품을 upsert 한다. Flutter 앱과는 분리된 Node.js
프로그램이다.

지금 쓰는 공급원은 **카카오톡 선물하기**(PlayMCP)뿐이다. 이 공급원은 공개
웹페이지를 Playwright로 긁지 않는다 — Claude Code가 PlayMCP의
`KakaotalkGift-SearchGift` 도구로 상품을 검색해 모은 결과를
`crawler/out/kakao_raw.json`에 저장하고, `node src/kakao/build.js`가 그 결과를
정규화해 Supabase에 올린다. 그래서 상품 검색 자체는 Claude Code 세션 안에서만
할 수 있고(개인 claude.ai 계정 연결이라 서버가 대신 부를 수 없다), 업로드
스크립트만 사람이 직접 실행한다.

텐바이텐·무신사·알라딘·다이소를 **공개 상품 페이지에서 Playwright로 긁는
방식은 더 쓰지 않는다**(실사용 상품으로 보기 어려워 걷어냈다). 그 어댑터들은
삭제했고, `src/adapters/index.js`의 레지스트리는 비어 있다. 아래 "Playwright
어댑터 기반 수집(지금은 안 씀)" 절은 앞으로 새 공급원을 **그런 방식으로** 추가할
때를 위해 남겨 둔 것이다.

## 카카오톡 선물하기 수집(지금 쓰는 방식)

```bash
cd crawler
npm install                 # @supabase/supabase-js 만 필요하다 (Playwright 불필요)
node src/kakao/build.js     # kakao_raw.json → 정규화 → Supabase upsert
```

1. Claude Code 세션에서 PlayMCP `KakaotalkGift-SearchGift`로 검색어별 상품을 모아
   `crawler/out/kakao_raw.json`에 `{ collectedAt, groups: [{ categoryHint, query, items: [...] }] }`
   형태로 저장한다. `items`는 PlayMCP가 돌려주는 `itemId/itemName/itemImageUrl/price/discountRate/link/reviewCount`를 그대로 담는다.
2. `node src/kakao/build.js`를 실행하면 `src/normalize.js#toProductRow`로
   분류·태그·가격 구간을 정하고, `source: 'kakao_gift'`로 Supabase에 upsert한다.
3. 재검색해서 같은 `itemId`가 다시 나오면 같은 행을 덮어쓴다(중복되지 않는다).

가격을 확인하지 못한 상품은 `price`가 `null`이다. 재고 상태는 PlayMCP 검색
결과에 없어 항상 `availability: 'unknown'`이고, 품절로 단정하지 않는다.

## 설치와 Supabase 키

```bash
cd crawler
npm install
```

Supabase에 올리려면 키가 필요하다. `.env.example`을 `.env`로 복사해 값을 채운다.

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sb_secret_xxxx
```

`service_role`(secret) 키는 **수집기에서만** 쓴다. Flutter 앱에는 절대 넣지 않는다.
앱은 publishable(anon) 키로 읽기만 한다(`docs/SUPABASE_SETUP.md`).
`.env`는 커밋하지 않는다(`crawler/.gitignore`).

결과는 업로드 성공 여부와 관계없이 항상 `crawler/out/`에 남는다.
Supabase 키가 없거나 업로드가 실패해도 DB의 기존 상품은 그대로다.
실제 상품 모드의 앱은 원격 읽기에 실패하면 데모로 덮지 않고 재시도 화면을 보여 준다.

## Playwright 어댑터 기반 수집(지금은 안 씀)

예전에는 공급원의 **공개 상품 페이지**에서 Playwright로 상품명·가격·이미지
URL·상품 URL을 직접 긁었다. 지금은 쓰지 않지만, 공개 페이지 스크래핑으로
새 공급원을 추가하고 싶을 때를 위해 아래 규칙과 공급원 추가 절차를 남겨 둔다.

```bash
npm run install:browser   # Playwright Chromium 내려받기
npm run collect                                     # 등록된 공급원에서 수집 + 업로드
node src/index.js --source all --limit 700 --rounds 8   # 넓게 수집
node src/index.js --limit 5 --dry-run               # 수집만 하고 out/에 저장
node src/index.js --headed                          # 브라우저 창을 띄워 확인
npm test                                            # 추출·정규화·중복·robots 테스트
```

지금은 `src/adapters/index.js`의 `adapters` 배열이 비어 있어 위 명령을 돌려도
수집되는 것이 없다. 공급원을 추가하면 다시 동작한다.

### 수집 규칙

- 시작 전에 공급원 `robots.txt`를 읽고, 우리 User-Agent에게 허용된 경로만 방문한다.
  `robots.txt`를 받을 수 없으면(차단·오류) 규칙을 모르는 것이므로 수집하지 않는다.
- **JSON-LD의 `schema.org/Product` / `Offer`를 먼저** 읽고, 없으면 `og:` 공개 메타데이터를 쓴다.
  그래도 비는 값은 어댑터의 `enrich`가 화면의 공개 표시값으로 채운다
  (예: 알라딘 도서는 JSON-LD가 없어 가격·저자를 이 경로로 읽는다). 값을 지어내지 않는다.
- 로그인·CAPTCHA·접근 제한 페이지는 **우회하지 않는다**. 감지하면 건너뛰고 `skipped`에 남긴다.
- 페이지 사이에 간격을 두고 이미지·폰트는 내려받지 않아 공급원 부하를 낮춘다.
- 가격을 확인하지 못하면 `price`는 `null`이다. 0원으로 만들지 않는다.
- 수집 상품은 `is_demo = false`, `source`/`source_url`/`collected_at`이 채워진다.
  번들 데모 상품(`is_demo = true`, `source = null`)과 구분된다.
- 재고는 `Offer.availability`로 읽어 `in_stock`에 넣는다.
  알려 주지 않으면 `null`이며 품절로 단정하지 않는다.
- 같은 상품은 `<source>-<sku>` 키로 항상 같은 행이 되어 여러 번 실행해도 중복되지 않는다.
- 공급원이 달라도 같은 상품이면 `dedupe_key`로 묶어 **하나만 남긴다**.
  고르는 순서는 가격을 아는 것 → 품절이 아닌 것 → 싼 것이다.
- 중복으로 빠진 판매처도 버리지 않는다. 판매처별 URL·가격은 `product_offers`에 남아
  "어디서 얼마에 파는지"를 잃지 않는다.
- 분류 페이지만 쓰면 한 분야(문구·취미)에 쏠리므로, `helpers.js`의 `GIFT_KEYWORDS`로
  향수·뷰티·식품·차·생활·패션·가전·취미까지 **검색으로 넓게 훑는다**.

## 현재 공급원

| id | 이름 | 방식 |
| --- | --- | --- |
| `kakao_gift` | 카카오톡 선물하기 | PlayMCP `KakaotalkGift-SearchGift` (위 "카카오톡 선물하기 수집" 절) |

### Playwright로 긁다가 뺀 곳

텐바이텐(`10x10`)·무신사(`musinsa`)·알라딘(`aladin`)·다이소몰(`daiso`) 어댑터는
실사용 상품으로 쓰기 어려워 모두 제거했다(이 넷의 `robots.txt` 근거는
`git log`의 이전 버전에 남아 있다). 29CM도 도입 전에 검토만 하고 넣지 않았다.
Playwright 방식으로 다시 수집하고 싶다면 "공급원 추가하기" 절차로 어댑터를
새로 만들어 `adapters` 배열에 추가한다.

### 검토했으나 제외한 곳

| 사이트 | 제외 이유 |
| --- | --- |
| **네이버쇼핑** | `robots.txt` 가 `User-agent: * Disallow: /` 이고 `ClaudeBot` 을 따로 또 차단한다. 검색 페이지는 봇 차단 응답(HTTP 418)을 준다. **우회하지 않는다** |
| **쿠팡** | `robots.txt` 자체가 HTTP 403(Akamai 엣지 차단)이라 규칙을 확인할 수 없고, 검색 페이지도 HTTP 403이다. 규칙을 모르면 수집하지 않는다 |
| 마켓컬리·바보사랑 | 목록 진입부터 CAPTCHA. **우회하지 않는다** |
| 펀샵·11번가·아이디어스 | `robots.txt`가 상품 경로를 막음 |
| W컨셉·G마켓·오늘의집 | `robots.txt`를 받을 수 없음(차단) |
| 교보문고·예스24·SSG·롯데온 | 상품 상세에 `Product` JSON-LD 없음 |
| 핫트랙스·1300K | 목록에서 상품 링크를 공개하지 않음(전용 선택자 필요) |

## 공급원 추가하기

1. `src/adapters/<이름>.js`에 어댑터 객체를 만든다. 계약은 다음과 같다.

   ```js
   export const myAdapter = {
     id: 'my-source',          // 상품 id 접두사 (my-source-<sku>)
     label: '내 공급원',
     origin: 'https://example.com',
     // helpers.listingPages 로 페이지를 여러 장 만들 수 있다.
     listingUrls: ['https://example.com/list'],
     // 공급원이 상품에 분류를 달아 주지 않을 때 목록으로 분류를 정한다(선택).
     categoryFor: hintMap([['/list/shoes', 'shoes']]),
     async collectProductUrls(page, listingUrl, limit) { /* 상세 URL 배열 */ },
     // 수집한 상품이 알려 준 하위 목록으로 범위를 넓힌다(선택).
     discoverListings(rawItems) { return []; },
     async openDetail(page, url) { /* 상세 페이지 열기 */ },
     // JSON-LD 에 없는 값을 화면의 공개 표시값으로 채운다(선택).
     async enrich(page, raw) { return raw; },
   };
   ```

   목록 렌더·링크 수집·페이지 넘기기는 `helpers.js`의 `collectLinks`,
   `listingPages`, `hintMap`을 쓰면 된다.

2. `src/adapters/index.js`의 `adapters` 배열에 넣는다.
3. 값 추출(JSON-LD → 메타데이터)과 정규화·업로드는 공통 모듈이 그대로 처리한다.
   공급원별 예외 처리가 필요하면 `src/extract.js`가 아니라 어댑터 안에 둔다.
4. robots.txt가 목록/상세 경로를 허용하는지 먼저 확인한다. 허용하지 않으면 수집기가 중단한다.

## 파일 구성

| 파일 | 역할 |
| --- | --- |
| `src/index.js` | CLI. 목록 → 상세 → 정규화 → 업로드 흐름 |
| `src/browser.js` | Playwright Chromium 실행과 User-Agent |
| `src/robots.js` | robots.txt 해석과 경로 허용 판단 |
| `src/extract.js` | JSON-LD / 메타데이터 추출, 접근 제한 감지 |
| `src/normalize.js` | 수집 결과 → `products` 행 (분류·태그·가격 구간) |
| `src/supabase.js` | 환경변수 읽기와 upsert |
| `src/adapters/` | 공급원별 목록·상세 규칙 (지금은 비어 있다) |
| `src/adapters/helpers.js` | 목록 렌더·링크 수집·페이지·분류 힌트 공통 도구 |
| `src/kakao/build.js` | `kakao_raw.json`(PlayMCP 수집 결과) → 정규화 → Supabase upsert |
