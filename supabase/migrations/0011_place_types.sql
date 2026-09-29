-- 店家快取加上 Google 類型清單，讓地圖與搜尋可依餐飲種類篩選已有評價的店
alter table public.places add column if not exists types text[] not null default '{}';

-- RPC 回傳多兩欄（primary_type, types），型別改變需先 drop
drop function if exists public.search_reviewed_places(text);
create function public.search_reviewed_places(q text)
returns table (
  place_id text, name text, address text, lat double precision, lng double precision,
  primary_type text, types text[],
  crowns bigint, greens bigint, mines bigint, poops bigint,
  igs bigint, photogenics bigint, richs bigint, dates bigint, fires bigint
) language sql stable set search_path = public as $$
  select p.place_id, p.name, p.address, p.lat, p.lng, p.primary_type, p.types,
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
  primary_type text, types text[],
  crowns bigint, greens bigint, mines bigint, poops bigint,
  igs bigint, photogenics bigint, richs bigint, dates bigint, fires bigint
) language sql stable set search_path = public as $$
  select p.place_id, p.name, p.address, p.lat, p.lng, p.primary_type, p.types,
         s.crowns, s.greens, s.mines, s.poops, s.igs, s.photogenics, s.richs, s.dates, s.fires
  from public.places p
  join public.place_stats s on s.place_id = p.place_id
  where p.lat between min_lat and max_lat
    and p.lng between min_lng and max_lng
  order by (s.crowns + s.richs + s.greens + s.mines) desc
  limit 200;
$$;
