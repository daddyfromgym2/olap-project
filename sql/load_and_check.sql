-- ПОЛНЫЙ АВТОМАТИЧЕСКИЙ ELT-ПАЙПЛАЙН (Задание З05)

-- 1. ИДЕМПОТЕНТНОСТЬ: Полное удаление старых таблиц перед перезагрузкой
DROP TABLE IF EXISTS fact_orders;
DROP TABLE IF EXISTS dim_products;
DROP TABLE IF EXISTS dim_customers;

-- Пересоздаем структуру "Звезды" с нуля
CREATE TABLE dim_products (
    product_id VARCHAR PRIMARY KEY,
    category VARCHAR
);

CREATE TABLE dim_customers (
    customer_id VARCHAR PRIMARY KEY
);

CREATE TABLE fact_orders (
    order_id VARCHAR,
    order_date DATE,
    customer_id VARCHAR,
    product_id VARCHAR,
    quantity INTEGER,
    price DECIMAL(15, 2),
    revenue DECIMAL(15, 2)
);

-- 2. ПРОВЕРКИ КАЧЕСТВА ДАННЫХ (Data Quality)
SELECT COUNT(*) AS check_negative_values 
FROM read_csv_auto('data/raw/orders.csv') 
WHERE quantity <= 0 OR price <= 0 OR revenue <= 0;

SELECT COUNT(*) AS check_null_keys 
FROM read_csv_auto('data/raw/orders.csv') 
WHERE order_id IS NULL OR customer_id IS NULL OR product_id IS NULL;


-- 3. ЗАГРУЗКА СПРАВОЧНИКОВ (Строго РАНЬШЕ таблицы фактов, с группировкой от дублей)
INSERT INTO dim_products
SELECT product_id, ANY_VALUE(category) AS category
FROM read_csv_auto('data/raw/orders.csv')
WHERE product_id IS NOT NULL
GROUP BY product_id;

INSERT INTO dim_customers
SELECT customer_id 
FROM read_csv_auto('data/raw/orders.csv')
WHERE customer_id IS NOT NULL
GROUP BY customer_id;


-- 4. ЗАГРУЗКА ТАБЛИЦЫ ФАКТОВ
INSERT INTO fact_orders
SELECT order_id, order_date, customer_id, product_id, quantity, price, revenue
FROM read_csv_auto('data/raw/orders.csv');


-- 5. КОНТРОЛЬНЫЙ СЪЕМ МЕТРИК ДЛЯ ЛОГА СДАЧИ
SELECT 'fact_orders_rows' AS metric_name, COUNT(*) AS metric_value FROM fact_orders
UNION ALL
SELECT 'canonical_total_revenue', SUM(revenue) FROM fact_orders;
