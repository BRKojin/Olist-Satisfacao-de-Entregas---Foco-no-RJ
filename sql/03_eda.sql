-- ============================================================================
-- PROJETO OLIST · SATISFAÇÃO E ENTREGAS NO RIO DE JANEIRO (2016–2018)
-- Script de Análise Exploratória de Dados (EDA), Qualidade e Análises
-- Autor: Iago Kojin
-- Base de Dados: PostgreSQL
-- Pré-requisito: rodar antes 01_create_schema.sql e 02_import_data.sql
-- ============================================================================

-- ============================================================================
-- PARTE 1: AUDITORIA GERAL DE DADOS BRUTOS (DATA QUALITY INICIAL)
-- Objetivo: Mapear e documentar o volume de inconsistências da base importada.
-- ============================================================================

-- 1.1. Perfilamento de Nulos na Tabela Principal de Pedidos
SELECT
    COUNT(*) AS volume_total_pedidos,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS aprovacao_nula,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS postagem_nula,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS entrega_nula,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NOT NULL AND order_delivered_customer_date IS NULL) AS despachado_em_transito
FROM orders;

-- 1.2. Mapeamento de Inconsistências de Status vs. Dados Logísticos
SELECT
    COUNT(*) FILTER (WHERE order_status = 'canceled' AND order_delivered_carrier_date IS NOT NULL) AS cancelados_com_dados_logisticos,
    COUNT(*) FILTER (WHERE order_status = 'delivered' AND (order_delivered_customer_date IS NULL OR order_delivered_carrier_date IS NULL)) AS entregues_com_rastreio_corrompido
FROM orders;

-- 1.3. Auditoria de Avaliações Sem Conteúdo Textual
SELECT
    COUNT(*) AS total_avaliacoes,
    COUNT(*) FILTER (WHERE review_comment_title IS NULL AND review_comment_message IS NULL) AS avaliacoes_sem_texto_opcional
FROM order_reviews;

-- 1.4. Identificação de Produtos Sem Cadastro de Categoria ou Dimensões
SELECT
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS sem_categoria,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL AND product_length_cm IS NULL) AS sem_dimensoes_fisicas
FROM products;


-- ============================================================================
-- PARTE 2: INVESTIGAÇÃO DE REGISTROS ÓRFÃOS
-- Objetivo: Localizar registros sem correspondência nas tabelas relacionadas.
-- Nota: as 2 categorias de produto sem tradução foram resolvidas na carga
-- (02_import_data.sql), antes de importar a tabela products.
-- ============================================================================

-- 2.1. Investigação do Pedido Órfão em 'order_payments'
SELECT o.order_id, o.order_status
FROM orders o
LEFT JOIN order_payments op ON o.order_id = op.order_id
WHERE o.order_status = 'delivered' AND op.order_id IS NULL;


-- ============================================================================
-- PARTE 3: VALIDAÇÃO DOS PARÂMETROS MACROSCÓPICOS (LINHA DE BASE FIXA)
-- Objetivo: Aferição de volumes cadastrais e horizontes temporais absolutos.
-- ============================================================================

-- 3.1. Validação de Clientes Únicos Cadastrados
SELECT COUNT(DISTINCT customer_unique_id) AS total_clientes_cadastrados FROM customers;

-- 3.2. Validação de Vendedores Ativos Cadastrados
SELECT COUNT(DISTINCT seller_id) AS total_vendedores_cadastrados FROM sellers;

-- 3.3. Determinação do Horizonte Temporal Bruto da Base
SELECT
    MIN(order_purchase_timestamp) AS timestamp_primeira_interacao,
    MAX(order_purchase_timestamp) AS timestamp_ultima_interacao
FROM orders;


-- ============================================================================
-- PARTE 4: ENGENHARIA DE ATRIBUTOS E IMPLEMENTAÇÃO DA REGRA DE OURO
-- Objetivo: Criação da View unificada de pedidos consumados.
--
-- CONVENÇÃO DE MÉTRICAS USADA NO SCRIPT
--   * "receita"/"faturamento" nos Blocos 1 a 4 = SUM(payment_value) da view
--     (pagamentos do pedido, inclui frete).
--   * "faturamento" nos Blocos 6 a 8 = SUM(price) de order_items (apenas o preço
--     dos itens, sem frete), pois a análise é por categoria e por vendedor.
--   * "atrasado" compara apenas datas (sem horário): entrega > data estimada.
-- ============================================================================

CREATE OR REPLACE VIEW vw_pedidos AS
WITH pagamento AS (
  SELECT order_id, SUM(payment_value) AS receita
  FROM order_payments
  GROUP BY order_id
),
itens AS (
  SELECT order_id, COUNT(*) AS qtd_itens
  FROM order_items
  GROUP BY order_id
),
avaliacao AS (
  SELECT order_id, AVG(review_score) AS nota
  FROM order_reviews
  GROUP BY order_id
)
SELECT
  o.order_id,
  c.customer_unique_id,
  c.customer_state AS estado,
  DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
  pg.receita,
  it.qtd_itens,
  av.nota,
  (o.order_delivered_customer_date::date - o.order_purchase_timestamp::date) AS dias_entrega,
  (o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date) AS dias_atraso,
  (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date) AS atrasado,
  (o.order_delivered_carrier_date::date - o.order_purchase_timestamp::date) AS dias_postagem,
  (o.order_delivered_customer_date::date - o.order_delivered_carrier_date::date) AS dias_transporte
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
LEFT JOIN pagamento pg ON pg.order_id = o.order_id
LEFT JOIN itens it ON it.order_id = o.order_id
LEFT JOIN avaliacao av ON av.order_id = o.order_id
WHERE o.order_status = 'delivered';

-- ----------------------------------------------------------------------------
-- BLOCO 1: CENÁRIO GERAL DA PLATAFORMA (LINHA DE BASE)
-- Objetivo: Medir o tamanho do ecossistema e estabelecer médias globais de controle.
-- ----------------------------------------------------------------------------
SELECT
    ROUND(SUM(receita), 2)                                                  AS faturamento_total,
    COUNT(DISTINCT customer_unique_id)                                      AS total_clientes,
    COUNT(order_id)                                                         AS pedidos,
    ROUND(AVG(receita), 2)                                                  AS ticket_medio,
    ROUND(AVG(qtd_itens), 2)                                                AS itens_pedido,
    ROUND(COUNT(order_id)::numeric / COUNT(DISTINCT customer_unique_id), 2) AS pedidos_clientes,
    ROUND(AVG(nota), 2)                                                     AS nota
FROM vw_pedidos;


-- ----------------------------------------------------------------------------
-- BLOCO 2: EVOLUÇÃO TEMPORAL E SINAL DE RECORRÊNCIA
-- Objetivo: Mapear a tração de crescimento anual e mensal (MoM).
-- ----------------------------------------------------------------------------

-- 2.1. Faturamento Consolidado por Ano Civil
SELECT
    EXTRACT(YEAR FROM mes)::int AS ano,
    ROUND(SUM(receita), 2)      AS faturamento_anual
FROM vw_pedidos
GROUP BY 1
ORDER BY ano ASC;

-- 2.2. Visão Mensal Contínua e Monitoramento de Prazos
SELECT
    mes,
    COUNT(order_id)                                                             AS pedidos,
    ROUND(SUM(receita), 2)                                                      AS faturamento,
    ROUND(100.0 * (SUM(receita) / LAG(SUM(receita)) OVER (ORDER BY mes) - 1), 1) AS variacao_mom,
    ROUND(AVG(nota), 2)                                                         AS nota,
    ROUND(100.0 * COUNT(order_id) FILTER (WHERE atrasado = true) / COUNT(order_id), 1) AS pedidos_atrasados
FROM vw_pedidos
GROUP BY mes
ORDER BY mes;


-- ----------------------------------------------------------------------------
-- BLOCO 3: INFRAESTRUTURA FINANCEIRA E MEIOS DE PAGAMENTO
-- Objetivo: Avaliar a dependência da plataforma em relação aos canais de captura.
-- ----------------------------------------------------------------------------
SELECT
    payment_type,
    COUNT(DISTINCT o.order_id)                                                   AS pedidos,
    ROUND(SUM(op.payment_value), 2)                                              AS faturamento,
    ROUND(SUM(op.payment_value) / COUNT(DISTINCT o.order_id), 2)                 AS ticket_medio,
    ROUND(100.0 * SUM(op.payment_value) / SUM(SUM(op.payment_value)) OVER (), 1) AS pct_faturamento
FROM orders o
JOIN order_payments op ON o.order_id = op.order_id
WHERE o.order_status = 'delivered'
GROUP BY op.payment_type
ORDER BY faturamento DESC;

-- ----------------------------------------------------------------------------
-- BLOCO 4: FUNIL GEOGRÁFICO E O PARADOXO LOGÍSTICO (DESTINO)
-- Objetivo: Identificar anomalias regionais de satisfação quebrando postagem e viagem.
-- Escopo: estados de destino com pelo menos 500 pedidos entregues.
-- O faturamento e o pct_faturamento_total seguem para o cálculo o escopo de estados com pelo menos 500 pedidos entregues, o que corresponde a 17 estados.
-- ----------------------------------------------------------------------------
SELECT
    estado,
    COUNT(DISTINCT customer_unique_id)   AS clientes,
    COUNT(order_id)                      AS pedidos,
    ROUND(SUM(receita), 2)              AS faturamento,
  	ROUND(100.0 * SUM(receita) / SUM(SUM(receita)) OVER (), 2) AS pct_faturamento_total,
    ROUND(AVG(dias_entrega), 2)          AS media_tempo_espera,
    ROUND(AVG(nota), 2)                  AS nota,
    ROUND(AVG(dias_atraso), 2)           AS media_atraso,
    ROUND(100.0 * AVG(atrasado::int), 1) AS pct_atraso,
    ROUND(AVG(dias_postagem), 1)         AS dias_para_postar,
    ROUND(AVG(dias_transporte), 1)       AS dias_de_viagem
FROM vw_pedidos
GROUP BY estado
HAVING COUNT(order_id) >= 500
ORDER BY pedidos DESC;


-- 4.1. Nota e tempo de espera por estado SEM os pedidos atrasados
-- Mesmos estados do Bloco 4 (500+ pedidos entregues na base toda), para as
-- duas tabelas serem comparáveis. Pedidos sem data de entrega ficam de fora.
SELECT
    estado,
    COUNT(order_id)                AS pedidos_no_prazo,
    ROUND(AVG(dias_entrega), 1)    AS media_tempo_espera,
    ROUND(AVG(nota), 2)            AS nota
FROM vw_pedidos
WHERE atrasado = false
  AND estado IN (SELECT estado FROM vw_pedidos GROUP BY estado HAVING COUNT(order_id) >= 500)
GROUP BY estado
ORDER BY pedidos_no_prazo DESC;

-- 4.2. Prazo prometido x prazo real por estado
-- folga_media_dias = prazo prometido - dias até a entrega (menor folga = mais risco de atraso).
SELECT
    v.estado,
    COUNT(v.order_id)                                                                       AS pedidos,
    ROUND(AVG(o.order_estimated_delivery_date::date - o.order_purchase_timestamp::date), 1) AS prazo_prometido_dias,
    ROUND(AVG(v.dias_entrega), 1)                                                           AS dias_entrega_real,
    ROUND(AVG(o.order_estimated_delivery_date::date - o.order_purchase_timestamp::date - v.dias_entrega), 1) AS folga_media_dias,
    ROUND(100.0 * AVG(v.atrasado::int), 1)                                                  AS pct_atraso
FROM vw_pedidos v
JOIN orders o ON o.order_id = v.order_id
GROUP BY v.estado
HAVING COUNT(v.order_id) >= 500
ORDER BY pedidos DESC;


-- ----------------------------------------------------------------------------
-- BLOCO 5: SENSIBILIDADE DO ATRASO NA SATISFAÇÃO
-- Objetivo: Quantificar a partir de quantos dias o atraso gera notas críticas (1 e 2).
-- ----------------------------------------------------------------------------
SELECT
    CASE
        WHEN dias_atraso <= 0 THEN '1. No prazo'
        WHEN dias_atraso <= 3 THEN '2. Atraso de 1 a 3 dias'
        WHEN dias_atraso <= 7 THEN '3. Atraso de 4 a 7 dias'
        ELSE                       '4. Atraso acima de 7 dias'
    END                                     AS faixa_atraso,
    COUNT(order_id)                         AS pedidos,
    ROUND(AVG(nota), 2)                     AS nota_media,
    ROUND(100.0 * AVG((nota <= 2)::int), 1) AS pct_notas_ruins
FROM vw_pedidos
WHERE dias_atraso IS NOT NULL AND nota IS NOT NULL
GROUP BY 1
ORDER BY 1;


-- 5.1. Percentual geral de pedidos atrasados (denominador: pedidos com data de entrega)
SELECT
    COUNT(order_id)                         AS pedidos,
    COUNT(order_id) FILTER (WHERE atrasado) AS pedidos_atrasados,
    ROUND(100.0 * AVG(atrasado::int), 1)    AS pct_atrasados
FROM vw_pedidos
WHERE atrasado IS NOT NULL;


-- ----------------------------------------------------------------------------
-- BLOCO 6: SEGMENTAÇÃO DE PERFORMANCE POR CATEGORIA
-- Objetivo: Ranquear categorias e criar indicador de criticidade comercial.
-- ----------------------------------------------------------------------------
WITH base_categorias AS (
    SELECT
        COALESCE(t.product_category_name_english, p.product_category_name) AS categoria,
        COUNT(DISTINCT oi.order_id)                                        AS pedidos,
        SUM(oi.price)                                                      AS faturamento,
        ROUND(AVG(v.dias_entrega), 1)                                      AS tempo_espera_medio,
        ROUND(100.0 * AVG(v.atrasado::int), 1)                             AS pct_atraso,
        ROUND(AVG(v.nota), 2)                                              AS nota_media
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    LEFT JOIN product_category_name_translation t ON t.product_category_name = p.product_category_name
    JOIN vw_pedidos v ON v.order_id = oi.order_id
    WHERE p.product_category_name IS NOT NULL
    GROUP BY 1
    HAVING COUNT(DISTINCT oi.order_id) >= 100
)
SELECT
    categoria,
    pedidos,
    RANK() OVER (ORDER BY pedidos DESC)                       AS rank_volume_pedidos,
    faturamento,
    RANK() OVER (ORDER BY faturamento DESC)                   AS rank_faturamento,
    ROUND(100.0 * faturamento / SUM(faturamento) OVER (), 2)  AS pct_marketshare,
    tempo_espera_medio,
    pct_atraso,
    nota_media,
    CASE
        WHEN RANK() OVER (ORDER BY faturamento DESC) <= 15 AND nota_media < 4.00
        THEN 'CRÍTICO: Alto Faturamento e Baixa Avaliação'
        ELSE 'Ok / Saudável'
    END                                                       AS status_analise
FROM base_categorias
ORDER BY faturamento DESC;

-- ----------------------------------------------------------------------------
-- BLOCO 7: CONCENTRAÇÃO FINANCEIRA DE PARCEIROS (CURVA DE PARETO)
-- Objetivo: Mapear a vulnerabilidade da receita em relação à rampa de lojistas.
-- Faixas EXCLUSIVAS; use pct_receita_acumulado para ler 'top 10% = X% da receita' (linha 2).
-- ----------------------------------------------------------------------------
WITH faturamento_vendedores AS (
    SELECT
        s.seller_id,
        SUM(oi.price) AS faturamento
    FROM order_items oi
    JOIN sellers s    ON s.seller_id = oi.seller_id
    JOIN vw_pedidos v ON v.order_id = oi.order_id
    GROUP BY s.seller_id
),
ranking_acumulado AS (
    SELECT
        seller_id,
        faturamento,
        PERCENT_RANK() OVER (ORDER BY faturamento DESC) AS percentual_posicao
    FROM faturamento_vendedores
),
faixas_vendedores AS (
    SELECT
        seller_id,
        faturamento,
        CASE
            WHEN percentual_posicao <= 0.01 THEN '1. Top 1%'
            WHEN percentual_posicao <= 0.10 THEN '2. Do top 1% ao top 10%'
            WHEN percentual_posicao <= 0.20 THEN '3. Do top 10% ao top 20%'
            ELSE                                 '4. Demais vendedores'
        END AS faixa_vendedor
    FROM ranking_acumulado
)
SELECT
    faixa_vendedor,
    COUNT(DISTINCT seller_id) AS qnt_vendedores,
    ROUND(SUM(faturamento), 2) AS faturamento_por_faixa,
    ROUND(100.0 * SUM(faturamento) / SUM(SUM(faturamento)) OVER (), 1) AS pct_participacao_receita,
    ROUND(100.0 * SUM(SUM(faturamento)) OVER (ORDER BY faixa_vendedor)
          / SUM(SUM(faturamento)) OVER (), 1)                          AS pct_receita_acumulado
FROM faixas_vendedores
GROUP BY 1
ORDER BY 1;


-- ----------------------------------------------------------------------------
-- BLOCO 8: HIPÓTESE 1 · TESTE DE COMPARAÇÃO DE CATEGORIAS CRÍTICAS
-- Objetivo: Testar se o gargalo é interno dos Big Players de SP (A) ou estrutural do produto (B).
-- Definição: Big Players SP = vendedor de SP no top 20% de faturamento (soma de price).
-- ----------------------------------------------------------------------------
WITH vendedor_ranking AS (
    SELECT
        s.seller_id,
        s.seller_state,
        SUM(oi.price)                                     AS faturamento,
        PERCENT_RANK() OVER (ORDER BY SUM(oi.price) DESC) AS percentual
    FROM order_items oi
    JOIN sellers s    ON s.seller_id = oi.seller_id
    JOIN vw_pedidos v ON v.order_id = oi.order_id
    GROUP BY s.seller_id, s.seller_state
)
SELECT
    t.product_category_name_english           AS categoria,
    CASE
        WHEN vr.seller_state = 'SP' AND vr.percentual <= 0.20 THEN '1. Big Players SP'
        ELSE                                                       '2. Resto do Mercado'
    END                                       AS grupo_analise,
    COUNT(DISTINCT v.order_id)                AS pedidos,
    ROUND(AVG(v.nota), 2)                     AS nota_media,
    ROUND(AVG(v.dias_postagem), 1)            AS dias_para_postar,
    ROUND(AVG(v.dias_transporte), 1)          AS dias_de_viagem,
    ROUND(100.0 * AVG((v.nota <= 2)::int), 1) AS pct_notas_ruins
FROM vendedor_ranking vr
JOIN order_items oi ON oi.seller_id = vr.seller_id
JOIN products p     ON p.product_id = oi.product_id
JOIN product_category_name_translation t ON t.product_category_name = p.product_category_name
JOIN vw_pedidos v   ON v.order_id   = oi.order_id
WHERE t.product_category_name_english IN (
    'bed_bath_table',
    'computers_accessories',
    'furniture_decor',
    'telephony',
    'office_furniture'
)
GROUP BY 1, 2
ORDER BY categoria ASC, grupo_analise ASC;


-- ----------------------------------------------------------------------------
-- BLOCO 9: HIPÓTESE 2 · ORIGEM PROPORCIONAL DAS NOTAS CRÍTICAS NO RJ
-- Objetivo: Isolar se as notas ruins do Rio são um problema interestadual de rota ou local.
-- Escopo: pedidos entregues no RJ, por estado de origem do vendedor (origens com 100+ pedidos).
-- Obs.: um pedido com itens de mais de um vendedor entra em mais de uma linha.
-- ----------------------------------------------------------------------------
SELECT
    s.seller_state                            AS estado_origem_vendedor,
    COUNT(DISTINCT v.order_id)                AS total_pedidos_para_rj,
    ROUND(AVG(v.nota), 2)                     AS nota_media_no_rj,
    ROUND(100.0 * AVG((v.nota <= 2)::int), 1) AS pct_notas_ruins_no_rj,
    ROUND(AVG(v.dias_postagem), 1)            AS dias_para_postar,
    ROUND(AVG(v.dias_transporte), 1)          AS dias_de_viagem
FROM vw_pedidos v
JOIN order_items oi ON oi.order_id = v.order_id
JOIN sellers s      ON s.seller_id = oi.seller_id
WHERE v.estado = 'RJ'
GROUP BY s.seller_state
HAVING COUNT(DISTINCT v.order_id) >= 100
ORDER BY total_pedidos_para_rj DESC;

-- 9.1. Mesma origem do Bloco 9, com % de atraso e % exato dos pedidos do RJ
-- pct_pedidos_rj usa como denominador os pedidos DISTINTOS entregues no RJ
-- (um pedido com vendedores de estados diferentes entra em mais de uma linha,
-- então a soma da coluna pode passar de 100%).
SELECT
    s.seller_state                                   AS estado_origem_vendedor,
    COUNT(DISTINCT v.order_id)                       AS total_pedidos_para_rj,
    ROUND(100.0 * COUNT(DISTINCT v.order_id)
          / (SELECT COUNT(*) FROM vw_pedidos WHERE estado = 'RJ'), 1) AS pct_pedidos_rj,
    ROUND(100.0 * AVG(v.atrasado::int), 1)           AS pct_atraso,
    ROUND(100.0 * AVG((v.nota <= 2)::int), 1)        AS pct_notas_ruins_no_rj,
    ROUND(AVG(v.dias_transporte), 1)                 AS dias_de_viagem
FROM vw_pedidos v
JOIN order_items oi ON oi.order_id = v.order_id
JOIN sellers s      ON s.seller_id = oi.seller_id
WHERE v.estado = 'RJ'
GROUP BY s.seller_state
HAVING COUNT(DISTINCT v.order_id) >= 100
ORDER BY total_pedidos_para_rj DESC;


