-- 留言至少 5 字（負評維持 10 字，見 0010）。只對新資料生效，舊評價不動。
alter table public.reviews drop constraint if exists reviews_min_body_check;
alter table public.reviews add constraint reviews_min_body_check
  check (char_length(btrim(body)) >= 5) not valid;
