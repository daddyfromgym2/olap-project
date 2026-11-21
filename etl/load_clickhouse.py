import urllib.request
import urllib.parse

CH_URL = "http://localhost:8123/"

def run_ch(query: str, data: bytes = None) -> str:
    url = CH_URL + "?" + urllib.parse.urlencode({"query": query})
    req = urllib.request.Request(url, data=data, method="POST")
    with urllib.request.urlopen(req) as resp:
        return resp.read().decode("utf-8").strip()

def load_data():
    # 1. Идемпотентное пересоздание таблиц (защита от дублей при повторном запуске)
    with open("sql/ddl_clickhouse.sql", "r", encoding="utf-8") as f:
        ddl_script = f.read()
    for stmt in ddl_script.split(";"):
        stmt = stmt.strip()
        if stmt:
            run_ch(stmt)

    # 2. Загрузка сырья в fact_orders
    with open("data/raw/orders.csv", "rb") as f:
        csv_bytes = f.read()
    run_ch("INSERT INTO fact_orders FORMAT CSVWithNames", data=csv_bytes)

    # 3. Наполнение справочников из загруженных фактов
    run_ch("""
        INSERT INTO dim_products
        SELECT DISTINCT product_id, category, price FROM fact_orders
    """)
    run_ch("""
        INSERT INTO dim_customers
        SELECT DISTINCT customer_id FROM fact_orders
    """)

if __name__ == "__main__":
    print("=== ПРОГОН 1: Первичная загрузка в ClickHouse ===")
    load_data()
    res1 = run_ch("SELECT count() AS rows, sum(revenue) AS total_revenue FROM fact_orders FORMAT PrettyCompact")
    print(res1)

    print("\n=== ПРОГОН 2: Повторный запуск (проверка защиты от дублей) ===")
    load_data()
    res2 = run_ch("SELECT count() AS rows, sum(revenue) AS total_revenue FROM fact_orders FORMAT PrettyCompact")
    print(res2)

    print("\n=== СВОДКА ПО ТАБЛИЦАМ CLICKHOUSE ===")
    summary = run_ch("""
        SELECT 'fact_orders' AS table_name, count() AS row_count, toString(sum(revenue)) AS canonical_metric FROM fact_orders
        UNION ALL
        SELECT 'dim_products', count(), '-' FROM dim_products
        UNION ALL
        SELECT 'dim_customers', count(), '-' FROM dim_customers
        FORMAT PrettyCompact
    """)
    print(summary)
