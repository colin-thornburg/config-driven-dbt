{{
    config(
        materialized='table',
        tags=['platform_demo', 'dimension']
    )
}}

{#
    ════════════════════════════════════════════════════════════════════════════
    DIMENSION: dim_product_platform
    ════════════════════════════════════════════════════════════════════════════
    
    Product dimension with automatic platform control fields.
    
    The platform automatically adds SCD Type 2 fields for tracking changes:
    - _surrogate_key: Unique key for each version
    - _valid_from/_valid_to: When this version was active
    - _is_current: Quick filter for current records
    
    ════════════════════════════════════════════════════════════════════════════
#}

{{ platform_entity(
    entity_type='dimension',
    primary_key='product_id',
    source_cdc_column='updated_at'
) }}

SELECT
    -- Primary key
    product_id,
    
    -- Product attributes
    product_name,
    sku,
    category,
    subcategory,
    
    -- Pricing
    unit_price,
    cost_price,
    unit_price - cost_price AS margin,
    ROUND((unit_price - cost_price) / NULLIF(unit_price, 0) * 100, 2) AS margin_pct,
    
    -- Status
    supplier_id,
    is_active,
    
    -- Source timestamps
    created_at,
    updated_at

FROM {{ ref('raw_products') }}

{{ platform_entity_end() }}

