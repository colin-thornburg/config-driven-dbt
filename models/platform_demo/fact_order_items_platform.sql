{{
    config(
        materialized='table',
        tags=['platform_demo', 'bridge']
    )
}}

{#
    ════════════════════════════════════════════════════════════════════════════
    BRIDGE: fact_order_items_platform
    ════════════════════════════════════════════════════════════════════════════
    
    This model demonstrates the Platform Entity pattern for BRIDGE tables.
    
    Bridge tables connect two entities in a many-to-many relationship.
    Example: Orders ←→ Products (through order line items)
    
    WHAT HAPPENS AUTOMATICALLY:
    ──────────────────────────────────────────────────────────────────────────
    │ Field                    │ Purpose                              │
    ├──────────────────────────┼──────────────────────────────────────┤
    │ _relationship_created_at │ When this link was established       │
    │ _is_active               │ Is this relationship still active?   │
    │ _loaded_at               │ When dbt loaded this record          │
    │ _source_schema           │ Source schema name                   │
    │ _model_name              │ Model name for lineage               │
    │ _dbt_run_id              │ dbt invocation ID                    │
    
    RELATIONSHIPS (defined in schema.yml):
    ──────────────────────────────────────────────────────────────────────────
    - order_id → fact_orders_platform (many_to_one)
    - product_id → dim_product_platform (many_to_one)
    
    ════════════════════════════════════════════════════════════════════════════
#}

{{ platform_entity(
    entity_type='bridge'
) }}

SELECT
    -- Primary key
    order_item_id,
    
    -- Foreign keys (relationships)
    order_id,
    product_id,
    
    -- Line item details
    quantity,
    unit_price,
    line_total,
    discount_applied,
    
    -- Calculated fields
    unit_price * quantity AS gross_amount,
    line_total - discount_applied AS net_line_amount

FROM {{ ref('raw_order_items') }}

{{ platform_entity_end() }}

