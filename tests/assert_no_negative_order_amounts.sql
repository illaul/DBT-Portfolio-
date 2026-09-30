-- Singular test: an order's total amount can never be negative.
-- Returns offending rows; the test passes when zero rows come back.
select
    order_id,
    amount
from {{ ref('fct_orders') }}
where amount < 0
