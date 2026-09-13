-- Giftmap · 가전 분류와 판매처별 Offer
-- 실행 순서: 0001 → seed/0002 → 0003 → 0004 → 0005 → 이 파일

insert into public.categories (id, label, group_id, group_label, sort_order) values
  ('appliance', '가전·디지털', 'appliance', '가전·디지털', 25)
on conflict (id) do update set
  label = excluded.label, group_id = excluded.group_id, group_label = excluded.group_label;

-- 같은 상품을 여러 판매처에서 팔 때 판매처별 URL·가격을 보존한다.
-- products 행은 대표 정보(가장 싼 판매 중 offer)를 갖고, 나머지는 여기에 남는다.
create table if not exists public.product_offers (
  product_id   text        not null references public.products (id)
                           on update cascade on delete cascade,
  source       text        not null,
  source_url   text        not null,
  price        integer     check (price is null or price > 0),
  in_stock     boolean,
  collected_at timestamptz not null default now(),
  primary key (product_id, source)
);

create index if not exists product_offers_product_idx
  on public.product_offers (product_id, price);

alter table public.product_offers enable row level security;

drop policy if exists "product_offers: read active" on public.product_offers;
create policy "product_offers: read active"
  on public.product_offers for select
  to anon, authenticated
  using (
    exists (select 1 from public.products p
            where p.id = product_id and p.is_active)
  );

comment on table public.product_offers is
  '판매처별 가격·URL. 중복 통합으로 products 에서 빠진 판매처 정보를 잃지 않기 위해 둔다.';
