-- 負評（地雷判斷或大便標籤）必須寫至少 10 字說明（伺服器端也擋，避免繞過 App）
alter table public.reviews drop constraint if exists reviews_negative_body_check;
alter table public.reviews add constraint reviews_negative_body_check
  check (
    (verdict <> 'mine' and not ('poop' = any(tags)))
    or char_length(btrim(body)) >= 10
  ) not valid;  -- 只對新資料生效，舊評價不動
