-- Giftmap · 실제 상품 모드 컬럼
-- 실행 순서: 0001 → seed/0002 → 0003 → 이 파일
--
--  in_stock   : 품절 여부. null 이면 공급원이 알려주지 않은 것이며 품절로 단정하지 않는다.
--  dedupe_key : 공급원이 달라도 같은 상품이면 같은 값. 중복 통합에 쓴다.

alter table public.products
  add column if not exists in_stock   boolean,
  add column if not exists dedupe_key text;

create index if not exists products_dedupe_key_idx
  on public.products (dedupe_key) where dedupe_key is not null;

create index if not exists products_real_paging_idx
  on public.products (is_demo, in_stock, sort_order, id) where is_active;

comment on column public.products.in_stock is '재고 여부. null 이면 공급원이 알려주지 않은 것이며 0/false 로 단정하지 않는다.';
comment on column public.products.dedupe_key is '브랜드+상품명 정규화 키. 여러 공급원의 같은 상품을 하나로 본다.';
