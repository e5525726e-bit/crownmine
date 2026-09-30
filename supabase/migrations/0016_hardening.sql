-- 安全強化
-- 1. 店家快取：一般使用者只能新增（寫評價前建立那一列），不能改別人已存在的店名、地址；
--    更新交給後端函式（service role）在向 Google 查詳細資料時自動刷新
drop policy if exists "places update" on public.places;

-- 2. 每人每日寫入上限（防灌水、防機器人）
create or replace function public.enforce_daily_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  n integer;
  lim integer := tg_argv[0]::integer;
  col text := tg_argv[1];
  uid uuid := auth.uid();
begin
  if uid is null then return new; end if;
  execute format('select count(*) from %I.%I where %I = $1 and created_at > now() - interval ''1 day''',
                 tg_table_schema, tg_table_name, col)
    into n using uid;
  if n >= lim then
    raise exception '今天的次數已達上限（%），明天再試', lim using errcode = 'P0001';
  end if;
  return new;
end $$;
revoke all on function public.enforce_daily_limit() from public, anon, authenticated;

drop trigger if exists reviews_daily_limit on public.reviews;
create trigger reviews_daily_limit before insert on public.reviews
  for each row execute function public.enforce_daily_limit('30', 'user_id');

drop trigger if exists reports_daily_limit on public.reports;
create trigger reports_daily_limit before insert on public.reports
  for each row execute function public.enforce_daily_limit('20', 'reporter_id');

-- 3. 顯示名稱不能夾帶換行、控制字元
alter table public.profiles drop constraint if exists profiles_display_name_clean;
alter table public.profiles add constraint profiles_display_name_clean
  check (display_name !~ '[[:cntrl:]]') not valid;
