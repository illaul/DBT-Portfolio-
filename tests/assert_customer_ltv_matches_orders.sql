-- Singular test: total lifetime value in dim_customers must reconcile
-- exactly with total order revenue in fct_orders (no fan-out, no drops).
with dim as (
    select sum(lifetime_value) as total from {{ ref('dim_customers') }}
),
fct as (
    select sum(amount) as total from {{ ref('fct_orders') }}
)
select dim.total as dim_total, fct.total as fct_total
from dim cross join fct
where abs(dim.total - fct.total) > 0.001
