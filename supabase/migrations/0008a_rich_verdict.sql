-- 「老子有錢不差錢」從附加標籤改為第五種核心判斷（第一步：加 enum 值，須獨立一次交易）
alter type public.verdict add value if not exists 'rich' after 'crown';
