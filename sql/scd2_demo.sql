-- ============================================================================
-- ЗАДАНИЕ З06: РЕАЛИЗАЦИЯ И АУДИТ ИСТОРИЧЕСКОГО СПРАВОЧНИКА (SCD TYPE 2)
-- ============================================================================

DROP TABLE IF EXISTS dim_products_scd2;

-- 1. DDL: Создание версионного измерения товаров
CREATE TABLE dim_products_scd2 (
    product_sk INTEGER PRIMARY KEY,
    product_id VARCHAR NOT NULL,
    category VARCHAR NOT NULL,
    price DECIMAL(38,2) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL,
    is_current BOOLEAN NOT NULL,
    change_reason VARCHAR
);

-- 2. Первичная инициализация справочника (все товары действуют с 2026-01-01)
INSERT INTO dim_products_scd2
SELECT 
    row_number() OVER (ORDER BY product_id) AS product_sk,
    product_id,
    category,
    price,
    DATE '2026-01-01' AS valid_from,
    DATE '9999-12-31' AS valid_to,
    TRUE AS is_current,
    'Initial load' AS change_reason
FROM (
    SELECT DISTINCT product_id, category, price 
    FROM 'data/raw/orders.csv'
);

-- 3. Симуляция бизнес-событий (смена категорий у товаров P01 и P05)
-- Событие 1: С 2026-06-01 товар P01 переведён из 'Электроника' в 'Умный дом и гаджеты'
UPDATE dim_products_scd2
SET valid_to = DATE '2026-05-31', is_current = FALSE
WHERE product_id = 'P01' AND is_current = TRUE;

INSERT INTO dim_products_scd2
SELECT 
    (SELECT max(product_sk) + 1 FROM dim_products_scd2),
    'P01', 'Умный дом и гаджеты', 15000.00,
    DATE '2026-06-01', DATE '9999-12-31', TRUE,
    'Rebranding: Электроника -> Умный дом и гаджеты';

-- Событие 2: С 2026-08-01 товар P05 выделен из 'Электроника' в 'Премиум-техника'
UPDATE dim_products_scd2
SET valid_to = DATE '2026-07-31', is_current = FALSE
WHERE product_id = 'P05' AND is_current = TRUE;

INSERT INTO dim_products_scd2
SELECT 
    (SELECT max(product_sk) + 1 FROM dim_products_scd2),
    'P05', 'Премиум-техника', 28000.00,
    DATE '2026-08-01', DATE '9999-12-31', TRUE,
    'Segment split: Электроника -> Премиум-техника';


-- ============================================================================
-- БЛОК 1: ЖУРНАЛ ВЕРСИЙ ИЗМЕНЁННЫХ ТОВАРОВ (SCD2 VERSION AUDIT)
-- ============================================================================
SELECT 
    product_sk AS sk,
    product_id,
    category,
    price,
    valid_from,
    valid_to,
    CASE WHEN is_current THEN 'ACTIVE' ELSE 'EXPIRED' END AS status,
    change_reason
FROM dim_products_scd2
WHERE product_id IN ('P01', 'P05')
ORDER BY product_id, valid_from;


-- ============================================================================
-- БЛОК 2: ИСТОРИЧЕСКАЯ РАЗБИВКА ВЫРУЧКИ ПО ВЕРСИЯМ (AS-OF POINT-IN-TIME JOIN)
-- ============================================================================
SELECT 
    p.product_id,
    p.category AS historical_category,
    p.valid_from || ' .. ' || p.valid_to AS active_period,
    count(f.order_id) AS orders_cnt,
    sum(f.quantity) AS units_sold,
    CAST(sum(f.revenue) AS DECIMAL(38,2)) AS historical_revenue,
    round(100.0 * sum(f.revenue) / sum(sum(f.revenue)) OVER (PARTITION BY p.product_id), 2) AS product_rev_share_pct
FROM fact_orders f
JOIN dim_products_scd2 p 
    ON f.product_id = p.product_id
    AND f.order_date BETWEEN p.valid_from AND p.valid_to
WHERE p.product_id IN ('P01', 'P05')
GROUP BY p.product_id, p.category, p.valid_from, p.valid_to
ORDER BY p.product_id, p.valid_from;


-- ============================================================================
-- БЛОК 3: СРАВНЕНИЕ SCD1 (ОШИБКА ПЕРЕЗАПИСИ) VS SCD2 (ЧЕСТНАЯ ИСТОРИЯ)
-- ============================================================================
WITH scd2_agg AS (
    SELECT p.category, CAST(sum(f.revenue) AS DECIMAL(38,2)) AS rev_scd2
    FROM fact_orders f
    JOIN dim_products_scd2 p 
        ON f.product_id = p.product_id AND f.order_date BETWEEN p.valid_from AND p.valid_to
    GROUP BY p.category
),
scd1_agg AS (
    SELECT p.category, CAST(sum(f.revenue) AS DECIMAL(38,2)) AS rev_scd1
    FROM fact_orders f
    JOIN dim_products_scd2 p 
        ON f.product_id = p.product_id AND p.is_current = TRUE
    GROUP BY p.category
)
SELECT 
    COALESCE(s2.category, s1.category) AS category_name,
    COALESCE(s1.rev_scd1, 0.00) AS naive_scd1_revenue,
    COALESCE(s2.rev_scd2, 0.00) AS true_scd2_revenue,
    COALESCE(s2.rev_scd2, 0.00) - COALESCE(s1.rev_scd1, 0.00) AS reporting_distortion_diff
FROM scd2_agg s2
FULL OUTER JOIN scd1_agg s1 ON s2.category = s1.category
ORDER BY true_scd2_revenue DESC;


-- ============================================================================
-- БЛОК 4: КОНТРОЛЬ ЦЕЛОСТНОСТИ SCD2 И СХОДИМОСТИ МЕТРИКИ (DATA QUALITY GATE)
-- ============================================================================
SELECT 
    (SELECT count(*) FROM dim_products_scd2) AS total_dim_versions,
    (SELECT count(*) FROM dim_products_scd2 WHERE is_current = TRUE) AS active_products,
    (SELECT count(*) FROM dim_products_scd2 a JOIN dim_products_scd2 b 
        ON a.product_id = b.product_id AND a.product_sk < b.product_sk 
        AND a.valid_from <= b.valid_to AND b.valid_from <= a.valid_to) AS overlapping_intervals,
    (SELECT CAST(sum(revenue) AS DECIMAL(38,2)) FROM fact_orders) AS fact_canonical_revenue,
    (SELECT CAST(sum(f.revenue) AS DECIMAL(38,2)) FROM fact_orders f 
        JOIN dim_products_scd2 p ON f.product_id = p.product_id 
        AND f.order_date BETWEEN p.valid_from AND p.valid_to) AS scd2_joined_revenue;
