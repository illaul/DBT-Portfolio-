with source as (

    select * from {{ source('raw', 'raw_payments') }}

),

renamed as (

    select
        id                          as payment_id,
        order_id,
        lower(trim(payment_method)) as payment_method,
        -- source stores cents; convert to dollars once, here
        amount / 100.0              as amount
    from source

)

select * from renamed
