-- ============================================================================
-- ЗАДАНИЕ З09: СВОДНАЯ ВИТРИНА ПОД ГРАФИК (MATERIALIZED VIEW + SUMMINGMERGETREE)
-- Будущий график (З10): Линейный / столбчатый график "Динамика выручки по дням и категориям"
-- Зерно сводки: одна строка = один день (order_date) x одна категория (category)
-- ============================================================================

DROP VIEW IF EXISTS mv_daily_category_sales;
DROP TABLE IF EXISTS mart_daily_category_sales;

-- 1. Целевая сводная таблица (агрегат на SummingMergeTree)
CREATE TABLE mart_daily_category_sales (
    order_date Date,
    category String,
    orders_count UInt64,
    units_sold Int64,
    revenue_sum Decimal(38, 2)
) ENGINE = SummingMergeTree((orders_count, units_sold, revenue_sum))
ORDER BY (order_date, category);

-- 2. Materialized View: автоматически обновляет сводку при новых вставках в fact_orders
CREATE MATERIALIZED VIEW mv_daily_category_sales
TO mart_daily_category_sales
AS
SELECT
    order_date,
    category,
    count() AS orders_count,
    sum(quantity) AS units_sold,
    sum(revenue) AS revenue_sum
FROM fact_orders
GROUP BY order_date, category;

-- 3. Наполнение сводки историческими данными, уже лежащими в fact_orders
INSERT INTO mart_daily_category_sales
SELECT
    order_date,
    category,
    count() AS orders_count,
    sum(quantity) AS units_sold,
    sum(revenue) AS revenue_sum
FROM fact_orders
GROUP BY order_date, category;

-- 4. СВЕРКА 1: Контрольный месяц (Январь 2026) — детальный факт vs сводная витрина
SELECT
    'Jan 2026 Reconciliation' AS check_name,
    (SELECT count() FROM fact_orders WHERE order_date BETWEEN '2026-01-01' AND '2026-01-31') AS fact_orders_cnt,
    (SELECT sum(orders_count) FROM mart_daily_category_sales WHERE order_date BETWEEN '2026-01-01' AND '2026-01-31') AS mart_orders_cnt,
    (SELECT sum(revenue) FROM fact_orders WHERE order_date BETWEEN '2026-01-01' AND '2026-01-31') AS fact_jan_revenue,
    (SELECT sum(revenue_sum) FROM mart_daily_category_sales WHERE order_date BETWEEN '2026-01-01' AND '2026-01-31') AS mart_jan_revenue;

-- 5. СВЕРКА 2: Полный период (сжатие строк и 100% сходимость с эталонной метрикой)
SELECT
    (SELECT count() FROM fact_orders) AS detailed_fact_rows,
    (SELECT count() FROM mart_daily_category_sales) AS aggregated_mart_rows,
    (SELECT sum(revenue) FROM fact_orders) AS canonical_fact_revenue,
    (SELECT sum(revenue_sum) FROM mart_daily_category_sales) AS mart_total_revenue;
