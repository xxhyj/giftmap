# Giftmap API (Vercel)

Flutter 앱이 부르는 HTTPS API다. 앱은 이 주소 하나만 알고, 비밀키는 전부 여기에만 있다.

```
Flutter 앱 → Vercel API → Supabase 상품 DB / OpenAI
```

앱에는 `API_BASE_URL` 만 들어간다. Supabase 키도 OpenAI 키도 APK 에 넣지 않는다.

## 엔드포인트

| 메서드 | 경로 | 하는 일 |
| --- | --- | --- |
| GET | `/api/health` | 살아 있는지와 환경변수가 채워졌는지(값은 담지 않는다) |
| GET | `/api/products?page=&limit=&category=&query=` | 상품 한 페이지 |
| GET | `/api/products/:id` | 상품 하나 |
| POST | `/api/recommend` | 조건에 맞는 실제 상품 3~5개 |

오류는 어디서 나든 모양이 같다.

```json
{ "error": { "code": "rate_limited", "message": "추천 요청이 너무 잦습니다." } }
```

`POST /api/recommend` 는 고를 수 없을 때도 200 으로 답한다. 못 고르는 것은 오류가
아니며, 앱이 `fallback: true` 를 보고 자기 로컬 추천 엔진으로 잇는다.

```json
{ "fallback": true, "reason": "조건에 맞는 실제 상품이 없습니다." }
```

## 환경변수

이름은 `.env.example` 에 있고, 값은 **Vercel 프로젝트 환경변수에만** 넣는다.
저장소에는 어떤 실제 값도 두지 않는다.

| 이름 | 필요한 곳 |
| --- | --- |
| `SUPABASE_URL` | 상품 조회 |
| `SUPABASE_SERVICE_ROLE_KEY` | 상품 조회(서버 전용 키) |
| `OPENAI_API_KEY` | 추천 |
| `OPENAI_MODEL` | 추천(기본 `gpt-5-nano`) |
| `ALLOWED_ORIGINS` | 브라우저에서 부를 때의 CORS. 비우면 모두 허용 |
| `RECOMMEND_RATE_LIMIT_PER_MINUTE` | 추천 호출 제한(기본 10) |

## 테스트

계정도 키도 배포도 필요 없다. 가짜 요청·응답으로 핸들러를 직접 부른다.

```bash
cd server
npm test
```

## 안전장치

- 입력은 모두 검증한다. 모르는 값은 버리고, 검색어에서 PostgREST 필터 문법을
  뜻하는 문자를 지운다. 상품 id 는 정해진 모양만 받는다.
- 모델 호출은 IP 기준으로 분당 횟수를 제한한다(429 + `retry-after`).
- 모델이 거절하면 상태 코드만 남긴다. 응답 본문에 키가 섞여 나올 수 있어 기록하지 않는다.
- 모델은 상품을 만들 수 없고 후보 중에서 고를 수만 있다. 앱은 받은 id 를 자기
  카탈로그에서 한 번 더 확인하고, 없으면 버린다.
