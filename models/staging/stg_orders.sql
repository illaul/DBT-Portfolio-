with source as (

    select * from {{ source('raw', 'raw_orders') }}

),

renamed as (

    select
        id                      as order_id,
        user_id                 as customer_id,
        cast(order_date as date) as order_date,
        lower(trim(status))     as status
    from source

)

select * from renamed
