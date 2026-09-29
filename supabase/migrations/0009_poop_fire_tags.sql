-- 「難吃／態度環境很差」（大便）從核心判斷改為附加標籤；新增「超好吃／必吃」（火焰）標籤
-- 1. 舊的大便評價：判斷改為地雷，並加上 poop 標籤
update public.reviews
  set verdict = 'mine', tags = array_append(tags, 'poop')
  where verdict = 'poop' and not ('poop' = any(tags));
update public.reviews set verdict = 'mine' where verdict = 'poop';

-- 2. 之後禁止再寫入 poop 判斷（enum 值無法移除，只能用 check 擋）
alter table public.reviews drop constraint if exists reviews_verdict_check;
alter table public.reviews add constraint reviews_verdict_check check (verdict <> 'poop');

-- 3. tags 檢查條件加入 poop、fire
alter table public.reviews drop constraint if exists reviews_tags_check;
alter table public.reviews
  add constraint reviews_tags_check check (tags <@ array['fire', 'ig', 'photogenic', 'date', 'poop']);

-- 4. 重建統計 view：poops 改為標籤計數，新增 fires
drop view if exists public.place_stats;
create view public.place_stats
with (security_invoker = true) as
select
  place_id,
  count(*) filter (where verdict = 'crown') as crowns,
  count(*) filter (where verdict = 'rich')  as richs,
  count(*) filter (where verdict = 'green') as greens,
  count(*) filter (where verdict = 'mine')  as mines,
  count(*) filter (where 'poop' = any(tags))       as poops,
  count(*) filter (where 'ig' = any(tags))         as igs,
  count(*) filter (where 'photogenic' = any(tags)) as photogenics,
  count(*) filter (where 'date' = any(tags))       as dates,
  count(*) filter (where 'fire' = any(tags))       as fires
from public.reviews
where status = 'visible'
group by place_id;

-- 5. RPC 回傳多一欄 fires（型別改變需先 drop），排序改為四種合計
drop function if exists public.search_reviewed_places(text);
create function public.search_reviewed_places(q text)
returns table (
  place_id text, name text, address text, lat double precision, lng double precision,
  crowns bigint, greens bigint, mines bigint, poops bigint,
  igs bigint, photogenics bigint, richs bigint, dates bigint, fires bigint
) language sql stable set search_path = public as $$
  select p.place_id, p.name, p.address, p.lat, p.lng,
         s.crowns, s.greens, s.mines, s.poops, s.igs, s.photogenics, s.richs, s.dates, s.fires
  from public.places p
  join public.place_stats s on s.place_id = p.place_id
  where q = '' or p.name ilike '%' || q || '%' or p.address ilike '%' || q || '%'
  order by (s.crowns + s.richs + s.greens + s.mines) desc, p.name
  limit 50;
$$;

drop function if exists public.places_in_bounds(double precision, double precision, double precision, double precision);
create function public.places_in_bounds(
  min_lat double precision, min_lng double precision,
  max_lat double precision, max_lng double precision
)
returns table (
  place_id text, name text, address text, lat double precision, lng double precision,
  crowns bigint, greens bigint, mines bigint, poops bigint,
  igs bigint, photogenics bigint, richs bigint, dates bigint, fires bigint
) language sql stable set search_path = public as $$
  select p.place_id, p.name, p.address, p.lat, p.lng,
         s.crowns, s.greens, s.mines, s.poops, s.igs, s.photogenics, s.richs, s.dates, s.fires
  from public.places p
  join public.place_stats s on s.place_id = p.place_id
  where p.lat between min_lat and max_lat
    and p.lng between min_lng and max_lng
  order by (s.crowns + s.richs + s.greens + s.mines) desc
  limit 200;
$$;
