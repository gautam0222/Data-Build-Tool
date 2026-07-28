with sales as 
(
    select 
        sales_id,
        product_sk,
        customer_sk,
        {{ multiply ('unit_price', 'quantity') }} as calculated_gross_amount,
        gross_amount,
        payment_method
    from 
        {{ref('bronze_sales')}}
),

products as 
(
    select 
        product_sk,
        category
    from 
        {{ref('bronze_product')}}
),

customers as 
(
    select 
        customer_sk,
        gender
    from 
        {{ref('bronze_customer')}}
),

joined_data as 
(
    select 
        sales.sales_id,
        sales.calculated_gross_amount,
        sales.gross_amount,
        sales.payment_method,
        products.category,
        customers.gender
    from 
        sales
    join 
        products on sales.product_sk = products.product_sk
    join 
        customers on sales.customer_sk = customers.customer_sk
)
select
    category,
    gender,
    sum(calculated_gross_amount) as total_calculated_gross_amount
from 
    joined_data
group by
    category, gender
order by
    total_calculated_gross_amount desc