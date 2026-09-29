-- 一次性：清掉今天的照片次數（測試期間額度被縮圖用完）
delete from public.api_usage where subject like '%:photo' and day = current_date;
