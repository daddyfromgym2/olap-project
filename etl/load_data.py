-- АВТОМАТИЧЕСКИЙ ELT-ПАЙПЛАЙН (Задание З05)

-- 1. ИДЕМПОТЕНТНОСТЬ: Очистка таблиц перед загрузкой (Второй прогон не удваивает данные)
TRUNCATE TABLE fact_orders;
TRUNCATE TABLE dim_products;
TRUNCATE TABLE dim_customers;

-- 2. ПРОВЕРКИ КАЧЕСТВА ДАННЫХ (Data Quality)
-- Если этот запрос вернет число больше 0, значит в сырье есть ошибки (отрицательные цены/количества)
SELECT COUNT(*) AS check_negative_values 
FROM read_csv_auto('data/raw/orders.csv') 
WHERE quantity <= 0 OR price <= 0 OR revenue <= 0;

-- Если этот запрос вернет число больше 0, значит есть пустые обязательные ключи
SELECT COUNT(*) AS check_null_keys 
FROM read_csv_auto('data/raw/orders.csv') 
WHERE order_id IS NULL OR customer_id IS NULL OR product_id IS NULL;


-- 3. ЗАГРУЗКА СПРАВОЧНИКОВ (Строго РАНЬШЕ таблицы фактов)
-- Используем ANY_VALUE, чтобы для каждого product_id взять ровно одну категорию и избежать дублирования
INSERT INTO dim_products
SELECT product_id, ANY_VALUE(category) AS category
FROM read_csv_auto('data/raw/orders.csv')
WHERE product_id IS NOT NULL
GROUP BY product_id;

-- То же самое для клиентов — группируем по customer_id
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
