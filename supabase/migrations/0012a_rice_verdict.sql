-- 新增第五種核心判斷「好吃便宜又大碗」（第一步：加 enum 值，須獨立一次交易）
alter type public.verdict add value if not exists 'rice' after 'crown';
