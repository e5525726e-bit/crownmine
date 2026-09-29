-- 改為「四種核心判斷 + 附加標籤」：
-- 新增 tags 欄位。既有 enum 內的 camera / igtrap 值保留不用（Postgres 無法移除 enum 值）。
alter table public.reviews
  add column if not exists tags text[] not null default '{}'
  check (tags <@ array['ig', 'photogenic']);
