{{
    config(
        materialized='incremental',
        unique_key='order_id',
        tags=['platform_demo', 'fact']
    )
}}

{#
    ════════════════════════════════════════════════════════════════════════════
    FACT: fact_orders_platform
    ════════════════════════════════════════════════════════════════════════════
    
    This model demonstrates the Platform Entity pattern for FACT tables.
    
    WHAT HAPPENS AUTOMATICALLY:
    ──────────────────────────────────────────────────────────────────────────
    The platform_entity() macro automatically injects these control fields:
    
    │ Field             │ Purpose                             │ Source          │
    ├───────────────────┼─────────────────────────────────────┼─────────────────┤
    │ _transaction_time │ When the business event occurred    │ CDC column      │
    │ _ingestion_time   │ When data was ingested to platform  │ CDC column      │
    │ _source_system    │ Which system sent the data          │ Config param    │
    │ _loaded_at        │ When dbt loaded this record         │ CURRENT_TIME    │
    │ _source_schema    │ Source schema name                  │ this.schema     │
    │ _model_name       │ Model name for lineage              │ this.name       │
    │ _dbt_run_id       │ dbt invocation ID for debugging     │ invocation_id   │
    
    INCREMENTAL PROCESSING:
    ──────────────────────────────────────────────────────────────────────────
    The platform uses _transaction_time for incremental loads:
    - Only new/changed records are processed
    - Uses the transaction_time_column for filtering
    
    RELATIONSHIPS (defined in schema.yml):
    ──────────────────────────────────────────────────────────────────────────
    - customer_id → dim_customer_platform (many_to_one)
    - order_id → fact_order_items_platform (one_to_many)
    
    The platform validates these relationships at compile time.
    
    ════════════════════════════════════════════════════════════════════════════
#}

{{ platform_entity(
    entity_type='fact',
    transaction_time_column='transaction_time',
    ingestion_time_column='ingestion_time',
    source_system='ecommerce_platform'
) }}

SELECT
    -- Primary key
    order_id,
    
    -- Foreign keys (relationships defined in schema.yml)
    customer_id,
    
    -- Order details
    order_date,
    order_status,
    
    -- Shipping
    shipping_address,
    shipping_city,
    shipping_state,
    shipping_postal,
    
    -- Financials
    total_amount,
    discount_amount,
    tax_amount,
    total_amount - discount_amount + tax_amount AS net_amount,
    payment_method,
    
    -- Source CDC columns (used by platform for incremental processing)
    transaction_time,
    ingestion_time

FROM {{ ref('raw_orders') }}

{% if is_incremental() %}
    -- Platform incremental filter: only process new/changed records
    WHERE transaction_time > (SELECT MAX(_transaction_time) FROM {{ this }})
{% endif %}

{{ platform_entity_end() }}

