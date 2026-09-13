# Supabase 연결 가이드 (처음 하는 사람 기준)

Giftmap은 **Supabase 없이도 그대로 동작한다.** 아무 설정을 하지 않으면 앱에 들어 있는
번들 Mock 데이터(`lib/data/products.json`)를 쓴다.
이 문서는 그 데이터를 Supabase로 옮겨서 **앱을 다시 빌드하지 않고 상품을 고칠 수 있게**
만드는 과정을 순서대로 설명한다.

> 걸리는 시간: 처음이면 20~30분.
> 준비물: Supabase 계정(이미 있음), 이 저장소, Flutter 실행 환경.

---

## 0. 전체 그림

```
Supabase (products / categories / collections / search_suggestions)
        │  읽기 전용, Publishable(anon) 키
        ▼
Flutter  SupabaseProductDataSource
        │  실패하거나 설정이 없으면
        ▼
Flutter  BundledProductDataSource  ← 지금 쓰고 있는 Mock 데이터
```

- 앱은 **읽기만** 한다. 상품 추가·수정은 Supabase 화면에서 한다.
- 찜 / 최근 본 상품 / 추천 기록은 **지금처럼 기기에만 저장**된다. 로그인은 아직 없다.

---

## 1. Supabase 새 프로젝트 만들기

1. https://supabase.com 에 로그인한다.
2. 왼쪽 위 조직(Organization)을 고르고 **New project**를 누른다.
3. 입력값:

   | 항목 | 무엇을 넣나 |
   |---|---|
   | **Name** | `giftmap` (아무 이름이나 괜찮다) |
   | **Database Password** | 강한 비밀번호를 만들고 **따로 저장**한다. 앱에는 쓰지 않지만 분실하면 재설정해야 한다 |
   | **Region** | `Northeast Asia (Seoul)` — 한국에서 가장 빠르다 |
   | **Pricing Plan** | `Free` |

4. **Create new project**를 누르고 1~2분 기다린다.
   상단에 "Setting up project..."가 사라지면 준비 끝이다.

---

## 2. Project URL과 Publishable Key 확인하기

앱에 넣을 값은 딱 두 개다.

1. 왼쪽 아래 **Settings(톱니바퀴)** → **API** 로 들어간다.
2. 두 값을 복사한다.

   | 화면에 보이는 이름 | 예시 형태 | 앱에서 쓰는 이름 |
   |---|---|---|
   | **Project URL** | `https://abcdefghijkl.supabase.co` | `SUPABASE_URL` |
   | **Publishable key** (예전 이름: `anon` `public`) | `sb_publishable_...` 또는 `eyJhbGciOi...` | `SUPABASE_PUBLISHABLE_KEY` |

> ⚠️ 같은 화면에 있는 **`service_role` / `secret` 키는 절대 앱에 넣지 않는다.**
> 이 키는 모든 보안 규칙을 통과하는 관리자 키다. 앱에 넣으면 누구나 데이터를 지울 수 있다.
> 앱은 실수로 이 키가 들어오면 연결을 거부하고 Mock 데이터로 돌아가도록 만들어 두었다.

---

## 3. SQL Editor 사용법

1. 왼쪽 메뉴 **SQL Editor**를 누른다.
2. 오른쪽 위 **New query**(또는 `+`)를 누르면 빈 편집기가 열린다.
3. 아래에서 안내하는 SQL 파일을 **통째로 복사해 붙여넣는다.**
4. 오른쪽 아래 **Run**(또는 `Ctrl` + `Enter`)을 누른다.
5. 아래쪽에 `Success. No rows returned` 같은 메시지가 나오면 성공이다.

---

## 4. SQL 실행 순서 (중요)

**반드시 이 순서대로 한 번씩** 실행한다.

### 4-1. 표 만들기

저장소의 `supabase/migrations/0001_init_schema.sql` 내용을 전부 복사해서 실행한다.

이 SQL이 하는 일:
- `categories`, `products`, `product_categories`, `collections`,
  `collection_products`, `search_suggestions` 표 생성
- 검색·정렬이 빨라지도록 index 생성
- 표 사이 연결(foreign key) 설정
- **RLS(Row Level Security) 활성화** — 앱은 `is_active = true`인 행만 읽을 수 있고,
  쓰기 정책은 만들지 않아 앱 키로는 수정·삭제가 불가능하다

### 4-2. 데모 데이터 넣기

`supabase/seed/0002_seed_demo_data.sql` 내용을 전부 복사해서 실행한다.

- 현재 Mock 데이터가 그대로 들어간다(모두 `is_demo = true`).
- 여러 번 실행해도 안전하다(같은 id는 덮어쓴다).
- 이 파일은 자동 생성 파일이다. Mock 데이터를 고쳤다면 아래 명령으로 다시 만든다.

  ```bash
  dart run tool/generate_supabase_seed.dart
  ```

### 4-3. 수집 출처 컬럼 추가하기

`supabase/migrations/0003_product_source_columns.sql` 내용을 전부 복사해서 실행한다.

- `products`에 `source`, `source_product_id`, `source_url`, `collected_at`을 추가한다.
- 이 컬럼은 `crawler/`가 공개 페이지에서 수집한 실제 상품을 표시하기 위한 것이다.
  데모 상품은 `source`가 비어 있다.
- 수집 실행 방법은 `crawler/README.md`를 본다. 수집기는 `service_role` 키를
  환경변수로 받아 서버 쪽에서만 쓴다. 앱에는 넣지 않는다.

---

## 5. 표가 잘 만들어졌는지 확인

**Table Editor**(왼쪽 메뉴)에 들어가면 표 6개가 보여야 한다.
또는 SQL Editor에서 아래를 실행한다.

```sql
select
  (select count(*) from public.categories)         as categories,
  (select count(*) from public.products)           as products,
  (select count(*) from public.collections)        as collections,
  (select count(*) from public.search_suggestions) as suggestions;
```

`products`가 0이 아니면 정상이다.

---

## 6. Flutter에서 실행하기

키를 코드에 넣지 않고 **실행할 때 전달**한다.

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://여기에_내_프로젝트_URL.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=여기에_내_publishable_key
```

Windows PowerShell에서는 줄바꿈 기호가 다르다.

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://여기에_내_프로젝트_URL.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=여기에_내_publishable_key
```

**아무것도 전달하지 않고 `flutter run`만 해도 앱은 잘 돌아간다.** 이때는 Mock 데이터다.

매번 타이핑하기 번거로우면 VS Code / Cursor의 `.vscode/launch.json`에
`"toolArgs"`로 넣어 두면 된다. 이 파일은 **Git에 올리지 않는 것을 권장**한다.

---

## 7. 연결이 됐는지 확인하는 방법

1. 실행하면 콘솔(디버그 로그)에 다음 중 하나가 찍힌다.

   | 로그 | 뜻 |
   |---|---|
   | `[Giftmap] Supabase 연결 준비 완료` | 연결 성공 |
   | `[Giftmap] SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY 가 없어 번들 Mock 데이터로 실행합니다.` | 값을 안 넘겼다 |
   | `[Giftmap] 원격 상품을 불러오지 못해 번들 데이터를 사용합니다: ...` | 연결은 됐지만 읽기 실패 |
   | `[Giftmap] 원격 상품이 비어 있어 번들 데이터를 사용합니다.` | 표는 있는데 seed를 안 넣었다 |

2. 눈으로 확인하려면 Supabase에서 상품 하나의 이름을 바꾸고 앱을 다시 실행한다.
   바뀐 이름이 보이면 원격 데이터를 읽고 있는 것이다.

---

## 8. 실제 상품 추가 · 수정 · 비활성화

모두 Supabase **Table Editor** 또는 **SQL Editor**에서 한다. 앱에서는 할 수 없다.

### 추가 (Table Editor)

1. **Table Editor** → `products` → **Insert** → **Insert row**
2. 최소한 채워야 하는 값:

   | 칸 | 설명 |
   |---|---|
   | `id` | 겹치지 않는 영문 id (예: `perfume_47`) |
   | `product_name` | 상품명 |
   | `category_id` | `categories` 표에 있는 id (예: `perfume`) |

3. 나머지는 비워도 된다. 비웠을 때 앱 동작:

   | 비운 칸 | 앱 화면 |
   |---|---|
   | `brand_name` | 카테고리 이름을 대신 보여준다 |
   | `price` | **"가격 확인 필요"** 로 표시한다 (0원으로 쓰지 말 것) |
   | `image_asset` | 카테고리별 기본 그림을 그린다 |
   | `product_url` | "상품 보러가기" 버튼이 비활성 상태로 남는다 |

### 추가 (SQL Editor)

```sql
insert into public.products (id, product_name, brand_name, category_id, price, is_demo)
values ('perfume_47', '새 향수 세트', '브랜드명', 'perfume', 52000, false);
```

### 수정

```sql
update public.products
set price = 45000, discount_rate = 10
where id = 'perfume_47';
```

### 비활성화 (지우지 않고 숨기기)

```sql
update public.products set is_active = false where id = 'perfume_47';
```

`is_active = false`면 앱에서 즉시 사라진다. 되살리려면 `true`로 바꾸면 된다.
**되도록 삭제 대신 비활성화를 쓴다.** 찜·최근 본 상품 기록이 그 id를 참조하기 때문이다.

### 추천 검색어 바꾸기

```sql
update public.search_suggestions set keyword = '무향 핸드크림' where id = 'suggestion_2';
```

---

## 9. 자주 나는 오류와 해결

| 증상 | 원인 | 해결 |
|---|---|---|
| 앱에 예전 Mock 상품만 보인다 | `--dart-define`을 안 넘겼거나 오타 | 콘솔 로그를 확인한다. URL 끝에 `/`를 붙이지 않는다 |
| `relation "public.products" does not exist` | 4-1을 실행하지 않았다 | migration SQL부터 실행한다 |
| seed 실행 시 `violates foreign key constraint` | 순서가 바뀌었다 | migration → seed 순서로 다시 실행한다 |
| 표에는 데이터가 있는데 앱은 비어 있다 | `is_active`가 false거나 RLS 정책이 지워졌다 | `select * from public.products where is_active;` 로 확인 |
| `Invalid API key` | 키를 잘못 복사했다 | Settings → API 에서 **Publishable** 키를 다시 복사 |
| 연결을 거부했다는 로그가 뜬다 | service_role 키를 넣었다 | Publishable 키로 바꾼다 |
| `SocketException` / 타임아웃 | 네트워크 문제, 또는 에뮬레이터가 인터넷에 못 나감 | 앱은 6초 후 Mock 데이터로 넘어간다. 네트워크를 확인한다 |
| `permission denied for table products` | RLS 읽기 정책이 없다 | migration SQL의 policy 부분을 다시 실행한다 |
| 상품을 지웠더니 찜 목록이 이상하다 | 참조하던 id가 사라졌다 | 삭제 대신 `is_active = false`를 쓴다. 앱은 없는 id를 조용히 건너뛴다 |

---

## 10. 지금 단계에서 하지 않는 것

- 로그인 / 회원가입 / 사용자별 동기화
- 앱에서 Supabase에 쓰기(상품 등록·수정)
- 결제, 실제 판매 링크, 실시간 가격·재고
- 이미지 업로드(Storage) — 지금은 카테고리별 로컬 그림을 쓴다
- `collections` 표는 만들어 두었지만 홈 화면은 아직 앱 내부 규칙으로 큐레이션한다.
  홈을 원격에서 관리하는 작업은 다음 단계다.
