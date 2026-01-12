{{
    config(
        materialized='table',
        tags=['platform_demo', 'dimension']
    )
}}

{#
    ════════════════════════════════════════════════════════════════════════════
    DIMENSION: dim_customer_platform
    ════════════════════════════════════════════════════════════════════════════
    
    This model demonstrates the Platform Entity pattern for DIMENSIONS.
    
    WHAT HAPPENS AUTOMATICALLY:
    ──────────────────────────────────────────────────────────────────────────
    The platform_entity() macro automatically injects these control fields:
    
    │ Field            │ Purpose                              │ Source          │
    ├──────────────────┼──────────────────────────────────────┼─────────────────┤
    │ _surrogate_key   │ Hash key for SCD Type 2              │ MD5(primary_key)│
    │ _valid_from      │ When this version became active      │ source CDC col  │
    │ _valid_to        │ When this version was superseded     │ '9999-12-31'    │
    │ _is_current      │ Is this the current version?         │ TRUE            │
    │ _loaded_at       │ When dbt loaded this record          │ CURRENT_TIME    │
    │ _source_schema   │ Source schema name                   │ this.schema     │
    │ _model_name      │ Model name for lineage               │ this.name       │
    │ _dbt_run_id      │ dbt invocation ID for debugging      │ invocation_id   │
    
    USER WRITES:
    ──────────────────────────────────────────────────────────────────────────
    The user only needs to write the business logic SELECT statement.
    All platform/infrastructure code is handled automatically.
    
    ════════════════════════════════════════════════════════════════════════════
#}

{{ platform_entity(
    entity_type='dimension',
    primary_key='customer_id',
    source_cdc_column='updated_at'
) }}

-- ═══════════════════════════════════════════════════════════════════════════
-- USER'S BUSINESS LOGIC (this is all they need to write!)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
    -- Primary key
    customer_id,
    
    -- Customer attributes
    first_name,
    last_name,
    first_name || ' ' || last_name AS full_name,
    email,
    phone,
    
    -- Address
    address_line1,
    city,
    state,
    postal_code,
    country,
    
    -- Business attributes
    is_active,
    created_at,
    updated_at

FROM {{ ref('raw_customers') }}

{{ platform_entity_end() }}

