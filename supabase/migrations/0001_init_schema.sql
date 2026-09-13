-- Giftmap · Supabase 초기 스키마
-- 실행 순서: 1) 이 파일  2) seed/0002_seed_demo_data.sql
--
-- 읽기: 앱(anon 키)은 is_active = true 인 행만 SELECT 할 수 있다.
-- 쓰기: INSERT/UPDATE/DELETE 정책을 만들지 않았으므로 anon 키로는 불가능하다.
--       상품 추가·수정은 Supabase Dashboard(Table Editor / SQL Editor)에서만 한다.

-- ---------------------------------------------------------------------------
-- 공통: updated_at 자동 갱신
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- categories : 상품 분류 (예: perfume = 향수)
-- ---------------------------------------------------------------------------
create table if not exists public.categories (
  id          text primary key,
  label       text        not null,
  group_id    text,
  group_label text,
  description text,
  sort_order  integer     not null default 0,
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists categories_active_order_idx
  on public.categories (is_active, sort_order, id);

drop trigger if exists categories_set_updated_at on public.categories;
create trigger categories_set_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- products : 상품 본체
--   price 가 null 이면 앱은 "가격 확인 필요"로 표시한다. 0 으로 넣지 말 것.
--   product_url 이 null 이면 앱의 구매 버튼은 비활성 상태로 유지된다.
-- ---------------------------------------------------------------------------
create table if not exists public.products (
  id                      text primary key,
  brand_name              text,
  product_name            text        not null,
  category_id             text        references public.categories (id)
                                      on update cascade on delete set null,
  sub_category            text,
  price                   integer     check (price is null or price > 0),
  original_price          integer     check (original_price is null or original_price > 0),
  discount_rate           integer     check (discount_rate is null or (discount_rate between 1 and 99)),
  image_asset             text,
  image_url               text,
  product_url             text,
  tags                    text[]      not null default '{}',
  occasions               text[]      not null default '{}',
  recipient_types         text[]      not null default '{}',
  gender_target           text,
  age_range               text[]      not null default '{}',
  price_range             text,
  recommendation_keywords text[]      not null default '{}',
  description             text        not null default '',
  recommendation_reason   text        not null default '',
  is_demo                 boolean     not null default true,
  is_active               boolean     not null default true,
  sort_order              integer     not null default 0,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create index if not exists products_active_idx
  on public.products (is_active, sort_order, id);
create index if not exists products_category_idx
  on public.products (category_id) where is_active;
create index if not exists products_price_idx
  on public.products (price) where is_active;
create index if not exists products_occasions_idx
  on public.products using gin (occasions);
create index if not exists products_recipients_idx
  on public.products using gin (recipient_types);
create index if not exists products_tags_idx
  on public.products using gin (tags);

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- product_categories : 상품이 여러 분류에 걸칠 때 쓰는 연결 표
-- ---------------------------------------------------------------------------
create table if not exists public.product_categories (
  product_id  text not null references public.products (id)
                   on update cascade on delete cascade,
  category_id text not null references public.categories (id)
                   on update cascade on delete cascade,
  is_primary  boolean not null default false,
  sort_order  integer not null default 0,
  primary key (product_id, category_id)
);

create index if not exists product_categories_category_idx
  on public.product_categories (category_id, sort_order);

-- ---------------------------------------------------------------------------
-- collections : 홈 큐레이션 묶음 (예: "요즘 눈여겨볼 선물")
-- ---------------------------------------------------------------------------
create table if not exists public.collections (
  id          text primary key,
  title       text        not null,
  subtitle    text,
  sort_order  integer     not null default 0,
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists collections_active_order_idx
  on public.collections (is_active, sort_order, id);

drop trigger if exists collections_set_updated_at on public.collections;
create trigger collections_set_updated_at
  before update on public.collections
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- collection_products : 큐레이션에 담긴 상품과 순서
-- ---------------------------------------------------------------------------
create table if not exists public.collection_products (
  collection_id text not null references public.collections (id)
                     on update cascade on delete cascade,
  product_id    text not null references public.products (id)
                     on update cascade on delete cascade,
  sort_order    integer not null default 0,
  primary key (collection_id, product_id)
);

create index if not exists collection_products_order_idx
  on public.collection_products (collection_id, sort_order);

-- ---------------------------------------------------------------------------
-- search_suggestions : 검색 화면의 추천 검색어
-- ---------------------------------------------------------------------------
create table if not exists public.search_suggestions (
  id         text primary key,
  keyword    text        not null,
  sort_order integer     not null default 0,
  is_active  boolean     not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists search_suggestions_active_order_idx
  on public.search_suggestions (is_active, sort_order, id);

drop trigger if exists search_suggestions_set_updated_at on public.search_suggestions;
create trigger search_suggestions_set_updated_at
  before update on public.search_suggestions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS : 모든 표에 켜고, "활성 데이터 읽기"만 허용한다.
-- ---------------------------------------------------------------------------
alter table public.categories          enable row level security;
alter table public.products            enable row level security;
alter table public.product_categories  enable row level security;
alter table public.collections         enable row level security;
alter table public.collection_products enable row level security;
alter table public.search_suggestions  enable row level security;

drop policy if exists "categories: read active" on public.categories;
create policy "categories: read active"
  on public.categories for select
  to anon, authenticated
  using (is_active);

drop policy if exists "products: read active" on public.products;
create policy "products: read active"
  on public.products for select
  to anon, authenticated
  using (is_active);

-- 연결 표는 양쪽이 모두 활성일 때만 보인다.
drop policy if exists "product_categories: read active" on public.product_categories;
create policy "product_categories: read active"
  on public.product_categories for select
  to anon, authenticated
  using (
    exists (select 1 from public.products p
            where p.id = product_id and p.is_active)
    and exists (select 1 from public.categories c
                where c.id = category_id and c.is_active)
  );

drop policy if exists "collections: read active" on public.collections;
create policy "collections: read active"
  on public.collections for select
  to anon, authenticated
  using (is_active);

drop policy if exists "collection_products: read active" on public.collection_products;
create policy "collection_products: read active"
  on public.collection_products for select
  to anon, authenticated
  using (
    exists (select 1 from public.collections c
            where c.id = collection_id and c.is_active)
    and exists (select 1 from public.products p
                where p.id = product_id and p.is_active)
  );

drop policy if exists "search_suggestions: read active" on public.search_suggestions;
create policy "search_suggestions: read active"
  on public.search_suggestions for select
  to anon, authenticated
  using (is_active);

-- 쓰기 정책은 의도적으로 만들지 않는다.
-- Dashboard(SQL Editor / Table Editor)는 RLS를 우회하는 권한으로 실행되므로
-- 관리자는 그대로 추가·수정할 수 있고, 앱의 anon 키로는 쓰기가 거부된다.
