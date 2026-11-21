-- ============================================================================
-- ЗАДАНИЕ З08: ЭТАЛОН МЕТРИКИ И АНАЛИТИЧЕСКИЕ ЗАПРОСЫ В CLICKHOUSE
-- ============================================================================

-- 0. Эталон главной метрики (сверка с sql/canonical_metric.sql)
SELECT
    'canonical_total_revenue' AS metric_name,
    count() AS total_orders,
    sum(revenue) AS canonical_total_revenue
FROM fact_orders;

-- 1. Вопрос 1 (фильтрация по ключу сортировки + группировка):
-- Выручка и объём продаж по категориям за 1-й квартал 2026 года (использует префикс ORDER BY: order_date, category)
SELECT
    category,
    count() AS orders_count,
    sum(quantity) AS items_sold,
    sum(revenue) AS q1_category_revenue
FROM fact_orders
WHERE order_date >= '2026-01-01' AND order_date <= '2026-03-31'
GROUP BY category
ORDER BY q1_category_revenue DESC;

-- 2. Вопрос 2 (топ-5 клиентов по количеству купленных товаров за весь период):
SELECT
    customer_id,
    count() AS orders_count,
    sum(quantity) AS total_items_bought,
    sum(revenue) AS customer_total_spend
FROM fact_orders
GROUP BY customer_id
ORDER BY total_items_bought DESC, customer_total_spend DESC
LIMIT 5;

-- 3. Вопрос 3 (оконная функция: доля каждой категории в общей выручке):
SELECT
    category,
    sum(revenue) AS category_revenue,
    round(100.0 * toFloat64(sum(revenue)) / toFloat64(sum(sum(revenue)) OVER ()), 2) AS revenue_share_pct
FROM fact_orders
GROUP BY category
ORDER BY category_revenue DESC;
