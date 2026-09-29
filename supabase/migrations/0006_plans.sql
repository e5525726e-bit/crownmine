-- 方案：free / pro。pro = 付費免廣告（額度也放寬）。付費身分之後由內購服務（例如 RevenueCat webhook）寫入。
alter table public.profiles
  add column if not exists plan text not null default 'free' check (plan in ('free', 'pro')),
  add column if not exists plan_until timestamptz;

-- 目前有效的方案（付費到期就回到 free）
create or replace function public.effective_plan(p_user uuid)
returns text language sql stable security definer set search_path = public as $$
  select case
    when p.plan = 'pro' and (p.plan_until is null or p.plan_until > now()) then 'pro'
    else 'free'
  end
  from public.profiles p where p.id = p_user;
$$;
revoke all on function public.effective_plan(uuid) from public, anon, authenticated;
