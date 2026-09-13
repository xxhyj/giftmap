# Giftmap 상품 수집기

공급원의 **공개 상품 페이지**에서 상품명·가격·이미지 URL·상품 URL을 읽어
Supabase `products` 표에 upsert 한다. Flutter 앱과는 분리된 Node.js 프로그램이며
Claude Code나 MCP 없이 단독으로 실행된다.

## 설치

```bash
cd crawler
npm install
npm run install:browser   # Playwright Chromium 내려받기
```

Supabase에 올리려면 키가 필요하다. `.env.example`을 `.env`로 복사해 값을 채운다.

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sb_secret_xxxx
```

`service_role`(secret) 키는 **수집기에서만** 쓴다. Flutter 앱에는 절대 넣지 않는다.
앱은 publishable(anon) 키로 읽기만 한다(`docs/SUPABASE_SETUP.md`).
`.env`는 커밋하지 않는다(`crawler/.gitignore`).

## 실행

```bash
npm run collect                                     # 모든 공급원에서 수집 + 업로드
node src/index.js --source all --limit 700 --rounds 8   # 넓게 수집
node src/index.js --source musinsa --limit 200      # 한 공급원만
node src/index.js --limit 5 --dry-run               # 수집만 하고 out/에 저장
node src/index.js --headed                          # 브라우저 창을 띄워 확인
npm test                                            # 추출·정규화·중복·robots 테스트
```

**공급원 하나가 끝날 때마다 바로 Supabase에 올린다.** 마지막에 한 번만 올리면
중간에 멈췄을 때 그때까지 수집한 것이 모두 사라지기 때문이다. 한 공급원 저장이
실패해도 남은 공급원 수집은 계속된다.

결과는 업로드 성공 여부와 관계없이 항상 `crawler/out/<대상>.json`에 남는다.
Supabase 키가 없거나 업로드가 실패해도 DB의 기존 상품은 그대로다.
실제 상품 모드의 앱은 원격 읽기에 실패하면 데모로 덮지 않고 재시도 화면을 보여 준다.

## 수집 규칙

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

| id | 이름 | 근거 |
| --- | --- | --- |
| `10x10` | 텐바이텐 | `robots.txt`가 ClaudeBot 계열에 `/shopping/`, `/category/`, `/search/` 허용. 상세에 `Product`/`Offer` JSON-LD 제공. 목록의 breadcrumb로 하위 분류까지 넓힌다 |
| `musinsa` | 무신사 | `robots.txt`의 `ClaudeBot` 포함 그룹에 상품 경로 허용. `Product`/`Offer` JSON-LD와 재고 제공 |
| `aladin` | 알라딘 | `robots.txt`의 `ClaudeBot` 포함 그룹에 `/shop/` 허용. `Product`/`Offer` JSON-LD 제공 |
| `daiso` | 다이소몰 | `robots.txt`가 `ClaudeBot`에 `/pd/` 허용. sitemap으로 상품 약 2만 건을 공개하고 JSON-LD에 이름·브랜드·가격·재고·이미지·분류가 모두 있다. 생활·주방·청소·문구·뷰티를 넓게 덮는다 |
| `29cm` | 29CM | `robots.txt`의 `*` 그룹이 상품·검색 경로 허용. 검색 결과가 상품 링크를 그대로 노출하고 상세에 `Product` JSON-LD가 있다(이미지는 `og:image`로 보완). 향수·뷰티·패션·리빙을 덮는다 |

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
| `src/adapters/` | 공급원별 목록·상세 규칙 |
| `src/adapters/helpers.js` | 목록 렌더·링크 수집·페이지·분류 힌트 공통 도구 |
