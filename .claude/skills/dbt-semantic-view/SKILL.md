---
name: dbt-semantic-view
description: Build or modify Snowflake Semantic Views through dbt. Use when creating semantic view models, defining facts/dimensions/metrics, or querying semantic views from downstream models.
allowed-tools: Bash(dbt *), Read, Write, Edit, Glob, Grep
---

# dbt Semantic View Skill

You are building Snowflake-native Semantic Views deployed through dbt. This is **not** the dbt Semantic Layer / MetricFlow — this is native Snowflake DDL that Cortex Analyst can consume directly.

## How to Deploy: Package vs. Macro (Read This First)

There are two approaches. Choose based on whether the project uses dbt-fusion:

### Approach A — dbt-fusion (Cloud CLI): Use a `run-operation` Macro

dbt-fusion's local SQL parser **rejects** Semantic View DDL because it tries to parse it as standard SQL before sending it to Snowflake. The workaround is a macro that uses `run_query()` to send the DDL directly to Snowflake, bypassing the parser entirely.

**Use this approach when:** the project runs `dbt-fusion` (i.e., uses the dbt Cloud CLI).

**File:** `macros/create_semantic_view.sql`

```sql
{% macro create_semantic_view() %}

{% set my_relation = ref('<model_name>') %}

{% set sql %}
CREATE OR REPLACE SEMANTIC VIEW {{ target.database }}.{{ target.schema }}.<view_name>
TABLES (
    <table_alias> AS {{ my_relation }}
)
DIMENSIONS (
    <table_alias>.<dim_name> AS <sql_expr> COMMENT = '<description>',
    ...
)
METRICS (
    <metric_name> AS <agg_expr> COMMENT = '<description>',
    ...
)
COMMENT = '<view-level description>'
{% endset %}

{% do run_query(sql) %}
{% do log('Semantic view <view_name> created in ' ~ target.database ~ '.' ~ target.schema, info=True) %}

{% endmacro %}
```

**Deploy with:**
```bash
dbt run-operation create_semantic_view
```

### Approach B — dbt Core (non-fusion): Use the Package Materialization

The `Snowflake-Labs/dbt_semantic_view` package (v1.0.3) is already in `packages.yml`. Write a model file with `materialized='semantic_view'` and run it normally.

**Use this approach when:** the project uses dbt Core (not the Cloud CLI / fusion).

```sql
-- models/marts/<view_name>.sql
{{ config(materialized='semantic_view') }}
TABLES(
  {{ ref('<model_name>') }}
)
DIMENSIONS (
  ...
)
METRICS (
  ...
)
COMMENT = '<view-level description>'
```

**Deploy with:**
```bash
dbt run --select <view_name>
```

---

## Native Snowflake Semantic View DDL Syntax

This is the correct native DDL. It differs from the dbt package's DSL — use this syntax in both the macro approach and the package approach.

### Full Structure

```sql
CREATE [OR REPLACE] SEMANTIC VIEW <database>.<schema>.<name>
TABLES (
    <table_alias> AS <table_ref>         -- alias BEFORE the table ref
    [ COMMENT = '<comment>' ]
)
[ RELATIONSHIPS (
    <alias1>.<col> REFERENCES <alias2>.<col> [ AS <rel_name> ]
) ]
[ DIMENSIONS (
    <table_alias>.<dim_name> AS <sql_expr> COMMENT = '<description>',
    ...
) ]
[ METRICS (
    <metric_name> AS <agg_expr> COMMENT = '<description>',
    ...
) ]
[ COMMENT = '<view-level description>' ]
```

### Critical Syntax Rules — These Will Cause Errors If Wrong

| Rule | Correct | Wrong |
|------|---------|-------|
| Table alias order | `alias AS {{ ref(...) }}` | `{{ ref(...) }} AS alias` |
| COMMENT format | `COMMENT = 'text'` | `COMMENT 'text'` (missing `=`) |
| DIMENSIONS format | `alias.col_name AS sql_expr` | `sql_expr AS col_name` |
| METRICS format | `metric_name AS agg_expr` | `agg_expr AS metric_name` |
| No COUNT() in METRICS | Use `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` | `COUNT(col)` or `COUNT(*)` |

### DIMENSIONS
Each dimension is scoped to a table alias and maps a logical name to a SQL expression:
```sql
DIMENSIONS (
    team_games.tournament_year AS tournament_year COMMENT = 'Calendar year of the tournament',
    team_games.team_name       AS team_name       COMMENT = 'Name of the team',
    team_games.is_winner       AS is_winner       COMMENT = 'True if this team won'
)
```

### METRICS
Metrics are view-scoped (no table alias prefix) and reference columns via `table_alias.col`:
```sql
METRICS (
    total_wins AS SUM(CASE WHEN team_games.is_winner = TRUE THEN 1 ELSE 0 END)
        COMMENT = 'Total games won',

    win_rate AS AVG(CASE WHEN team_games.is_winner = TRUE THEN 1.0 ELSE 0.0 END)
        COMMENT = 'Win percentage (0.0 to 1.0)',

    avg_margin AS AVG(team_games.point_differential)
        COMMENT = 'Average margin of victory or defeat'
)
```

**No `COUNT()` in METRICS** — Snowflake rejects it. Use `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` instead.

---

## Querying a Semantic View

Use Snowflake's `semantic_view()` table function — **never** a plain `SELECT FROM <view_name>`:

```sql
SELECT *
FROM semantic_view(
    <sem_view_name>
    METRICS  <metric1> [, <metric2>]
    DIMENSIONS <dim1> [, <dim2>]
    [ WHERE <predicate> ]
)
```

In a dbt model, reference the semantic view by its fully-qualified name (not `{{ ref() }}`):

```sql
{{ config(materialized='table') }}
select *
from semantic_view(
    {{ target.database }}.{{ target.schema }}.<view_name>
    METRICS total_wins, win_rate
    DIMENSIONS team_name, tournament_year
    WHERE tournament_year >= 2010
)
```

---

## Step-by-Step Approach

1. **Check if the project uses fusion** — run `dbt --version` or look for `dbt-fusion` in logs. If fusion, use the macro approach (Approach A).

2. **Preview the source data** — use `dbt show --select <model> --limit 10` to confirm column names before writing any DDL.

3. **Classify columns:**
   - DIMENSIONS: all columns (categorical, boolean, numeric — Snowflake puts everything here except aggregates)
   - METRICS: pre-defined aggregations using SUM/AVG with CASE expressions (no COUNT)

4. **Write the macro or model** following the syntax rules above.

5. **Deploy and verify:**
   - Fusion: `dbt run-operation create_semantic_view`
   - Core: `dbt run --select <view_name>`

6. **Confirm creation** in Snowflake:
   ```sql
   SHOW SEMANTIC VIEWS IN SCHEMA <database>.<schema>;
   ```

---

## Worked Example — Tournament Analytics

```sql
{% macro create_semantic_view() %}
{% set fct_relation = ref('fct_team_tournament_games') %}
{% set sql %}
CREATE OR REPLACE SEMANTIC VIEW {{ target.database }}.{{ target.schema }}.sem_tournament_analytics
TABLES (
    team_games AS {{ fct_relation }}
)
DIMENSIONS (
    team_games.tournament_year    AS tournament_year    COMMENT = 'Calendar year of the NCAA tournament',
    team_games.round_name         AS round_name         COMMENT = 'Human-readable round label',
    team_games.team_name          AS team_name          COMMENT = 'Name of the team this row represents',
    team_games.team_seed          AS team_seed          COMMENT = 'Tournament seed (1-16); lower is better',
    team_games.team_score         AS team_score         COMMENT = 'Points scored by this team',
    team_games.opponent_name      AS opponent_name      COMMENT = 'Name of the opposing team',
    team_games.is_winner          AS is_winner          COMMENT = 'True if this team won the game',
    team_games.point_differential AS point_differential COMMENT = 'Score margin from this team perspective; positive = win',
    team_games.is_upset           AS is_upset           COMMENT = 'True when the winner had a worse seed than the loser',
    team_games.is_underdog        AS is_underdog        COMMENT = 'True when this team had a worse seed than their opponent'
)
METRICS (
    total_wins AS SUM(CASE WHEN team_games.is_winner = TRUE THEN 1 ELSE 0 END)
        COMMENT = 'Total tournament games won',
    total_losses AS SUM(CASE WHEN team_games.is_winner = FALSE THEN 1 ELSE 0 END)
        COMMENT = 'Total tournament games lost',
    win_rate AS AVG(CASE WHEN team_games.is_winner = TRUE THEN 1.0 ELSE 0.0 END)
        COMMENT = 'Win percentage (0.0 to 1.0)',
    avg_point_differential AS AVG(team_games.point_differential)
        COMMENT = 'Average margin of victory (positive) or defeat (negative)',
    upset_wins AS SUM(CASE WHEN team_games.is_winner = TRUE AND team_games.is_underdog = TRUE THEN 1 ELSE 0 END)
        COMMENT = 'Games won as the underdog'
)
COMMENT = 'Snowflake Semantic View for NCAA March Madness analytics 1985-2024.'
{% endset %}
{% do run_query(sql) %}
{% do log('Semantic view created in ' ~ target.database ~ '.' ~ target.schema, info=True) %}
{% endmacro %}
```

---

## Common Mistakes

- **Wrong table alias order** — `alias AS table`, not `table AS alias`
- **Missing `=` in COMMENT** — `COMMENT = 'text'`, not `COMMENT 'text'`
- **Using COUNT() in METRICS** — not supported; use `SUM(CASE WHEN ... THEN 1 ELSE 0 END)`
- **Using `materialized='semantic_view'` with fusion** — the fusion parser will reject the DDL; use the macro approach instead
- **Querying with plain SELECT** — always use `semantic_view()` table function, not `SELECT * FROM <view_name>`
- **Using `{{ ref() }}` in downstream FROM clauses** — use fully-qualified name inside `semantic_view()` instead
