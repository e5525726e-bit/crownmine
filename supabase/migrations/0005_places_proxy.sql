-- Google Places 代理：快取（Google 允許 30 天）與每日用量限制
-- 這些表只有後端函式（service role）會讀寫，前端不能直接碰。

create table if not exists public.places_cache (
  cache_key  text primary key,          -- 例：details:<place_id>、search:<query>:<lat>:<lng>、nearby:<lat>:<lng>:<r>、photo:<name>
  data       jsonb not null,
  fetched_at timestamptz not null default now()
);
create index if not exists places_cache_fetched_idx on public.places_cache (fetched_at);

create table if not exists public.api_usage (
  day     date not null,
  subject text not null,                -- user:<uuid> 或 ip:<address>
  count   integer not null default 0,
  primary key (day, subject)
);

-- 累加今日用量並回傳是否仍在上限內
create or replace function public.bump_usage(p_subject text, p_limit integer)
returns boolean language plpgsql security definer set search_path = public as $$
declare c integer;
begin
  insert into public.api_usage (day, subject, count) values (current_date, p_subject, 1)
  on conflict (day, subject) do update set count = api_usage.count + 1
  returning count into c;
  return c <= p_limit;
end $$;

alter table public.places_cache enable row level security;
alter table public.api_usage    enable row level security;
revoke all on function public.bump_usage(text, integer) from public, anon, authenticated;

-- 每天清一次 30 天以上的快取（若專案有 pg_cron 才會生效，沒有也無妨）
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('places-cache-cleanup', '17 4 * * *',
      $cron$ delete from public.places_cache where fetched_at < now() - interval '30 days';
             delete from public.api_usage where day < current_date - 7; $cron$);
  end if;
exception when others then null;
end $$;
