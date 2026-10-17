-- АНАЛИТИЧЕСКИЙ SQL (Задание З04)

-- Вопрос 1: Какой общий оборот продаж (revenue) по каждой категории товаров за весь доступный период?
-- Тип: Группировка (GROUP BY) и сортировка
SELECT 
    p.category,
    SUM(f.revenue) AS total_category_revenue
FROM fact_orders f
JOIN dim_products p ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY total_category_revenue DESC;


-- Вопрос 2: Кто входит в Топ-5 клиентов по объёму выкупленных товаров (quantity)?
-- Тип: Ограничение выборки (LIMIT) и сортировка
SELECT 
    customer_id,
    SUM(quantity) AS total_items_bought
FROM fact_orders
GROUP BY customer_id
ORDER BY total_items_bought DESC
LIMIT 5;


-- Вопрос 3: Какова доля каждой категории товара в общем объёме выручки магазина?
-- Тип: Оконная функция (SUM() OVER ()) для расчета долей без схлопывания строк
SELECT 
    p.category,
    SUM(f.revenue) AS category_revenue,
    -- Оконная функция считает общую сумму по всей таблице для вычисления процента доли
    ROUND(SUM(f.revenue) * 100.0 / SUM(SUM(f.revenue)) OVER (), 2) AS revenue_percentage
FROM fact_orders f
JOIN dim_products p ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue_percentage DESC;
