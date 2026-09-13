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
npm run collect                                  # 기본 공급원에서 20건 수집 + 업로드
node src/index.js --source 10x10 --limit 30      # 개수 지정
node src/index.js --source 10x10 --dry-run       # 수집만 하고 out/에 저장
node src/index.js --source 10x10 --headed        # 브라우저 창을 띄워 확인
npm test                                         # 추출·정규화·robots 규칙 테스트
```

결과는 업로드 성공 여부와 관계없이 항상 `crawler/out/<source>.json`에 남는다.
Supabase 키가 없거나 업로드가 실패해도 앱은 멈추지 않는다. 앱은 원격 읽기가
실패하면 번들 Mock 데이터로 되돌아간다(`RemoteFirstProductDataSource`).

## 수집 규칙

- 시작 전에 공급원 `robots.txt`를 읽고, 우리 User-Agent에게 허용된 경로만 방문한다.
- **JSON-LD의 `schema.org/Product` / `Offer`를 먼저** 읽고, 없으면 `og:` 공개 메타데이터를 쓴다.
- 로그인·CAPTCHA·접근 제한 페이지는 **우회하지 않는다**. 감지하면 건너뛰고 `skipped`에 남긴다.
- 페이지 사이에 간격을 두고 이미지·폰트는 내려받지 않아 공급원 부하를 낮춘다.
- 가격을 확인하지 못하면 `price`는 `null`이다. 0원으로 만들지 않는다.
- 수집 상품은 `is_demo = false`, `source`/`source_url`/`collected_at`이 채워진다.
  번들 데모 상품(`is_demo = true`, `source = null`)과 구분된다.
- 같은 상품은 `<source>-<sku>` 키로 항상 같은 행이 되어 여러 번 실행해도 중복되지 않는다.

## 현재 공급원

| id | 이름 | 근거 |
| --- | --- | --- |
| `10x10` | 텐바이텐 | `robots.txt`가 ClaudeBot 계열에 `/shopping/`, `/category/`, `/search/` 허용. 상세 페이지에 완전한 `Product`/`Offer` JSON-LD 제공 |

## 공급원 추가하기

1. `src/adapters/<이름>.js`에 어댑터 객체를 만든다. 계약은 다음과 같다.

   ```js
   export const myAdapter = {
     id: 'my-source',          // 상품 id 접두사 (my-source-<sku>)
     label: '내 공급원',
     origin: 'https://example.com',
     listingUrls: ['https://example.com/list'],
     async collectProductUrls(page, listingUrl, limit) { /* 상세 URL 배열 */ },
     async openDetail(page, url) { /* 상세 페이지 열기 */ },
   };
   ```

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
