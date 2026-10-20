-- =====================================================================
-- PROJETO OLIST
-- Ordem de criação respeita as dependências de FK:
-- 1) tabelas sem dependência (product_category_name_translation, sellers, customers)
-- 2) products (depende da translation)
-- 3) orders (depende de customers)
-- 4) order_items, order_payments, order_reviews (dependem de orders + products/sellers)
-- (ordem inversa: filhas antes das pais, por causa das FKs)

DROP TABLE IF EXISTS order_reviews CASCADE;
DROP TABLE IF EXISTS order_payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS product_category_name_translation CASCADE;

-- ---------------------------------------------------------------------
-- 1. product_category_name_translation
-- ---------------------------------------------------------------------
CREATE TABLE product_category_name_translation (
    product_category_name          VARCHAR(100) PRIMARY KEY,
    product_category_name_english  VARCHAR(100) NOT NULL
);

-- ---------------------------------------------------------------------
-- 2. sellers
-- ---------------------------------------------------------------------
CREATE TABLE sellers (
    seller_id               VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix  VARCHAR(5)  NOT NULL,
    seller_city             VARCHAR(60) NOT NULL,
    seller_state            CHAR(2)     NOT NULL
);

-- ---------------------------------------------------------------------
-- 3. customers
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id               VARCHAR(32) PRIMARY KEY,
    customer_unique_id        VARCHAR(32) NOT NULL,
    customer_zip_code_prefix  VARCHAR(5)  NOT NULL,
    customer_city             VARCHAR(60) NOT NULL,
    customer_state            CHAR(2)     NOT NULL
);

-- ---------------------------------------------------------------------
-- 4. products
-- ---------------------------------------------------------------------
CREATE TABLE products (
    product_id                  VARCHAR(32) PRIMARY KEY,
    product_category_name       VARCHAR(100) NULL,
    product_name_lenght         SMALLINT NULL,
    product_description_lenght  INTEGER NULL,
    product_photos_qty          SMALLINT NULL,
    product_weight_g            NUMERIC(10,2) NULL,
    product_length_cm           NUMERIC(10,2) NULL,
    product_height_cm           NUMERIC(10,2) NULL,
    product_width_cm            NUMERIC(10,2) NULL,
    CONSTRAINT fk_products_category
        FOREIGN KEY (product_category_name)
        REFERENCES product_category_name_translation (product_category_name)
);

-- ---------------------------------------------------------------------
-- 5. orders
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id                       VARCHAR(32) PRIMARY KEY,
    customer_id                    VARCHAR(32) NOT NULL,
    order_status                   VARCHAR(20) NOT NULL,
    order_purchase_timestamp       TIMESTAMP NOT NULL,
    order_approved_at              TIMESTAMP NULL,
    order_delivered_carrier_date   TIMESTAMP NULL,
    order_delivered_customer_date  TIMESTAMP NULL,
    order_estimated_delivery_date  TIMESTAMP NOT NULL,
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
);

-- ---------------------------------------------------------------------
-- 6. order_items (chave composta: um pedido pode ter vários itens)
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_id             VARCHAR(32) NOT NULL,
    order_item_id        SMALLINT    NOT NULL,
    product_id           VARCHAR(32) NOT NULL,
    seller_id            VARCHAR(32) NOT NULL,
    shipping_limit_date  TIMESTAMP   NOT NULL,
    price                NUMERIC(10,2) NOT NULL,
    freight_value        NUMERIC(10,2) NOT NULL,
    CONSTRAINT pk_order_items PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id) REFERENCES products (product_id),
    CONSTRAINT fk_order_items_seller
        FOREIGN KEY (seller_id) REFERENCES sellers (seller_id)
);

-- ---------------------------------------------------------------------
-- 7. order_payments (chave composta: um pedido pode ter vários pagamentos,
--    ex.: parcelado com métodos diferentes)
-- ---------------------------------------------------------------------
CREATE TABLE order_payments (
    order_id              VARCHAR(32) NOT NULL,
    payment_sequential    SMALLINT    NOT NULL,
    payment_type          VARCHAR(20) NOT NULL,
    payment_installments  SMALLINT    NOT NULL,
    payment_value         NUMERIC(10,2) NOT NULL,
    CONSTRAINT pk_order_payments PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_order_payments_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

-- ---------------------------------------------------------------------
-- 8. order_reviews (chave composta: 789 review_id se repetem, mas o par
--    review_id + order_id é sempre único — validado nos CSVs)
-- ---------------------------------------------------------------------
CREATE TABLE order_reviews (
    review_id                VARCHAR(32) NOT NULL,
    order_id                 VARCHAR(32) NOT NULL,
    review_score             SMALLINT    NOT NULL,
    review_comment_title     VARCHAR(100) NULL,
    review_comment_message   TEXT NULL,
    review_creation_date     TIMESTAMP NOT NULL,
    review_answer_timestamp  TIMESTAMP NOT NULL,
    CONSTRAINT pk_order_reviews PRIMARY KEY (review_id, order_id),
    CONSTRAINT fk_order_reviews_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

-- ---------------------------------------------------------------------
-- Índices auxiliares nas FKs
-- ---------------------------------------------------------------------
CREATE INDEX idx_orders_customer_id        ON orders (customer_id);
CREATE INDEX idx_order_items_product_id    ON order_items (product_id);
CREATE INDEX idx_order_items_seller_id     ON order_items (seller_id);
CREATE INDEX idx_products_category_name    ON products (product_category_name);


