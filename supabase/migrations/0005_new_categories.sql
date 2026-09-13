-- Giftmap · 실제 상품 공급원이 늘면서 필요해진 분류
-- 실행 순서: 0001 → seed/0002 → 0003 → 0004 → 이 파일

insert into public.categories (id, label, group_id, group_label, sort_order) values
  ('fashion_clothing', '의류',   'fashion', '패션',      20),
  ('bag',              '가방',   'fashion', '패션',      21),
  ('shoes',            '신발',   'fashion', '패션',      22),
  ('book',             '책',     'culture', '문화·취미', 23),
  ('music',            '음반',   'culture', '문화·취미', 24)
on conflict (id) do update set
  label       = excluded.label,
  group_id    = excluded.group_id,
  group_label = excluded.group_label;
