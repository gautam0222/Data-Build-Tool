# Data Build Tool — dbt + Databricks

An end-to-end dbt learning project that models retail data in Databricks using a medallion-style architecture. It demonstrates source definitions, layered transformations, reusable Jinja macros, schema and data-quality tests, CSV seeds, snapshots, and standalone analyses.

> **Security note:** Configure Databricks credentials with environment variables or a secret manager. Do not commit personal access tokens, `.env` files, or production credentials. If a token has ever been committed, revoke and replace it before making the repository public.

## What this project covers

- Connecting a dbt project to Databricks with separate development and production targets.
- Declaring raw Databricks relations as dbt sources.
- Building bronze, silver, and gold model layers.
- Configuring models at the project, folder, and model levels.
- Using `ref()` to define model dependencies and `source()` to reference raw data.
- Writing reusable macros and Jinja control flow.
- Loading and querying a CSV seed.
- Adding built-in and custom generic tests, plus a singular data test.
- Snapshotting a deduplicated items relation using the timestamp strategy.
- Writing analyses for exploration, variables, Jinja, macros, and DDL experiments.

## Architecture

```text
Databricks source schema
  ├── fact_sales, fact_returns
  ├── dim_customer, dim_date, dim_product, dim_store
  └── items
          │
          ▼
Bronze layer (source-aligned models)
  ├── bronze_sales, bronze_returns
  ├── bronze_customer, bronze_date, bronze_product, bronze_store
  └── schema: bronze
          │
          ├──────────────► silver_salesinfo (sales by product category and customer gender)
          └──────────────► silver_returns (returns and refunds by date, store, category, and reason)
                              schema: silver

items ──► source_gold_items (latest record per id) ──► gold_items snapshot
                                                         schema: gold
```

The target catalog is controlled by the active dbt target. Sources resolve to `{{ target.catalog }}.source`, so development and production can point at separate catalogs while using the same model SQL.

## Project contents

| Path | Purpose |
| --- | --- |
| `gautam_dbt/dbt_project.yml` | dbt project configuration, paths, schemas, and default materializations |
| `gautam_dbt/profiles.yml` | Databricks dev/prod connection profiles; token is read from `DATABRICKS_TOKEN` |
| `gautam_dbt/models/source/sources.yml` | Declares raw sales, returns, dimension, and items relations |
| `gautam_dbt/models/bronze/` | Source-aligned retail models and their properties/tests |
| `gautam_dbt/models/silver/` | Enriched aggregate models for sales and returns analysis |
| `gautam_dbt/models/gold/` | Deduplicated current-state items model used by the snapshot |
| `gautam_dbt/snapshots/gold_items.yml` | Timestamp-based snapshot configuration for item history |
| `gautam_dbt/tests/` | Singular negative-value test and custom generic non-negative test |
| `gautam_dbt/macros/` | Schema naming override and arithmetic macro |
| `gautam_dbt/seeds/lookup.csv` | Small customer lookup seed |
| `gautam_dbt/analyses/` | Compilable exploratory SQL and Jinja examples; not built by `dbt run` |
| `pyproject.toml`, `requirements.txt`, `uv.lock` | Python/dbt dependency definitions and lockfile |

## Data models

### Bronze

The bronze layer selects directly from declared sources. The project default is a table in the `bronze` schema, while several models override that default to materialize as views:

| Model | Source | Materialization | Notes |
| --- | --- | --- | --- |
| `bronze_sales` | `source.fact_sales` | View | Sales facts; has primary quality checks |
| `bronze_returns` | `source.fact_returns` | Table | Return facts |
| `bronze_customer` | `source.dim_customer` | Table | Customer dimension |
| `bronze_date` | `source.dim_date` | View | Date dimension |
| `bronze_product` | `source.dim_product` | View | Product dimension |
| `bronze_store` | `source.dim_store` | Table | Store dimension |

### Silver

| Model | Inputs | Output |
| --- | --- | --- |
| `silver_salesinfo` | Bronze sales, products, and customers | Total calculated gross sales grouped by product category and customer gender. The calculated gross amount uses `unit_price * quantity` through a macro. |
| `silver_returns` | Bronze returns, dates, stores, and products | Return quantity and refund amount grouped by return date, store, category, and reason, ordered by refund amount. This model explicitly materializes as a view. |

### Gold and snapshot

`source_gold_items` keeps the newest version of every item by assigning `row_number()` over `id`, ordered by `updateDate` descending. The `gold_items` snapshot tracks changes to that deduplicated relation with:

- `unique_key: id`
- `strategy: timestamp`
- `updated_at: updateDate`
- a current-row sentinel date of `9999-12-31`

This gives the project a slowly changing history of item attributes whenever the source timestamp advances.

## Data quality

`models/bronze/properties.yml` defines the following checks:

| Target | Test | Behaviour |
| --- | --- | --- |
| `bronze_sales.sales_id` | `not_null`, `unique` | Fails if a sales identifier is missing or duplicated. |
| `bronze_sales.gross_amount` | `generic_nonnegative` | Uses the project’s custom generic test to find values below zero. |
| `bronze_store.store_name` | `accepted_values` | Warns, rather than fails, when a store name is outside the five configured Megamart stores. |
| `bronze_sales` | `non_negative_test` | Singular test that returns rows where both gross and net amounts are negative. |

The generic test lives in `tests/generic/generic_nonnegative.sql`; singular tests live directly under `tests/`.

## Macros and Jinja examples

- `multiply(col1, col2)` renders a multiplication expression and is used in `silver_salesinfo` and an analysis query.
- `generate_schema_name` overrides dbt’s schema naming so configured schemas such as `bronze`, `silver`, and `gold` are used directly instead of being prefixed with the target schema.
- The analyses demonstrate `target.catalog`, `ref()`, variables, a Jinja list loop, conditional SQL, macro calls, and exploratory DDL/DML for the `items` source.

## Setup

### Prerequisites

- Python 3.12 or later
- Access to a Databricks SQL Warehouse
- A Databricks personal access token with the necessary catalog, schema, read, and write permissions
- Source relations in `<catalog>.source`: `fact_sales`, `fact_returns`, `dim_customer`, `dim_date`, `dim_product`, `dim_store`, and `items`

Install dependencies with either `uv` (the repository includes `uv.lock`) or `pip`:

```powershell
uv sync
# or
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Configure credentials

`gautam_dbt/profiles.yml` contains the workspace host, warehouse HTTP path, catalogs, and targets. Set the token only in your current shell or CI secret store:

```powershell
$env:DATABRICKS_TOKEN = "<your-databricks-personal-access-token>"
```

For a public fork, replace the workspace-specific host, HTTP path, and catalog names with your own values. Keep the token as an environment variable.

## Run the project

Run all commands from the repository root:

```powershell
dbt debug --project-dir .\gautam_dbt --profiles-dir .\gautam_dbt
dbt parse --project-dir .\gautam_dbt --profiles-dir .\gautam_dbt
dbt seed --project-dir .\gautam_dbt --profiles-dir .\gautam_dbt
dbt run --project-dir .\gautam_dbt --profiles-dir .\gautam_dbt
dbt test --project-dir .\gautam_dbt --profiles-dir .\gautam_dbt
dbt snapshot --project-dir .\gautam_dbt --profiles-dir .\gautam_dbt
```

Useful scoped runs:

```powershell
# Compile SQL without executing it in Databricks
dbt compile --project-dir .\gautam_dbt --profiles-dir .\gautam_dbt

# Build a model and its upstream dependencies, then test it
dbt build --select +silver_salesinfo --project-dir .\gautam_dbt --profiles-dir .\gautam_dbt

# Test only bronze models
dbt test --select path:models/bronze --project-dir .\gautam_dbt --profiles-dir .\gautam_dbt
```

To use the production target, add `--target prod` only after confirming the production catalog and permissions.

## Documentation and lineage

Generate dbt documentation and serve the lineage graph locally:

```powershell
dbt docs generate --project-dir .\gautam_dbt --profiles-dir .\gautam_dbt
dbt docs serve --project-dir .\gautam_dbt --profiles-dir .\gautam_dbt
```

`ref()` and `source()` create dbt’s dependency graph automatically. The graph will show the bronze-to-silver model dependencies and the path from `source.items` through `source_gold_items` to the `gold_items` snapshot.

## Before publishing to GitHub

- Revoke any access token that was previously stored in Git history, then create a new one.
- Confirm `DATABRICKS_TOKEN` is supplied through your shell, GitHub Actions secrets, or another secret manager.
- Do not commit `target/`, `logs/`, `.env`, virtual environments, or generated dbt artifacts.
- Review workspace host names, warehouse IDs, catalog names, and source data for anything that should remain private.
- Consider adding model and column descriptions to the YAML files so generated dbt docs are more informative.

## Technology

- dbt Core 1.12
- dbt-databricks 1.10
- Databricks SQL Warehouse
- Python 3.12+
