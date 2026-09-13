-- Giftmap · 수집 출처 컬럼
-- 실행 순서: 0001_init_schema.sql → seed/0002_seed_demo_data.sql → 이 파일
--
-- source 가 null 이면 번들 데모 데이터, 값이 있으면 crawler/ 가 수집한 실제 상품이다.
-- 실제/데모 구분은 is_demo 로 하고, source 는 어느 공급원에서 왔는지를 남긴다.

alter table public.products
  add column if not exists source            text,
  add column if not exists source_product_id text,
  add column if not exists source_url        text,
  add column if not exists collected_at      timestamptz;

create unique index if not exists products_source_unique_idx
  on public.products (source, source_product_id)
  where source is not null;

create index if not exists products_real_idx
  on public.products (is_demo, sort_order, id) where is_active;

comment on column public.products.source is '수집 공급원 id (예: 10x10). null 이면 번들 데모 데이터.';
comment on column public.products.collected_at is '수집 시각. 재수집하면 갱신된다.';
