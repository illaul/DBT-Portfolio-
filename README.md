# dbt_analytics_demo

A small, complete **analytics-engineering project** built with **dbt-core + DuckDB**.
It turns raw e-commerce data (customers, orders, payments) into a tested, documented
dimensional model, and it runs entirely on your laptop with no cloud account and no credentials.

![dbt](https://img.shields.io/badge/dbt-1.8%2B-FF694B?logo=dbt&logoColor=white)
![DuckDB](https://img.shields.io/badge/DuckDB-local-FFF000?logo=duckdb&logoColor=black)
![tests](https://img.shields.io/badge/data%20tests-29%20passing-brightgreen)

---

## What this project demonstrates

| Practice | Where |
|---|---|
| Declared **sources** over raw data | `models/staging/sources.yml` |
| **Layered modeling**: staging → marts | `models/staging/`, `models/marts/` |
| **Dimensional modeling**: a dimension and a fact table | `dim_customers`, `fct_orders` |
| **Materialization strategy** set centrally | `dbt_project.yml` (staging = `view`, marts = `table`) |
| **Generic tests**: `unique`, `not_null`, `relationships`, `accepted_values` | `*.yml` files |
| **Singular tests**: custom business-rule SQL | `tests/` |
| **Documentation + lineage graph** | descriptions in YAML, `dbt docs generate` |
| **Reproducible local dev** | seeds + DuckDB + a checked-in `profiles.yml` |

## Data lineage

```
seeds (CSV)             staging (views)          marts (tables)
─────────────           ───────────────          ──────────────
raw_customers  ───────▶ stg_customers  ─────────────────────────▶ dim_customers
raw_orders     ───────▶ stg_orders     ──┐                          ▲
raw_payments   ───────▶ stg_payments   ──┴──────▶ fct_orders ───────┘
```

- **`fct_orders`** has one row per order, with payment totals pivoted by payment method
  (credit card, bank transfer, coupon, gift card) and an overall `amount`.
- **`dim_customers`** has one row per customer, with `first_order_date`, `most_recent_order_date`,
  `number_of_orders` and `lifetime_value`. Customers who never ordered are kept with zeros.

The dataset is synthetic and jaffle-shop-style: 50 customers, 120 orders and 150 payments.
Payment amounts are stored in **cents** in the raw data and converted to dollars once, in staging.

## Project structure

```
.
├── dbt_project.yml              # project config + materialization strategy
├── profiles.yml                 # local DuckDB connection (no secrets)
├── requirements.txt             # dbt-core + dbt-duckdb
├── seeds/                       # raw CSV data loaded with `dbt seed`
│   ├── raw_customers.csv
│   ├── raw_orders.csv
│   └── raw_payments.csv
├── models/
│   ├── staging/                 # 1:1 with sources: rename, cast, clean (views)
│   │   ├── sources.yml
│   │   ├── stg_models.yml
│   │   ├── stg_customers.sql
│   │   ├── stg_orders.sql
│   │   └── stg_payments.sql
│   └── marts/                   # business-facing dimensional models (tables)
│       ├── marts_models.yml
│       ├── dim_customers.sql
│       └── fct_orders.sql
├── tests/                       # singular (custom SQL) data tests
│   ├── assert_no_negative_order_amounts.sql
│   └── assert_customer_ltv_matches_orders.sql
└── macros/
    └── generate_schema_name.sql # clean schema names: raw / staging / marts
```

## How to run it

Prerequisite: Python 3.9+.

```bash
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Then run the four commands:

```bash
dbt seed     # load the CSVs into DuckDB (schema: raw)
dbt run      # build 3 staging views + 2 mart tables
dbt test     # run all 29 data tests
dbt docs generate && dbt docs serve   # browse docs + the lineage graph at http://localhost:8080
```

`dbt build` runs seed, run and test together in dependency order.

`profiles.yml` sits in the project root, so dbt finds it automatically. The warehouse is written
to a local file called `dbt_analytics_demo.duckdb`, which is git-ignored. Open it with the DuckDB
CLI to query the models directly, for example `select * from marts.dim_customers order by lifetime_value desc`.

## Tests (29 total, all passing)

| Layer | Tests |
|---|---|
| Sources (6) | `unique` + `not_null` on each raw primary key |
| Staging (11) | PK `unique`/`not_null` on each model; `relationships` orders→customers and payments→orders; `accepted_values` on order status and payment method |
| Marts (10) | PK `unique`/`not_null`; `relationships` fct_orders→dim_customers; `accepted_values` on status; `not_null` on amounts and metrics |
| Singular (2) | `assert_no_negative_order_amounts`; `assert_customer_ltv_matches_orders` (total LTV reconciles exactly to total order revenue) |

## Interview talking points

**Why separate staging and marts?**
- *Staging* is the one place raw data gets cleaned: renaming (`id` → `customer_id`), casting,
  normalizing values (`lower(trim(status))`), and unit conversion (cents → dollars). Each staging
  model maps 1:1 to a source, and nothing downstream reads raw tables directly. If a source
  system changes, you fix it in one file.
- *Marts* hold business logic: joins, aggregations and metrics. They are shaped for the people
  and BI tools that consume them.
- Materializations follow the same split. Staging models are **views**, which are cheap, always
  fresh and never queried by end users. Marts are **tables**, which are fast for dashboards and
  stable for consumers. This is configured once in `dbt_project.yml` instead of in every model.

**Why dimension and fact tables?**
- A **fact** (`fct_orders`) records events at a clearly declared grain (one row per order) with
  additive measures you can sum.
- A **dimension** (`dim_customers`) describes entities (one row per customer) with attributes to
  filter and group by, plus handy pre-computed metrics like lifetime value.
- A star schema is intuitive for analysts, efficient for BI tools, and prevents double counting
  because every table has one grain. The `unique` tests enforce that grain.

**How do tests protect trust in the data?**
- `unique` + `not_null` on primary keys guarantee the grain. A bad join that fans out rows
  fails immediately.
- `relationships` catch orphaned records, such as a payment for an order that doesn't exist.
- `accepted_values` catch new or unexpected categories from upstream, such as a new order status
  that no one has mapped yet.
- Singular tests encode business rules. For example, no negative order totals, and total customer
  LTV must equal total order revenue, which proves the dimension neither drops nor duplicates money.
- In CI (`dbt build` on every pull request), a failing test blocks bad data *before* it reaches
  a dashboard. Stakeholders find out about problems from a red check, not from a wrong number in a meeting.

**Why sources + `ref()`?** They let dbt build the DAG automatically. That gives correct build order,
the lineage graph in the docs, and the ability to run a subset such as `dbt build -s +dim_customers`.

## Portable to Snowflake / BigQuery / Databricks

Nothing in the models is DuckDB-specific: they use standard SQL, `ref()` and `source()`. To run
the same project on a cloud warehouse, install that adapter (`dbt-snowflake`, `dbt-bigquery` or
`dbt-databricks`) and swap the **profile**. Add an output to `profiles.yml` (or to `~/.dbt/profiles.yml`
so credentials stay out of git) and point `target` at it:

```yaml
dbt_analytics_demo:
  target: snowflake
  outputs:
    dev:
      type: duckdb
      path: dbt_analytics_demo.duckdb
    snowflake:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: TRANSFORMER
      warehouse: TRANSFORMING
      database: ANALYTICS
      schema: dbt_dev
      threads: 8
```

Then run the same four commands. No model code changes.
