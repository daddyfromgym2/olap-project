-- ЭТАЛОН ГЛАВНОЙ МЕТРИКИ (Задание З04)
-- Название: Общий оборот продаж (Total Revenue)
-- Критически важно: это число должно сойтись на дашборде в задании З11!

SELECT 
    SUM(revenue) AS canonical_total_revenue 
FROM fact_orders;
