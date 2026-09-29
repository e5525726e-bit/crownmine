-- 留言改為選填：放寬長度限制（0 到 2000 字）
alter table public.reviews alter column body set default '';
alter table public.reviews drop constraint if exists reviews_body_check;
alter table public.reviews add constraint reviews_body_check check (char_length(body) <= 2000);
