-- 「老子有錢不差錢」從附加標籤改為第五種核心判斷（第二步）
-- 1. 舊的 rich 標籤：轉成該則評價的判斷（原本是皇冠或綠燈者才轉，負面評價不動），再從 tags 移除
update public.reviews set verdict = 'rich'
  where 'rich' = any(tags) and verdict in ('crown', 'green');
update public.reviews set tags = array_remove(tags, 'rich') where 'rich' = any(tags);

-- 2. tags 檢查條件改為三種
alter table public.reviews drop constraint if exists reviews_tags_check;
alter table public.reviews
  add constraint reviews_tags_check check (tags <@ array['ig', 'photogenic', 'date']);

-- 3. 重建統計 view（richs 改為判斷計數；欄位名稱不變，RPC 回傳型別不變）
drop view if exists public.place_stats;
create view public.place_stats
with (security_invoker = true) as
select
  place_id,
  count(*) filter (where verdict = 'crown') as crowns,
  count(*) filter (where verdict = 'rich')  as richs,
  count(*) filter (where verdict = 'green') as greens,
  count(*) filter (where verdict = 'mine')  as mines,
  count(*) filter (where verdict = 'poop')  as poops,
  count(*) filter (where 'ig' = any(tags))         as igs,
  count(*) filter (where 'photogenic' = any(tags)) as photogenics,
  count(*) filter (where 'date' = any(tags))       as dates
from public.reviews
where status = 'visible'
group by place_id;

-- 4. 搜尋與地圖 RPC：排序改為五種合計
create or replace function public.search_reviewed_places(q text)
returns table (
  place_id text, name text, address text, lat double precision, lng double precision,
  crowns bigint, greens bigint, mines bigint, poops bigint,
  igs bigint, photogenics bigint, richs bigint, dates bigint
) language sql stable set search_path = public as $$
  select p.place_id, p.name, p.address, p.lat, p.lng,
         s.crowns, s.greens, s.mines, s.poops, s.igs, s.photogenics, s.richs, s.dates
  from public.places p
  join public.place_stats s on s.place_id = p.place_id
  where q = '' or p.name ilike '%' || q || '%' or p.address ilike '%' || q || '%'
  order by (s.crowns + s.richs + s.greens + s.mines + s.poops) desc, p.name
  limit 50;
$$;

create or replace function public.places_in_bounds(
  min_lat double precision, min_lng double precision,
  max_lat double precision, max_lng double precision
)
returns table (
  place_id text, name text, address text, lat double precision, lng double precision,
  crowns bigint, greens bigint, mines bigint, poops bigint,
  igs bigint, photogenics bigint, richs bigint, dates bigint
) language sql stable set search_path = public as $$
  select p.place_id, p.name, p.address, p.lat, p.lng,
         s.crowns, s.greens, s.mines, s.poops, s.igs, s.photogenics, s.richs, s.dates
  from public.places p
  join public.place_stats s on s.place_id = p.place_id
  where p.lat between min_lat and max_lat
    and p.lng between min_lng and max_lng
  order by (s.crowns + s.richs + s.greens + s.mines + s.poops) desc
  limit 200;
$$;
