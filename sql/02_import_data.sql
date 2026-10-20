-- =====================================================================
-- PROJETO OLIST — Carga dos CSVs (psql + \copy)
-- =====================================================================
-- COMO RODAR (a partir da RAIZ do repositório):
--   psql -U seu_usuario -d olist -f sql/02_import_data.sql
--
-- Pré-requisitos:
--   1) Tabelas criadas com sql/01_create_schema.sql
--   2) CSVs do Kaggle salvos em dados/csv/ (ver dados/README.md)
--
-- IMPORTANTE:
--   * \copy é um comando do CLIENTE psql (não existe em SQL puro). O editor
--     SQL do DBeaver NÃO o executa. Para ficar 100% no DBeaver, veja a
--     alternativa "Import Data" no final deste arquivo.
--   * O \copy não aceita variáveis do psql (:'var') nos argumentos, e o
--     comando precisa caber em UMA linha. Por isso os caminhos abaixo são
--     literais e relativos à pasta de onde o psql foi executado.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tradução de categoria
-- ---------------------------------------------------------------------
\copy product_category_name_translation (product_category_name, product_category_name_english) FROM 'dados/csv/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ACHADO (validado nos CSVs): 2 categorias usadas em products não existem
-- na tabela de tradução: pc_gamer e portateis_cozinha_e_preparadores_de_alimentos.
-- Mesma lógica do pedido órfão em order_payments (ver 03_eda.sql, Parte 2):
-- a FK só revela o problema na hora de aplicar, não em um teste de IS NULL.
-- Resolvendo antes de carregar products, para não perder integridade nem
-- descartar produtos.
INSERT INTO product_category_name_translation (product_category_name, product_category_name_english) VALUES
    ('pc_gamer', 'pc_gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'kitchen_portables_and_food_processors')
ON CONFLICT (product_category_name) DO NOTHING;

-- ---------------------------------------------------------------------
-- 2. Sellers
-- ---------------------------------------------------------------------
\copy sellers (seller_id, seller_zip_code_prefix, seller_city, seller_state) FROM 'dados/csv/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ---------------------------------------------------------------------
-- 3. Customers
-- ---------------------------------------------------------------------
\copy customers (customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state) FROM 'dados/csv/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ---------------------------------------------------------------------
-- 4. Products (depende de product_category_name_translation)
-- ---------------------------------------------------------------------
\copy products (product_id, product_category_name, product_name_lenght, product_description_lenght, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm) FROM 'dados/csv/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ---------------------------------------------------------------------
-- 5. Orders (depende de customers)
-- ---------------------------------------------------------------------
\copy orders (order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date) FROM 'dados/csv/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ---------------------------------------------------------------------
-- 6. Order_items (depende de orders, products, sellers)
-- ---------------------------------------------------------------------
\copy order_items (order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value) FROM 'dados/csv/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ---------------------------------------------------------------------
-- 7. Order_payments (depende de orders)
-- ---------------------------------------------------------------------
\copy order_payments (order_id, payment_sequential, payment_type, payment_installments, payment_value) FROM 'dados/csv/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ---------------------------------------------------------------------
-- 8. Order_reviews (depende de orders)
-- ---------------------------------------------------------------------
\copy order_reviews (review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp) FROM 'dados/csv/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- =====================================================================
-- Conferência rápida de volume pós-import
-- Valores de referência: orders = 99.441 e sellers = 3.095.
-- (A contagem de clientes únicos é conferida em 03_eda.sql, Parte 3.)
-- =====================================================================
SELECT 'product_category_name_translation' AS tabela, COUNT(*) AS linhas FROM product_category_name_translation
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews;

-- =====================================================================
-- ALTERNATIVA: Import 100% pelo DBeaver (sem terminal/psql)
-- 1. Crie as tabelas rodando o 01_create_schema.sql no editor SQL do DBeaver
-- 2. Rode o INSERT das 2 categorias órfãs (bloco acima) ANTES de importar
--    products, senão a FK vai rejeitar a carga
-- 3. No navegador de banco, clique com o botão direito na tabela > "Import Data"
-- 4. Escolha "CSV" como fonte, aponte o arquivo e confira o mapeamento de
--    colunas (geralmente bate automático, já que os headers têm os mesmos nomes)
-- 5. Importe respeitando a MESMA ORDEM acima (tabelas-pai antes das filhas)
-- =====================================================================


