-- 新增第五種核心判斷「好吃便宜又大碗」（第二步：統計加 rices，RPC 回傳型別改變需先 drop）
drop view if exists public.place_stats;
create view public.place_stats
with (security_invoker = true) as
select
  place_id,
  count(*) filter (where verdict = 'crown') as crowns,
  count(*) filter (where verdict = 'rice')  as rices,
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

drop function if exists public.search_reviewed_places(text);
create function public.search_reviewed_places(q text)
returns table (
  place_id text, name text, address text, lat double precision, lng double precision,
  primary_type text, types text[],
  crowns bigint, greens bigint, mines bigint, poops bigint,
  igs bigint, photogenics bigint, richs bigint, dates bigint, fires bigint, rices bigint
) language sql stable set search_path = public as $$
  select p.place_id, p.name, p.address, p.lat, p.lng, p.primary_type, p.types,
         s.crowns, s.greens, s.mines, s.poops, s.igs, s.photogenics, s.richs, s.dates, s.fires, s.rices
  from public.places p
  join public.place_stats s on s.place_id = p.place_id
  where q = '' or p.name ilike '%' || q || '%' or p.address ilike '%' || q || '%'
  order by (s.crowns + s.rices + s.richs + s.greens + s.mines) desc, p.name
  limit 50;
$$;

drop function if exists public.places_in_bounds(double precision, double precision, double precision, double precision);
create function public.places_in_bounds(
  min_lat double precision, min_lng double precision,
  max_lat double precision, max_lng double precision
)
returns table (
  place_id text, name text, address text, lat double precision, lng double precision,
  primary_type text, types text[],
  crowns bigint, greens bigint, mines bigint, poops bigint,
  igs bigint, photogenics bigint, richs bigint, dates bigint, fires bigint, rices bigint
) language sql stable set search_path = public as $$
  select p.place_id, p.name, p.address, p.lat, p.lng, p.primary_type, p.types,
         s.crowns, s.greens, s.mines, s.poops, s.igs, s.photogenics, s.richs, s.dates, s.fires, s.rices
  from public.places p
  join public.place_stats s on s.place_id = p.place_id
  where p.lat between min_lat and max_lat
    and p.lng between min_lng and max_lng
  order by (s.crowns + s.rices + s.richs + s.greens + s.mines) desc
  limit 200;
$$;
