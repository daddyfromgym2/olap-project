-- Скрипт создания таблиц схемы "Звезда" в DuckDB (Задание З03)

-- 1. Очистка таблиц перед созданием (Защита от дублирования при повторном запуске)
DROP TABLE IF EXISTS fact_orders;
DROP TABLE IF EXISTS dim_products;
DROP TABLE IF EXISTS dim_customers;

-- 2. Создание справочника товаров (Измерение)
CREATE TABLE dim_products (
    product_id VARCHAR PRIMARY KEY,
    category VARCHAR
);

-- 3. Создание справочника клиентов (Измерение)
CREATE TABLE dim_customers (
    customer_id VARCHAR PRIMARY KEY
);

-- 4. Создание таблицы фактов заказов (События)
-- Зернистость: одна строка = одна позиция в чеке
CREATE TABLE fact_orders (
    order_id VARCHAR,
    order_date DATE,
    customer_id VARCHAR,
    product_id VARCHAR,
    quantity INTEGER,
    price DECIMAL(15, 2),  -- Используем DECIMAL вместо FLOAT, чтобы копейки не разъехались
    revenue DECIMAL(15, 2) -- Главная мера (quantity * price)
);
