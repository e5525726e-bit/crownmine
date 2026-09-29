-- 重建統計 view 與搜尋函式，加入 cameras / igtraps 欄位（回傳型別改變，需先 drop）
-- 統計 view：每家店六種標記各幾個
-- ---------------------------------------------------------------------
drop view if exists public.place_stats;
create view public.place_stats
with (security_invoker = true) as
select
  place_id,
  count(*) filter (where verdict = 'crown')  as crowns,
  count(*) filter (where verdict = 'camera') as cameras,
  count(*) filter (where verdict = 'green')  as greens,
  count(*) filter (where verdict = 'mine')   as mines,
  count(*) filter (where verdict = 'igtrap') as igtraps,
  count(*) filter (where verdict = 'poop')   as poops
from public.reviews
where status = 'visible'
group by place_id;

-- App 內搜尋評價（q 為空字串時回傳全部，依評價數排序，當作排行榜）
drop function if exists public.search_reviewed_places(text);
create function public.search_reviewed_places(q text)
returns table (
  place_id text, name text, address text, lat double precision, lng double precision,
  crowns bigint, cameras bigint, greens bigint, mines bigint, igtraps bigint, poops bigint
) language sql stable set search_path = public as $$
  select p.place_id, p.name, p.address, p.lat, p.lng,
         s.crowns, s.cameras, s.greens, s.mines, s.igtraps, s.poops
  from public.places p
  join public.place_stats s on s.place_id = p.place_id
  where q = '' or p.name ilike '%' || q || '%' or p.address ilike '%' || q || '%'
  order by (s.crowns + s.cameras + s.greens + s.mines + s.igtraps + s.poops) desc, p.name
  limit 50;
$$;

-- 地圖：回傳某個經緯度範圍內、有評價的店家（最多 200 家，評價多的優先）
drop function if exists public.places_in_bounds(double precision, double precision, double precision, double precision);
create function public.places_in_bounds(
  min_lat double precision, min_lng double precision,
  max_lat double precision, max_lng double precision
)
returns table (
  place_id text, name text, address text, lat double precision, lng double precision,
  crowns bigint, cameras bigint, greens bigint, mines bigint, igtraps bigint, poops bigint
) language sql stable set search_path = public as $$
  select p.place_id, p.name, p.address, p.lat, p.lng,
         s.crowns, s.cameras, s.greens, s.mines, s.igtraps, s.poops
  from public.places p
  join public.place_stats s on s.place_id = p.place_id
  where p.lat between min_lat and max_lat
    and p.lng between min_lng and max_lng
  order by (s.crowns + s.cameras + s.greens + s.mines + s.igtraps + s.poops) desc
  limit 200;
$$;



