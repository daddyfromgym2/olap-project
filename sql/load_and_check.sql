-- 1. ЗАГРУЗКА ДАННЫХ ИЗ СЫРЫХ CSV ФАЙЛОВ

-- Заполняем справочник товаров уникальными значениями из сырого файла
INSERT INTO dim_products
SELECT DISTINCT product_id, category 
FROM read_csv_auto('data/raw/orders.csv');

-- Заполняем справочник клиентов уникальными значениями из сырого файла
INSERT INTO dim_customers
SELECT DISTINCT customer_id 
FROM read_csv_auto('data/raw/orders.csv');

-- Загружаем все транзакции в таблицу фактов
INSERT INTO fact_orders
SELECT order_id, order_date, customer_id, product_id, quantity, price, revenue
FROM read_csv_auto('data/raw/orders.csv');


-- 2. ПРОВЕРОЧНЫЕ ЗАПРОСЫ ДЛЯ СДАЧИ (СМОТРИМ РЕЗУЛЬТАТ)

-- Проверка 1: Сколько строк загрузилось в таблицы
SELECT 'fact_orders' AS table_name, COUNT(*) AS row_count FROM fact_orders
UNION ALL
SELECT 'dim_products', COUNT(*) FROM dim_products
UNION ALL
SELECT 'dim_customers', COUNT(*) FROM dim_customers;

-- Проверка 2: Контроль пустых ключей (Битые строки)
SELECT COUNT(*) AS broken_rows 
FROM fact_orders 
WHERE order_id IS NULL OR customer_id IS NULL OR product_id IS NULL;

-- Проверка 3: Сумма главной меры (Первая фиксация метрики)
SELECT SUM(revenue) AS total_revenue_check FROM fact_orders;
