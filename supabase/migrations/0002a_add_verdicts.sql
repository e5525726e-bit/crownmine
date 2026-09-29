-- 新增兩種標記：網美店（camera）、IG 推薦但不推（igtrap）
-- 注意：enum 新值必須先提交，才能在 view / function 中使用，所以拆成 0002a 與 0002b 兩次執行。
alter type public.verdict add value if not exists 'camera' after 'crown';
alter type public.verdict add value if not exists 'igtrap' after 'mine';
