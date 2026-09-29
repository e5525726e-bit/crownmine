-- =====================================================================
-- CrownMine 資料庫初始結構
-- 在 Supabase Dashboard → SQL Editor 貼上整份執行即可。
-- =====================================================================

create extension if not exists pg_trgm;

-- 六種標記：皇冠（真心推薦）、網美店、綠燈（普通中規中矩）、地雷（普通又貴）、IG 推薦但不推、大便（難吃／態度環境很差）
create type public.verdict as enum ('crown', 'camera', 'green', 'mine', 'igtrap', 'poop');

-- ---------------------------------------------------------------------
-- 使用者公開資料（auth.users 建立時自動產生）
-- ---------------------------------------------------------------------
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 30),
  is_banned    boolean not null default false,
  created_at   timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), '食客' || left(new.id::text, 6))
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- 店家快取
-- Google 條款：place_id 可永久保存，其他欄位最多快取 30 天，
-- App 會依 cached_at 判斷過期並重新向 Google 取得。
-- ---------------------------------------------------------------------
create table public.places (
  place_id        text primary key,
  name            text not null,
  address         text,
  lat             double precision,
  lng             double precision,
  primary_type    text,
  google_maps_uri text,
  cached_at       timestamptz not null default now()
);

create index places_name_trgm on public.places using gin (name gin_trgm_ops);
create index places_address_trgm on public.places using gin (address gin_trgm_ops);

-- ---------------------------------------------------------------------
-- 評價：一人一店一則，可修改
-- ---------------------------------------------------------------------
create table public.reviews (
  id           uuid primary key default gen_random_uuid(),
  place_id     text not null references public.places (place_id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  verdict      public.verdict not null,
  body         text not null check (char_length(body) between 10 and 2000),
  price_paid   integer check (price_paid is null or price_paid between 0 and 100000),
  visited_on   date,
  receipt_path text,                       -- 消費證明（私有 bucket）
  status       text not null default 'visible' check (status in ('visible', 'hidden', 'removed')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (place_id, user_id)
);

create index reviews_place_idx on public.reviews (place_id, status);
create index reviews_user_idx on public.reviews (user_id);

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger reviews_touch before update on public.reviews
  for each row execute function public.touch_updated_at();

create table public.review_photos (
  id           uuid primary key default gen_random_uuid(),
  review_id    uuid not null references public.reviews (id) on delete cascade,
  storage_path text not null,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 檢舉與封鎖（App Store / Play 對 UGC 的必要功能）
-- ---------------------------------------------------------------------
create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  review_id   uuid not null references public.reviews (id) on delete cascade,
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reason      text not null check (reason in ('spam', 'fake', 'harassment', 'privacy', 'other')),
  detail      text check (detail is null or char_length(detail) <= 500),
  status      text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  created_at  timestamptz not null default now(),
  unique (review_id, reporter_id)
);

-- 同一則評價被 3 位不同使用者檢舉就先自動隱藏，等待人工審核。
create or replace function public.auto_hide_reported_review()
returns trigger language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  select count(distinct reporter_id) into n
  from public.reports where review_id = new.review_id and status = 'open';
  if n >= 3 then
    update public.reviews set status = 'hidden' where id = new.review_id and status = 'visible';
  end if;
  return new;
end $$;

create trigger reports_auto_hide after insert on public.reports
  for each row execute function public.auto_hide_reported_review();

create table public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- ---------------------------------------------------------------------
-- 統計 view：每家店六種標記各幾個
-- ---------------------------------------------------------------------
create or replace view public.place_stats
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
create or replace function public.search_reviewed_places(q text)
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
create or replace function public.places_in_bounds(
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

create index places_lat_lng_idx on public.places (lat, lng);

-- Apple 規定 App 內必須能刪除帳號
create or replace function public.delete_own_account()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end $$;

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------
alter table public.profiles      enable row level security;
alter table public.places        enable row level security;
alter table public.reviews       enable row level security;
alter table public.review_photos enable row level security;
alter table public.reports       enable row level security;
alter table public.blocks        enable row level security;

-- profiles：大家可讀，只能改自己
create policy "profiles read"   on public.profiles for select using (true);
create policy "profiles update" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- places：大家可讀，登入者可寫（快取）
create policy "places read"   on public.places for select using (true);
create policy "places insert" on public.places for insert to authenticated with check (true);
create policy "places update" on public.places for update to authenticated using (true) with check (true);

-- reviews：只看得到 visible、且沒被自己封鎖的作者；自己的評價不論狀態都看得到
create policy "reviews read" on public.reviews for select using (
  user_id = auth.uid()
  or (
    status = 'visible'
    and not exists (
      select 1 from public.blocks b
      where b.blocker_id = auth.uid() and b.blocked_id = reviews.user_id
    )
    and not exists (
      select 1 from public.profiles pr where pr.id = reviews.user_id and pr.is_banned
    )
  )
);
create policy "reviews insert" on public.reviews for insert to authenticated with check (
  user_id = auth.uid()
  and not exists (select 1 from public.profiles pr where pr.id = auth.uid() and pr.is_banned)
);
create policy "reviews update" on public.reviews for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and status <> 'removed');
create policy "reviews delete" on public.reviews for delete to authenticated using (user_id = auth.uid());

-- review_photos：跟著評價走
create policy "photos read" on public.review_photos for select using (
  exists (select 1 from public.reviews r where r.id = review_id)
);
create policy "photos write" on public.review_photos for insert to authenticated with check (
  exists (select 1 from public.reviews r where r.id = review_id and r.user_id = auth.uid())
);
create policy "photos delete" on public.review_photos for delete to authenticated using (
  exists (select 1 from public.reviews r where r.id = review_id and r.user_id = auth.uid())
);

-- reports：只能新增自己的檢舉、看自己的檢舉
create policy "reports insert" on public.reports for insert to authenticated with check (reporter_id = auth.uid());
create policy "reports read own" on public.reports for select to authenticated using (reporter_id = auth.uid());

-- blocks：只管自己的封鎖名單
create policy "blocks all own" on public.blocks for all to authenticated
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- ---------------------------------------------------------------------
-- Storage buckets
-- review-photos：公開讀取；receipts：私有，只有本人可讀
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('review-photos', 'review-photos', true,  5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('receipts',      'receipts',      false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- 路徑規則：{user_id}/... ，第一層資料夾必須是自己的 uid
create policy "review photos public read" on storage.objects for select
  using (bucket_id = 'review-photos');
create policy "review photos own write" on storage.objects for insert to authenticated
  with check (bucket_id = 'review-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "review photos own delete" on storage.objects for delete to authenticated
  using (bucket_id = 'review-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "receipts own read" on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "receipts own write" on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
