-- 新增兩種附加標籤：rich（老子有錢不差錢）、date（適合約會）
-- 1. 放寬 tags 的檢查條件（0003a 建立時未命名，Postgres 預設名稱為 reviews_tags_check）
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.reviews'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) like '%tags%'
  loop
    execute format('alter table public.reviews drop constraint %I', c.conname);
  end loop;
end $$;
alter table public.reviews
  add constraint reviews_tags_check check (tags <@ array['ig', 'photogenic', 'rich', 'date']);

-- 2. 重建統計 view 與搜尋函式（回傳型別改變，需先 drop）
drop view if exists public.place_stats;
create view public.place_stats
with (security_invoker = true) as
select
  place_id,
  count(*) filter (where verdict = 'crown') as crowns,
  count(*) filter (where verdict = 'green') as greens,
  count(*) filter (where verdict = 'mine')  as mines,
  count(*) filter (where verdict = 'poop')  as poops,
  count(*) filter (where 'ig' = any(tags))         as igs,
  count(*) filter (where 'photogenic' = any(tags)) as photogenics,
  count(*) filter (where 'rich' = any(tags))       as richs,
  count(*) filter (where 'date' = any(tags))       as dates
from public.reviews
where status = 'visible'
group by place_id;

drop function if exists public.search_reviewed_places(text);
create function public.search_reviewed_places(q text)
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
  order by (s.crowns + s.greens + s.mines + s.poops) desc, p.name
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
  igs bigint, photogenics bigint, richs bigint, dates bigint
) language sql stable set search_path = public as $$
  select p.place_id, p.name, p.address, p.lat, p.lng,
         s.crowns, s.greens, s.mines, s.poops, s.igs, s.photogenics, s.richs, s.dates
  from public.places p
  join public.place_stats s on s.place_id = p.place_id
  where p.lat between min_lat and max_lat
    and p.lng between min_lng and max_lng
  order by (s.crowns + s.greens + s.mines + s.poops) desc
  limit 200;
$$;
