-- Giftmap · 재고 상태와 익명 검색 집계
-- 실행 순서: 0001 → seed/0002 → 0003 → 0004 → 0005 → 0006 → 이 파일

-- 재고 상태를 명시적인 값으로 관리한다.
--   in_stock / out_of_stock / unknown (모르면 품절로 단정하지 않는다)
alter table public.products
  add column if not exists availability      text
    check (availability in ('in_stock', 'out_of_stock', 'unknown')),
  add column if not exists last_verified_at  timestamptz;

update public.products
set availability = case
      when in_stock is true then 'in_stock'
      when in_stock is false then 'out_of_stock'
      else 'unknown'
    end
where availability is null;

update public.products
set last_verified_at = coalesce(collected_at, updated_at)
where last_verified_at is null and not is_demo;

alter table public.products
  alter column availability set default 'unknown';

create index if not exists products_availability_idx
  on public.products (availability, last_verified_at desc) where is_active;

comment on column public.products.availability is
  '재고 상태. out_of_stock 이어도 행을 지우지 않고 화면에서 뒤로 보내거나 제외한다.';
comment on column public.products.last_verified_at is
  '공급원 페이지에서 마지막으로 확인한 시각. 오래된 상품은 추천 우선순위를 낮춘다.';

-- 익명 검색·클릭 집계. 개인을 식별할 수 있는 값은 저장하지 않는다.
create table if not exists public.search_events (
  id         bigint generated always as identity primary key,
  keyword    text        not null check (char_length(keyword) between 1 and 40),
  kind       text        not null default 'search'
               check (kind in ('search', 'click')),
  created_at timestamptz not null default now()
);

create index if not exists search_events_recent_idx
  on public.search_events (created_at desc, keyword);

alter table public.search_events enable row level security;

-- 앱은 넣기만 할 수 있고 읽거나 지울 수 없다.
drop policy if exists "search_events: insert only" on public.search_events;
create policy "search_events: insert only"
  on public.search_events for insert
  to anon, authenticated
  with check (char_length(keyword) between 1 and 40);

-- 집계 결과만 공개한다.
create or replace view public.search_trends
with (security_invoker = false) as
select
  keyword,
  count(*) filter (where kind = 'search')                          as searches,
  count(*) filter (where kind = 'click')                           as clicks,
  count(*) filter (where created_at > now() - interval '7 days')   as recent,
  count(*) filter (where created_at <= now() - interval '7 days')  as previous,
  max(created_at)                                                  as last_seen
from public.search_events
where created_at > now() - interval '14 days'
group by keyword
having count(*) >= 3;

grant select on public.search_trends to anon, authenticated;

comment on view public.search_trends is
  '최근 14일 익명 집계. 3회 미만 검색어는 빼서 한두 사람의 입력이 드러나지 않게 한다.';
