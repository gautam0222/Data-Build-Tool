{{ config(materialized='view') }}

with returns as (
    select
        date_sk,
        store_sk,
        product_sk,
        returned_qty,
        return_reason,
        refund_amount
    from {{ ref('bronze_returns') }}
),

dates as (
    select
        date_sk,
        date
    from {{ ref('bronze_date') }}
),

stores as (
    select
        store_sk,
        store_name
    from {{ ref('bronze_store') }}
),

products as (
    select
        product_sk,
        category
    from {{ ref('bronze_product') }}
),

joined_data as (
    select
        dates.date as return_date,
        stores.store_name,
        products.category,
        returns.return_reason,
        returns.returned_qty,
        returns.refund_amount
    from returns
    inner join dates on returns.date_sk = dates.date_sk
    inner join stores on returns.store_sk = stores.store_sk
    inner join products on returns.product_sk = products.product_sk
)

select
    return_date,
    store_name,
    category,
    return_reason,
    sum(returned_qty) as total_returned_quantity,
    sum(refund_amount) as total_refund_amount
from joined_data
group by
    return_date,
    store_name,
    category,
    return_reason
order by
    total_refund_amount desc
