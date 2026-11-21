-- DDL для ClickHouse (Задание З07)
-- Движок: MergeTree, деньги: Decimal(38, 2)

DROP TABLE IF EXISTS fact_orders;
DROP TABLE IF EXISTS dim_products;
DROP TABLE IF EXISTS dim_customers;

-- 1. Таблица фактов заказов
CREATE TABLE fact_orders (
    order_id String,
    order_date Date,
    customer_id String,
    product_id String,
    category String,
    quantity Int32,
    price Decimal(38, 2),
    revenue Decimal(38, 2)
) ENGINE = MergeTree()
ORDER BY (order_date, category, product_id);

-- 2. Справочник товаров
CREATE TABLE dim_products (
    product_id String,
    category String,
    price Decimal(38, 2)
) ENGINE = MergeTree()
ORDER BY (category, product_id);

-- 3. Справочник клиентов
CREATE TABLE dim_customers (
    customer_id String
) ENGINE = MergeTree()
ORDER BY (customer_id);
