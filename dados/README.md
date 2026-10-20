# Dados

Os CSVs não estão neste repositório (são grandes e têm licença própria). Baixe-os do Kaggle e salve em `dados/csv/`.

**Fonte:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). Consulte a página do dataset para a licença de uso.

## Como baixar

- **Pelo site:** abra o link acima, baixe o `.zip` e extraia os arquivos em `dados/csv/`.
- **Pela linha de comando** (precisa da CLI do Kaggle e de uma chave de API):

```bash
kaggle datasets download -d olistbr/brazilian-ecommerce -p dados/csv --unzip
```

## Arquivos esperados em `dados/csv/`

| Arquivo | Usado no projeto |
|---|---|
| `olist_customers_dataset.csv` | Sim |
| `olist_orders_dataset.csv` | Sim |
| `olist_order_items_dataset.csv` | Sim |
| `olist_order_payments_dataset.csv` | Sim |
| `olist_order_reviews_dataset.csv` | Sim |
| `olist_products_dataset.csv` | Sim |
| `olist_sellers_dataset.csv` | Sim |
| `product_category_name_translation.csv` | Sim |
| `olist_geolocation_dataset.csv` | Não (não é necessário para a análise) |

Depois de baixar, siga os passos da seção "Como reproduzir" do [README principal](../README.md).
